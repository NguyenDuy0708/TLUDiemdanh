import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class AdminRequestService {
  static const String baseUrl = 'http://127.0.0.1:8000/api';
  static const platform = MethodChannel(
    'com.example.face_recognition_app/storage',
  );

  Future<String?> _getSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('session_id');
  }

  // Get all requests
  Future<Map<String, dynamic>> getAllRequests({
    String? status,
    int? teacherId,
  }) async {
    try {
      final sessionId = await _getSessionId();
      if (sessionId == null) {
        return {'success': false, 'message': 'Chưa đăng nhập'};
      }

      String url = '$baseUrl/admin/requests';
      List<String> params = [];
      if (status != null) params.add('status=$status');
      if (teacherId != null) params.add('teacher_id=$teacherId');
      if (params.isNotEmpty) url += '?${params.join('&')}';

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

  // Approve request
  Future<Map<String, dynamic>> approveRequest({
    required int requestId,
    String? adminNote,
  }) async {
    try {
      final sessionId = await _getSessionId();
      if (sessionId == null) {
        return {'success': false, 'message': 'Chưa đăng nhập'};
      }

      final response = await http.put(
        Uri.parse('$baseUrl/admin/requests/$requestId/approve'),
        headers: {'Content-Type': 'application/json', 'session-id': sessionId},
        body: jsonEncode({if (adminNote != null) 'admin_note': adminNote}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data, 'message': 'Đã duyệt yêu cầu'};
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['detail'] ?? 'Duyệt thất bại',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi: $e'};
    }
  }

  // Reject request
  Future<Map<String, dynamic>> rejectRequest({
    required int requestId,
    String? adminNote,
  }) async {
    try {
      final sessionId = await _getSessionId();
      if (sessionId == null) {
        return {'success': false, 'message': 'Chưa đăng nhập'};
      }

      final response = await http.put(
        Uri.parse('$baseUrl/admin/requests/$requestId/reject'),
        headers: {'Content-Type': 'application/json', 'session-id': sessionId},
        body: jsonEncode({if (adminNote != null) 'admin_note': adminNote}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data, 'message': 'Đã từ chối yêu cầu'};
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['detail'] ?? 'Từ chối thất bại',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi: $e'};
    }
  }

  // Download attendance statistics
  Future<Map<String, dynamic>> downloadAttendanceStatistics({
    int? classId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final sessionId = await _getSessionId();
      if (sessionId == null) {
        return {'success': false, 'message': 'Chưa đăng nhập'};
      }

      String url = '$baseUrl/admin/attendance/statistics';
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
        final fileName = 'attendance_statistics_$timestamp.xlsx';
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
            'message': 'Tải thống kê thành công',
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
              'message': 'Tải thống kê thành công',
              'filePath': filePath,
            };
          }
          return {'success': false, 'message': 'Lỗi lưu file: ${e.message}'};
        }
      } else {
        return {'success': false, 'message': 'Tải thống kê thất bại'};
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
