import cv2
import os
import sys

def create_directory(directory):
    """
    Create a directory if it doesn't exist.

    Parameters:
        directory (str): The path of the directory to be created.
    """
    if not os.path.exists(directory):
        os.makedirs(directory)

if __name__ == "__main__":
    # Nhận student_code từ command line argument hoặc input
    # PHẢI là student_code (VD: SV001) để đồng bộ với database
    if len(sys.argv) > 1:
        student_code = sys.argv[1].upper()  # Uppercase để chuẩn hóa
    else:
        student_code = str(input("Enter Student Code (e.g., SV001): ")).upper()

    # Validate student_code format
    if not student_code.startswith('SV') or len(student_code) < 4:
        print("Error: Invalid student code format. Must be like SV001, SV002, etc.")
        sys.exit(1)

    video = cv2.VideoCapture(0)
    facedetect = cv2.CascadeClassifier('haarcascade_frontalface_default.xml')
    count = 0

    # Lưu vào thư mục với student_code để đồng bộ với database
    path = '../Dataset/FaceData/raw/' + student_code

    create_directory(path)

    print(f"Starting capture for student {student_code}. Press 'q' to quit early.")

    while True:
        ret, frame = video.read()
        if not ret:
            print("Failed to grab frame")
            break

        faces = facedetect.detectMultiScale(frame, 1.3, 5)
        for x, y, w, h in faces:
            count = count + 1
            # Tên file dùng student_code
            image_path = f"{path}/{student_code}-{count}.jpg"
            print(f"Capturing image {count}/100: {image_path}")
            cv2.imwrite(image_path, frame[y:y + h, x:x + w])
            cv2.rectangle(frame, (x, y), (x + w, y + h), (0, 255, 0), 3)

        # Hiển thị student_code và số ảnh đã chụp
        cv2.putText(frame, f"{student_code}: {count}/100", (10, 30),
                    cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
        cv2.imshow("Capture Face - Press 'q' to quit", frame)

        # Nhấn 'q' để thoát sớm
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break
        if count >= 100:
            break

    video.release()
    cv2.destroyAllWindows()
    print(f"Capture completed! Total images: {count}")
    print(f"Images saved to: {path}")
