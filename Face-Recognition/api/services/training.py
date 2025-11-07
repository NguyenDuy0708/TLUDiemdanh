import sys
import os
import subprocess
from pathlib import Path

# Add parent directory to path
sys.path.append(os.path.join(os.path.dirname(__file__), '../../'))

class TrainingService:
    def __init__(self):
        self.project_root = Path(__file__).parent.parent.parent
        self.preprocessing_script = self.project_root / "src" / "align_dataset_mtcnn.py"
        self.classifier_script = self.project_root / "src" / "classifier.py"
        self.input_dir = self.project_root / "Dataset" / "FaceData" / "raw"
        self.output_dir = self.project_root / "Dataset" / "FaceData" / "processed"
        
    def train_model(self):
        """Run preprocessing and training"""
        try:
            # Check if there are at least 2 students with images
            import os
            raw_dir = self.input_dir
            student_dirs = [d for d in os.listdir(raw_dir) if os.path.isdir(os.path.join(raw_dir, d))]

            if len(student_dirs) < 2:
                return False, f"Cần ít nhất 2 học sinh để training. Hiện tại chỉ có {len(student_dirs)} học sinh."

            # Run preprocessing with arguments
            print("Running preprocessing...")
            result = subprocess.run(
                [
                    sys.executable,
                    str(self.preprocessing_script),
                    str(self.input_dir),
                    str(self.output_dir),
                    "--image_size", "160",
                    "--margin", "32"
                ],
                cwd=str(self.project_root / "src"),
                capture_output=True,
                text=True,
                timeout=300  # 5 minutes timeout
            )

            print("Preprocessing stdout:", result.stdout)
            print("Preprocessing stderr:", result.stderr)

            if result.returncode != 0:
                return False, f"Preprocessing failed: {result.stderr}"

            print("Preprocessing completed")
            
            # Run classifier training
            print("Running classifier training...")
            result = subprocess.run(
                [
                    sys.executable,
                    str(self.classifier_script),
                    "TRAIN",
                    str(self.output_dir),
                    str(self.project_root / "Models" / "20180402-114759.pb"),
                    str(self.project_root / "Models" / "facemodel.pkl"),
                    "--batch_size", "90"
                ],
                cwd=str(self.project_root / "src"),
                capture_output=True,
                text=True,
                timeout=300  # 5 minutes timeout
            )
            
            print("Training stdout:", result.stdout)
            print("Training stderr:", result.stderr)

            if result.returncode != 0:
                return False, f"Training failed: {result.stderr}"

            print("Training completed")
            return True, "Model trained successfully"
            
        except subprocess.TimeoutExpired:
            return False, "Training timeout (exceeded 5 minutes)"
        except Exception as e:
            return False, f"Training error: {str(e)}"

# Global instance
training_service = TrainingService()

