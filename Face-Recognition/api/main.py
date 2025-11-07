from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from database import engine, Base
from routers import auth, admin, face, teacher, teacher_requests, attendance_reports, admin_requests

Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Face Recognition Attendance API",
    description="API for face recognition based attendance system",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
)

app.include_router(auth.router)
app.include_router(admin.router)
app.include_router(teacher.router)
app.include_router(face.router)
app.include_router(teacher_requests.router)
app.include_router(attendance_reports.router)
app.include_router(admin_requests.router)

from routers import student
app.include_router(student.router)

@app.get("/")
def root():
    return {
        "message": "Face Recognition",
        "version": "1.0.0",
    }

@app.get("/health")
def health_check():
    return {"status": "healthy"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

