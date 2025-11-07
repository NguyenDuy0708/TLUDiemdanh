from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from database import get_db
from pydantic import BaseModel
from typing import Optional
from models import Student, AttendanceRecord, AttendanceSession
from services.face_recognition import face_recognition_service
from routers.auth import require_admin
from datetime import datetime, date

router = APIRouter(prefix="/api/face", tags=["Face Recognition"])

class FaceRecognitionRequest(BaseModel):
    image_base64: str

class FaceRecognitionResponse(BaseModel):
    success: bool
    student_name: Optional[str] = None
    student_code: Optional[str] = None
    confidence: Optional[float] = None
    message: str

def get_or_create_session(db: Session, class_id: int):
    today = date.today()

    session = db.query(AttendanceSession).filter(
        AttendanceSession.class_id == class_id,
        db.func.date(AttendanceSession.created_at) == today
    ).first()

    if not session:
        session = AttendanceSession(
            class_id=class_id,
            created_by=1
        )
        db.add(session)
        db.commit()
        db.refresh(session)

    return session

@router.post("/recognize", response_model=FaceRecognitionResponse)
def recognize_face(request: FaceRecognitionRequest, db: Session = Depends(get_db), admin_session = Depends(require_admin)):
    from models import Class

    name, confidence, message = face_recognition_service.recognize_face(request.image_base64)

    if name is None:
        return {
            "success": False,
            "message": message
        }

    import unicodedata
    def normalize_name(text):
        text = unicodedata.normalize('NFD', text)
        text = ''.join(char for char in text if unicodedata.category(char) != 'Mn')
        text = text.replace(' ', '').replace('_', '').lower().strip()
        return text

    normalized_recognized = normalize_name(name)
    student = None
    for s in db.query(Student).all():
        if normalize_name(s.full_name) == normalized_recognized:
            student = s
            break

    if not student:
        return {
            "success": False,
            "message": f"Student '{name}' not found in database"
        }

    first_class = db.query(Class).first()
    attendance_session = None
    if first_class:
        attendance_session = get_or_create_session(db, first_class.id)

    if attendance_session:
        existing = db.query(AttendanceRecord).filter(
            AttendanceRecord.session_id == attendance_session.id,
            AttendanceRecord.student_id == student.id
        ).first()

        if existing:
            return {
                "success": False,
                "student_name": student.full_name,
                "student_code": student.student_code,
                "confidence": confidence,
                "message": "Already marked"
            }

        record = AttendanceRecord(
            session_id=attendance_session.id,
            student_id=student.id,
            status="present",
            confidence=confidence,
            check_in_time=datetime.now()
        )
        db.add(record)
        db.commit()

        return {
            "success": True,
            "student_name": student.full_name,
            "student_code": student.student_code,
            "confidence": confidence,
            "message": "Attendance marked successfully"
        }
    else:
        return {
            "success": True,
            "student_name": student.full_name,
            "student_code": student.student_code,
            "confidence": confidence,
            "message": "Student recognized (no active session)"
        }

@router.get("/status")
def get_model_status():
    return {
        "model_loaded": face_recognition_service.model_loaded,
        "model_path": face_recognition_service.model_path,
        "classifier_path": face_recognition_service.classifier_path
    }

