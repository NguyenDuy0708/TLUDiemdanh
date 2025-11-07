import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../constants/api_constants.dart';
import 'admin_class_detail_page.dart';

class AdminClassesPage extends StatefulWidget {
  const AdminClassesPage({super.key});

  @override
  State<AdminClassesPage> createState() => _AdminClassesPageState();
}

class _AdminClassesPageState extends State<AdminClassesPage> {
  final _authService = AuthService();
  bool _isLoading = true;
  List<dynamic> _classes = [];
  List<dynamic> _teachers = [];
  List<dynamic> _subjects = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final sessionId = await _authService.getSessionId();
      if (sessionId == null) return;

      final headers = {'session-id': sessionId};

      final responses = await Future.wait([
        http.get(
          Uri.parse('${ApiConstants.baseUrl}/admin/classes'),
          headers: headers,
        ),
        http.get(
          Uri.parse('${ApiConstants.baseUrl}/admin/teachers'),
          headers: headers,
        ),
        http.get(
          Uri.parse('${ApiConstants.baseUrl}/admin/subjects'),
          headers: headers,
        ),
      ]);

      if (responses[0].statusCode == 200) {
        setState(() {
          _classes = json.decode(responses[0].body);
          _teachers = json.decode(responses[1].body);
          _subjects = json.decode(responses[2].body);
        });
      }
    } catch (e) {
      print('Error: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _showAddDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final semesterController = TextEditingController();
    final yearController = TextEditingController(
      text: DateTime.now().year.toString(),
    );
    int? selectedTeacherId;
    int? selectedSubjectId;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Thêm lớp học'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên lớp *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v?.isEmpty ?? true ? 'Nhập tên lớp' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Giáo viên *',
                      border: OutlineInputBorder(),
                    ),
                    value: selectedTeacherId,
                    items: _teachers.map<DropdownMenuItem<int>>((teacher) {
                      return DropdownMenuItem<int>(
                        value: teacher['id'],
                        child: Text(teacher['full_name']),
                      );
                    }).toList(),
                    onChanged: (value) =>
                        setState(() => selectedTeacherId = value),
                    validator: (v) => v == null ? 'Chọn giáo viên' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Môn học *',
                      border: OutlineInputBorder(),
                    ),
                    value: selectedSubjectId,
                    items: _subjects.map<DropdownMenuItem<int>>((subject) {
                      return DropdownMenuItem<int>(
                        value: subject['id'],
                        child: Text(subject['subject_name']),
                      );
                    }).toList(),
                    onChanged: (value) =>
                        setState(() => selectedSubjectId = value),
                    validator: (v) => v == null ? 'Chọn môn học' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: semesterController,
                    decoration: const InputDecoration(
                      labelText: 'Học kỳ *',
                      border: OutlineInputBorder(),
                      hintText: 'VD: HK1, HK2',
                    ),
                    validator: (v) => v?.isEmpty ?? true ? 'Nhập học kỳ' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: yearController,
                    decoration: const InputDecoration(
                      labelText: 'Năm học *',
                      border: OutlineInputBorder(),
                      hintText: 'VD: 2024',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v?.isEmpty ?? true) return 'Nhập năm học';
                      final year = int.tryParse(v!);
                      if (year == null || year < 2000 || year > 2100) {
                        return 'Năm học không hợp lệ';
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
                  await _addClass(
                    nameController.text,
                    selectedTeacherId!,
                    selectedSubjectId!,
                    semesterController.text,
                    int.parse(yearController.text),
                  );
                }
              },
              child: const Text('Thêm'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addClass(
    String className,
    int teacherId,
    int subjectId,
    String semester,
    int year,
  ) async {
    try {
      final sessionId = await _authService.getSessionId();
      if (sessionId == null) return;

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/admin/classes'),
        headers: {'session-id': sessionId, 'Content-Type': 'application/json'},
        body: json.encode({
          'class_name': className,
          'teacher_id': teacherId,
          'subject_id': subjectId,
          'semester': semester,
          'year': year,
        }),
      );

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thêm lớp học thành công!')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> cls) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: cls['class_name']);
    final semesterController = TextEditingController(
      text: cls['semester'] ?? '',
    );
    final yearController = TextEditingController(
      text: cls['year']?.toString() ?? '',
    );
    int? selectedTeacherId = cls['teacher_id'];
    int? selectedSubjectId = cls['subject_id'];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Sửa lớp học'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên lớp *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v?.isEmpty ?? true ? 'Nhập tên lớp' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Giáo viên *',
                      border: OutlineInputBorder(),
                    ),
                    value: selectedTeacherId,
                    items: _teachers.map<DropdownMenuItem<int>>((teacher) {
                      return DropdownMenuItem<int>(
                        value: teacher['id'],
                        child: Text(teacher['full_name']),
                      );
                    }).toList(),
                    onChanged: (value) =>
                        setState(() => selectedTeacherId = value),
                    validator: (v) => v == null ? 'Chọn giáo viên' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Môn học *',
                      border: OutlineInputBorder(),
                    ),
                    value: selectedSubjectId,
                    items: _subjects.map<DropdownMenuItem<int>>((subject) {
                      return DropdownMenuItem<int>(
                        value: subject['id'],
                        child: Text(subject['subject_name']),
                      );
                    }).toList(),
                    onChanged: (value) =>
                        setState(() => selectedSubjectId = value),
                    validator: (v) => v == null ? 'Chọn môn học' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: semesterController,
                    decoration: const InputDecoration(
                      labelText: 'Học kỳ *',
                      border: OutlineInputBorder(),
                      hintText: 'VD: HK1, HK2',
                    ),
                    validator: (v) => v?.isEmpty ?? true ? 'Nhập học kỳ' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: yearController,
                    decoration: const InputDecoration(
                      labelText: 'Năm học *',
                      border: OutlineInputBorder(),
                      hintText: 'VD: 2024',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v?.isEmpty ?? true) return 'Nhập năm học';
                      final year = int.tryParse(v!);
                      if (year == null || year < 2000 || year > 2100) {
                        return 'Năm học không hợp lệ';
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
                  await _editClass(
                    cls['id'],
                    nameController.text,
                    selectedTeacherId!,
                    selectedSubjectId!,
                    semesterController.text,
                    int.parse(yearController.text),
                  );
                }
              },
              child: const Text('Cập nhật'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editClass(
    int id,
    String className,
    int teacherId,
    int subjectId,
    String semester,
    int year,
  ) async {
    try {
      final sessionId = await _authService.getSessionId();
      if (sessionId == null) return;

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/admin/classes/$id'),
        headers: {'session-id': sessionId, 'Content-Type': 'application/json'},
        body: json.encode({
          'class_name': className,
          'teacher_id': teacherId,
          'subject_id': subjectId,
          'semester': semester,
          'year': year,
        }),
      );

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật lớp học thành công!')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Future<void> _deleteClass(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa lớp "$name"?'),
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
        Uri.parse('${ApiConstants.baseUrl}/admin/classes/$id'),
        headers: {'session-id': sessionId},
      );

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Xóa lớp học thành công!')),
        );
        _loadData();
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
        title: const Text('Quản lý lớp học'),
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
              onRefresh: _loadData,
              child: _classes.isEmpty
                  ? const Center(child: Text('Chưa có lớp học nào'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _classes.length,
                      itemBuilder: (context, index) {
                        final cls = _classes[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 3,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.orange.shade100,
                              child: Icon(
                                Icons.class_,
                                color: Colors.orange.shade700,
                              ),
                            ),
                            title: Text(
                              cls['class_name'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Mã lớp: ${cls['class_code']}'),
                                Text('GV: ${cls['teacher_name'] ?? 'N/A'}'),
                                Text('Môn: ${cls['subject_name'] ?? 'N/A'}'),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () => _showEditDialog(cls),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.arrow_forward,
                                    color: Colors.green,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            AdminClassDetailPage(
                                              classId: cls['id'],
                                              className: cls['class_name'],
                                            ),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _deleteClass(
                                    cls['id'],
                                    cls['class_name'],
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
