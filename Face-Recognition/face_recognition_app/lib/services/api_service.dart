import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/api_constants.dart';
import '../models/student.dart';
import '../models/teacher.dart';
import '../models/class_model.dart';
import '../models/recognition_result.dart';
import 'auth_service.dart';

class ApiService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final sessionId = await _authService.getSessionId();
    return {
      'Content-Type': 'application/json',
      if (sessionId != null) 'session-id': sessionId,
    };
  }

  Future<List<Student>> getStudents() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.students}'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Student.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Get students error: $e');
      return [];
    }
  }

  Future<List<Teacher>> getTeachers() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.teachers}'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Teacher.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Get teachers error: $e');
      return [];
    }
  }

  Future<List<ClassModel>> getClasses() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.classes}'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => ClassModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Get classes error: $e');
      return [];
    }
  }

  Future<bool> captureImage(int studentId, String base64Image) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.faceCapture}'),
        headers: headers,
        body: json.encode({
          'student_id': studentId,
          'image': base64Image,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Capture image error: $e');
      return false;
    }
  }

  Future<bool> trainModel() async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.faceTrain}'),
        headers: headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Train model error: $e');
      return false;
    }
  }

  Future<RecognitionResult?> recognizeFace(String base64Image) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.faceRecognize}'),
        headers: headers,
        body: json.encode({
          'image': base64Image,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return RecognitionResult.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Recognize face error: $e');
      return null;
    }
  }
}

