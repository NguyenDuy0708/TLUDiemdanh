from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session, joinedload
from typing import List, Optional
from pydantic import BaseModel
from datetime import datetime
import openpyxl
from io import BytesIO
from pathlib import Path

from database import get_db
from models import User, TeacherRequest, Class, Subject, AttendanceSession, AttendanceRecord, ClassStudent, Student
from routers.auth import require_admin

router = APIRouter(prefix="/api/admin", tags=["admin-requests"])

# Pydantic models
class ApproveRejectRequest(BaseModel):
    admin_note: Optional[str] = None

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
    # New fields for "dạy_bù"
    original_class_id: Optional[int] = None
    original_class_name: Optional[str] = None
    original_date: Optional[str] = None
    original_start_time: Optional[str] = None
    original_end_time: Optional[str] = None
    makeup_class_id: Optional[int] = None
    makeup_class_name: Optional[str] = None
    makeup_date: Optional[str] = None
    makeup_start_time: Optional[str] = None
    makeup_end_time: Optional[str] = None
    status: str
    admin_note: Optional[str]
    created_at: datetime
    updated_at: datetime

# Get all requests
@router.get("/requests", response_model=List[TeacherRequestResponse])
def get_all_requests(
    status: Optional[str] = None,
    teacher_id: Optional[int] = None,
    db: Session = Depends(get_db),
    _admin = Depends(require_admin)
):
    """Xem tất cả yêu cầu của giảng viên"""
    # Build query with eager loading
    query = db.query(TeacherRequest).options(
        joinedload(TeacherRequest.class_obj),
        joinedload(TeacherRequest.original_class_obj),
        joinedload(TeacherRequest.makeup_class_obj),
        joinedload(TeacherRequest.subject),
        joinedload(TeacherRequest.teacher)
    )
    
    # Filter by status if provided
    if status:
        query = query.filter(TeacherRequest.status == status)
    
    # Filter by teacher_id if provided
    if teacher_id:
        query = query.filter(TeacherRequest.teacher_id == teacher_id)
    
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
            # New fields for "dạy_bù"
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
            updated_at=req.updated_at or datetime.now()
        ))

    return result

# Approve request
@router.put("/requests/{request_id}/approve", response_model=TeacherRequestResponse)
def approve_request(
    request_id: int,
    data: ApproveRejectRequest,
    user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Duyệt yêu cầu"""
    # Find request
    req = db.query(TeacherRequest).filter(TeacherRequest.id == request_id).first()
    
    if not req:
        raise HTTPException(status_code=404, detail="Request not found")
    
    if req.status != "pending":
        raise HTTPException(status_code=400, detail="Can only approve pending requests")
    
    # Update status
    req.status = "approved"
    req.admin_note = data.admin_note
    req.approved_by = user.id
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
    )

# Reject request
@router.put("/requests/{request_id}/reject", response_model=TeacherRequestResponse)
def reject_request(
    request_id: int,
    data: ApproveRejectRequest,
    user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Từ chối yêu cầu"""
    # Find request
    req = db.query(TeacherRequest).filter(TeacherRequest.id == request_id).first()
    
    if not req:
        raise HTTPException(status_code=404, detail="Request not found")
    
    if req.status != "pending":
        raise HTTPException(status_code=400, detail="Can only reject pending requests")
    
    # Update status
    req.status = "rejected"
    req.admin_note = data.admin_note
    req.approved_by = user.id
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
    )

# Get attendance statistics for all classes
@router.get("/attendance/statistics")
def get_attendance_statistics(
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    class_id: Optional[int] = None,
    db: Session = Depends(get_db),
    _admin = Depends(require_admin)
):
    """Thống kê chuyên cần tổng hợp - Export to Excel"""
    try:
        # Parse dates
        if start_date:
            start_date_obj = datetime.strptime(start_date, "%Y-%m-%d").date()
        else:
            start_date_obj = None
        
        if end_date:
            end_date_obj = datetime.strptime(end_date, "%Y-%m-%d").date()
        else:
            end_date_obj = None
        
        # Build query for classes
        classes_query = db.query(Class)
        if class_id:
            classes_query = classes_query.filter(Class.id == class_id)
        
        classes = classes_query.all()
        
        if not classes:
            raise HTTPException(status_code=404, detail="No classes found")
        
        # Create workbook
        wb = openpyxl.Workbook()
        ws = wb.active
        ws.title = "Thống kê chuyên cần"
        
        # Header
        ws.append(["THỐNG KÊ CHUYÊN CẦN TỔNG HỢP"])
        ws.append([f"Ngày xuất: {datetime.now().strftime('%d/%m/%Y %H:%M')}"])
        if start_date_obj and end_date_obj:
            ws.append([f"Từ ngày: {start_date_obj.strftime('%d/%m/%Y')} - Đến ngày: {end_date_obj.strftime('%d/%m/%Y')}"])
        ws.append([])
        
        for cls in classes:
            # Class header
            ws.append([f"Lớp: {cls.class_name} ({cls.class_code})"])
            ws.append([f"Môn học: {cls.subject.subject_name}"])
            ws.append([f"Giảng viên: {cls.teacher.full_name}"])
            ws.append([])
            
            # Table header
            ws.append(["Mã SV", "Họ và tên", "Email", "Tổng buổi", "Có mặt", "Muộn", "Vắng", "Tỷ lệ vắng (%)"])
            
            # Get students in class
            enrollments = db.query(ClassStudent).filter(ClassStudent.class_id == cls.id).all()
            
            for enrollment in enrollments:
                student = enrollment.student
                
                # Build query for attendance sessions
                sessions_query = db.query(AttendanceSession).filter(
                    AttendanceSession.class_id == cls.id
                )
                if start_date_obj:
                    sessions_query = sessions_query.filter(AttendanceSession.session_date >= start_date_obj)
                if end_date_obj:
                    sessions_query = sessions_query.filter(AttendanceSession.session_date <= end_date_obj)
                
                total_sessions = sessions_query.count()
                
                if total_sessions == 0:
                    ws.append([
                        student.student_code,
                        student.full_name,
                        student.email or "",
                        0, 0, 0, 0, 0.0
                    ])
                    continue
                
                # Get attendance records
                session_ids = [s.id for s in sessions_query.all()]
                
                records = db.query(AttendanceRecord).filter(
                    AttendanceRecord.session_id.in_(session_ids),
                    AttendanceRecord.student_id == student.id
                ).all()
                
                present_count = sum(1 for r in records if r.status == "present")
                late_count = sum(1 for r in records if r.status == "late")
                absent_count = total_sessions - len(records)
                
                absence_rate = (absent_count / total_sessions * 100) if total_sessions > 0 else 0.0
                
                ws.append([
                    student.student_code,
                    student.full_name,
                    student.email or "",
                    total_sessions,
                    present_count,
                    late_count,
                    absent_count,
                    round(absence_rate, 2)
                ])
            
            ws.append([])
            ws.append([])

        # Generate filename
        filename = f"attendance_statistics_{datetime.now().strftime('%Y%m%d_%H%M%S')}.xlsx"

        # Save to host Downloads folder
        try:
            downloads_folder = Path.home() / "Downloads"
            downloads_folder.mkdir(parents=True, exist_ok=True)
            host_filepath = downloads_folder / filename
            wb.save(host_filepath)
            print(f"✅ File saved to host: {host_filepath}")
        except Exception as e:
            print(f"⚠️ Could not save to host Downloads: {e}")

        # Save to BytesIO for response
        output = BytesIO()
        wb.save(output)
        output.seek(0)

        # Return as downloadable file
        return StreamingResponse(
            output,
            media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            headers={"Content-Disposition": f"attachment; filename={filename}"}
        )
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Lỗi tạo báo cáo: {str(e)}")

