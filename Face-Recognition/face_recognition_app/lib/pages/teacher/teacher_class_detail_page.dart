import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../services/excel_service.dart';
import '../../constants/api_constants.dart';
import '../../widgets/custom_loading.dart';

class TeacherClassDetailPage extends StatefulWidget {
  final int classId;
  final String className;
  final String subjectName;
  final String startTime;
  final String endTime;
  final String room;
  final String mode;
  final int studentCount;

  const TeacherClassDetailPage({
    super.key,
    required this.classId,
    required this.className,
    required this.subjectName,
    required this.startTime,
    required this.endTime,
    required this.room,
    required this.mode,
    required this.studentCount,
  });

  @override
  State<TeacherClassDetailPage> createState() => _TeacherClassDetailPageState();
}

class _TeacherClassDetailPageState extends State<TeacherClassDetailPage> {
  final _authService = AuthService();
  final _excelService = ExcelService();
  bool _isLoading = true;
  bool _isExporting = false;
  List<dynamic> _students = [];
  Map<int, String> _attendanceStatus = {}; // student_id -> status

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

      // Get students
      final studentsResponse = await http.get(
        Uri.parse(
          '${ApiConstants.baseUrl}/teacher/classes/${widget.classId}/students',
        ),
        headers: {'session-id': sessionId},
      );

      if (studentsResponse.statusCode == 200) {
        _students = json.decode(studentsResponse.body);
      }

      // Get attendance for today
      final attendanceResponse = await http.get(
        Uri.parse(
          '${ApiConstants.baseUrl}/teacher/classes/${widget.classId}/attendance?start_time=${widget.startTime}&end_time=${widget.endTime}',
        ),
        headers: {'session-id': sessionId},
      );

      if (attendanceResponse.statusCode == 200) {
        final attendanceList = json.decode(attendanceResponse.body) as List;
        for (var record in attendanceList) {
          _attendanceStatus[record['student_id']] = record['status'];
        }
      }
    } catch (e) {
      print('Error loading students: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _markAttendance(int studentId, String status) async {
    try {
      final sessionId = await _authService.getSessionId();
      if (sessionId == null) return;

      final response = await http.post(
        Uri.parse(
          '${ApiConstants.baseUrl}/teacher/classes/${widget.classId}/attendance/manual',
        ),
        headers: {'session-id': sessionId, 'Content-Type': 'application/json'},
        body: json.encode({
          'student_id': studentId,
          'status': status,
          'start_time': widget.startTime,
          'end_time': widget.endTime,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _attendanceStatus[studentId] = status;
        });
      }
    } catch (e) {
      print('Error marking attendance: $e');
    }
  }

  Future<void> _showAddStudentDialog() async {
    try {
      final sessionId = await _authService.getSessionId();
      if (sessionId == null) return;

      // Get all students
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/students'),
        headers: {'session-id': sessionId},
      );

      if (response.statusCode != 200) return;

      final allStudents = json.decode(response.body) as List;

      // Filter out students already in class
      final currentStudentIds = _students.map((s) => s['student_id']).toSet();
      final availableStudents = allStudents
          .where((s) => !currentStudentIds.contains(s['student_id']))
          .toList();

      if (!mounted) return;

      final selectedStudents = await showDialog<List<int>>(
        context: context,
        builder: (context) => _AddStudentDialog(students: availableStudents),
      );

      if (selectedStudents != null && selectedStudents.isNotEmpty) {
        await _addStudentsToClass(selectedStudents);
      }
    } catch (e) {
      print('Error showing add student dialog: $e');
    }
  }

  Future<void> _addStudentsToClass(List<int> studentIds) async {
    try {
      final sessionId = await _authService.getSessionId();
      if (sessionId == null) return;

      final response = await http.post(
        Uri.parse(
          '${ApiConstants.baseUrl}/teacher/classes/${widget.classId}/students',
        ),
        headers: {'session-id': sessionId, 'Content-Type': 'application/json'},
        body: json.encode({'student_ids': studentIds}),
      );

      if (response.statusCode == 200) {
        // Reload students
        await _loadStudents();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã thêm sinh viên vào lớp')),
          );
        }
      }
    } catch (e) {
      print('Error adding students: $e');
    }
  }

  Future<void> _removeStudent(int studentId, String studentName) async {
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
        await _loadStudents();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa sinh viên khỏi lớp')),
          );
        }
      }
    } catch (e) {
      print('Error removing student: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Future<void> _handleExport() async {
    setState(() {
      _isExporting = true;
    });

    try {
      final result = await _excelService.exportStudentsTeacher(widget.classId);

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Export thành công!\nĐã lưu tại: ${result['filePath']}',
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
          _isExporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF7FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Buổi học hôm nay',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFFC7C7C7),
          ),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const CustomLoading()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Class info card
                  _buildClassInfoCard(),
                  const SizedBox(height: 16),
                  // Student list header with add button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Danh sách sinh viên',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isExporting ? null : _handleExport,
                            icon: const Icon(Icons.download, size: 18),
                            label: const Text('Export'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _showAddStudentDialog,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Thêm SV'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Students list
                  ..._students.map((student) => _buildStudentItem(student)),
                ],
              ),
            ),
    );
  }

  Widget _buildClassInfoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFBEE5FF)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.subjectName.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFD7FAD2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Hoàn thành',
                  style: TextStyle(fontSize: 12, color: Color(0xFF1E9E3F)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('⏰ Thời gian: ${widget.startTime} – ${widget.endTime}'),
          Text('📍 Phòng học: ${widget.room}'),
          Text('👨‍🎓 Sinh viên: ${_students.length}/${widget.studentCount}'),
          Text(
            '💻 Hình thức: ${widget.mode == 'online' ? 'Online' : 'Offline'}',
          ),
        ],
      ),
    );
  }

  Widget _buildStudentItem(Map<String, dynamic> student) {
    final studentId = student['student_id'];
    final currentStatus = _attendanceStatus[studentId] ?? 'absent';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: Color(0xFFE0E0E0),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, size: 20),
          ),
          const SizedBox(width: 12),
          // Student info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Họ và Tên: ${student['full_name']}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'MSSV: ${student['student_code']}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          // Radio buttons
          Row(
            children: [
              _buildRadioButton('Có mặt', 'present', currentStatus, studentId),
              const SizedBox(width: 8),
              _buildRadioButton('Đi muộn', 'late', currentStatus, studentId),
              const SizedBox(width: 8),
              _buildRadioButton('Vắng', 'absent', currentStatus, studentId),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                onPressed: () =>
                    _removeStudent(studentId, student['full_name']),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRadioButton(
    String label,
    String value,
    String currentStatus,
    int studentId,
  ) {
    final isSelected = currentStatus == value;
    return GestureDetector(
      onTap: () => _markAttendance(studentId, value),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: isSelected ? Colors.blue : Colors.grey),
              color: isSelected ? Colors.blue : Colors.transparent,
            ),
            child: isSelected
                ? const Icon(Icons.circle, size: 8, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

// Dialog to add students to class
class _AddStudentDialog extends StatefulWidget {
  final List<dynamic> students;

  const _AddStudentDialog({required this.students});

  @override
  State<_AddStudentDialog> createState() => _AddStudentDialogState();
}

class _AddStudentDialogState extends State<_AddStudentDialog> {
  final Set<int> _selectedStudentIds = {};
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<dynamic> get _filteredStudents {
    if (_searchQuery.isEmpty) return widget.students;

    final query = _searchQuery.toLowerCase();
    return widget.students.where((student) {
      final name = (student['full_name'] ?? '').toLowerCase();
      final code = (student['student_code'] ?? '').toLowerCase();
      final email = (student['email'] ?? '').toLowerCase();
      return name.contains(query) ||
          code.contains(query) ||
          email.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thêm sinh viên vào lớp'),
      content: SizedBox(
        width: double.maxFinite,
        height: 500,
        child: Column(
          children: [
            // Search bar
            TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Tìm kiếm theo tên, mã SV, email...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Student list
            Expanded(
              child: _filteredStudents.isEmpty
                  ? Center(
                      child: Text(
                        _searchQuery.isEmpty
                            ? 'Không có sinh viên nào để thêm'
                            : 'Không tìm thấy sinh viên',
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredStudents.length,
                      itemBuilder: (context, index) {
                        final student = _filteredStudents[index];
                        final studentId = student['student_id'];
                        final isSelected = _selectedStudentIds.contains(
                          studentId,
                        );

                        return CheckboxListTile(
                          title: Text(student['full_name']),
                          subtitle: Text('MSSV: ${student['student_code']}'),
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedStudentIds.add(studentId);
                              } else {
                                _selectedStudentIds.remove(studentId);
                              }
                            });
                          },
                        );
                      },
                    ),
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
          onPressed: _selectedStudentIds.isEmpty
              ? null
              : () => Navigator.pop(context, _selectedStudentIds.toList()),
          child: Text('Thêm (${_selectedStudentIds.length})'),
        ),
      ],
    );
  }
}
