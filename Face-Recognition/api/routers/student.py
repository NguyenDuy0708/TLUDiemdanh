from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from database import get_db
from models import User, Student, Class, ClassSchedule, ClassStudent, AttendanceSession, AttendanceRecord, Teacher, Subject, TeacherRequest
from routers.auth import require_student
from datetime import datetime, date, time
from typing import List
from pydantic import BaseModel
import os
import shutil
from pathlib import Path

router = APIRouter(prefix="/api/student", tags=["student"])

class ChangePasswordRequest(BaseModel):
    old_password: str
    new_password: str

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

@router.get("/my-schedule")
def get_my_schedule(
    schedule_date: str = None,
    user: User = Depends(require_student),
    db: Session = Depends(get_db)
):
    """Get student's schedule for a specific date - OPTIMIZED with eager loading"""
    from sqlalchemy.orm import joinedload

    if not user.student:
        raise HTTPException(status_code=404, detail="Student profile not found")

    target_date = datetime.strptime(schedule_date, "%Y-%m-%d").date() if schedule_date else date.today()
    day_of_week = target_date.isoweekday()

    # Eager load class_obj with teacher, subject, and schedules
    enrollments = db.query(ClassStudent).options(
        joinedload(ClassStudent.class_obj).joinedload(Class.teacher),
        joinedload(ClassStudent.class_obj).joinedload(Class.subject),
        joinedload(ClassStudent.class_obj).joinedload(Class.schedules)
    ).filter(ClassStudent.student_id == user.student.id).all()

    schedule_list = []
    enrolled_class_ids = []  # Track enrolled classes

    for enrollment in enrollments:
        cls = enrollment.class_obj
        enrolled_class_ids.append(cls.id)

        # Filter schedules for the target day (already loaded)
        schedules = [s for s in cls.schedules if s.day_of_week == day_of_week]

        for schedule in schedules:
            # Check for approved request
            request_status = get_request_status_for_schedule(
                db, cls.id, target_date, schedule.start_time, schedule.end_time
            )

            schedule_list.append({
                "class_id": cls.id,
                "class_code": cls.class_code,
                "class_name": cls.class_name,
                "subject_code": cls.subject.subject_code if cls.subject else None,
                "subject_name": cls.subject.subject_name if cls.subject else None,
                "teacher_code": cls.teacher.teacher_code if cls.teacher else None,
                "teacher_name": cls.teacher.full_name if cls.teacher else None,
                "start_time": str(schedule.start_time),
                "end_time": str(schedule.end_time),
                "room": schedule.room,
                "mode": schedule.mode,
                "day_of_week": schedule.day_of_week,
                "request_status": request_status  # None hoặc {"type": "nghỉ"/"dạy_bù", "reason": "..."}
            })

    # Check for makeup classes on this date (even if no regular schedule)
    makeup_requests = db.query(TeacherRequest).options(
        joinedload(TeacherRequest.makeup_class_obj).joinedload(Class.teacher),
        joinedload(TeacherRequest.makeup_class_obj).joinedload(Class.subject),
        joinedload(TeacherRequest.makeup_class_obj).joinedload(Class.schedules),
        joinedload(TeacherRequest.original_class_obj)
    ).filter(
        TeacherRequest.request_type == "dạy_bù",
        TeacherRequest.makeup_date == target_date,
        TeacherRequest.status == "approved",
        TeacherRequest.makeup_class_id.in_(enrolled_class_ids)  # Only enrolled classes
    ).all()

    for makeup_req in makeup_requests:
        makeup_class = makeup_req.makeup_class_obj
        if makeup_class:
            # Check if already in schedule_list (to avoid duplicates)
            already_exists = any(
                s["class_id"] == makeup_class.id and
                s["start_time"] == str(makeup_req.makeup_start_time) and
                s["end_time"] == str(makeup_req.makeup_end_time)
                for s in schedule_list
            )

            if not already_exists:
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
                    "subject_code": makeup_class.subject.subject_code if makeup_class.subject else None,
                    "subject_name": makeup_class.subject.subject_name if makeup_class.subject else None,
                    "teacher_code": makeup_class.teacher.teacher_code if makeup_class.teacher else None,
                    "teacher_name": makeup_class.teacher.full_name if makeup_class.teacher else None,
                    "start_time": str(makeup_req.makeup_start_time),
                    "end_time": str(makeup_req.makeup_end_time),
                    "room": room,
                    "mode": mode,
                    "day_of_week": day_of_week,
                    "request_status": {
                        "type": "dạy_bù",
                        "reason": f"{makeup_req.reason} (Bù cho buổi {original_info['date'] if original_info else 'trước'})",
                        "original_info": original_info
                    }
                })

    schedule_list.sort(key=lambda x: x["start_time"])

    return {
        "date": str(target_date),
        "day_of_week": day_of_week,
        "schedules": schedule_list
    }

@router.get("/my-classes")
def get_my_classes(
    user: User = Depends(require_student),
    db: Session = Depends(get_db)
):
    """Get student's classes - OPTIMIZED with eager loading"""
    from sqlalchemy.orm import joinedload

    if not user.student:
        raise HTTPException(status_code=404, detail="Student profile not found")

    # Eager load class_obj with teacher, subject, and schedules
    enrollments = db.query(ClassStudent).options(
        joinedload(ClassStudent.class_obj).joinedload(Class.teacher),
        joinedload(ClassStudent.class_obj).joinedload(Class.subject),
        joinedload(ClassStudent.class_obj).joinedload(Class.schedules)
    ).filter(ClassStudent.student_id == user.student.id).all()

    classes = []
    for enrollment in enrollments:
        cls = enrollment.class_obj

        schedule_list = []
        for schedule in cls.schedules:
            schedule_list.append({
                "day_of_week": schedule.day_of_week,
                "start_time": str(schedule.start_time),
                "end_time": str(schedule.end_time),
                "room": schedule.room,
                "mode": schedule.mode
            })

        classes.append({
            "class_id": cls.id,
            "class_code": cls.class_code,
            "class_name": cls.class_name,
            "subject_code": cls.subject.subject_code if cls.subject else None,
            "subject_name": cls.subject.subject_name if cls.subject else None,
            "credits": cls.subject.credits if cls.subject else None,
            "teacher_code": cls.teacher.teacher_code if cls.teacher else None,
            "teacher_name": cls.teacher.full_name if cls.teacher else None,
            "semester": cls.semester,
            "year": cls.year,
            "schedules": schedule_list
        })

    return classes

@router.get("/my-attendance")
def get_my_attendance(
    class_id: int = None,
    user: User = Depends(require_student),
    db: Session = Depends(get_db)
):
    if not user.student:
        raise HTTPException(status_code=404, detail="Student profile not found")
    
    if class_id:
        enrollment = db.query(ClassStudent).filter(
            ClassStudent.student_id == user.student.id,
            ClassStudent.class_id == class_id
        ).first()
        if not enrollment:
            raise HTTPException(status_code=404, detail="Not enrolled in this class")
        
        sessions = db.query(AttendanceSession).filter(AttendanceSession.class_id == class_id).all()
    else:
        enrollments = db.query(ClassStudent).filter(ClassStudent.student_id == user.student.id).all()
        class_ids = [e.class_id for e in enrollments]
        sessions = db.query(AttendanceSession).filter(AttendanceSession.class_id.in_(class_ids)).all()
    
    attendance_records = []
    for session in sessions:
        cls = db.query(Class).filter(Class.id == session.class_id).first()
        record = db.query(AttendanceRecord).filter(
            AttendanceRecord.session_id == session.id,
            AttendanceRecord.student_id == user.student.id
        ).first()
        
        attendance_records.append({
            "session_id": session.id,
            "class_code": cls.class_code,
            "class_name": cls.class_name,
            "session_date": str(session.session_date),
            "start_time": str(session.start_time),
            "end_time": str(session.end_time),
            "status": record.status if record else "absent",
            "check_in_time": str(record.check_in_time) if record and record.check_in_time else None,
            "confidence": record.confidence if record else None
        })
    
    attendance_records.sort(key=lambda x: x["session_date"], reverse=True)
    
    return attendance_records

@router.post("/check-in")
async def student_check_in(
    class_id: int,
    image_base64: str,
    user: User = Depends(require_student),
    db: Session = Depends(get_db)
):
    if not user.student:
        raise HTTPException(status_code=404, detail="Student profile not found")
    
    enrollment = db.query(ClassStudent).filter(
        ClassStudent.student_id == user.student.id,
        ClassStudent.class_id == class_id
    ).first()
    if not enrollment:
        raise HTTPException(status_code=404, detail="Not enrolled in this class")
    
    today = date.today()
    now = datetime.now()
    current_time = now.time()
    day_of_week = today.isoweekday()
    
    schedule = db.query(ClassSchedule).filter(
        ClassSchedule.class_id == class_id,
        ClassSchedule.day_of_week == day_of_week
    ).first()
    
    if not schedule:
        raise HTTPException(status_code=400, detail="No class scheduled for today")
    
    if current_time < schedule.start_time or current_time > schedule.end_time:
        raise HTTPException(status_code=400, detail=f"Check-in only allowed between {schedule.start_time} and {schedule.end_time}")
    
    session = db.query(AttendanceSession).filter(
        AttendanceSession.class_id == class_id,
        AttendanceSession.session_date == today
    ).first()
    
    if not session:
        session = AttendanceSession(
            class_id=class_id,
            session_date=today,
            start_time=schedule.start_time,
            end_time=schedule.end_time,
            created_by=user.id
        )
        db.add(session)
        db.commit()
        db.refresh(session)
    
    existing_record = db.query(AttendanceRecord).filter(
        AttendanceRecord.session_id == session.id,
        AttendanceRecord.student_id == user.student.id
    ).first()
    
    if existing_record:
        raise HTTPException(status_code=400, detail="Already checked in for this session")
    
    import base64
    from services.face_recognition import face_recognition_service
    
    try:
        image_data = base64.b64decode(image_base64)
        result = await face_recognition_service.recognize_face(image_data)
        
        if not result or not result.get("student_code"):
            raise HTTPException(status_code=400, detail="Face not recognized")
        
        if result["student_code"] != user.student.student_code:
            raise HTTPException(status_code=400, detail="Face does not match your profile")
        
        status = "present"
        if current_time > schedule.start_time:
            time_diff = (datetime.combine(today, current_time) - datetime.combine(today, schedule.start_time)).total_seconds() / 60
            if time_diff > 15:
                status = "late"
        
        record = AttendanceRecord(
            session_id=session.id,
            student_id=user.student.id,
            status=status,
            check_in_time=now,
            confidence=result.get("confidence")
        )
        db.add(record)
        db.commit()
        
        return {
            "success": True,
            "status": status,
            "check_in_time": str(now),
            "confidence": result.get("confidence"),
            "message": f"Checked in successfully as {status}"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Check-in failed: {str(e)}")


@router.post("/capture-face")
async def capture_face(
    user: User = Depends(require_student),
    db: Session = Depends(get_db)
):
    """Capture face images using computer camera (student only) - ONLY CAPTURE, NO TRAINING"""
    import subprocess
    import sys

    if not user.student:
        raise HTTPException(status_code=404, detail="Student profile not found")

    student_code = user.student.student_code

    # Path to capture script
    project_root = Path(__file__).parent.parent.parent
    capture_script = project_root / "src" / "capture.py"

    if not capture_script.exists():
        raise HTTPException(status_code=500, detail=f"Capture script not found: {capture_script}")

    try:
        # Run capture script
        print(f"Starting capture for {student_code}...")
        result = subprocess.run(
            [sys.executable, str(capture_script), student_code],
            cwd=str(project_root / "src"),
            capture_output=True,
            text=True,
            timeout=300  # 5 minutes timeout
        )

        print("Capture stdout:", result.stdout)
        if result.stderr:
            print("Capture stderr:", result.stderr)

        if result.returncode != 0:
            return {
                "success": False,
                "message": f"Capture failed: {result.stderr or 'Unknown error'}"
            }

        # Count captured images
        raw_dir = project_root / "Dataset" / "FaceData" / "raw" / student_code
        if raw_dir.exists():
            images_count = len(list(raw_dir.glob("*.jpg")))
        else:
            images_count = 0

        return {
            "success": True,
            "message": f"Đã chụp {images_count} ảnh thành công cho {user.student.full_name}. Vui lòng bấm 'Train Model' để hoàn tất.",
            "images_count": images_count,
            "student_code": student_code,
            "student_name": user.student.full_name
        }

    except subprocess.TimeoutExpired:
        return {
            "success": False,
            "message": "Capture timeout (exceeded 5 minutes)"
        }
    except Exception as e:
        return {
            "success": False,
            "message": f"Capture error: {str(e)}"
        }


@router.post("/train-model")
async def train_model(
    user: User = Depends(require_student),
    db: Session = Depends(get_db)
):
    """Train face recognition model (student only)"""
    import asyncio

    if not user.student:
        raise HTTPException(status_code=404, detail="Student profile not found")

    student_code = user.student.student_code

    # Check if images exist
    project_root = Path(__file__).parent.parent.parent
    raw_dir = project_root / "Dataset" / "FaceData" / "raw" / student_code

    if not raw_dir.exists() or not any(raw_dir.glob("*.jpg")):
        return {
            "success": False,
            "message": "Chưa có ảnh để train. Vui lòng chụp ảnh trước."
        }

    try:
        print(f"Training model for {student_code}...")
        from services.training import training_service

        loop = asyncio.get_event_loop()
        train_success, train_message = await loop.run_in_executor(None, training_service.train_model)

        if train_success:
            from services.face_recognition import face_recognition_service
            face_recognition_service.model_loaded = False
            print(f"Training completed: {train_message}")

            return {
                "success": True,
                "message": f"Train model thành công cho {user.student.full_name}!",
                "student_code": student_code,
                "student_name": user.student.full_name,
                "train_message": train_message
            }
        else:
            print(f"Training failed: {train_message}")
            return {
                "success": False,
                "message": f"Train model thất bại: {train_message}"
            }

    except Exception as e:
        return {
            "success": False,
            "message": f"Training error: {str(e)}"
        }


@router.post("/upload-face-images")
async def upload_face_images(
    files: List[UploadFile] = File(...),
    user: User = Depends(require_student),
    db: Session = Depends(get_db)
):
    """Upload face images for training"""
    if not user.student:
        raise HTTPException(status_code=404, detail="Student profile not found")

    student_code = user.student.student_code

    # Create directory for student's face data
    base_dir = Path("Dataset/FaceData/processed")
    student_dir = base_dir / student_code
    student_dir.mkdir(parents=True, exist_ok=True)

    uploaded_files = []
    for file in files:
        if not file.content_type.startswith("image/"):
            continue

        # Generate unique filename
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
        ext = os.path.splitext(file.filename)[1]
        filename = f"{student_code}_{timestamp}{ext}"
        file_path = student_dir / filename

        # Save file
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        uploaded_files.append({
            "filename": filename,
            "path": str(file_path)
        })

    return {
        "success": True,
        "uploaded_count": len(uploaded_files),
        "files": uploaded_files,
        "message": f"Uploaded {len(uploaded_files)} images for {student_code}"
    }


@router.get("/my-face-images")
def get_my_face_images(
    user: User = Depends(require_student),
    db: Session = Depends(get_db)
):
    """Get list of uploaded face images"""
    if not user.student:
        raise HTTPException(status_code=404, detail="Student profile not found")

    student_code = user.student.student_code
    student_dir = Path("Dataset/FaceData/processed") / student_code

    if not student_dir.exists():
        return {"images": [], "count": 0}

    images = []
    for img_file in student_dir.glob("*"):
        if img_file.is_file() and img_file.suffix.lower() in ['.jpg', '.jpeg', '.png']:
            images.append({
                "filename": img_file.name,
                "size": img_file.stat().st_size,
                "created_at": datetime.fromtimestamp(img_file.stat().st_ctime).isoformat()
            })

    return {
        "images": images,
        "count": len(images),
        "student_code": student_code
    }


@router.delete("/my-face-images/{filename}")
def delete_my_face_image(
    filename: str,
    user: User = Depends(require_student),
    db: Session = Depends(get_db)
):
    """Delete a face image"""
    if not user.student:
        raise HTTPException(status_code=404, detail="Student profile not found")

    student_code = user.student.student_code
    file_path = Path("Dataset/FaceData/processed") / student_code / filename

    if not file_path.exists():
        raise HTTPException(status_code=404, detail="Image not found")

    # Security check: ensure filename doesn't contain path traversal
    if ".." in filename or "/" in filename or "\\" in filename:
        raise HTTPException(status_code=400, detail="Invalid filename")

    file_path.unlink()

    return {
        "success": True,
        "message": f"Deleted {filename}"
    }


@router.post("/attendance/recognize")
async def recognize_attendance(
    class_id: int,
    session_date: str = None,
    user: User = Depends(require_student),
    db: Session = Depends(get_db)
):
    """Recognize face using computer camera and mark attendance"""
    import subprocess
    import sys
    import asyncio

    if not user.student:
        raise HTTPException(status_code=404, detail="Student profile not found")

    # Parse date
    target_date = datetime.strptime(session_date, "%Y-%m-%d").date() if session_date else date.today()

    # Check if student is enrolled in this class
    enrollment = db.query(ClassStudent).filter(
        ClassStudent.student_id == user.student.id,
        ClassStudent.class_id == class_id
    ).first()

    if not enrollment:
        raise HTTPException(status_code=403, detail="You are not enrolled in this class")

    # Get class info
    cls = db.query(Class).filter(Class.id == class_id).first()
    if not cls:
        raise HTTPException(status_code=404, detail="Class not found")

    # Path to recognize script
    project_root = Path(__file__).parent.parent.parent
    recognize_script = project_root / "src" / "recognize.py"

    if not recognize_script.exists():
        raise HTTPException(status_code=500, detail=f"Recognition script not found: {recognize_script}")

    try:
        # Run recognition script
        print(f"Starting face recognition for {user.student.full_name}...")
        result = subprocess.run(
            [sys.executable, str(recognize_script)],
            cwd=str(project_root / "src"),
            capture_output=True,
            text=True,
            timeout=60  # 1 minute timeout
        )

        print("Recognition stdout:", result.stdout)
        if result.stderr:
            print("Recognition stderr:", result.stderr)

        if result.returncode != 0:
            # Extract only the last error line from stderr (skip TensorFlow warnings)
            error_lines = [line for line in result.stderr.split('\n') if line.strip() and 'ERROR' in line.upper()]
            error_msg = error_lines[-1] if error_lines else "Không thể nhận diện khuôn mặt. Vui lòng thử lại."
            return {
                "success": False,
                "message": error_msg
            }

        # Get recognized student_code from stdout (last non-empty line)
        stdout_lines = [line.strip() for line in result.stdout.split('\n') if line.strip()]
        recognized_code = stdout_lines[-1] if stdout_lines else ""

        print(f"Recognized code: {recognized_code}", file=sys.stderr)

        # Verify it matches the logged-in student
        if recognized_code != user.student.student_code:
            return {
                "success": False,
                "message": f"Face recognized as {recognized_code}, but you are logged in as {user.student.student_code}. Please login with the correct account."
            }

        # Find or create attendance session
        attendance_session = db.query(AttendanceSession).filter(
            AttendanceSession.class_id == class_id,
            AttendanceSession.session_date == target_date
        ).first()

        if not attendance_session:
            # Create new session with current time (remove microseconds)
            now = datetime.now().replace(microsecond=0)
            attendance_session = AttendanceSession(
                class_id=class_id,
                session_date=target_date,
                start_time=now.time(),
                end_time=now.time(),
                created_at=now
            )
            db.add(attendance_session)
            db.commit()
            db.refresh(attendance_session)

        # Find or create attendance record
        attendance_record = db.query(AttendanceRecord).filter(
            AttendanceRecord.session_id == attendance_session.id,
            AttendanceRecord.student_id == user.student.id
        ).first()

        # Remove microseconds from datetime to avoid MySQL error
        current_time = datetime.now().replace(microsecond=0)

        if attendance_record:
            # Update existing record
            attendance_record.status = "present"
            attendance_record.check_in_time = current_time
        else:
            # Create new record
            attendance_record = AttendanceRecord(
                session_id=attendance_session.id,
                student_id=user.student.id,
                status="present",
                check_in_time=current_time
            )
            db.add(attendance_record)

        db.commit()

        return {
            "success": True,
            "message": f"Attendance marked successfully for {user.student.full_name}",
            "student_code": recognized_code,
            "student_name": user.student.full_name,
            "class_name": cls.class_name,
            "date": str(target_date),
            "check_in_time": str(current_time),
            "status": "present"
        }

    except subprocess.TimeoutExpired:
        return {
            "success": False,
            "message": "Recognition timeout (exceeded 1 minute)"
        }
    except Exception as e:
        print(f"Recognition error: {str(e)}")
        return {
            "success": False,
            "message": f"Recognition error: {str(e)}"
        }


@router.get("/avatar")
async def get_avatar(
    user: User = Depends(require_student),
    db: Session = Depends(get_db)
):
    """Get student's avatar image from processed dataset"""
    if not user.student:
        raise HTTPException(status_code=404, detail="Student profile not found")

    student_code = user.student.student_code

    # Path to processed images
    project_root = Path(__file__).parent.parent.parent
    processed_dir = project_root / "Dataset" / "FaceData" / "processed" / student_code

    # Find first image
    if processed_dir.exists():
        images = list(processed_dir.glob("*.png")) + list(processed_dir.glob("*.jpg"))
        if images:
            return FileResponse(
                path=str(images[0]),
                media_type="image/jpeg",
                filename=f"{student_code}_avatar.jpg"
            )

    # If no processed image, try raw
    raw_dir = project_root / "Dataset" / "FaceData" / "raw" / student_code
    if raw_dir.exists():
        images = list(raw_dir.glob("*.png")) + list(raw_dir.glob("*.jpg"))
        if images:
            return FileResponse(
                path=str(images[0]),
                media_type="image/jpeg",
                filename=f"{student_code}_avatar.jpg"
            )

    # No image found
    raise HTTPException(status_code=404, detail="No avatar image found. Please capture images first.")


@router.post("/change-password")
def change_password(
    request: ChangePasswordRequest,
    user: User = Depends(require_student),
    db: Session = Depends(get_db)
):
    """Change student password"""
    if not user.student:
        raise HTTPException(status_code=404, detail="Student profile not found")

    # Verify old password
    if user.password != request.old_password:
        raise HTTPException(status_code=400, detail="Mật khẩu cũ không đúng")

    # Update password in both User and Student tables
    user.password = request.new_password
    user.student.password = request.new_password

    db.commit()

    return {
        "success": True,
        "message": "Đổi mật khẩu thành công"
    }
