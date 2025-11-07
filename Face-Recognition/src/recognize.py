"""
Face Recognition Script for Attendance
Usage: python recognize.py
Output: Prints recognized student_code to stdout
"""
from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

# Suppress TensorFlow warnings
import os
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'  # Suppress TF logging
os.environ['TF_ENABLE_ONEDNN_OPTS'] = '0'  # Disable oneDNN warnings

import tensorflow.compat.v1 as tf
tf.disable_v2_behavior()
# Suppress TF deprecation warnings
import warnings
warnings.filterwarnings('ignore', category=DeprecationWarning)
warnings.filterwarnings('ignore', category=FutureWarning)

from imutils.video import VideoStream

import argparse
import facenet
import imutils
import sys
import math
import pickle
import align.detect_face
import numpy as np
import cv2
import collections
from sklearn.svm import SVC
import time


def main():
    MINSIZE = 20
    THRESHOLD = [0.6, 0.7, 0.7]
    FACTOR = 0.709
    IMAGE_SIZE = 182
    INPUT_IMAGE_SIZE = 160

    # Get absolute paths (script is in src/, models are in ../Models/)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    CLASSIFIER_PATH = os.path.join(project_root, 'Models', 'facemodel.pkl')
    FACENET_MODEL_PATH = os.path.join(project_root, 'Models', '20180402-114759.pb')

    # Check if model exists
    if not os.path.exists(CLASSIFIER_PATH):
        print("ERROR: Model not found. Please train the model first.", file=sys.stderr)
        sys.exit(1)

    # Load The Custom Classifier
    with open(CLASSIFIER_PATH, 'rb') as file:
        model, class_names = pickle.load(file)
    print("Custom Classifier loaded successfully", file=sys.stderr)

    with tf.Graph().as_default():
        # Optimized GPU settings - reduce memory usage and disable logging
        gpu_options = tf.compat.v1.GPUOptions(
            per_process_gpu_memory_fraction=0.4,  # Reduced from 0.6
            allow_growth=True  # Allow dynamic memory allocation
        )
        config = tf.compat.v1.ConfigProto(
            gpu_options=gpu_options,
            log_device_placement=False,
            allow_soft_placement=True,  # Allow TF to choose device
            intra_op_parallelism_threads=2,  # Optimize CPU threads
            inter_op_parallelism_threads=2
        )
        sess = tf.compat.v1.Session(config=config)

        with sess.as_default():
            # Load the model
            print('Loading model...', file=sys.stderr)
            facenet.load_model(FACENET_MODEL_PATH)

            # Get input and output tensors
            images_placeholder = tf.get_default_graph().get_tensor_by_name("input:0")
            embeddings = tf.get_default_graph().get_tensor_by_name("embeddings:0")
            phase_train_placeholder = tf.get_default_graph().get_tensor_by_name("phase_train:0")
            embedding_size = embeddings.get_shape()[1]

            # Use absolute path for align folder
            align_path = os.path.join(script_dir, "align")
            pnet, rnet, onet = align.detect_face.create_mtcnn(sess, align_path)

            person_detected = collections.Counter()
            recognized_person = None
            recognition_count = 0

            print("Opening camera...", file=sys.stderr)
            cap = VideoStream(src=0).start()
            time.sleep(1.5)  # Wait for camera to warm up

            frame_count = 0
            print("Camera ready. Looking for faces... (Press 'q' to quit)", file=sys.stderr)

            while True:  # Run indefinitely until face recognized or user quits
                frame = cap.read()
                if frame is None:
                    print("Warning: Empty frame", file=sys.stderr)
                    time.sleep(0.1)  # Wait a bit before trying again
                    continue

                frame = imutils.resize(frame, width=600)
                frame = cv2.flip(frame, 1)

                bounding_boxes, _ = align.detect_face.detect_face(frame, MINSIZE, pnet, rnet, onet, THRESHOLD, FACTOR)

                faces_found = bounding_boxes.shape[0]
                try:
                    if faces_found > 1:
                        cv2.putText(frame, "Only one face allowed", (10, 30), cv2.FONT_HERSHEY_COMPLEX_SMALL,
                                    1, (0, 0, 255), thickness=1, lineType=2)
                    elif faces_found > 0:
                        det = bounding_boxes[:, 0:4]
                        bb = np.zeros((faces_found, 4), dtype=np.int32)
                        for i in range(faces_found):
                            bb[i][0] = det[i][0]
                            bb[i][1] = det[i][1]
                            bb[i][2] = det[i][2]
                            bb[i][3] = det[i][3]
                            
                            # Check if face is large enough
                            if (bb[i][3]-bb[i][1])/frame.shape[0] > 0.25:
                                cropped = frame[bb[i][1]:bb[i][3], bb[i][0]:bb[i][2], :]
                                scaled = cv2.resize(cropped, (INPUT_IMAGE_SIZE, INPUT_IMAGE_SIZE),
                                                    interpolation=cv2.INTER_CUBIC)
                                scaled = facenet.prewhiten(scaled)
                                scaled_reshape = scaled.reshape(-1, INPUT_IMAGE_SIZE, INPUT_IMAGE_SIZE, 3)
                                feed_dict = {images_placeholder: scaled_reshape, phase_train_placeholder: False}
                                emb_array = sess.run(embeddings, feed_dict=feed_dict)

                                predictions = model.predict_proba(emb_array)
                                best_class_indices = np.argmax(predictions, axis=1)
                                best_class_probabilities = predictions[
                                    np.arange(len(best_class_indices)), best_class_indices]
                                best_name = class_names[best_class_indices[0]]

                                # Threshold for recognition (lowered from 0.8 to 0.75 for faster recognition)
                                if best_class_probabilities[0] > 0.75:
                                    cv2.rectangle(frame, (bb[i][0], bb[i][1]), (bb[i][2], bb[i][3]), (0, 255, 0), 2)
                                    text_x = bb[i][0]
                                    text_y = bb[i][3] + 20

                                    name = class_names[best_class_indices[0]]
                                    cv2.putText(frame, name, (text_x, text_y), cv2.FONT_HERSHEY_COMPLEX_SMALL,
                                                1, (0, 255, 0), thickness=2, lineType=2)
                                    cv2.putText(frame, f"{round(best_class_probabilities[0], 3)}", (text_x, text_y + 20),
                                                cv2.FONT_HERSHEY_COMPLEX_SMALL,
                                                1, (0, 255, 0), thickness=2, lineType=2)

                                    person_detected[best_name] += 1

                                    # If recognized 2 times (reduced from 3), confirm
                                    if person_detected[best_name] >= 2:
                                        recognized_person = best_name
                                        print(f"Recognized: {best_name}", file=sys.stderr)
                                        break
                                else:
                                    cv2.rectangle(frame, (bb[i][0], bb[i][1]), (bb[i][2], bb[i][3]), (0, 0, 255), 2)
                                    cv2.putText(frame, "Unknown", (bb[i][0], bb[i][3] + 20), 
                                                cv2.FONT_HERSHEY_COMPLEX_SMALL,
                                                1, (0, 0, 255), thickness=1, lineType=2)
                    else:
                        cv2.putText(frame, "No face detected", (10, 30), cv2.FONT_HERSHEY_COMPLEX_SMALL,
                                    1, (0, 0, 255), thickness=1, lineType=2)

                except Exception as e:
                    print(f"Error processing frame: {e}", file=sys.stderr)
                    pass

                # Show instruction and frame count
                cv2.putText(frame, f"Frame: {frame_count} - Press 'q' to quit",
                            (10, frame.shape[0] - 10),
                            cv2.FONT_HERSHEY_COMPLEX_SMALL, 1, (255, 255, 255), thickness=1, lineType=2)

                cv2.imshow('Face Recognition - Attendance', frame)

                # Wait for key press (30ms to allow window to update)
                key = cv2.waitKey(30) & 0xFF

                # Break if recognized or user presses 'q'
                if recognized_person:
                    print(f"Recognition complete at frame {frame_count}", file=sys.stderr)
                    break
                if key == ord('q'):
                    print("User quit", file=sys.stderr)
                    break

                frame_count += 1

            cap.stop()
            cv2.destroyAllWindows()

            # Output result to stdout (for API to capture)
            if recognized_person:
                print(recognized_person)  # Print to stdout
                sys.exit(0)
            else:
                print("ERROR: No face recognized", file=sys.stderr)
                sys.exit(1)


if __name__ == '__main__':
    main()

