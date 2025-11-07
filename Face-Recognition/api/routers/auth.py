from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy.orm import Session
from database import get_db
from pydantic import BaseModel
from typing import Optional
from services.auth import authenticate_user, get_session, logout_user, get_user_from_session, require_role

router = APIRouter(prefix="/api/auth", tags=["Authentication"])

class LoginRequest(BaseModel):
    username: str
    password: str
    role: Optional[str] = None

class LoginResponse(BaseModel):
    session_id: str
    username: str
    role: str
    student_id: Optional[int] = None
    student_code: Optional[str] = None
    teacher_id: Optional[int] = None
    teacher_code: Optional[str] = None
    full_name: Optional[str] = None

def require_admin(auth_session_id: str = Header(None, alias="session-id"), db: Session = Depends(get_db)):
    if not auth_session_id:
        raise HTTPException(status_code=401, detail="Session ID required")
    user = require_role(db, auth_session_id, "admin")
    if not user:
        raise HTTPException(status_code=403, detail="Admin access required")
    return user

def require_student(auth_session_id: str = Header(None, alias="session-id"), db: Session = Depends(get_db)):
    if not auth_session_id:
        raise HTTPException(status_code=401, detail="Session ID required")
    user = require_role(db, auth_session_id, "student")
    if not user:
        raise HTTPException(status_code=403, detail="Student access required")
    return user

def require_teacher(auth_session_id: str = Header(None, alias="session-id"), db: Session = Depends(get_db)):
    if not auth_session_id:
        raise HTTPException(status_code=401, detail="Session ID required")
    user = require_role(db, auth_session_id, "teacher")
    if not user:
        raise HTTPException(status_code=403, detail="Teacher access required")
    return user

def require_auth(auth_session_id: str = Header(None, alias="session-id"), db: Session = Depends(get_db)):
    if not auth_session_id:
        raise HTTPException(status_code=401, detail="Session ID required")
    user = get_user_from_session(db, auth_session_id)
    if not user:
        raise HTTPException(status_code=401, detail="Invalid or expired session")
    return user

@router.post("/login", response_model=LoginResponse)
def login(request: LoginRequest, db: Session = Depends(get_db)):
    session_id, user = authenticate_user(db, request.username, request.password, request.role)
    if not session_id or not user:
        raise HTTPException(status_code=401, detail="Invalid username or password")

    response = {
        "session_id": session_id,
        "username": user.username,
        "role": user.role
    }

    if user.role == "student" and user.student:
        response["student_id"] = user.student.id
        response["student_code"] = user.student.student_code
        response["full_name"] = user.student.full_name
    elif user.role == "teacher" and user.teacher:
        response["teacher_id"] = user.teacher.id
        response["teacher_code"] = user.teacher.teacher_code
        response["full_name"] = user.teacher.full_name

    return response

@router.post("/logout")
def logout(session_id: str = Header(None, alias="session-id"), db: Session = Depends(get_db)):
    if not session_id:
        raise HTTPException(status_code=401, detail="Session ID required")
    success = logout_user(db, session_id)
    if not success:
        raise HTTPException(status_code=404, detail="Session not found")
    return {"message": "Logged out successfully"}

@router.get("/me")
def get_current_user(user = Depends(require_auth), db: Session = Depends(get_db)):
    response = {
        "username": user.username,
        "role": user.role
    }

    if user.role == "student" and user.student:
        response["student_id"] = user.student.id
        response["student_code"] = user.student.student_code
        response["full_name"] = user.student.full_name
    elif user.role == "teacher" and user.teacher:
        response["teacher_id"] = user.teacher.id
        response["teacher_code"] = user.teacher.teacher_code
        response["full_name"] = user.teacher.full_name

    return response
