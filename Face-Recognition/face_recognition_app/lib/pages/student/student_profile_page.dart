import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../constants/api_constants.dart';

class StudentProfilePage extends StatefulWidget {
  const StudentProfilePage({super.key});

  @override
  State<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> {
  final _authService = AuthService();
  bool _isLoading = true;
  Map<String, dynamic>? _userInfo;
  List<dynamic> _faceImages = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final sessionId = await _authService.getSessionId();
      if (sessionId == null) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      // Get user info
      final userResponse = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/auth/me'),
        headers: {'session-id': sessionId},
      );

      if (userResponse.statusCode == 200) {
        _userInfo = json.decode(userResponse.body);
      }

      // Get face images
      final imagesResponse = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/student/my-face-images'),
        headers: {'session-id': sessionId},
      );

      if (imagesResponse.statusCode == 200) {
        final data = json.decode(imagesResponse.body);
        if (data is List) {
          _faceImages = data;
        }
      }
    } catch (e) {
      print('Error loading data: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _captureImages() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chụp ảnh khuôn mặt'),
        content: const Text(
          'Hệ thống sẽ mở camera máy tính để chụp 100 ảnh khuôn mặt của bạn.\n\n'
          'Vui lòng:\n'
          '• Ngồi trước camera\n'
          '• Xoay mặt nhiều góc độ\n'
          '• Giữ khuôn mặt trong khung hình\n'
          '• Nhấn Q để thoát sớm\n\n'
          'Bạn có muốn tiếp tục?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Bắt đầu'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      if (!mounted) return;
      setState(() => _isLoading = true);

      final sessionId = await _authService.getSessionId();
      if (sessionId == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }

      // Step 1: Capture images
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/student/capture-face'),
        headers: {'session-id': sessionId},
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // Show success message
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Chụp ảnh thành công!')),
          );

          // Ask if user wants to train model
          if (!mounted) return;
          final trainNow = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Chụp ảnh thành công!'),
              content: Text(
                '${data['message']}\n\n'
                'Bạn có muốn train model ngay bây giờ không?\n'
                '(Quá trình train có thể mất 1-2 phút)',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Để sau'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Train ngay'),
                ),
              ],
            ),
          );

          if (trainNow == true) {
            _trainModel();
          } else {
            _loadData();
          }
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Chụp ảnh thất bại!')),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Chụp ảnh thất bại!')));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _trainModel() async {
    try {
      if (!mounted) return;
      setState(() => _isLoading = true);

      final sessionId = await _authService.getSessionId();
      if (sessionId == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }

      // Show progress dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Đang train model...\nVui lòng đợi 1-2 phút'),
            ],
          ),
        ),
      );

      // Step 2: Train model
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/student/train-model'),
        headers: {'session-id': sessionId},
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      // Close progress dialog
      if (!mounted) return;
      Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Train model thành công!'),
            ),
          );
          _loadData();
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Train model thất bại!')),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Train model thất bại!')));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      // Close progress dialog if still open
      if (mounted) Navigator.pop(context);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _deleteImage(String filename) async {
    try {
      final sessionId = await _authService.getSessionId();
      if (sessionId == null) return;

      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/student/my-face-images/$filename'),
        headers: {'session-id': sessionId},
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Xóa ảnh thành công!')));
        _loadData();
      }
    } catch (e) {
      // Error deleting image
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đổi mật khẩu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mật khẩu cũ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mật khẩu mới',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Xác nhận mật khẩu mới',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              if (newPasswordController.text !=
                  confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mật khẩu mới không khớp!')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Đổi mật khẩu'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _changePassword(
        oldPasswordController.text,
        newPasswordController.text,
      );
    }
  }

  Future<void> _changePassword(String oldPassword, String newPassword) async {
    try {
      final sessionId = await _authService.getSessionId();
      if (sessionId == null) return;

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/student/change-password'),
        headers: {'session-id': sessionId, 'Content-Type': 'application/json'},
        body: json.encode({
          'old_password': oldPassword,
          'new_password': newPassword,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Đổi mật khẩu thành công!'),
          ),
        );
      } else {
        final error = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error['detail'] ?? 'Đổi mật khẩu thất bại!')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF4FB),
      appBar: AppBar(
        title: const Text('Thông tin cá nhân'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User info card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          FutureBuilder<String?>(
                            future: _authService.getSessionId(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data != null) {
                                final sessionId = snapshot.data!;
                                final avatarUrl =
                                    '${ApiConstants.baseUrl}/student/avatar';

                                return CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.blue.shade100,
                                  backgroundImage: NetworkImage(
                                    avatarUrl,
                                    headers: {'session-id': sessionId},
                                  ),
                                  onBackgroundImageError: (_, __) {
                                    // Fallback to icon if image fails to load
                                  },
                                  child: const SizedBox(),
                                );
                              }

                              // Fallback to icon
                              return CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.blue.shade100,
                                child: Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.blue.shade700,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _userInfo?['full_name'] ?? '',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            'MSSV',
                            _userInfo?['student_code'] ?? '',
                          ),
                          _buildInfoRow(
                            'Username',
                            _userInfo?['username'] ?? '',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Change password button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showChangePasswordDialog,
                      icon: const Icon(Icons.lock),
                      label: const Text('Đổi mật khẩu'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Face images section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ảnh khuôn mặt (${_faceImages.length})',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _captureImages,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Chụp ảnh'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _faceImages.isEmpty
                      ? Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Center(
                              child: Text(
                                'Chưa có ảnh khuôn mặt.\nVui lòng thêm ảnh để train model.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ),
                          ),
                        )
                      : GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                          itemCount: _faceImages.length,
                          itemBuilder: (context, index) {
                            final image = _faceImages[index];
                            return Card(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Icon(
                                    Icons.image,
                                    size: 50,
                                    color: Colors.grey.shade400,
                                  ),
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () =>
                                          _deleteImage(image['filename']),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      color: Colors.black54,
                                      padding: const EdgeInsets.all(4),
                                      child: Text(
                                        image['filename'] ?? '',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }
}
