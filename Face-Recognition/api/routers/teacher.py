from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import func
from typing import List, Optional
from pydantic import BaseModel
from datetime import datetime, date, time
import os
import shutil
from pathlib import Path
import openpyxl
from io import BytesIO

from database import get_db
from models import User, Teacher, Class, Student, ClassStudent, AttendanceSession, AttendanceRecord, TeacherRequest
from routers.auth import require_teacher

router = APIRouter(prefix="/api/teacher", tags=["teacher"])

def get_request_status_for_schedule(db: Session, class_id: int, target_date: date, start_time: time, end_time: time):
    """
    Kiểm tra xem có yêu cầu nghỉ/dạy bù đã được duyệt cho lớp này vào thời gian này không
    Returns: None hoặc {"type": "nghỉ"/"dạy_bù", "reason": "...", "makeup_info": {...}}

    Logic:
    - Nghỉ: Check class_id, request_date, start_time, end_time -> return "nghỉ"
    - Dạy bù:
      * Check original_class_id, original_date, original_start_time, original_end_time -> return "nghỉ" (lớp bị hủy)
      * Check makeup_class_id, makeup_date, makeup_start_time, makeup_end_time -> return "dạy_bù" (lớp dạy bù)
    """
    # Check for "nghỉ" request
    nghỉ_request = db.query(TeacherRequest).filter(
        TeacherRequest.request_type == "nghỉ",
        TeacherRequest.class_id == class_id,
        TeacherRequest.request_date == target_date,
        TeacherRequest.start_time == start_time,
        TeacherRequest.end_time == end_time,
        TeacherRequest.status == "approved"
    ).first()

    if nghỉ_request:
        return {
            "type": "nghỉ",
            "reason": nghỉ_request.reason
        }

    # Check for "dạy_bù" request - original class (being cancelled)
    dạy_bù_original = db.query(TeacherRequest).filter(
        TeacherRequest.request_type == "dạy_bù",
        TeacherRequest.original_class_id == class_id,
        TeacherRequest.original_date == target_date,
        TeacherRequest.original_start_time == start_time,
        TeacherRequest.original_end_time == end_time,
        TeacherRequest.status == "approved"
    ).first()

    if dạy_bù_original:
        # This class is being cancelled, show as "nghỉ"
        makeup_info = None
        if dạy_bù_original.makeup_class_obj:
            makeup_info = {
                "class_name": dạy_bù_original.makeup_class_obj.class_name,
                "date": str(dạy_bù_original.makeup_date),
                "start_time": str(dạy_bù_original.makeup_start_time),
                "end_time": str(dạy_bù_original.makeup_end_time)
            }
        return {
            "type": "nghỉ",
            "reason": f"{dạy_bù_original.reason} (Sẽ dạy bù)",
            "makeup_info": makeup_info
        }

    # Check for "dạy_bù" request - makeup class (replacement)
    dạy_bù_makeup = db.query(TeacherRequest).filter(
        TeacherRequest.request_type == "dạy_bù",
        TeacherRequest.makeup_class_id == class_id,
        TeacherRequest.makeup_date == target_date,
        TeacherRequest.makeup_start_time == start_time,
        TeacherRequest.makeup_end_time == end_time,
        TeacherRequest.status == "approved"
    ).first()

    if dạy_bù_makeup:
        # This is a makeup class
        original_info = None
        if dạy_bù_makeup.original_class_obj:
            original_info = {
                "class_name": dạy_bù_makeup.original_class_obj.class_name,
                "date": str(dạy_bù_makeup.original_date),
                "start_time": str(dạy_bù_makeup.original_start_time),
                "end_time": str(dạy_bù_makeup.original_end_time)
            }
        return {
            "type": "dạy_bù",
            "reason": f"{dạy_bù_makeup.reason} (Bù cho buổi {original_info['date'] if original_info else 'trước'})",
            "original_info": original_info
        }

    return None

class ClassInfo(BaseModel):
    class_id: int
    class_code: str
    class_name: str
    subject_code: str
    subject_name: str
    credits: int
    semester: str
    year: int
    student_count: int
    schedules: List[dict]

class StudentInfo(BaseModel):
    student_id: int
    student_code: str
    full_name: str
    email: Optional[str]
    phone: Optional[str]
    year: Optional[int]
    has_face_data: bool

class AddStudentsRequest(BaseModel):
    student_ids: List[int]

class FaceImageInfo(BaseModel):
    image_path: str
    created_at: Optional[str]

class AttendanceInfo(BaseModel):
    student_id: int
    student_code: str
    full_name: str
    check_in_time: Optional[datetime]
    status: str
    confidence: Optional[float]

class ChangePasswordRequest(BaseModel):
    old_password: str
    new_password: str

class UpdateProfileRequest(BaseModel):
    full_name: str
    phone: Optional[str]
    department: Optional[str]

@router.get("/students", response_model=List[StudentInfo])
def get_all_students(
    search: Optional[str] = None,
    user: User = Depends(require_teacher),
    db: Session = Depends(get_db)
):
    """Get all students (for adding to class) - OPTIMIZED with search"""
    if not user.teacher:
        raise HTTPException(status_code=404, detail="Teacher profile not found")

    # Build query with search filter
    query = db.query(Student)
    if search:
        search_pattern = f"%{search}%"
        query = query.filter(
            (Student.full_name.like(search_pattern)) |
            (Student.student_code.like(search_pattern)) |
            (Student.email.like(search_pattern))
        )

    students = query.all()
    result = []
    for student in students:
        # Check if student has face data - use Path for better performance
        face_data_path = Path(f"Dataset/FaceData/processed/{student.student_code}")
        has_face_data = face_data_path.exists() and any(face_data_path.glob("*.jpg"))

        result.append(StudentInfo(
            student_id=student.id,
            student_code=student.student_code,
            full_name=student.full_name,
            email=student.email,
            phone=student.phone,
            year=student.year,
            has_face_data=has_face_data
        ))

    return result

@router.get("/my-classes", response_model=List[ClassInfo])
def get_my_classes(user: User = Depends(require_teacher), db: Session = Depends(get_db)):
    """Get teacher's classes - OPTIMIZED with eager loading"""
    if not user.teacher:
        raise HTTPException(status_code=404, detail="Teacher profile not found")

    # Eager load subject and schedules to avoid N+1 queries
    classes = db.query(Class).options(
        joinedload(Class.subject),
        joinedload(Class.schedules)
    ).filter(Class.teacher_id == user.teacher.id).all()

    result = []
    for cls in classes:
        # Use subquery for student count to avoid N+1
        student_count = db.query(func.count(ClassStudent.id)).filter(
            ClassStudent.class_id == cls.id
        ).scalar()

        schedules = []
        for schedule in cls.schedules:
            schedules.append({
                "day_of_week": schedule.day_of_week,
                "start_time": str(schedule.start_time),
                "end_time": str(schedule.end_time),
                "room": schedule.room,
                "mode": schedule.mode
            })

        result.append(ClassInfo(
            class_id=cls.id,
            class_code=cls.class_code,
            class_name=cls.class_name,
            subject_code=cls.subject.subject_code,
            subject_name=cls.subject.subject_name,
            credits=cls.subject.credits,
            semester=cls.semester,
            year=cls.year,
            student_count=student_count,
            schedules=schedules
        ))

    return result

@router.get("/my-schedule")
def get_my_schedule(
    schedule_date: Optional[str] = None,
    user: User = Depends(require_teacher),
    db: Session = Depends(get_db)
):
    """Get teacher's schedule for a specific date with request status"""
    if not user.teacher:
        raise HTTPException(status_code=404, detail="Teacher profile not found")

    # Parse date or use today
    if schedule_date:
        try:
            target_date = datetime.strptime(schedule_date, "%Y-%m-%d").date()
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD")
    else:
        target_date = date.today()

    day_of_week = target_date.isoweekday()  # 1=Monday, 7=Sunday

    # Get all classes with schedules
    classes = db.query(Class).options(
        joinedload(Class.subject),
        joinedload(Class.schedules)
    ).filter(Class.teacher_id == user.teacher.id).all()

    schedule_list = []
    for cls in classes:
        # Filter schedules for target day
        for schedule in cls.schedules:
            if schedule.day_of_week == day_of_week:
                # Check for approved request
                request_status = get_request_status_for_schedule(
                    db, cls.id, target_date, schedule.start_time, schedule.end_time
                )

                # Get student count
                student_count = db.query(func.count(ClassStudent.id)).filter(
                    ClassStudent.class_id == cls.id
                ).scalar()

                schedule_list.append({
                    "class_id": cls.id,
                    "class_code": cls.class_code,
                    "class_name": cls.class_name,
                    "subject_name": cls.subject.subject_name if cls.subject else None,
                    "start_time": str(schedule.start_time),
                    "end_time": str(schedule.end_time),
                    "room": schedule.room,
                    "mode": schedule.mode,
                    "student_count": student_count,
                    "request_status": request_status  # None hoặc {"type": "nghỉ"/"dạy_bù", "reason": "..."}
                })

    # Check for makeup classes on this date (even if no regular schedule)
    makeup_requests = db.query(TeacherRequest).filter(
        TeacherRequest.request_type == "dạy_bù",
        TeacherRequest.makeup_date == target_date,
        TeacherRequest.status == "approved"
    ).all()

    for makeup_req in makeup_requests:
        # Check if this makeup class belongs to this teacher
        makeup_class = db.query(Class).filter(Class.id == makeup_req.makeup_class_id).first()
        if makeup_class and makeup_class.teacher_id == user.teacher.id:
            # Check if already in schedule_list (to avoid duplicates)
            already_exists = any(
                s["class_id"] == makeup_class.id and
                s["start_time"] == str(makeup_req.makeup_start_time) and
                s["end_time"] == str(makeup_req.makeup_end_time)
                for s in schedule_list
            )

            if not already_exists:
                # Get student count
                student_count = db.query(func.count(ClassStudent.id)).filter(
                    ClassStudent.class_id == makeup_class.id
                ).scalar()

                # Get original info
                original_info = None
                if makeup_req.original_class_obj:
                    original_info = {
                        "class_name": makeup_req.original_class_obj.class_name,
                        "date": str(makeup_req.original_date),
                        "start_time": str(makeup_req.original_start_time),
                        "end_time": str(makeup_req.original_end_time)
                    }

                # Get room and mode from regular schedule (if exists)
                room = "TBA"
                mode = "offline"
                if makeup_class.schedules:
                    room = makeup_class.schedules[0].room
                    mode = makeup_class.schedules[0].mode

                schedule_list.append({
                    "class_id": makeup_class.id,
                    "class_code": makeup_class.class_code,
                    "class_name": makeup_class.class_name,
                    "subject_name": makeup_class.subject.subject_name if makeup_class.subject else None,
                    "start_time": str(makeup_req.makeup_start_time),
                    "end_time": str(makeup_req.makeup_end_time),
                    "room": room,
                    "mode": mode,
                    "student_count": student_count,
                    "request_status": {
                        "type": "dạy_bù",
                        "reason": f"{makeup_req.reason} (Bù cho buổi {original_info['date'] if original_info else 'trước'})",
                        "original_info": original_info
                    }
                })

    # Sort by start_time
    schedule_list.sort(key=lambda x: x["start_time"])

    return {
        "date": str(target_date),
        "day_of_week": day_of_week,
        "schedules": schedule_list
    }

@router.get("/classes/{class_id}/students", response_model=List[StudentInfo])
def get_class_students(class_id: int, user: User = Depends(require_teacher), db: Session = Depends(get_db)):
    """Get students in a class - OPTIMIZED with eager loading"""
    if not user.teacher:
        raise HTTPException(status_code=404, detail="Teacher profile not found")

    cls = db.query(Class).filter(Class.id == class_id, Class.teacher_id == user.teacher.id).first()
    if not cls:
        raise HTTPException(status_code=404, detail="Class not found or you don't have permission")

    # Eager load student data to avoid N+1 queries
    enrollments = db.query(ClassStudent).options(
        joinedload(ClassStudent.student)
    ).filter(ClassStudent.class_id == class_id).all()

    result = []
    for enrollment in enrollments:
        student = enrollment.student

        # Use Path for better performance
        face_data_path = Path("Dataset") / "FaceData" / "processed" / student.student_code
        has_face_data = face_data_path.exists() and any(face_data_path.glob("*.jpg"))

        result.append(StudentInfo(
            student_id=student.id,
            student_code=student.student_code,
            full_name=student.full_name,
            email=student.email,
            phone=student.phone,
            year=student.year,
            has_face_data=has_face_data
        ))

    return result

@router.post("/classes/{class_id}/students")
def add_students_to_class(class_id: int, request: AddStudentsRequest, user: User = Depends(require_teacher), db: Session = Depends(get_db)):
    if not user.teacher:
        raise HTTPException(status_code=404, detail="Teacher profile not found")

    cls = db.query(Class).filter(Class.id == class_id, Class.teacher_id == user.teacher.id).first()
    if not cls:
        raise HTTPException(status_code=404, detail="Class not found or you don't have permission")

    added_count = 0
    for student_id in request.student_ids:
        student = db.query(Student).filter(Student.id == student_id).first()
        if not student:
            continue

        existing = db.query(ClassStudent).filter(
            ClassStudent.class_id == class_id,
            ClassStudent.student_id == student_id
        ).first()

        if not existing:
            enrollment = ClassStudent(class_id=class_id, student_id=student_id)
            db.add(enrollment)
            added_count += 1

    db.commit()

    return {"message": f"Added {added_count} students to class", "added_count": added_count}

@router.delete("/classes/{class_id}/students/{student_id}")
def remove_student_from_class(class_id: int, student_id: int, user: User = Depends(require_teacher), db: Session = Depends(get_db)):
    if not user.teacher:
        raise HTTPException(status_code=404, detail="Teacher profile not found")

    cls = db.query(Class).filter(Class.id == class_id, Class.teacher_id == user.teacher.id).first()
    if not cls:
        raise HTTPException(status_code=404, detail="Class not found or you don't have permission")

    enrollment = db.query(ClassStudent).filter(
        ClassStudent.class_id == class_id,
        ClassStudent.student_id == student_id
    ).first()

    if not enrollment:
        raise HTTPException(status_code=404, detail="Student not enrolled in this class")

    db.delete(enrollment)
    db.commit()

    return {"message": "Student removed from class"}

@router.get("/students/{student_id}/face-images", response_model=List[FaceImageInfo])
def get_student_face_images(student_id: int, user: User = Depends(require_teacher), db: Session = Depends(get_db)):
    if not user.teacher:
        raise HTTPException(status_code=404, detail="Teacher profile not found")

    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    enrolled_classes = db.query(ClassStudent).filter(
        ClassStudent.student_id == student_id,
        ClassStudent.class_id.in_(
            db.query(Class.id).filter(Class.teacher_id == user.teacher.id)
        )
    ).first()

    if not enrolled_classes:
        raise HTTPException(status_code=403, detail="Student not in any of your classes")

    face_data_path = os.path.join("Dataset", "FaceData", "processed", student.student_code)

    if not os.path.exists(face_data_path):
        return []

    images = []
    for filename in os.listdir(face_data_path):
        if filename.endswith(('.jpg', '.jpeg', '.png')):
            image_path = os.path.join(face_data_path, filename)
            created_at = datetime.fromtimestamp(os.path.getctime(image_path)).isoformat()
            images.append(FaceImageInfo(
                image_path=image_path,
                created_at=created_at
            ))

    return images

@router.delete("/students/{student_id}/face-images")
def delete_student_face_images(student_id: int, user: User = Depends(require_teacher), db: Session = Depends(get_db)):
    if not user.teacher:
        raise HTTPException(status_code=404, detail="Teacher profile not found")

    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    enrolled_classes = db.query(ClassStudent).filter(
        ClassStudent.student_id == student_id,
        ClassStudent.class_id.in_(
            db.query(Class.id).filter(Class.teacher_id == user.teacher.id)
        )
    ).first()

    if not enrolled_classes:
        raise HTTPException(status_code=403, detail="Student not in any of your classes")

    face_data_path = os.path.join("Dataset", "FaceData", "processed", student.student_code)

    if not os.path.exists(face_data_path):
        return {"message": "No face images found", "deleted_count": 0}

    deleted_count = len(os.listdir(face_data_path))
    shutil.rmtree(face_data_path)

    return {"message": f"Deleted {deleted_count} face images", "deleted_count": deleted_count}

@router.get("/classes/{class_id}/attendance", response_model=List[AttendanceInfo])
def get_class_attendance(
    class_id: int,
    attendance_date: Optional[date] = None,
    start_time: Optional[str] = None,
    end_time: Optional[str] = None,
    user: User = Depends(require_teacher),
    db: Session = Depends(get_db)
):
    if not user.teacher:
        raise HTTPException(status_code=404, detail="Teacher profile not found")

    cls = db.query(Class).filter(Class.id == class_id, Class.teacher_id == user.teacher.id).first()
    if not cls:
        raise HTTPException(status_code=404, detail="Class not found or you don't have permission")

    if not attendance_date:
        attendance_date = date.today()

    # Parse time parameters if provided
    session_start = None
    session_end = None
    if start_time and end_time:
        try:
            session_start = time.fromisoformat(start_time)
            session_end = time.fromisoformat(end_time)
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid time format. Use HH:MM:SS")

    enrollments = db.query(ClassStudent).filter(ClassStudent.class_id == class_id).all()

    result = []
    for enrollment in enrollments:
        student = enrollment.student

        # Build query with optional time filter
        query = db.query(AttendanceRecord).join(AttendanceSession).filter(
            AttendanceSession.class_id == class_id,
            AttendanceRecord.student_id == student.id,
            AttendanceSession.session_date == attendance_date
        )

        # Add time filter if provided
        if session_start and session_end:
            query = query.filter(
                AttendanceSession.start_time == session_start,
                AttendanceSession.end_time == session_end
            )

        attendance_record = query.first()

        if attendance_record:
            result.append(AttendanceInfo(
                student_id=student.id,
                student_code=student.student_code,
                full_name=student.full_name,
                check_in_time=attendance_record.check_in_time,
                status=attendance_record.status,
                confidence=attendance_record.confidence
            ))
        else:
            result.append(AttendanceInfo(
                student_id=student.id,
                student_code=student.student_code,
                full_name=student.full_name,
                check_in_time=None,
                status="absent",
                confidence=None
            ))

    return result

class ManualAttendanceRequest(BaseModel):
    student_id: int
    status: str
    start_time: Optional[str] = None  # Format: "HH:MM:SS"
    end_time: Optional[str] = None    # Format: "HH:MM:SS"

class StudentCreateRequest(BaseModel):
    full_name: str
    email: Optional[str] = None
    phone: Optional[str] = None
    year: Optional[int] = None
    password: str

class StudentUpdateRequest(BaseModel):
    full_name: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    year: Optional[int] = None

@router.post("/classes/{class_id}/attendance/manual")
def mark_manual_attendance(
    class_id: int,
    request: ManualAttendanceRequest,
    user: User = Depends(require_teacher),
    db: Session = Depends(get_db)
):
    if not user.teacher:
        raise HTTPException(status_code=404, detail="Teacher profile not found")

    cls = db.query(Class).filter(Class.id == class_id, Class.teacher_id == user.teacher.id).first()
    if not cls:
        raise HTTPException(status_code=404, detail="Class not found or you don't have permission")

    enrollment = db.query(ClassStudent).filter(
        ClassStudent.class_id == class_id,
        ClassStudent.student_id == request.student_id
    ).first()
    if not enrollment:
        raise HTTPException(status_code=404, detail="Student not enrolled in this class")

    if request.status not in ["present", "late", "absent"]:
        raise HTTPException(status_code=400, detail="Invalid status. Must be: present, late, or absent")

    today = date.today()

    # Parse start_time and end_time if provided
    if request.start_time and request.end_time:
        try:
            session_start = time.fromisoformat(request.start_time)
            session_end = time.fromisoformat(request.end_time)
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid time format. Use HH:MM:SS")

        # Find session by date and time range
        session = db.query(AttendanceSession).filter(
            AttendanceSession.class_id == class_id,
            AttendanceSession.session_date == today,
            AttendanceSession.start_time == session_start,
            AttendanceSession.end_time == session_end
        ).first()
    else:
        # Fallback: find any session for today
        session = db.query(AttendanceSession).filter(
            AttendanceSession.class_id == class_id,
            func.date(AttendanceSession.created_at) == today
        ).first()
        session_start = datetime.now().time()
        session_end = datetime.now().time()

    if not session:
        session = AttendanceSession(
            class_id=class_id,
            session_date=today,
            start_time=session_start,
            end_time=session_end,
            created_by=user.id
        )
        db.add(session)
        db.commit()
        db.refresh(session)

    existing_record = db.query(AttendanceRecord).filter(
        AttendanceRecord.session_id == session.id,
        AttendanceRecord.student_id == request.student_id
    ).first()

    if existing_record:
        existing_record.status = request.status
        existing_record.check_in_time = datetime.now()
        db.commit()
        return {"message": "Attendance updated", "status": request.status}
    else:
        record = AttendanceRecord(
            session_id=session.id,
            student_id=request.student_id,
            status=request.status,
            check_in_time=datetime.now(),
            confidence=None
        )
        db.add(record)
        db.commit()
        return {"message": "Attendance marked", "status": request.status}

@router.post("/classes/{class_id}/students/new")
def create_and_add_student(
    class_id: int,
    student_data: StudentCreateRequest,
    user: User = Depends(require_teacher),
    db: Session = Depends(get_db)
):
    if not user.teacher:
        raise HTTPException(status_code=404, detail="Teacher profile not found")

    cls = db.query(Class).filter(Class.id == class_id, Class.teacher_id == user.teacher.id).first()
    if not cls:
        raise HTTPException(status_code=404, detail="Class not found or you don't have permission")

    last_student = db.query(Student).order_by(Student.id.desc()).first()
    next_number = 1 if not last_student else last_student.id + 1
    student_code = f"SV{next_number:03d}"

    student = Student(
        student_code=student_code,
        full_name=student_data.full_name,
        email=student_data.email,
        phone=student_data.phone,
        year=student_data.year,
        password=student_data.password
    )
    db.add(student)
    db.commit()
    db.refresh(student)

    user_account = User(
        username=student.student_code,
        password=student_data.password,
        role="student",
        student_id=student.id
    )
    db.add(user_account)

    enrollment = ClassStudent(
        class_id=class_id,
        student_id=student.id
    )
    db.add(enrollment)
    db.commit()

    return {
        "student_id": student.id,
        "student_code": student.student_code,
        "full_name": student.full_name,
        "message": "Student added to class successfully"
    }

@router.put("/classes/{class_id}/students/{student_id}")
def update_student_in_class(
    class_id: int,
    student_id: int,
    student_data: StudentUpdateRequest,
    user: User = Depends(require_teacher),
    db: Session = Depends(get_db)
):
    if not user.teacher:
        raise HTTPException(status_code=404, detail="Teacher profile not found")

    cls = db.query(Class).filter(Class.id == class_id, Class.teacher_id == user.teacher.id).first()
    if not cls:
        raise HTTPException(status_code=404, detail="Class not found or you don't have permission")

    enrollment = db.query(ClassStudent).filter(
        ClassStudent.class_id == class_id,
        ClassStudent.student_id == student_id
    ).first()
    if not enrollment:
        raise HTTPException(status_code=404, detail="Student not found in this class")

    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    if student_data.full_name is not None:
        student.full_name = student_data.full_name
    if student_data.email is not None:
        student.email = student_data.email
    if student_data.phone is not None:
        student.phone = student_data.phone
    if student_data.year is not None:
        student.year = student_data.year

    db.commit()
    db.refresh(student)

    return {
        "student_id": student.id,
        "student_code": student.student_code,
        "full_name": student.full_name,
        "email": student.email,
        "phone": student.phone,
        "year": student.year,
        "message": "Student updated successfully"
    }

@router.delete("/classes/{class_id}/students/{student_id}")
def remove_student_from_class(
    class_id: int,
    student_id: int,
    user: User = Depends(require_teacher),
    db: Session = Depends(get_db)
):
    if not user.teacher:
        raise HTTPException(status_code=404, detail="Teacher profile not found")

    cls = db.query(Class).filter(Class.id == class_id, Class.teacher_id == user.teacher.id).first()
    if not cls:
        raise HTTPException(status_code=404, detail="Class not found or you don't have permission")

    enrollment = db.query(ClassStudent).filter(
        ClassStudent.class_id == class_id,
        ClassStudent.student_id == student_id
    ).first()
    if not enrollment:
        raise HTTPException(status_code=404, detail="Student not found in this class")

    db.delete(enrollment)
    db.commit()

    return {"message": "Student removed from class successfully"}

@router.get("/classes/{class_id}/students/{student_id}/images")
def get_student_images(
    class_id: int,
    student_id: int,
    user: User = Depends(require_teacher),
    db: Session = Depends(get_db)
):
    if not user.teacher:
        raise HTTPException(status_code=404, detail="Teacher profile not found")

    cls = db.query(Class).filter(Class.id == class_id, Class.teacher_id == user.teacher.id).first()
    if not cls:
        raise HTTPException(status_code=404, detail="Class not found or you don't have permission")

    enrollment = db.query(ClassStudent).filter(
        ClassStudent.class_id == class_id,
        ClassStudent.student_id == student_id
    ).first()
    if not enrollment:
        raise HTTPException(status_code=404, detail="Student not found in this class")

    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    face_data_path = f"../Dataset/FaceData/processed/{student.student_code}"
    if not os.path.exists(face_data_path):
        return {"student_code": student.student_code, "images": []}

    images = []
    for filename in os.listdir(face_data_path):
        if filename.lower().endswith(('.jpg', '.jpeg', '.png')):
            image_path = os.path.join(face_data_path, filename)
            stat = os.stat(image_path)
            images.append({
                "filename": filename,
                "path": image_path,
                "created_at": datetime.fromtimestamp(stat.st_ctime).isoformat()
            })

    return {
        "student_code": student.student_code,
        "full_name": student.full_name,
        "images": images
    }


@router.post("/change-password")
def change_password(
    request: ChangePasswordRequest,
    user: User = Depends(require_teacher),
    db: Session = Depends(get_db)
):
    """Change teacher password"""
    if not user.teacher:
        raise HTTPException(status_code=404, detail="Teacher profile not found")

    # Verify old password
    if user.password != request.old_password:
        raise HTTPException(status_code=400, detail="Mật khẩu cũ không đúng")

    # Update password in both User and Teacher tables
    user.password = request.new_password
    user.teacher.password = request.new_password

    db.commit()

    return {
        "success": True,
        "message": "Đổi mật khẩu thành công"
    }

@router.put("/profile")
def update_profile(
    request: UpdateProfileRequest,
    user: User = Depends(require_teacher),
    db: Session = Depends(get_db)
):
    """Update teacher profile"""
    if not user.teacher:
        raise HTTPException(status_code=404, detail="Teacher profile not found")

    # Update User table
    user.full_name = request.full_name
    user.phone = request.phone

    # Update Teacher table
    user.teacher.full_name = request.full_name
    user.teacher.phone = request.phone
    user.teacher.department = request.department

    db.commit()

    return {
        "success": True,
        "message": "Cập nhật thông tin thành công"
    }

# Export students to Excel
@router.get("/students/export")
def export_students_excel(
    user: User = Depends(require_teacher),
    db: Session = Depends(get_db)
):
    """Export all students to Excel file (for teacher)"""
    try:
        if not user.teacher:
            raise HTTPException(status_code=404, detail="Teacher profile not found")

        # Get all students
        students = db.query(Student).all()

        # Create workbook
        wb = openpyxl.Workbook()
        ws = wb.active
        ws.title = "Danh sách sinh viên"

        # Header
        headers = ["Mã SV", "Họ và tên", "Email", "Số điện thoại", "Năm"]
        ws.append(headers)

        # Data rows
        for student in students:
            ws.append([
                student.student_code,
                student.full_name,
                student.email or "",
                student.phone or "",
                student.year or ""
            ])

        # Generate filename
        filename = f"students_{datetime.now().strftime('%Y%m%d_%H%M%S')}.xlsx"

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
        raise HTTPException(status_code=500, detail=f"Lỗi tạo file Excel: {str(e)}")
