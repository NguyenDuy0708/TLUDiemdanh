import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../constants/api_constants.dart';

class TeacherAttendancePage extends StatefulWidget {
  final int classId;
  final String className;
  final List<dynamic> schedules;

  const TeacherAttendancePage({
    super.key,
    required this.classId,
    required this.className,
    required this.schedules,
  });

  @override
  State<TeacherAttendancePage> createState() => _TeacherAttendancePageState();
}

class _TeacherAttendancePageState extends State<TeacherAttendancePage> {
  final _authService = AuthService();
  bool _isLoading = true;
  List<dynamic> _attendance = [];
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic>? _selectedSchedule;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final sessionId = await _authService.getSessionId();
      if (sessionId == null) return;

      final dateStr =
          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

      // Build URL with optional time parameters
      var url =
          '${ApiConstants.baseUrl}/teacher/classes/${widget.classId}/attendance?attendance_date=$dateStr';

      if (_selectedSchedule != null) {
        final startTime = _selectedSchedule!['start_time'];
        final endTime = _selectedSchedule!['end_time'];
        url += '&start_time=$startTime&end_time=$endTime';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {'session-id': sessionId},
      );

      if (response.statusCode == 200) {
        setState(() {
          _attendance = json.decode(response.body);
        });
      }
    } catch (e) {
      print('Error loading attendance: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _markAttendance(int studentId, String status) async {
    try {
      // Check if schedule is selected
      if (_selectedSchedule == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng chọn buổi học trước khi điểm danh!'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final sessionId = await _authService.getSessionId();
      if (sessionId == null) return;

      final body = {
        'student_id': studentId,
        'status': status,
        'start_time': _selectedSchedule!['start_time'],
        'end_time': _selectedSchedule!['end_time'],
      };

      final response = await http.post(
        Uri.parse(
          '${ApiConstants.baseUrl}/teacher/classes/${widget.classId}/attendance/manual',
        ),
        headers: {'session-id': sessionId, 'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Điểm danh thành công!')));
        _loadAttendance();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadAttendance();
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'present':
        return Colors.green;
      case 'late':
        return Colors.orange;
      case 'absent':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'present':
        return 'Có mặt';
      case 'late':
        return 'Muộn';
      case 'absent':
        return 'Vắng';
      default:
        return 'Chưa điểm danh';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF4FB),
      appBar: AppBar(
        title: Text('Điểm danh - ${widget.className}'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAttendance,
          ),
        ],
      ),
      body: Column(
        children: [
          // Date selector
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ngày: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _selectDate,
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('Chọn ngày'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Schedule selector
          if (widget.schedules.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chọn buổi học:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: _selectedSchedule,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    hint: const Text('Chọn buổi học'),
                    items: widget.schedules.map((schedule) {
                      final dayNames = [
                        '',
                        'Thứ 2',
                        'Thứ 3',
                        'Thứ 4',
                        'Thứ 5',
                        'Thứ 6',
                        'Thứ 7',
                        'Chủ nhật',
                      ];
                      final dayName = dayNames[schedule['day_of_week'] ?? 0];
                      final startTime = schedule['start_time'] ?? '';
                      final endTime = schedule['end_time'] ?? '';
                      final room = schedule['room'] ?? '';
                      final mode = schedule['mode'] == 'online'
                          ? '(Online)'
                          : '';

                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: schedule,
                        child: Text(
                          '$dayName $startTime-$endTime - $room $mode',
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedSchedule = value;
                      });
                      // Reload attendance when schedule changes
                      _loadAttendance();
                    },
                  ),
                ],
              ),
            ),
          if (widget.schedules.isNotEmpty) const Divider(height: 1),

          // Attendance list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadAttendance,
                    child: _attendance.isEmpty
                        ? const Center(child: Text('Chưa có sinh viên nào'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _attendance.length,
                            itemBuilder: (context, index) {
                              final record = _attendance[index];
                              final status = record['status'] ?? 'absent';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 3,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _getStatusColor(
                                      status,
                                    ).withOpacity(0.2),
                                    child: Icon(
                                      Icons.person,
                                      color: _getStatusColor(status),
                                    ),
                                  ),
                                  title: Text(
                                    record['full_name'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('MSSV: ${record['student_code']}'),
                                      if (record['check_in_time'] != null)
                                        Text(
                                          'Giờ điểm danh: ${record['check_in_time']}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      if (record['confidence'] != null)
                                        Text(
                                          'Độ tin cậy: ${(record['confidence'] * 100).toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(
                                        status,
                                      ).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: DropdownButton<String>(
                                      value: status,
                                      underline: const SizedBox(),
                                      style: TextStyle(
                                        color: _getStatusColor(status),
                                        fontWeight: FontWeight.bold,
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'present',
                                          child: Text('Có mặt'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'late',
                                          child: Text('Muộn'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'absent',
                                          child: Text('Vắng'),
                                        ),
                                      ],
                                      onChanged: (newStatus) {
                                        if (newStatus != null) {
                                          _markAttendance(
                                            record['student_id'],
                                            newStatus,
                                          );
                                        }
                                      },
                                    ),
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
