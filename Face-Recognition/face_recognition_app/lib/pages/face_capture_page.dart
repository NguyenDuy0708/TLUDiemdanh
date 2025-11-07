import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:convert';
import 'dart:async';
import '../services/api_service.dart';
import '../models/student.dart';

class FaceCapturePage extends StatefulWidget {
  const FaceCapturePage({super.key});

  @override
  State<FaceCapturePage> createState() => _FaceCapturePageState();
}

class _FaceCapturePageState extends State<FaceCapturePage> {
  final _apiService = ApiService();
  
  CameraController? _cameraController;
  List<Student> _students = [];
  Student? _selectedStudent;
  bool _isLoading = true;
  bool _isCapturing = false;
  int _capturedCount = 0;
  Timer? _captureTimer;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadStudents();
  }

  @override
  void dispose() {
    _captureTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không tìm thấy camera')),
          );
        }
        return;
      }

      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.medium,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Camera initialization error: $e');
    }
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
    });

    final students = await _apiService.getStudents();

    setState(() {
      _students = students;
      _isLoading = false;
    });
  }

  Future<void> _startCapture() async {
    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn sinh viên')),
      );
      return;
    }

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera chưa sẵn sàng')),
      );
      return;
    }

    setState(() {
      _isCapturing = true;
      _capturedCount = 0;
    });

    _captureTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_capturedCount >= 50) {
        timer.cancel();
        setState(() {
          _isCapturing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã chụp đủ 50 ảnh!'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }

      try {
        final image = await _cameraController!.takePicture();
        final bytes = await image.readAsBytes();
        final base64Image = base64Encode(bytes);

        final success = await _apiService.captureImage(
          _selectedStudent!.id,
          base64Image,
        );

        if (success) {
          setState(() {
            _capturedCount++;
          });
        }
      } catch (e) {
        print('Capture error: $e');
      }
    });
  }

  void _stopCapture() {
    _captureTimer?.cancel();
    setState(() {
      _isCapturing = false;
    });
  }

  Future<void> _trainModel() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final success = await _apiService.trainModel();

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Train model thành công!' : 'Train model thất bại!',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chụp ảnh khuôn mặt'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    color: Colors.black,
                    child: _cameraController != null &&
                            _cameraController!.value.isInitialized
                        ? CameraPreview(_cameraController!)
                        : const Center(
                            child: Text(
                              'Camera không khả dụng',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<Student>(
                          value: _selectedStudent,
                          decoration: InputDecoration(
                            labelText: 'Chọn sinh viên',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: _students.map((student) {
                            return DropdownMenuItem(
                              value: student,
                              child: Text(
                                '${student.studentCode} - ${student.fullName}',
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedStudent = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        if (_isCapturing)
                          LinearProgressIndicator(
                            value: _capturedCount / 50,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.purple,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          'Đã chụp: $_capturedCount/50 ảnh',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isCapturing ? _stopCapture : _startCapture,
                                icon: Icon(_isCapturing ? Icons.stop : Icons.camera),
                                label: Text(
                                  _isCapturing ? 'Dừng chụp' : 'Bắt đầu chụp',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isCapturing
                                      ? Colors.red
                                      : Colors.purple,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _capturedCount > 0 ? _trainModel : null,
                                icon: const Icon(Icons.model_training),
                                label: const Text('Train Model'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

