import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TeacherRequestService {
  static const String baseUrl = 'http://127.0.0.1:8000/api';
  static const platform = MethodChannel(
    'com.example.face_recognition_app/storage',
  );

  Future<String?> _getSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('session_id');
  }

  // Create new request
  Future<Map<String, dynamic>> createRequest(
    Map<String, dynamic> requestData,
  ) async {
    try {
      final sessionId = await _getSessionId();
      if (sessionId == null) {
        return {'success': false, 'message': 'Chưa đăng nhập'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/teacher/requests'),
        headers: {'Content-Type': 'application/json', 'session-id': sessionId},
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['detail'] ?? 'Tạo yêu cầu thất bại',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi: $e'};
    }
  }

  // Get all requests
  Future<Map<String, dynamic>> getRequests({String? status}) async {
    try {
      final sessionId = await _getSessionId();
      if (sessionId == null) {
        return {'success': false, 'message': 'Chưa đăng nhập'};
      }

      String url = '$baseUrl/teacher/requests';
      if (status != null) {
        url += '?status=$status';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {'session-id': sessionId},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Lấy danh sách thất bại'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi: $e'};
    }
  }

  // Update request
  Future<Map<String, dynamic>> updateRequest({
    required int requestId,
    String? requestType,
    String? reason,
    int? classId,
    int? subjectId,
    String? requestDate,
    String? startTime,
    String? endTime,
  }) async {
    try {
      final sessionId = await _getSessionId();
      if (sessionId == null) {
        return {'success': false, 'message': 'Chưa đăng nhập'};
      }

      final body = <String, dynamic>{};
      if (requestType != null) body['request_type'] = requestType;
      if (reason != null) body['reason'] = reason;
      if (classId != null) body['class_id'] = classId;
      if (subjectId != null) body['subject_id'] = subjectId;
      if (requestDate != null) body['request_date'] = requestDate;
      if (startTime != null) body['start_time'] = startTime;
      if (endTime != null) body['end_time'] = endTime;

      final response = await http.put(
        Uri.parse('$baseUrl/teacher/requests/$requestId'),
        headers: {'Content-Type': 'application/json', 'session-id': sessionId},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['detail'] ?? 'Cập nhật thất bại',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi: $e'};
    }
  }

  // Delete request
  Future<Map<String, dynamic>> deleteRequest(int requestId) async {
    try {
      final sessionId = await _getSessionId();
      if (sessionId == null) {
        return {'success': false, 'message': 'Chưa đăng nhập'};
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/teacher/requests/$requestId'),
        headers: {'session-id': sessionId},
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Xóa thành công'};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'message': error['detail'] ?? 'Xóa thất bại'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi: $e'};
    }
  }

  // Download attendance report
  Future<Map<String, dynamic>> downloadAttendanceReport({
    int? classId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final sessionId = await _getSessionId();
      if (sessionId == null) {
        return {'success': false, 'message': 'Chưa đăng nhập'};
      }

      String url = '$baseUrl/teacher/attendance/report';
      List<String> params = [];
      if (classId != null) params.add('class_id=$classId');
      if (startDate != null) params.add('start_date=$startDate');
      if (endDate != null) params.add('end_date=$endDate');
      if (params.isNotEmpty) url += '?${params.join('&')}';

      final response = await http.get(
        Uri.parse(url),
        headers: {'session-id': sessionId},
      );

      if (response.statusCode == 200) {
        // Save to temporary directory first
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'attendance_report_$timestamp.xlsx';
        final tempFilePath = '${tempDir.path}/$fileName';
        final tempFile = File(tempFilePath);
        await tempFile.writeAsBytes(response.bodyBytes);

        // Use MediaStore to save to Downloads folder (Android 10+)
        try {
          final result = await platform.invokeMethod('saveFileToDownloads', {
            'filePath': tempFilePath,
            'fileName': fileName,
          });

          // Delete temp file
          await tempFile.delete();

          return {
            'success': true,
            'message': 'Tải báo cáo thành công',
            'filePath': result ?? '/storage/emulated/0/Download/$fileName',
          };
        } on PlatformException catch (e) {
          // Fallback: try direct write for older Android versions
          final directory = await _getDownloadDirectory();
          if (directory != null) {
            final filePath = '${directory.path}/$fileName';
            await tempFile.copy(filePath);
            await tempFile.delete();
            return {
              'success': true,
              'message': 'Tải báo cáo thành công',
              'filePath': filePath,
            };
          }
          return {'success': false, 'message': 'Lỗi lưu file: ${e.message}'};
        }
      } else {
        return {'success': false, 'message': 'Tải báo cáo thất bại'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi: $e'};
    }
  }

  Future<Directory?> _getDownloadDirectory() async {
    try {
      if (Platform.isAndroid) {
        // For Android, use external storage
        final directory = Directory('/storage/emulated/0/Download');
        if (await directory.exists()) {
          return directory;
        }
        // Fallback to app documents directory
        return await getApplicationDocumentsDirectory();
      } else if (Platform.isIOS) {
        // For iOS, use documents directory
        return await getApplicationDocumentsDirectory();
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // For desktop, use downloads directory
        return await getDownloadsDirectory();
      }
      return null;
    } catch (e) {
      print('Error getting download directory: $e');
      return null;
    }
  }
}
