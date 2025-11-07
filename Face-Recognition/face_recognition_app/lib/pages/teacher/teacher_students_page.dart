import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../constants/api_constants.dart';
import 'teacher_student_images_page.dart';

class TeacherStudentsPage extends StatefulWidget {
  final int classId;
  final String className;

  const TeacherStudentsPage({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<TeacherStudentsPage> createState() => _TeacherStudentsPageState();
}

class _TeacherStudentsPageState extends State<TeacherStudentsPage> {
  final _authService = AuthService();
  bool _isLoading = true;
  List<dynamic> _students = [];

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final sessionId = await _authService.getSessionId();
      if (sessionId == null) return;

      final response = await http.get(
        Uri.parse(
          '${ApiConstants.baseUrl}/teacher/classes/${widget.classId}/students',
        ),
        headers: {'session-id': sessionId},
      );

      if (response.statusCode == 200) {
        setState(() {
          _students = json.decode(response.body);
        });
      }
    } catch (e) {
      print('Error loading students: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _showAddStudentDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final yearController = TextEditingController();
    final passwordController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thêm sinh viên mới'),
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
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập họ tên';
                    }
                    return null;
                  },
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
                  controller: yearController,
                  decoration: const InputDecoration(
                    labelText: 'Năm học',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu *',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập mật khẩu';
                    }
                    return null;
                  },
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
                await _addStudent(
                  nameController.text,
                  emailController.text.isEmpty ? null : emailController.text,
                  phoneController.text.isEmpty ? null : phoneController.text,
                  yearController.text.isEmpty
                      ? null
                      : int.tryParse(yearController.text),
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

  Future<void> _addStudent(
    String fullName,
    String? email,
    String? phone,
    int? year,
    String password,
  ) async {
    try {
      final sessionId = await _authService.getSessionId();
      if (sessionId == null) return;

      final response = await http.post(
        Uri.parse(
          '${ApiConstants.baseUrl}/teacher/classes/${widget.classId}/students/new',
        ),
        headers: {'session-id': sessionId, 'Content-Type': 'application/json'},
        body: json.encode({
          'full_name': fullName,
          'email': email,
          'phone': phone,
          'year': year,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thêm sinh viên thành công!')),
        );
        _loadStudents();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: ${response.body}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _showEditStudentDialog(Map<String, dynamic> student) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: student['full_name']);
    final emailController = TextEditingController(text: student['email'] ?? '');
    final phoneController = TextEditingController(text: student['phone'] ?? '');
    final yearController = TextEditingController(
      text: student['year']?.toString() ?? '',
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sửa thông tin sinh viên'),
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
                  controller: yearController,
                  decoration: const InputDecoration(
                    labelText: 'Năm học',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
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
              await _updateStudent(
                student['student_id'],
                nameController.text,
                emailController.text.isEmpty ? null : emailController.text,
                phoneController.text.isEmpty ? null : phoneController.text,
                yearController.text.isEmpty
                    ? null
                    : int.tryParse(yearController.text),
              );
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStudent(
    int studentId,
    String fullName,
    String? email,
    String? phone,
    int? year,
  ) async {
    try {
      final sessionId = await _authService.getSessionId();
      if (sessionId == null) return;

      final response = await http.put(
        Uri.parse(
          '${ApiConstants.baseUrl}/teacher/classes/${widget.classId}/students/$studentId',
        ),
        headers: {'session-id': sessionId, 'Content-Type': 'application/json'},
        body: json.encode({
          'full_name': fullName,
          'email': email,
          'phone': phone,
          'year': year,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cập nhật thành công!')));
        _loadStudents();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _deleteStudent(int studentId, String studentName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Bạn có chắc muốn xóa sinh viên "$studentName" khỏi lớp?',
        ),
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
        Uri.parse(
          '${ApiConstants.baseUrl}/teacher/classes/${widget.classId}/students/$studentId',
        ),
        headers: {'session-id': sessionId},
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Xóa sinh viên thành công!')),
        );
        _loadStudents();
      }
    } catch (e) {
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
        title: Text('Danh sách SV - ${widget.className}'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddStudentDialog,
        backgroundColor: Colors.blue.shade700,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStudents,
              child: _students.isEmpty
                  ? const Center(child: Text('Chưa có sinh viên nào'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _students.length,
                      itemBuilder: (context, index) {
                        final student = _students[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 3,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: student['has_face_data']
                                  ? Colors.green.shade100
                                  : Colors.grey.shade300,
                              child: Icon(
                                student['has_face_data']
                                    ? Icons.face
                                    : Icons.person,
                                color: student['has_face_data']
                                    ? Colors.green.shade700
                                    : Colors.grey.shade600,
                              ),
                            ),
                            title: Text(
                              student['full_name'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('MSSV: ${student['student_code']}'),
                                if (student['email'] != null)
                                  Text('Email: ${student['email']}'),
                                if (student['phone'] != null)
                                  Text('SĐT: ${student['phone']}'),
                                if (student['year'] != null)
                                  Text('Năm: ${student['year']}'),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.image,
                                    color: Colors.green,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            TeacherStudentImagesPage(
                                              classId: widget.classId,
                                              studentId: student['student_id'],
                                              studentName: student['full_name'],
                                            ),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () =>
                                      _showEditStudentDialog(student),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _deleteStudent(
                                    student['student_id'],
                                    student['full_name'],
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
