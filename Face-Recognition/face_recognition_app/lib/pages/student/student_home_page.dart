import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../constants/api_constants.dart';
import '../../widgets/custom_loading.dart';
import '../login_page.dart';
import '../face_attendance_page.dart';

class StudentHomePage extends StatefulWidget {
  const StudentHomePage({super.key});

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  bool _isLoading = true;
  Map<String, dynamic>? _userInfo;
  List<dynamic> _todaySchedule = [];
  List<dynamic> _allClasses = [];
  List<dynamic> _attendanceHistory = [];
  late TabController _tabController;

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
    setState(() {
      _isLoading = true;
    });

    try {
      final sessionId = await _authService.getSessionId();
      if (sessionId == null) {
        _logout();
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

      // Get today's schedule - use Tuesday for testing
      final dateStr = '2025-10-21'; // Tuesday for testing

      try {
        final scheduleResponse = await http.get(
          Uri.parse(
            '${ApiConstants.baseUrl}/student/my-schedule?schedule_date=$dateStr',
          ),
          headers: {'session-id': sessionId},
        );

        if (scheduleResponse.statusCode == 200) {
          final data = json.decode(scheduleResponse.body);
          print('Schedule response: $data');
          _todaySchedule = data['schedules'] ?? [];
        }
      } catch (e) {
        print('Error loading schedule: $e');
      }

      // Get all classes
      try {
        print('About to load classes...');
        final classesResponse = await http.get(
          Uri.parse('${ApiConstants.baseUrl}/student/my-classes'),
          headers: {'session-id': sessionId},
        );

        print('Classes status code: ${classesResponse.statusCode}');
        if (classesResponse.statusCode == 200) {
          print('Classes response body: ${classesResponse.body}');
          final data = json.decode(classesResponse.body);
          print('Classes response type: ${data.runtimeType}');
          if (data is List) {
            _allClasses = data;
            print('Loaded ${_allClasses.length} classes');
          } else {
            print('Data is not a List, it is: ${data.runtimeType}');
            print('Data content: $data');
            _allClasses = [];
          }
        }
      } catch (e, stackTrace) {
        print('Error loading classes: $e');
        print('Stack trace: $stackTrace');
      }

      // Get attendance history
      try {
        final attendanceResponse = await http.get(
          Uri.parse('${ApiConstants.baseUrl}/student/my-attendance'),
          headers: {'session-id': sessionId},
        );

        if (attendanceResponse.statusCode == 200) {
          final data = json.decode(attendanceResponse.body);
          if (data is List) {
            _attendanceHistory = data;
          } else {
            _attendanceHistory = [];
          }
        }
      } catch (e) {
        print('Error loading attendance: $e');
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error loading data: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF7FF),
      appBar: AppBar(
        title: const Text('Trang sinh viên'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _isLoading
          ? const CustomLoading()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUserInfoCard(),
                    const SizedBox(height: 16),
                    _buildTodayScheduleCard(),
                    const SizedBox(height: 16),
                    _buildAttendanceHistoryCard(),
                  ],
                ),
              ),
            ),
    );
  }

  // 👤 Thẻ thông tin người dùng
  Widget _buildUserInfoCard() {
    final studentName = _userInfo?['full_name'] ?? 'Sinh viên';
    final studentCode = _userInfo?['student_code'] ?? 'N/A';

    return Container(
      width: 394,
      height: 103,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFBEE5FF)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, '/student-profile');
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Icon trái
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/ellipse15.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Văn bản
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      studentName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'MSSV: $studentCode',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              // Icon phải
              const Icon(Icons.chevron_right, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  // 📅 Thẻ "Lịch học hôm nay"
  Widget _buildTodayScheduleCard() {
    // Format date
    final now = DateTime.now();
    final weekdays = [
      'Chủ nhật',
      'Thứ hai',
      'Thứ ba',
      'Thứ tư',
      'Thứ năm',
      'Thứ sáu',
      'Thứ bảy',
    ];
    final dateStr =
        '${weekdays[now.weekday % 7]}, ${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';

    return Container(
      width: 394,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFBEE5FF)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: () {
              _showAllSchedules();
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 15),
                  const SizedBox(width: 8),
                  const Text(
                    'Lịch học hôm nay',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
            ),
          ),
          // Sub text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              dateStr,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 8),
          // Bên trong - 2 thẻ con cho mỗi tiết học
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _todaySchedule.isEmpty
                ? Container(
                    height: 100,
                    alignment: Alignment.center,
                    child: Text(
                      'Không có lịch học hôm nay',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : Column(
                    children: _todaySchedule.map((schedule) {
                      return _buildScheduleItem(schedule);
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // 🕖 Thẻ con – Môn học
  Widget _buildScheduleItem(Map<String, dynamic> schedule) {
    final startTime = schedule['start_time']?.toString().substring(0, 5) ?? '';
    final subjectName = schedule['subject_name'] ?? '';
    final room = schedule['room'] ?? '';
    final requestStatus = schedule['request_status'];

    return Container(
      width: 360,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFBEE5FF)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FaceAttendancePage(
                classId: schedule['class_id'],
                className: subjectName,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            children: [
              // Time
              Text(
                startTime,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      subjectName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      room,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (requestStatus != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: requestStatus['type'] == 'nghỉ'
                              ? Colors.red.shade100
                              : Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          requestStatus['type'] == 'nghỉ' ? 'Nghỉ' : 'Dạy bù',
                          style: TextStyle(
                            fontSize: 11,
                            color: requestStatus['type'] == 'nghỉ'
                                ? Colors.red.shade700
                                : Colors.orange.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🕘 Thẻ "Lịch sử điểm danh"
  Widget _buildAttendanceHistoryCard() {
    return Container(
      width: 394,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFBEE5FF)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: () {
              _showAllAttendanceHistory();
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 15),
                  const SizedBox(width: 8),
                  const Text(
                    'Lịch sử điểm danh',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
            ),
          ),
          // Body
          Container(
            height: 150,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: _attendanceHistory.isEmpty
                ? Center(
                    child: Text(
                      'Chưa có lịch sử điểm danh',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
                    itemCount: _attendanceHistory.length > 5
                        ? 5
                        : _attendanceHistory.length,
                    itemBuilder: (context, index) {
                      final record = _attendanceHistory[index];
                      final status = record['status'] ?? '';
                      String statusText = status;
                      Color statusColor = Colors.grey;

                      if (status == 'present') {
                        statusText = 'Có mặt';
                        statusColor = Colors.green;
                      } else if (status == 'late') {
                        statusText = 'Muộn';
                        statusColor = Colors.orange;
                      } else if (status == 'absent') {
                        statusText = 'Vắng';
                        statusColor = Colors.red;
                      }

                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                        ),
                        leading: Icon(
                          status == 'present'
                              ? Icons.check_circle
                              : status == 'late'
                              ? Icons.access_time
                              : Icons.cancel,
                          color: statusColor,
                          size: 20,
                        ),
                        title: Text(
                          record['class_name'] ?? record['subject_name'] ?? '',
                          style: const TextStyle(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          record['session_date'] ?? record['date'] ?? '',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 12,
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showAllAttendanceHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lịch sử điểm danh'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: _attendanceHistory.isEmpty
              ? Center(
                  child: Text(
                    'Chưa có lịch sử điểm danh',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              : ListView.builder(
                  itemCount: _attendanceHistory.length,
                  itemBuilder: (context, index) {
                    final record = _attendanceHistory[index];
                    final status = record['status'] ?? '';
                    String statusText = status;
                    Color statusColor = Colors.grey;

                    if (status == 'present') {
                      statusText = 'Có mặt';
                      statusColor = Colors.green;
                    } else if (status == 'late') {
                      statusText = 'Muộn';
                      statusColor = Colors.orange;
                    } else if (status == 'absent') {
                      statusText = 'Vắng';
                      statusColor = Colors.red;
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: statusColor,
                          child: Icon(
                            status == 'present'
                                ? Icons.check
                                : status == 'late'
                                ? Icons.access_time
                                : Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          record['class_name'] ?? record['subject_name'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Ngày: ${record['session_date'] ?? record['date'] ?? ''}\n'
                          'Giờ: ${record['start_time'] ?? ''} - ${record['end_time'] ?? ''}\n'
                          'Điểm danh: ${record['check_in_time'] ?? 'Chưa điểm danh'}',
                        ),
                        trailing: Chip(
                          label: Text(statusText),
                          backgroundColor: statusColor.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
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

  void _showAllSchedules() async {
    // Get all schedules for all days
    final sessionId = await _authService.getSessionId();
    if (sessionId == null) return;

    if (!mounted) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CustomLoading()),
    );

    try {
      // Get schedules for all 7 days
      Map<int, List<dynamic>> schedulesByDay = {};
      final weekdays = [
        'Chủ nhật',
        'Thứ hai',
        'Thứ ba',
        'Thứ tư',
        'Thứ năm',
        'Thứ sáu',
        'Thứ bảy',
      ];

      // Get current week dates
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));

      for (int i = 0; i < 7; i++) {
        final date = monday.add(Duration(days: i));
        final dateStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

        final response = await http.get(
          Uri.parse(
            '${ApiConstants.baseUrl}/student/my-schedule?schedule_date=$dateStr',
          ),
          headers: {'session-id': sessionId},
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final schedules = data['schedules'] ?? [];
          if (schedules.isNotEmpty) {
            schedulesByDay[date.weekday % 7] = schedules;
          }
        }
      }

      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      // Show all schedules dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Lịch học cả tuần'),
          content: SizedBox(
            width: double.maxFinite,
            height: 500,
            child: schedulesByDay.isEmpty
                ? Center(
                    child: Text(
                      'Không có lịch học',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
                    itemCount: 7,
                    itemBuilder: (context, dayIndex) {
                      final schedules = schedulesByDay[dayIndex] ?? [];
                      if (schedules.isEmpty) return const SizedBox.shrink();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Day header
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(4),
                                  topRight: Radius.circular(4),
                                ),
                              ),
                              child: Text(
                                weekdays[dayIndex],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // Schedules for this day
                            ...schedules.map((schedule) {
                              final startTime =
                                  schedule['start_time']?.toString().substring(
                                    0,
                                    5,
                                  ) ??
                                  '';
                              final endTime =
                                  schedule['end_time']?.toString().substring(
                                    0,
                                    5,
                                  ) ??
                                  '';
                              final subjectName =
                                  schedule['subject_name'] ?? '';
                              final room = schedule['room'] ?? '';
                              final teacherName =
                                  schedule['teacher_name'] ?? '';

                              return ListTile(
                                dense: true,
                                leading: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      startTime,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      endTime,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                title: Text(
                                  subjectName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text('$room • $teacherName'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.camera_alt),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => FaceAttendancePage(
                                          classId: schedule['class_id'],
                                          className: subjectName,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    },
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
    } catch (e) {
      if (!mounted) return;
      // Close loading dialog if error
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }
}
