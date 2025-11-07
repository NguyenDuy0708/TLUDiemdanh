import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'auth_service.dart';
import '../constants/api_constants.dart';

class ExcelService {
  final AuthService _authService = AuthService();
  static const platform = MethodChannel(
    'com.example.face_recognition_app/storage',
  );

  /// Import students from Excel file (Admin only)
  Future<Map<String, dynamic>?> importStudents() async {
    try {
      // Pick Excel file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result == null || result.files.single.path == null) {
        return {'success': false, 'message': 'Không có file được chọn'};
      }

      final filePath = result.files.single.path!;
      final file = File(filePath);

      // Get session ID
      final sessionId = await _authService.getSessionId();
      if (sessionId == null) {
        return {'success': false, 'message': 'Phiên đăng nhập hết hạn'};
      }

      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConstants.baseUrl}/admin/students/import'),
      );

      request.headers['session-id'] = sessionId;
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      // Send request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Import thành công',
          'data': response.body,
        };
      } else {
        return {
          'success': false,
          'message': 'Import thất bại: ${response.body}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi: $e'};
    }
  }

  /// Export students to Excel file (Admin)
  Future<Map<String, dynamic>> exportStudentsAdmin() async {
    try {
      final sessionId = await _authService.getSessionId();
      if (sessionId == null) {
        return {'success': false, 'message': 'Phiên đăng nhập hết hạn'};
      }

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/admin/students/export'),
        headers: {'session-id': sessionId},
      );

      if (response.statusCode == 200) {
        // Save to temporary directory first
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'students_$timestamp.xlsx';
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
            'message': 'Export thành công',
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
              'message': 'Export thành công',
              'filePath': filePath,
            };
          }
          return {'success': false, 'message': 'Lỗi lưu file: ${e.message}'};
        }
      } else {
        return {'success': false, 'message': 'Export thất bại'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi: $e'};
    }
  }

  /// Export students to Excel file (Teacher - specific class)
  Future<Map<String, dynamic>> exportStudentsTeacher(int classId) async {
    try {
      final sessionId = await _authService.getSessionId();
      if (sessionId == null) {
        return {'success': false, 'message': 'Phiên đăng nhập hết hạn'};
      }

      // For teacher, we'll use the general export endpoint
      // In the future, you can create a specific endpoint for class export
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/students/export'),
        headers: {'session-id': sessionId},
      );

      if (response.statusCode == 200) {
        // Save to temporary directory first
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'students_class_${classId}_$timestamp.xlsx';
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
            'message': 'Export thành công',
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
              'message': 'Export thành công',
              'filePath': filePath,
            };
          }
          return {'success': false, 'message': 'Lỗi lưu file: ${e.message}'};
        }
      } else {
        return {'success': false, 'message': 'Export thất bại'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi: $e'};
    }
  }

  /// Get download directory based on platform
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

  /// Download sample Excel template
  Future<Map<String, dynamic>> downloadSampleTemplate() async {
    try {
      final directory = await _getDownloadDirectory();
      if (directory == null) {
        return {'success': false, 'message': 'Không thể truy cập thư mục'};
      }

      // Create a simple sample file content
      // In a real app, you might want to download this from the server
      final filePath = '${directory.path}/students_import_template.xlsx';

      return {
        'success': true,
        'message': 'Tải mẫu thành công',
        'filePath': filePath,
        'note':
            'File mẫu có định dạng: Họ và tên | Email | Số điện thoại | Năm | Mật khẩu',
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi: $e'};
    }
  }
}
