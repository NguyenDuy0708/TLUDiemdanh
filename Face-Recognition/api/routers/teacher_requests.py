from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import func, and_, or_
from typing import List, Optional
from pydantic import BaseModel
from datetime import datetime, date, time
import openpyxl
from io import BytesIO

from database import get_db
from models import User, Teacher, TeacherRequest, Class, Subject, AttendanceSession, AttendanceRecord, ClassStudent, Student
from routers.auth import require_teacher

router = APIRouter(prefix="/api/teacher", tags=["teacher-requests"])

# Pydantic models
class TeacherRequestCreate(BaseModel):
    request_type: str  # "nghỉ" or "dạy_bù"
    reason: str

    # For "nghỉ" requests
    class_id: Optional[int] = None
    subject_id: Optional[int] = None
    request_date: Optional[str] = None  # YYYY-MM-DD
    start_time: Optional[str] = None  # HH:MM:SS
    end_time: Optional[str] = None  # HH:MM:SS

    # For "dạy_bù" requests - original class (being cancelled)
    original_class_id: Optional[int] = None
    original_date: Optional[str] = None
    original_start_time: Optional[str] = None
    original_end_time: Optional[str] = None

    # For "dạy_bù" requests - makeup class (replacement)
    makeup_class_id: Optional[int] = None
    makeup_date: Optional[str] = None
    makeup_start_time: Optional[str] = None
    makeup_end_time: Optional[str] = None

class TeacherRequestUpdate(BaseModel):
    request_type: Optional[str] = None
    reason: Optional[str] = None
    class_id: Optional[int] = None
    subject_id: Optional[int] = None
    request_date: Optional[str] = None
    start_time: Optional[str] = None
    end_time: Optional[str] = None
    original_class_id: Optional[int] = None
    original_date: Optional[str] = None
    original_start_time: Optional[str] = None
    original_end_time: Optional[str] = None
    makeup_class_id: Optional[int] = None
    makeup_date: Optional[str] = None
    makeup_start_time: Optional[str] = None
    makeup_end_time: Optional[str] = None

class TeacherRequestResponse(BaseModel):
    id: int
    teacher_id: int
    teacher_name: str
    request_type: str
    reason: str
    class_id: Optional[int]
    class_name: Optional[str]
    subject_id: Optional[int]
    subject_name: Optional[str]
    request_date: Optional[str]
    start_time: Optional[str]
    end_time: Optional[str]
    original_class_id: Optional[int]
    original_class_name: Optional[str]
    original_date: Optional[str]
    original_start_time: Optional[str]
    original_end_time: Optional[str]
    makeup_class_id: Optional[int]
    makeup_class_name: Optional[str]
    makeup_date: Optional[str]
    makeup_start_time: Optional[str]
    makeup_end_time: Optional[str]
    status: str
    admin_note: Optional[str]
    created_at: datetime
    updated_at: Optional[datetime] = None

# Create new request
@router.post("/requests", response_model=TeacherRequestResponse)
def create_request(
    request_data: TeacherRequestCreate,
    user: User = Depends(require_teacher),
    db: Session = Depends(get_db)
):
    """Tạo yêu cầu nghỉ dạy hoặc dạy bù"""
    if not user.teacher:
        raise HTTPException(status_code=404, detail="Teacher profile not found")
    
    # Validate request_type
    if request_data.request_type not in ["nghỉ", "dạy_bù"]:
        raise HTTPException(status_code=400, detail="request_type must be 'nghỉ' or 'dạy_bù'")

    # Initialize variables
    request_date = None
    start_time = None
    end_time = None
    original_date = None
    original_start_time = None
    original_end_time = None
    makeup_date = None
    makeup_start_time = None
    makeup_end_time = None

    if request_data.request_type == "nghỉ":
        # Validate for "nghỉ" request
        if not request_data.class_id or not request_data.request_date or not request_data.start_time or not request_data.end_time:
            raise HTTPException(status_code=400, detail="For 'nghỉ' request, class_id, request_date, start_time, end_time are required")

        # Validate class_id
        cls = db.query(Class).filter(
            Class.id == request_data.class_id,
            Class.teacher_id == user.teacher.id
        ).first()
        if not cls:
            raise HTTPException(status_code=404, detail="Class not found or you don't have permission")

        # Parse date and time
        try:
            request_date = datetime.strptime(request_data.request_date, "%Y-%m-%d").date()
            start_time = datetime.strptime(request_data.start_time, "%H:%M:%S").time()
            end_time = datetime.strptime(request_data.end_time, "%H:%M:%S").time()
        except ValueError as e:
            raise HTTPException(status_code=400, detail=f"Invalid date/time format: {str(e)}")

    elif request_data.request_type == "dạy_bù":
        # Validate for "dạy_bù" request
        if not request_data.original_class_id or not request_data.original_date or not request_data.original_start_time or not request_data.original_end_time:
            raise HTTPException(status_code=400, detail="For 'dạy_bù' request, original_class_id, original_date, original_start_time, original_end_time are required")

        if not request_data.makeup_class_id or not request_data.makeup_date or not request_data.makeup_start_time or not request_data.makeup_end_time:
            raise HTTPException(status_code=400, detail="For 'dạy_bù' request, makeup_class_id, makeup_date, makeup_start_time, makeup_end_time are required")

        # Validate original class
        original_cls = db.query(Class).filter(
            Class.id == request_data.original_class_id,
            Class.teacher_id == user.teacher.id
        ).first()
        if not original_cls:
            raise HTTPException(status_code=404, detail="Original class not found or you don't have permission")

        # Validate makeup class
        makeup_cls = db.query(Class).filter(
            Class.id == request_data.makeup_class_id,
            Class.teacher_id == user.teacher.id
        ).first()
        if not makeup_cls:
            raise HTTPException(status_code=404, detail="Makeup class not found or you don't have permission")

        # Parse dates and times
        try:
            original_date = datetime.strptime(request_data.original_date, "%Y-%m-%d").date()
            original_start_time = datetime.strptime(request_data.original_start_time, "%H:%M:%S").time()
            original_end_time = datetime.strptime(request_data.original_end_time, "%H:%M:%S").time()
            makeup_date = datetime.strptime(request_data.makeup_date, "%Y-%m-%d").date()
            makeup_start_time = datetime.strptime(request_data.makeup_start_time, "%H:%M:%S").time()
            makeup_end_time = datetime.strptime(request_data.makeup_end_time, "%H:%M:%S").time()
        except ValueError as e:
            raise HTTPException(status_code=400, detail=f"Invalid date/time format: {str(e)}")

    # Validate subject_id if provided
    if request_data.subject_id:
        subject = db.query(Subject).filter(Subject.id == request_data.subject_id).first()
        if not subject:
            raise HTTPException(status_code=404, detail="Subject not found")

    # Create request
    new_request = TeacherRequest(
        teacher_id=user.teacher.id,
        request_type=request_data.request_type,
        reason=request_data.reason,
        class_id=request_data.class_id,
        subject_id=request_data.subject_id,
        request_date=request_date,
        start_time=start_time,
        end_time=end_time,
        original_class_id=request_data.original_class_id,
        original_date=original_date,
        original_start_time=original_start_time,
        original_end_time=original_end_time,
        makeup_class_id=request_data.makeup_class_id,
        makeup_date=makeup_date,
        makeup_start_time=makeup_start_time,
        makeup_end_time=makeup_end_time,
        status="pending"
    )
    
    db.add(new_request)
    db.commit()
    db.refresh(new_request)
    
    # Load relationships for response
    db.refresh(new_request)
    
    return TeacherRequestResponse(
        id=new_request.id,
        teacher_id=new_request.teacher_id,
        teacher_name=user.teacher.full_name,
        request_type=new_request.request_type,
        reason=new_request.reason,
        class_id=new_request.class_id,
        class_name=new_request.class_obj.class_name if new_request.class_obj else None,
        subject_id=new_request.subject_id,
        subject_name=new_request.subject.subject_name if new_request.subject else None,
        request_date=str(new_request.request_date) if new_request.request_date else None,
        start_time=str(new_request.start_time) if new_request.start_time else None,
        end_time=str(new_request.end_time) if new_request.end_time else None,
        original_class_id=new_request.original_class_id,
        original_class_name=new_request.original_class_obj.class_name if new_request.original_class_obj else None,
        original_date=str(new_request.original_date) if new_request.original_date else None,
        original_start_time=str(new_request.original_start_time) if new_request.original_start_time else None,
        original_end_time=str(new_request.original_end_time) if new_request.original_end_time else None,
        makeup_class_id=new_request.makeup_class_id,
        makeup_class_name=new_request.makeup_class_obj.class_name if new_request.makeup_class_obj else None,
        makeup_date=str(new_request.makeup_date) if new_request.makeup_date else None,
        makeup_start_time=str(new_request.makeup_start_time) if new_request.makeup_start_time else None,
        makeup_end_time=str(new_request.makeup_end_time) if new_request.makeup_end_time else None,
        status=new_request.status,
        admin_note=new_request.admin_note,
        created_at=new_request.created_at,
        updated_at=new_request.updated_at
    )

# Get all requests of current teacher
@router.get("/requests", response_model=List[TeacherRequestResponse])
def get_my_requests(
    status: Optional[str] = None,
    user: User = Depends(require_teacher),
    db: Session = Depends(get_db)
):
    """Xem danh sách yêu cầu của giảng viên"""
    if not user.teacher:
        raise HTTPException(status_code=404, detail="Teacher profile not found")
    
    # Build query with eager loading
    query = db.query(TeacherRequest).options(
        joinedload(TeacherRequest.class_obj),
        joinedload(TeacherRequest.original_class_obj),
        joinedload(TeacherRequest.makeup_class_obj),
        joinedload(TeacherRequest.subject),
        joinedload(TeacherRequest.teacher)
    ).filter(TeacherRequest.teacher_id == user.teacher.id)

    # Filter by status if provided
    if status:
        query = query.filter(TeacherRequest.status == status)

    requests = query.order_by(TeacherRequest.created_at.desc()).all()

    result = []
    for req in requests:
        result.append(TeacherRequestResponse(
            id=req.id,
            teacher_id=req.teacher_id,
            teacher_name=req.teacher.full_name,
            request_type=req.request_type,
            reason=req.reason,
            class_id=req.class_id,
            class_name=req.class_obj.class_name if req.class_obj else None,
            subject_id=req.subject_id,
            subject_name=req.subject.subject_name if req.subject else None,
            request_date=str(req.request_date) if req.request_date else None,
            start_time=str(req.start_time) if req.start_time else None,
            end_time=str(req.end_time) if req.end_time else None,
            original_class_id=req.original_class_id,
            original_class_name=req.original_class_obj.class_name if req.original_class_obj else None,
            original_date=str(req.original_date) if req.original_date else None,
            original_start_time=str(req.original_start_time) if req.original_start_time else None,
            original_end_time=str(req.original_end_time) if req.original_end_time else None,
            makeup_class_id=req.makeup_class_id,
            makeup_class_name=req.makeup_class_obj.class_name if req.makeup_class_obj else None,
            makeup_date=str(req.makeup_date) if req.makeup_date else None,
            makeup_start_time=str(req.makeup_start_time) if req.makeup_start_time else None,
            makeup_end_time=str(req.makeup_end_time) if req.makeup_end_time else None,
            status=req.status,
            admin_note=req.admin_note,
            created_at=req.created_at,
            updated_at=req.updated_at
        ))
    
    return result

# Update request (only if pending)
@router.put("/requests/{request_id}", response_model=TeacherRequestResponse)
def update_request(
    request_id: int,
    request_data: TeacherRequestUpdate,
    user: User = Depends(require_teacher),
    db: Session = Depends(get_db)
):
    """Sửa yêu cầu (chỉ khi đang pending)"""
    if not user.teacher:
        raise HTTPException(status_code=404, detail="Teacher profile not found")
    
    # Find request
    req = db.query(TeacherRequest).filter(
        TeacherRequest.id == request_id,
        TeacherRequest.teacher_id == user.teacher.id
    ).first()
    
    if not req:
        raise HTTPException(status_code=404, detail="Request not found")
    
    if req.status != "pending":
        raise HTTPException(status_code=400, detail="Can only edit pending requests")
    
    # Update fields
    if request_data.request_type:
        if request_data.request_type not in ["nghỉ", "dạy_bù"]:
            raise HTTPException(status_code=400, detail="request_type must be 'nghỉ' or 'dạy_bù'")
        req.request_type = request_data.request_type
    
    if request_data.reason:
        req.reason = request_data.reason
    
    if request_data.class_id is not None:
        if request_data.class_id > 0:
            cls = db.query(Class).filter(
                Class.id == request_data.class_id,
                Class.teacher_id == user.teacher.id
            ).first()
            if not cls:
                raise HTTPException(status_code=404, detail="Class not found or you don't have permission")
        req.class_id = request_data.class_id if request_data.class_id > 0 else None
    
    if request_data.subject_id is not None:
        if request_data.subject_id > 0:
            subject = db.query(Subject).filter(Subject.id == request_data.subject_id).first()
            if not subject:
                raise HTTPException(status_code=404, detail="Subject not found")
        req.subject_id = request_data.subject_id if request_data.subject_id > 0 else None
    
    if request_data.request_date:
        try:
            req.request_date = datetime.strptime(request_data.request_date, "%Y-%m-%d").date()
        except ValueError as e:
            raise HTTPException(status_code=400, detail=f"Invalid date format: {str(e)}")
    
    if request_data.start_time:
        try:
            req.start_time = datetime.strptime(request_data.start_time, "%H:%M:%S").time()
        except ValueError as e:
            raise HTTPException(status_code=400, detail=f"Invalid time format: {str(e)}")
    
    if request_data.end_time:
        try:
            req.end_time = datetime.strptime(request_data.end_time, "%H:%M:%S").time()
        except ValueError as e:
            raise HTTPException(status_code=400, detail=f"Invalid time format: {str(e)}")
    
    req.updated_at = datetime.utcnow()
    
    db.commit()
    db.refresh(req)
    
    return TeacherRequestResponse(
        id=req.id,
        teacher_id=req.teacher_id,
        teacher_name=req.teacher.full_name,
        request_type=req.request_type,
        reason=req.reason,
        class_id=req.class_id,
        class_name=req.class_obj.class_name if req.class_obj else None,
        subject_id=req.subject_id,
        subject_name=req.subject.subject_name if req.subject else None,
        request_date=str(req.request_date),
        start_time=str(req.start_time),
        end_time=str(req.end_time),
        status=req.status,
        admin_note=req.admin_note,
        created_at=req.created_at,
        updated_at=req.updated_at
    )

# Delete request (only if pending)
@router.delete("/requests/{request_id}")
def delete_request(
    request_id: int,
    user: User = Depends(require_teacher),
    db: Session = Depends(get_db)
):
    """Xóa yêu cầu (chỉ khi đang pending)"""
    if not user.teacher:
        raise HTTPException(status_code=404, detail="Teacher profile not found")

    # Find request
    req = db.query(TeacherRequest).filter(
        TeacherRequest.id == request_id,
        TeacherRequest.teacher_id == user.teacher.id
    ).first()

    if not req:
        raise HTTPException(status_code=404, detail="Request not found")

    if req.status != "pending":
        raise HTTPException(status_code=400, detail="Can only delete pending requests")

    db.delete(req)
    db.commit()

    return {"success": True, "message": "Request deleted successfully"}
