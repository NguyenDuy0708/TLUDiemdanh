from sqlalchemy.orm import Session
from datetime import datetime
from models import Session as DBSession, User, Student
from utils import generate_session_id, get_session_expiry

def authenticate_user(db: Session, username: str, password: str, role: str = None):
    user = db.query(User).filter(User.username == username).first()

    if not user or user.password != password:
        return None, None

    if role and user.role != role:
        return None, None

    session_id = generate_session_id()
    session = DBSession(
        session_id=session_id,
        user_id=user.id,
        expires_at=get_session_expiry()
    )
    db.add(session)
    db.commit()

    return session_id, user

def get_session(db: Session, session_id: str):
    session = db.query(DBSession).filter(
        DBSession.session_id == session_id,
        DBSession.expires_at > datetime.utcnow()
    ).first()
    return session

def get_user_from_session(db: Session, session_id: str):
    session = get_session(db, session_id)
    if not session:
        return None

    user = db.query(User).filter(User.id == session.user_id).first()
    return user

def logout_user(db: Session, session_id: str):
    session = db.query(DBSession).filter(DBSession.session_id == session_id).first()
    if session:
        db.delete(session)
        db.commit()
        return True
    return False

def require_role(db: Session, session_id: str, required_role: str):
    user = get_user_from_session(db, session_id)
    if not user or user.role != required_role:
        return None
    return user
