import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../constants/api_constants.dart';

class TeacherStudentImagesPage extends StatefulWidget {
  final int classId;
  final int studentId;
  final String studentName;

  const TeacherStudentImagesPage({
    super.key,
    required this.classId,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<TeacherStudentImagesPage> createState() =>
      _TeacherStudentImagesPageState();
}

class _TeacherStudentImagesPageState extends State<TeacherStudentImagesPage> {
  final _authService = AuthService();
  bool _isLoading = true;
  Map<String, dynamic>? _data;
  List<dynamic> _images = [];

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final sessionId = await _authService.getSessionId();
      if (sessionId == null) return;

      final response = await http.get(
        Uri.parse(
          '${ApiConstants.baseUrl}/teacher/classes/${widget.classId}/students/${widget.studentId}/images',
        ),
        headers: {'session-id': sessionId},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _data = data;
          _images = data['images'] ?? [];
        });
      }
    } catch (e) {
      print('Error loading images: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _deleteAllImages() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Bạn có chắc muốn xóa TẤT CẢ ${_images.length} ảnh khuôn mặt của ${widget.studentName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa tất cả'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final sessionId = await _authService.getSessionId();
      if (sessionId == null) return;

      final response = await http.delete(
        Uri.parse(
          '${ApiConstants.baseUrl}/teacher/students/${widget.studentId}/face-images',
        ),
        headers: {'session-id': sessionId},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa tất cả ảnh khuôn mặt!')),
          );
        }
        _loadImages();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF4FB),
      appBar: AppBar(
        title: Text('Ảnh khuôn mặt - ${widget.studentName}'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (_images.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_forever),
              onPressed: _deleteAllImages,
              tooltip: 'Xóa tất cả ảnh',
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadImages),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadImages,
              child: Column(
                children: [
                  // Student info
                  if (_data != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.white,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.blue.shade100,
                            child: Icon(
                              Icons.person,
                              size: 35,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _data!['full_name'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'MSSV: ${_data!['student_code'] ?? ''}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                Text(
                                  'Số ảnh: ${_images.length}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 1),

                  // Images list
                  Expanded(
                    child: _images.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image_not_supported,
                                  size: 80,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Chưa có ảnh khuôn mặt',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _images.length,
                            itemBuilder: (context, index) {
                              final image = _images[index];
                              final filename = image['filename'] ?? '';
                              final createdAt = image['created_at'] ?? '';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 3,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blue.shade100,
                                    child: Icon(
                                      Icons.image,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                  title: Text(
                                    filename,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Ngày tạo: ${createdAt.split('T')[0]}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.info_outline,
                                      color: Colors.blue,
                                    ),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Thông tin ảnh'),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text('Tên file: $filename'),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Đường dẫn: ${image['path'] ?? ''}',
                                              ),
                                              const SizedBox(height: 8),
                                              Text('Ngày tạo: $createdAt'),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text('Đóng'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
