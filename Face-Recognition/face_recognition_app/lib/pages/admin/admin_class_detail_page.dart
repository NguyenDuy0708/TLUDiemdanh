import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../constants/api_constants.dart';

class AdminClassDetailPage extends StatefulWidget {
  final int classId;
  final String className;

  const AdminClassDetailPage({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<AdminClassDetailPage> createState() => _AdminClassDetailPageState();
}

class _AdminClassDetailPageState extends State<AdminClassDetailPage>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _students = [];
  List<dynamic> _schedules = [];
  List<dynamic> _allStudents = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final sessionId = await _authService.getSessionId();
      if (sessionId == null) return;

      final headers = {'session-id': sessionId};

      final responses = await Future.wait([
        http.get(
          Uri.parse(
            '${ApiConstants.baseUrl}/admin/classes/${widget.classId}/students',
          ),
          headers: headers,
        ),
        http.get(
          Uri.parse(
            '${ApiConstants.baseUrl}/admin/classes/${widget.classId}/schedules',
          ),
          headers: headers,
        ),
        http.get(
          Uri.parse('${ApiConstants.baseUrl}/admin/students'),
          headers: headers,
        ),
      ]);

      if (responses[0].statusCode == 200) {
        setState(() {
          _students = json.decode(responses[0].body);
          _schedules = json.decode(responses[1].body);
          _allStudents = json.decode(responses[2].body);
        });
      }
    } catch (e) {
      print('Error: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _addStudent() async {
    final availableStudents = _allStudents
        .where((s) => !_students.any((cs) => cs['id'] == s['id']))
        .toList();

    if (availableStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không còn sinh viên nào để thêm')),
      );
      return;
    }

    int? selectedStudentId;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Thêm sinh viên'),
          content: DropdownButtonFormField<int>(
            decoration: const InputDecoration(
              labelText: 'Chọn sinh viên',
              border: OutlineInputBorder(),
            ),
            value: selectedStudentId,
            items: availableStudents.map<DropdownMenuItem<int>>((student) {
              return DropdownMenuItem<int>(
                value: student['id'],
                child: Text(
                  '${student['student_code']} - ${student['full_name']}',
                ),
              );
            }).toList(),
            onChanged: (value) => setState(() => selectedStudentId = value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedStudentId != null) {
                  Navigator.pop(context);
                  await _addStudentToClass(selectedStudentId!);
                }
              },
              child: const Text('Thêm'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addStudentToClass(int studentId) async {
    try {
      final sessionId = await _authService.getSessionId();
      if (sessionId == null) return;

      final response = await http.post(
        Uri.parse(
          '${ApiConstants.baseUrl}/admin/classes/${widget.classId}/students/$studentId',
        ),
        headers: {'session-id': sessionId},
      );

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thêm sinh viên thành công!')),
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

  Future<void> _removeStudent(int studentId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa "$name" khỏi lớp?'),
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
          '${ApiConstants.baseUrl}/admin/classes/${widget.classId}/students/$studentId',
        ),
        headers: {'session-id': sessionId},
      );

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Xóa sinh viên thành công!')),
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

  Future<void> _showAddScheduleDialog() async {
    final formKey = GlobalKey<FormState>();
    int? dayOfWeek;
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    final roomController = TextEditingController();
    String mode = 'offline';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Thêm lịch học'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Thứ *',
                      border: OutlineInputBorder(),
                    ),
                    value: dayOfWeek,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Thứ 2')),
                      DropdownMenuItem(value: 2, child: Text('Thứ 3')),
                      DropdownMenuItem(value: 3, child: Text('Thứ 4')),
                      DropdownMenuItem(value: 4, child: Text('Thứ 5')),
                      DropdownMenuItem(value: 5, child: Text('Thứ 6')),
                      DropdownMenuItem(value: 6, child: Text('Thứ 7')),
                      DropdownMenuItem(value: 7, child: Text('Chủ nhật')),
                    ],
                    onChanged: (value) => setState(() => dayOfWeek = value),
                    validator: (v) => v == null ? 'Chọn thứ' : null,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: const Text('Giờ bắt đầu'),
                    subtitle: Text(startTime?.format(context) ?? 'Chưa chọn'),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null) setState(() => startTime = time);
                    },
                  ),
                  ListTile(
                    title: const Text('Giờ kết thúc'),
                    subtitle: Text(endTime?.format(context) ?? 'Chưa chọn'),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null) setState(() => endTime = time);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: roomController,
                    decoration: const InputDecoration(
                      labelText: 'Phòng học *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v?.isEmpty ?? true ? 'Nhập phòng' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Hình thức',
                      border: OutlineInputBorder(),
                    ),
                    value: mode,
                    items: const [
                      DropdownMenuItem(
                        value: 'offline',
                        child: Text('Offline'),
                      ),
                      DropdownMenuItem(value: 'online', child: Text('Online')),
                    ],
                    onChanged: (value) => setState(() => mode = value!),
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
                if (formKey.currentState!.validate() &&
                    startTime != null &&
                    endTime != null) {
                  Navigator.pop(context);
                  await _addSchedule(
                    dayOfWeek!,
                    startTime!,
                    endTime!,
                    roomController.text,
                    mode,
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

  Future<void> _addSchedule(
    int dayOfWeek,
    TimeOfDay startTime,
    TimeOfDay endTime,
    String room,
    String mode,
  ) async {
    try {
      final sessionId = await _authService.getSessionId();
      if (sessionId == null) return;

      final response = await http.post(
        Uri.parse(
          '${ApiConstants.baseUrl}/admin/classes/${widget.classId}/schedules',
        ),
        headers: {'session-id': sessionId, 'Content-Type': 'application/json'},
        body: json.encode({
          'day_of_week': dayOfWeek,
          'start_time':
              '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00',
          'end_time':
              '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00',
          'room': room,
          'mode': mode,
        }),
      );

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thêm lịch học thành công!')),
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

  Future<void> _showEditScheduleDialog(Map<String, dynamic> schedule) async {
    final formKey = GlobalKey<FormState>();
    int? dayOfWeek = schedule['day_of_week'];

    // Parse time strings to TimeOfDay
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    if (schedule['start_time'] != null) {
      final parts = schedule['start_time'].toString().split(':');
      startTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }
    if (schedule['end_time'] != null) {
      final parts = schedule['end_time'].toString().split(':');
      endTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    final roomController = TextEditingController(text: schedule['room']);
    String mode = schedule['mode'] ?? 'offline';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Sửa lịch học'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Thứ *',
                      border: OutlineInputBorder(),
                    ),
                    value: dayOfWeek,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Thứ 2')),
                      DropdownMenuItem(value: 2, child: Text('Thứ 3')),
                      DropdownMenuItem(value: 3, child: Text('Thứ 4')),
                      DropdownMenuItem(value: 4, child: Text('Thứ 5')),
                      DropdownMenuItem(value: 5, child: Text('Thứ 6')),
                      DropdownMenuItem(value: 6, child: Text('Thứ 7')),
                      DropdownMenuItem(value: 7, child: Text('Chủ nhật')),
                    ],
                    onChanged: (value) => setState(() => dayOfWeek = value),
                    validator: (v) => v == null ? 'Chọn thứ' : null,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: const Text('Giờ bắt đầu'),
                    subtitle: Text(startTime?.format(context) ?? 'Chưa chọn'),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: startTime ?? TimeOfDay.now(),
                      );
                      if (time != null) setState(() => startTime = time);
                    },
                  ),
                  ListTile(
                    title: const Text('Giờ kết thúc'),
                    subtitle: Text(endTime?.format(context) ?? 'Chưa chọn'),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: endTime ?? TimeOfDay.now(),
                      );
                      if (time != null) setState(() => endTime = time);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: roomController,
                    decoration: const InputDecoration(
                      labelText: 'Phòng học *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v?.isEmpty ?? true ? 'Nhập phòng' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Hình thức',
                      border: OutlineInputBorder(),
                    ),
                    value: mode,
                    items: const [
                      DropdownMenuItem(
                        value: 'offline',
                        child: Text('Offline'),
                      ),
                      DropdownMenuItem(value: 'online', child: Text('Online')),
                    ],
                    onChanged: (value) => setState(() => mode = value!),
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
                if (formKey.currentState!.validate() &&
                    startTime != null &&
                    endTime != null) {
                  Navigator.pop(context);
                  await _editSchedule(
                    schedule['id'],
                    dayOfWeek!,
                    startTime!,
                    endTime!,
                    roomController.text,
                    mode,
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

  Future<void> _editSchedule(
    int scheduleId,
    int dayOfWeek,
    TimeOfDay startTime,
    TimeOfDay endTime,
    String room,
    String mode,
  ) async {
    try {
      final sessionId = await _authService.getSessionId();
      if (sessionId == null) return;

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/admin/schedules/$scheduleId'),
        headers: {'session-id': sessionId, 'Content-Type': 'application/json'},
        body: json.encode({
          'day_of_week': dayOfWeek,
          'start_time':
              '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00',
          'end_time':
              '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00',
          'room': room,
          'mode': mode,
        }),
      );

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật lịch học thành công!')),
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

  Future<void> _deleteSchedule(int scheduleId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc muốn xóa lịch học này?'),
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
          '${ApiConstants.baseUrl}/admin/classes/${widget.classId}/schedules/$scheduleId',
        ),
        headers: {'session-id': sessionId},
      );

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Xóa lịch học thành công!')),
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

  String _getDayName(int day) {
    const days = [
      '',
      'Thứ 2',
      'Thứ 3',
      'Thứ 4',
      'Thứ 5',
      'Thứ 6',
      'Thứ 7',
      'CN',
    ];
    return days[day];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF4FB),
      appBar: AppBar(
        title: Text(widget.className),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Sinh viên'),
            Tab(text: 'Lịch học'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildStudentsTab(), _buildSchedulesTab()],
            ),
    );
  }

  Widget _buildStudentsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _addStudent,
            icon: const Icon(Icons.add),
            label: const Text('Thêm sinh viên'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: _students.isEmpty
              ? const Center(child: Text('Chưa có sinh viên nào'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _students.length,
                  itemBuilder: (context, index) {
                    final student = _students[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: Icon(
                            Icons.person,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        title: Text(student['full_name'] ?? ''),
                        subtitle: Text('MSSV: ${student['student_code']}'),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.remove_circle,
                            color: Colors.red,
                          ),
                          onPressed: () => _removeStudent(
                            student['id'],
                            student['full_name'],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSchedulesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _showAddScheduleDialog,
            icon: const Icon(Icons.add),
            label: const Text('Thêm lịch học'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: _schedules.isEmpty
              ? const Center(child: Text('Chưa có lịch học nào'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _schedules.length,
                  itemBuilder: (context, index) {
                    final schedule = _schedules[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.shade100,
                          child: Icon(
                            Icons.schedule,
                            color: Colors.green.shade700,
                          ),
                        ),
                        title: Text(_getDayName(schedule['day_of_week'])),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${schedule['start_time']} - ${schedule['end_time']}',
                            ),
                            Text('Phòng: ${schedule['room']}'),
                            Text('Hình thức: ${schedule['mode']}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () =>
                                  _showEditScheduleDialog(schedule),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteSchedule(schedule['id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
