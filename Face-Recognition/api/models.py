from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Float, Date, Time
from sqlalchemy.orm import relationship
from datetime import datetime
from database import Base

ADMIN_USERNAME = "admin"
ADMIN_PASSWORD = "admin"

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, nullable=False, index=True)
    password = Column(String(100), nullable=False)
    role = Column(String(20), nullable=False)
    student_id = Column(Integer, ForeignKey("students.id"), nullable=True)
    teacher_id = Column(Integer, ForeignKey("teachers.id"), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    student = relationship("Student", back_populates="user", uselist=False)
    teacher = relationship("Teacher", back_populates="user", uselist=False)
    sessions = relationship("Session", back_populates="user", cascade="all, delete-orphan")

class Session(Base):
    __tablename__ = "sessions"

    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(String(255), unique=True, nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    expires_at = Column(DateTime, nullable=False)

    user = relationship("User", back_populates="sessions")

class Student(Base):
    __tablename__ = "students"

    id = Column(Integer, primary_key=True, index=True)
    student_code = Column(String(20), unique=True, nullable=False, index=True)
    full_name = Column(String(100), nullable=False)
    email = Column(String(100))
    phone = Column(String(20))
    year = Column(String(20))
    password = Column(String(100), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="student", uselist=False)
    attendance_records = relationship("AttendanceRecord", back_populates="student", cascade="all, delete-orphan")
    class_enrollments = relationship("ClassStudent", back_populates="student", cascade="all, delete-orphan")

class Teacher(Base):
    __tablename__ = "teachers"

    id = Column(Integer, primary_key=True, index=True)
    teacher_code = Column(String(20), unique=True, nullable=False, index=True)
    full_name = Column(String(100), nullable=False)
    email = Column(String(100))
    phone = Column(String(20))
    department = Column(String(100))
    password = Column(String(100), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="teacher", uselist=False)
    classes = relationship("Class", back_populates="teacher", cascade="all, delete-orphan")
    requests = relationship("TeacherRequest", back_populates="teacher", cascade="all, delete-orphan")

class Subject(Base):
    __tablename__ = "subjects"

    id = Column(Integer, primary_key=True, index=True)
    subject_code = Column(String(20), unique=True, nullable=False, index=True)
    subject_name = Column(String(100), nullable=False)
    credits = Column(Integer, default=3)
    description = Column(String(500))
    created_at = Column(DateTime, default=datetime.utcnow)

    classes = relationship("Class", back_populates="subject", cascade="all, delete-orphan")

class Class(Base):
    __tablename__ = "classes"

    id = Column(Integer, primary_key=True, index=True)
    class_code = Column(String(20), unique=True, nullable=False, index=True)
    class_name = Column(String(100), nullable=False)
    subject_id = Column(Integer, ForeignKey("subjects.id"), nullable=False)
    teacher_id = Column(Integer, ForeignKey("teachers.id"), nullable=False)
    semester = Column(String(20))
    year = Column(Integer)
    created_at = Column(DateTime, default=datetime.utcnow)

    subject = relationship("Subject", back_populates="classes")
    teacher = relationship("Teacher", back_populates="classes")
    students = relationship("ClassStudent", back_populates="class_obj", cascade="all, delete-orphan")
    schedules = relationship("ClassSchedule", back_populates="class_obj", cascade="all, delete-orphan")
    attendance_sessions = relationship("AttendanceSession", back_populates="class_obj", cascade="all, delete-orphan")

class ClassSchedule(Base):
    __tablename__ = "class_schedules"

    id = Column(Integer, primary_key=True, index=True)
    class_id = Column(Integer, ForeignKey("classes.id", ondelete="CASCADE"), nullable=False)
    day_of_week = Column(Integer, nullable=False)
    start_time = Column(Time, nullable=False)
    end_time = Column(Time, nullable=False)
    room = Column(String(50))
    mode = Column(String(20), default="offline")
    created_at = Column(DateTime, default=datetime.utcnow)

    class_obj = relationship("Class", back_populates="schedules")

class ClassStudent(Base):
    __tablename__ = "class_students"

    id = Column(Integer, primary_key=True, index=True)
    class_id = Column(Integer, ForeignKey("classes.id", ondelete="CASCADE"), nullable=False)
    student_id = Column(Integer, ForeignKey("students.id", ondelete="CASCADE"), nullable=False)
    enrolled_at = Column(DateTime, default=datetime.utcnow)

    class_obj = relationship("Class", back_populates="students")
    student = relationship("Student", back_populates="class_enrollments")

class AttendanceSession(Base):
    __tablename__ = "attendance_sessions"

    id = Column(Integer, primary_key=True, index=True)
    class_id = Column(Integer, ForeignKey("classes.id", ondelete="CASCADE"), nullable=False)
    session_date = Column(Date, nullable=False)
    start_time = Column(Time, nullable=False)
    end_time = Column(Time, nullable=False)
    created_by = Column(Integer, ForeignKey("users.id"), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    class_obj = relationship("Class", back_populates="attendance_sessions")
    records = relationship("AttendanceRecord", back_populates="session", cascade="all, delete-orphan")
    creator = relationship("User")

class AttendanceRecord(Base):
    __tablename__ = "attendance_records"

    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(Integer, ForeignKey("attendance_sessions.id", ondelete="CASCADE"), nullable=False)
    student_id = Column(Integer, ForeignKey("students.id", ondelete="CASCADE"), nullable=False)
    check_in_time = Column(DateTime, default=datetime.utcnow)
    status = Column(String(20), default="present")
    confidence = Column(Float)
    created_at = Column(DateTime, default=datetime.utcnow)

    session = relationship("AttendanceSession", back_populates="records")
    student = relationship("Student", back_populates="attendance_records")

class TeacherRequest(Base):
    __tablename__ = "teacher_requests"

    id = Column(Integer, primary_key=True, index=True)
    teacher_id = Column(Integer, ForeignKey("teachers.id", ondelete="CASCADE"), nullable=False)
    request_type = Column(String(20), nullable=False)  # "nghỉ" or "dạy_bù"
    reason = Column(String(500), nullable=False)

    # For "nghỉ" requests: use these fields
    class_id = Column(Integer, ForeignKey("classes.id", ondelete="SET NULL"), nullable=True)
    subject_id = Column(Integer, ForeignKey("subjects.id", ondelete="SET NULL"), nullable=True)
    request_date = Column(Date, nullable=True)
    start_time = Column(Time, nullable=True)
    end_time = Column(Time, nullable=True)

    # For "dạy_bù" requests: original class (the one being cancelled)
    original_class_id = Column(Integer, ForeignKey("classes.id", ondelete="SET NULL"), nullable=True)
    original_date = Column(Date, nullable=True)
    original_start_time = Column(Time, nullable=True)
    original_end_time = Column(Time, nullable=True)

    # For "dạy_bù" requests: makeup class (the replacement)
    makeup_class_id = Column(Integer, ForeignKey("classes.id", ondelete="SET NULL"), nullable=True)
    makeup_date = Column(Date, nullable=True)
    makeup_start_time = Column(Time, nullable=True)
    makeup_end_time = Column(Time, nullable=True)

    status = Column(String(20), default="pending")  # "pending", "approved", "rejected"
    admin_note = Column(String(500))
    approved_by = Column(Integer, ForeignKey("users.id"), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    teacher = relationship("Teacher", back_populates="requests")
    class_obj = relationship("Class", foreign_keys=[class_id])
    original_class_obj = relationship("Class", foreign_keys=[original_class_id])
    makeup_class_obj = relationship("Class", foreign_keys=[makeup_class_id])
    subject = relationship("Subject")
    approver = relationship("User")

