import sys
import os
import base64
import cv2
import numpy as np
from datetime import datetime
import threading

sys.path.append(os.path.join(os.path.dirname(__file__), '../../'))

class FaceRecognitionService:
    def __init__(self):
        self.model_path = "../Models/20180402-114759.pb"
        self.classifier_path = "../Models/facemodel.pkl"
        self.model_loaded = False
        self._load_lock = threading.Lock()

    def load_model(self):
        if self.model_loaded:
            return

        with self._load_lock:
            if self.model_loaded:
                return

            try:
                import tensorflow as tf
                tf.compat.v1.disable_v2_behavior()
                import pickle

                with open(self.classifier_path, 'rb') as f:
                    self.model, self.class_names = pickle.load(f)

                from src import facenet
                from src.align import detect_face

                self.facenet = facenet
                self.detect_face = detect_face

                gpu_options = tf.compat.v1.GPUOptions(per_process_gpu_memory_fraction=0.6)
                self.sess = tf.compat.v1.Session(config=tf.compat.v1.ConfigProto(gpu_options=gpu_options, log_device_placement=False))

                self.facenet.load_model(self.model_path)

                self.images_placeholder = tf.compat.v1.get_default_graph().get_tensor_by_name("input:0")
                self.embeddings = tf.compat.v1.get_default_graph().get_tensor_by_name("embeddings:0")
                self.phase_train_placeholder = tf.compat.v1.get_default_graph().get_tensor_by_name("phase_train:0")
                self.embedding_size = self.embeddings.get_shape()[1]

                pnet, rnet, onet = self.detect_face.create_mtcnn(self.sess, None)
                self.pnet = pnet
                self.rnet = rnet
                self.onet = onet

                self.model_loaded = True
                print("Face recognition model loaded successfully")

            except Exception as e:
                print(f"Error loading model: {e}")
                raise
    
    def recognize_face(self, image_base64: str):
        if not self.model_loaded:
            self.load_model()

        try:
            if ',' in image_base64:
                image_base64 = image_base64.split(',')[1]

            image_data = base64.b64decode(image_base64)
            nparr = np.frombuffer(image_data, np.uint8)
            frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

            if frame is None:
                return None, 0.0, "Failed to decode image"

            bounding_boxes, _ = self.detect_face.detect_face(
                frame, 20, self.pnet, self.rnet, self.onet,
                [0.6, 0.7, 0.7], 0.709
            )

            if len(bounding_boxes) == 0:
                return None, 0.0, "No face detected"

            det = bounding_boxes[0, 0:4]

            bb = np.zeros(4, dtype=np.int32)
            bb[0] = np.maximum(det[0] - 32 / 2, 0)
            bb[1] = np.maximum(det[1] - 32 / 2, 0)
            bb[2] = np.minimum(det[2] + 32 / 2, frame.shape[1])
            bb[3] = np.minimum(det[3] + 32 / 2, frame.shape[0])

            cropped = frame[bb[1]:bb[3], bb[0]:bb[2], :]
            aligned = cv2.resize(cropped, (160, 160))

            prewhitened = self.facenet.prewhiten(aligned)

            feed_dict = {
                self.images_placeholder: [prewhitened],
                self.phase_train_placeholder: False
            }
            emb = self.sess.run(self.embeddings, feed_dict=feed_dict)[0]

            predictions = self.model.predict_proba([emb])
            best_class_indices = np.argmax(predictions, axis=1)
            best_class_probabilities = predictions[
                np.arange(len(best_class_indices)),
                best_class_indices
            ]

            name = self.class_names[best_class_indices[0]]
            confidence = best_class_probabilities[0]

            return name, confidence, "Success"

        except Exception as e:
            return None, 0.0, f"Error: {str(e)}"
    
    def train_model(self):
        return "Training not implemented in API yet. Please run training scripts manually."

face_recognition_service = FaceRecognitionService()

