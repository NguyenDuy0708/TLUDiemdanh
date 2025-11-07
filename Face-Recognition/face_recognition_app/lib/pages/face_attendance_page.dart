import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../constants/api_constants.dart';

class FaceAttendancePage extends StatefulWidget {
  final int classId;
  final String className;

  const FaceAttendancePage({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<FaceAttendancePage> createState() => _FaceAttendancePageState();
}

class _FaceAttendancePageState extends State<FaceAttendancePage> {
  final _authService = AuthService();
  bool _isProcessing = false;
  String? _message;
  bool _success = false;

  Future<void> _recognizeAndCheckIn() async {
    setState(() {
      _isProcessing = true;
      _message = 'Đang mở camera ...\nVui lòng nhìn vào camera';
      _success = false;
    });

    try {
      final sessionId = await _authService.getSessionId();
      if (sessionId == null) {
        setState(() {
          _message = 'Phiên đăng nhập hết hạn';
          _isProcessing = false;
        });
        return;
      }

      // Get current date
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // Call recognize API
      final response = await http.post(
        Uri.parse(
          '${ApiConstants.baseUrl}/student/attendance/recognize?class_id=${widget.classId}&session_date=$dateStr',
        ),
        headers: {'session-id': sessionId},
      );

      print('Recognize response: ${response.statusCode}');
      print('Recognize body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          if (!mounted) return;
          setState(() {
            _message = data['message'] ?? 'Điểm danh thành công!';
            _isProcessing = false;
            _success = true;
          });

          // Show success dialog
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Thành công'),
              content: Text(
                '${data['message']}\n\n'
                'Sinh viên: ${data['student_name']}\n'
                'Mã SV: ${data['student_code']}\n'
                'Lớp: ${data['class_name']}\n'
                'Ngày: ${data['date']}\n'
                'Giờ điểm danh: ${data['check_in_time']}\n'
                'Trạng thái: ${data['status']}',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Go back to home
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          if (!mounted) return;
          setState(() {
            _message = data['message'] ?? 'Không thể điểm danh';
            _isProcessing = false;
          });
        }
      } else {
        final error = json.decode(response.body);
        if (!mounted) return;
        setState(() {
          _message = 'Lỗi: ${error['detail'] ?? 'Không thể điểm danh'}';
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = 'Lỗi: $e';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF7FF),
      appBar: AppBar(
        title: Text('Điểm danh - ${widget.className}'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              // Icon
              Icon(
                _success ? Icons.check_circle : Icons.camera_alt,
                size: 100,
                color: _success ? Colors.green : Colors.blue.shade700,
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                'Điểm danh bằng nhận diện khuôn mặt',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Message
              if (_message != null)
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _success
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _success ? Colors.green : Colors.orange,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _message!,
                      style: TextStyle(
                        color: _success
                            ? Colors.green.shade900
                            : Colors.orange.shade900,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              const SizedBox(height: 32),

              // Instructions
              const Text(
                'Hướng dẫn:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '1. Bấm nút "Bắt đầu điểm danh"\n'
                '2. Camera máy tính sẽ tự động mở\n'
                '3. Nhìn vào camera và chờ nhận diện\n'
                '4. Hệ thống sẽ tự động điểm danh',
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _recognizeAndCheckIn,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.camera_alt),
                  label: Text(
                    _isProcessing ? 'Đang xử lý...' : 'Bắt đầu điểm danh',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
