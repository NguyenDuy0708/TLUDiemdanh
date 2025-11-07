"""
Script to make request_date column nullable in teacher_requests table
"""
import sys
sys.path.append('api')

from database import engine
from sqlalchemy import text

def fix_request_date_nullable():
    """Make request_date nullable for dạy_bù requests"""
    with engine.connect() as conn:
        try:
            # Make request_date nullable
            conn.execute(text("ALTER TABLE teacher_requests MODIFY request_date DATE NULL"))
            conn.commit()
            print("✅ Successfully made request_date nullable")

            # Also make other fields nullable for consistency
            conn.execute(text("ALTER TABLE teacher_requests MODIFY start_time TIME NULL"))
            conn.execute(text("ALTER TABLE teacher_requests MODIFY end_time TIME NULL"))
            conn.commit()
            print("✅ Successfully made start_time and end_time nullable")

        except Exception as e:
            print(f"❌ Error: {e}")
            conn.rollback()

if __name__ == "__main__":
    print("Making request_date, start_time, end_time nullable in teacher_requests table...")
    fix_request_date_nullable()
    print("Done!")

