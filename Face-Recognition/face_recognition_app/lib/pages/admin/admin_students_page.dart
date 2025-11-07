import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../services/excel_service.dart';
import '../../constants/api_constants.dart';

class AdminStudentsPage extends StatefulWidget {
  const AdminStudentsPage({super.key});

  @override
  State<AdminStudentsPage> createState() => _AdminStudentsPageState();
}

class _AdminStudentsPageState extends State<AdminStudentsPage> {
  final _authService = AuthService();
  final _excelService = ExcelService();
  bool _isLoading = true;
  bool _isProcessing = false;
  List<dynamic> _students = [];
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents({String? search}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final sessionId = await _authService.getSessionId();
      if (sessionId == null) return;

      // Build URL with search parameter
      var url = '${ApiConstants.baseUrl}/admin/students';
      if (search != null && search.isNotEmpty) {
        url += '?search=${Uri.encodeComponent(search)}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {'session-id': sessionId},
      );

      if (response.statusCode == 200) {
        setState(() {
          _students = json.decode(response.body);
        });
      }
    } catch (e) {
      debugPrint('Error loading students: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
    _loadStudents(search: value);
  }

  Future<void> _showAddDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final yearController = TextEditingController();
    final passwordController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thêm sinh viên'),
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
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Vui lòng nhập họ tên' : null,
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
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Vui lòng nhập mật khẩu' : null,
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
        Uri.parse('${ApiConstants.baseUrl}/admin/students'),
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thêm sinh viên thành công!')),
          );
        }
        _loadStudents();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> student) async {
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
                student['id'],
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
    int id,
    String fullName,
    String? email,
    String? phone,
    int? year,
  ) async {
    try {
      final sessionId = await _authService.getSessionId();
      if (sessionId == null) return;

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/admin/students/$id'),
        headers: {'session-id': sessionId, 'Content-Type': 'application/json'},
        body: json.encode({
          'full_name': fullName,
          'email': email,
          'phone': phone,
          'year': year,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Cập nhật thành công!')));
        }
        _loadStudents();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Future<void> _deleteStudent(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa sinh viên "$name"?'),
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
        Uri.parse('${ApiConstants.baseUrl}/admin/students/$id'),
        headers: {'session-id': sessionId},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Xóa sinh viên thành công!')),
          );
        }
        _loadStudents();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Future<void> _handleImport() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await _excelService.importStudents();

      if (mounted) {
        if (result != null && result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Import thành công!'),
              backgroundColor: Colors.green,
            ),
          );
          // Reload students list
          await _loadStudents();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result?['message'] ?? 'Import thất bại!'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _handleExport() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await _excelService.exportStudentsAdmin();

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${result['message']}\nĐã lưu tại: ${result['filePath']}',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Export thất bại!'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showImportExportMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload_file, color: Colors.blue),
              title: const Text('Import từ Excel'),
              subtitle: const Text('Thêm sinh viên hàng loạt từ file Excel'),
              onTap: () {
                Navigator.pop(context);
                _handleImport();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.download, color: Colors.green),
              title: const Text('Export ra Excel'),
              subtitle: const Text('Tải xuống danh sách sinh viên'),
              onTap: () {
                Navigator.pop(context);
                _handleExport();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.orange),
              title: const Text('Hướng dẫn'),
              subtitle: const Text('Xem định dạng file Excel'),
              onTap: () {
                Navigator.pop(context);
                _showImportGuide();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showImportGuide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hướng dẫn Import Excel'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Định dạng file Excel:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 12),
              Text('• Cột A: Họ và tên (bắt buộc)'),
              Text('• Cột B: Email (tùy chọn)'),
              Text('• Cột C: Số điện thoại (tùy chọn)'),
              Text('• Cột D: Năm (tùy chọn)'),
              Text('• Cột E: Mật khẩu (bắt buộc)'),
              SizedBox(height: 12),
              Text(
                'Lưu ý:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text('• Dòng đầu tiên là tiêu đề (sẽ bị bỏ qua)'),
              Text('• Mã sinh viên sẽ được tự động tạo'),
              Text('• File phải có định dạng .xlsx hoặc .xls'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF4FB),
      appBar: AppBar(
        title: const Text('Quản lý sinh viên'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.import_export),
            tooltip: 'Import/Export Excel',
            onPressed: _isProcessing ? null : _showImportExportMenu,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: Colors.blue.shade700,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm theo tên, mã SV, email...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                // Student list
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => _loadStudents(search: _searchQuery),
                    child: _students.isEmpty
                        ? Center(
                            child: Text(
                              _searchQuery.isEmpty
                                  ? 'Chưa có sinh viên nào'
                                  : 'Không tìm thấy sinh viên',
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _students.length,
                            itemBuilder: (context, index) {
                              final student = _students[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 3,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blue.shade100,
                                    child: Icon(
                                      Icons.person,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                  title: Text(
                                    student['full_name'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                          Icons.edit,
                                          color: Colors.blue,
                                        ),
                                        onPressed: () =>
                                            _showEditDialog(student),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        onPressed: () => _deleteStudent(
                                          student['id'],
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
                ),
              ],
            ),
    );
  }
}
