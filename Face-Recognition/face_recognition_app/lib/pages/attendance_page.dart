import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:convert';
import 'dart:async';
import '../services/api_service.dart';
import '../models/recognition_result.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final _apiService = ApiService();
  
  CameraController? _cameraController;
  bool _isLoading = true;
  bool _isRecognizing = false;
  Timer? _recognitionTimer;
  
  RecognitionResult? _lastResult;
  final List<Map<String, dynamic>> _attendanceList = [];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _recognitionTimer?.cancel();
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
        setState(() {
          _isLoading = false;
        });
        _startRecognition();
      }
    } catch (e) {
      print('Camera initialization error: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startRecognition() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() {
      _isRecognizing = true;
    });

    _recognitionTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!_isRecognizing) {
        timer.cancel();
        return;
      }

      try {
        final image = await _cameraController!.takePicture();
        final bytes = await image.readAsBytes();
        final base64Image = base64Encode(bytes);

        final result = await _apiService.recognizeFace(base64Image);

        if (result != null && result.recognized && mounted) {
          setState(() {
            _lastResult = result;
          });

          final existingIndex = _attendanceList.indexWhere(
            (item) => item['studentId'] == result.studentId,
          );

          if (existingIndex == -1) {
            setState(() {
              _attendanceList.insert(0, {
                'studentId': result.studentId,
                'studentCode': result.studentCode,
                'studentName': result.studentName,
                'shift': result.shift,
                'shiftName': result.shiftName,
                'time': DateTime.now(),
              });
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Điểm danh thành công: ${result.studentName}',
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      } catch (e) {
        print('Recognition error: $e');
      }
    });
  }

  void _stopRecognition() {
    _recognitionTimer?.cancel();
    setState(() {
      _isRecognizing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Điểm danh'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isRecognizing ? Icons.pause : Icons.play_arrow),
            onPressed: _isRecognizing ? _stopRecognition : _startRecognition,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  flex: 2,
                  child: Stack(
                    children: [
                      Container(
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
                      if (_lastResult != null && _lastResult!.recognized)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withOpacity(0.8),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _lastResult!.studentName ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Mã SV: ${_lastResult!.studentCode}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  _lastResult!.shiftName ?? '',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                ),
                                if (_lastResult!.confidence != null)
                                  Text(
                                    'Độ tin cậy: ${(_lastResult!.confidence! * 100).toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      if (_isRecognizing)
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.fiber_manual_record,
                                  color: Colors.white,
                                  size: 12,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Đang nhận diện',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Danh sách điểm danh',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_attendanceList.length} sinh viên',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: _attendanceList.isEmpty
                              ? Center(
                                  child: Text(
                                    'Chưa có sinh viên nào điểm danh',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _attendanceList.length,
                                  itemBuilder: (context, index) {
                                    final item = _attendanceList[index];
                                    final time = item['time'] as DateTime;
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Colors.teal.shade100,
                                          child: Icon(
                                            Icons.person,
                                            color: Colors.teal.shade700,
                                          ),
                                        ),
                                        title: Text(
                                          item['studentName'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${item['studentCode']} - ${item['shiftName']}',
                                        ),
                                        trailing: Text(
                                          '${time.hour}:${time.minute.toString().padLeft(2, '0')}',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
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

