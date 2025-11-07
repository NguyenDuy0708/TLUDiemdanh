import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../constants/api_constants.dart';

class AdminTeachersPage extends StatefulWidget {
  const AdminTeachersPage({super.key});

  @override
  State<AdminTeachersPage> createState() => _AdminTeachersPageState();
}

class _AdminTeachersPageState extends State<AdminTeachersPage> {
  final _authService = AuthService();
  bool _isLoading = true;
  List<dynamic> _teachers = [];

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    setState(() => _isLoading = true);
    try {
      final sessionId = await _authService.getSessionId();
      if (sessionId == null) return;

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/admin/teachers'),
        headers: {'session-id': sessionId},
      );

      if (response.statusCode == 200) {
        setState(() => _teachers = json.decode(response.body));
      }
    } catch (e) {
      print('Error: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _showAddDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final deptController = TextEditingController();
    final passwordController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thêm giáo viên'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v?.isEmpty ?? true ? 'Nhập họ tên' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: deptController,
                  decoration: const InputDecoration(
                    labelText: 'Khoa',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu *',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (v) => v?.isEmpty ?? true ? 'Nhập mật khẩu' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                await _addTeacher(
                  nameController.text,
                  emailController.text.isEmpty ? null : emailController.text,
                  phoneController.text.isEmpty ? null : phoneController.text,
                  deptController.text.isEmpty ? null : deptController.text,
                  passwordController.text,
                );
              }
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

  Future<void> _addTeacher(
    String fullName,
    String? email,
    String? phone,
    String? department,
    String password,
  ) async {
    try {
      final sessionId = await _authService.getSessionId();
      if (sessionId == null) return;

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/admin/teachers'),
        headers: {'session-id': sessionId, 'Content-Type': 'application/json'},
        body: json.encode({
          'full_name': fullName,
          'email': email,
          'phone': phone,
          'department': department,
          'password': password,
        }),
      );

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thêm giáo viên thành công!')),
        );
        _loadTeachers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> teacher) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: teacher['full_name']);
    final emailController = TextEditingController(text: teacher['email'] ?? '');
    final phoneController = TextEditingController(text: teacher['phone'] ?? '');
    final deptController =
        TextEditingController(text: teacher['department'] ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sửa thông tin'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: deptController,
                  decoration: const InputDecoration(
                    labelText: 'Khoa',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _updateTeacher(
                teacher['id'],
                nameController.text,
                emailController.text.isEmpty ? null : emailController.text,
                phoneController.text.isEmpty ? null : phoneController.text,
                deptController.text.isEmpty ? null : deptController.text,
              );
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateTeacher(
    int id,
    String fullName,
    String? email,
    String? phone,
    String? department,
  ) async {
    try {
      final sessionId = await _authService.getSessionId();
      if (sessionId == null) return;

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/admin/teachers/$id'),
        headers: {'session-id': sessionId, 'Content-Type': 'application/json'},
        body: json.encode({
          'full_name': fullName,
          'email': email,
          'phone': phone,
          'department': department,
        }),
      );

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật thành công!')),
        );
        _loadTeachers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _deleteTeacher(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa giáo viên "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final sessionId = await _authService.getSessionId();
      if (sessionId == null) return;

      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/admin/teachers/$id'),
        headers: {'session-id': sessionId},
      );

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Xóa giáo viên thành công!')),
        );
        _loadTeachers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF4FB),
      appBar: AppBar(
        title: const Text('Quản lý giáo viên'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: Colors.blue.shade700,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTeachers,
              child: _teachers.isEmpty
                  ? const Center(child: Text('Chưa có giáo viên nào'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _teachers.length,
                      itemBuilder: (context, index) {
                        final teacher = _teachers[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 3,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green.shade100,
                              child: Icon(
                                Icons.school,
                                color: Colors.green.shade700,
                              ),
                            ),
                            title: Text(
                              teacher['full_name'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('MGV: ${teacher['teacher_code']}'),
                                if (teacher['email'] != null)
                                  Text('Email: ${teacher['email']}'),
                                if (teacher['phone'] != null)
                                  Text('SĐT: ${teacher['phone']}'),
                                if (teacher['department'] != null)
                                  Text('Khoa: ${teacher['department']}'),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => _showEditDialog(teacher),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteTeacher(
                                    teacher['id'],
                                    teacher['full_name'],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

