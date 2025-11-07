from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from typing import Optional
from datetime import datetime
import openpyxl
from io import BytesIO
from pathlib import Path

from database import get_db
from models import User, Class, AttendanceSession, AttendanceRecord, ClassStudent
from routers.auth import require_teacher

router = APIRouter(prefix="/api/teacher", tags=["attendance-reports"])

# Get attendance report for teacher's classes
@router.get("/attendance/report")
def get_attendance_report(
    class_id: Optional[int] = None,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    user: User = Depends(require_teacher),
    db: Session = Depends(get_db)
):
    """Báo cáo chuyên cần theo lớp - Export to Excel"""
    if not user.teacher:
        raise HTTPException(status_code=404, detail="Teacher profile not found")
    
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
        classes_query = db.query(Class).filter(Class.teacher_id == user.teacher.id)
        if class_id:
            classes_query = classes_query.filter(Class.id == class_id)
        
        classes = classes_query.all()
        
        if not classes:
            raise HTTPException(status_code=404, detail="No classes found")
        
        # Create workbook
        wb = openpyxl.Workbook()
        ws = wb.active
        ws.title = "Báo cáo chuyên cần"
        
        # Header
        ws.append(["BÁO CÁO CHUYÊN CẦN"])
        ws.append([f"Giảng viên: {user.teacher.full_name}"])
        ws.append([f"Ngày xuất: {datetime.now().strftime('%d/%m/%Y %H:%M')}"])
        if start_date_obj and end_date_obj:
            ws.append([f"Từ ngày: {start_date_obj.strftime('%d/%m/%Y')} - Đến ngày: {end_date_obj.strftime('%d/%m/%Y')}"])
        ws.append([])
        
        for cls in classes:
            # Class header
            ws.append([f"Lớp: {cls.class_name} ({cls.class_code})"])
            ws.append([f"Môn học: {cls.subject.subject_name}"])
            ws.append([])
            
            # Table header
            ws.append(["Mã SV", "Họ và tên", "Tổng buổi", "Có mặt", "Muộn", "Vắng", "Tỷ lệ vắng (%)"])
            
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
                    total_sessions,
                    present_count,
                    late_count,
                    absent_count,
                    round(absence_rate, 2)
                ])
            
            ws.append([])
            ws.append([])

        # Generate filename
        filename = f"attendance_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.xlsx"

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

