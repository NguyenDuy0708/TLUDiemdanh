import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../constants/api_constants.dart';

class AdminSubjectsPage extends StatefulWidget {
  const AdminSubjectsPage({super.key});

  @override
  State<AdminSubjectsPage> createState() => _AdminSubjectsPageState();
}

class _AdminSubjectsPageState extends State<AdminSubjectsPage> {
  final _authService = AuthService();
  bool _isLoading = true;
  List<dynamic> _subjects = [];

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    setState(() => _isLoading = true);
    try {
      final sessionId = await _authService.getSessionId();
      if (sessionId == null) return;

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/admin/subjects'),
        headers: {'session-id': sessionId},
      );

      if (response.statusCode == 200) {
        setState(() => _subjects = json.decode(response.body));
      }
    } catch (e) {
      print('Error: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _showAddDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final creditsController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thêm môn học'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Tên môn học *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Nhập tên môn' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: creditsController,
                decoration: const InputDecoration(
                  labelText: 'Số tín chỉ *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v?.isEmpty ?? true ? 'Nhập số tín chỉ' : null,
              ),
            ],
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
                await _addSubject(
                  nameController.text,
                  int.parse(creditsController.text),
                );
              }
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

  Future<void> _addSubject(String subjectName, int credits) async {
    try {
      final sessionId = await _authService.getSessionId();
      if (sessionId == null) return;

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/admin/subjects'),
        headers: {'session-id': sessionId, 'Content-Type': 'application/json'},
        body: json.encode({
          'subject_name': subjectName,
          'credits': credits,
        }),
      );

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thêm môn học thành công!')),
        );
        _loadSubjects();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> subject) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: subject['subject_name']);
    final creditsController =
        TextEditingController(text: subject['credits'].toString());

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sửa môn học'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Tên môn học',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: creditsController,
                decoration: const InputDecoration(
                  labelText: 'Số tín chỉ',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
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
              await _updateSubject(
                subject['id'],
                nameController.text,
                int.parse(creditsController.text),
              );
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateSubject(int id, String subjectName, int credits) async {
    try {
      final sessionId = await _authService.getSessionId();
      if (sessionId == null) return;

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/admin/subjects/$id'),
        headers: {'session-id': sessionId, 'Content-Type': 'application/json'},
        body: json.encode({
          'subject_name': subjectName,
          'credits': credits,
        }),
      );

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật thành công!')),
        );
        _loadSubjects();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _deleteSubject(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa môn học "$name"?'),
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
        Uri.parse('${ApiConstants.baseUrl}/admin/subjects/$id'),
        headers: {'session-id': sessionId},
      );

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Xóa môn học thành công!')),
        );
        _loadSubjects();
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
        title: const Text('Quản lý môn học'),
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
              onRefresh: _loadSubjects,
              child: _subjects.isEmpty
                  ? const Center(child: Text('Chưa có môn học nào'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _subjects.length,
                      itemBuilder: (context, index) {
                        final subject = _subjects[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 3,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.purple.shade100,
                              child: Icon(
                                Icons.book,
                                color: Colors.purple.shade700,
                              ),
                            ),
                            title: Text(
                              subject['subject_name'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Mã MH: ${subject['subject_code']}'),
                                Text('Tín chỉ: ${subject['credits']}'),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => _showEditDialog(subject),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteSubject(
                                    subject['id'],
                                    subject['subject_name'],
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

