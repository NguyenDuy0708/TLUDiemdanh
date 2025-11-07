import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../constants/api_constants.dart';
import '../../widgets/custom_loading.dart';
import '../login_page.dart';
import 'teacher_class_detail_page.dart';
import 'teacher_requests_page.dart';

class TeacherHomePage extends StatefulWidget {
  const TeacherHomePage({super.key});

  @override
  State<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  final _authService = AuthService();
  bool _isLoading = true;
  Map<String, dynamic>? _userInfo;
  List<dynamic> _myClasses = [];
  DateTime _selectedDate = DateTime.now();
  String _calendarView = 'Month'; // Month, Week, Day

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
        _logout();
        return;
      }

      final userResponse = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/auth/me'),
        headers: {'session-id': sessionId},
      );

      if (userResponse.statusCode == 200) {
        _userInfo = json.decode(userResponse.body);
      }

      final dateStr =
          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
      final scheduleResponse = await http.get(
        Uri.parse(
          '${ApiConstants.baseUrl}/teacher/my-schedule?schedule_date=$dateStr',
        ),
        headers: {'session-id': sessionId},
      );

      if (scheduleResponse.statusCode == 200) {
        final scheduleData = json.decode(scheduleResponse.body);
        _myClasses = scheduleData['schedules'] ?? [];
      }
    } catch (e) {
      print('Error loading data: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.of(context)
          .pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
    }
  }

  List<Map<String, dynamic>> _getTodayClasses() {
    return List<Map<String, dynamic>>.from(_myClasses);
  }

  String _getClassStatus(String startTime, String endTime) {
    final now = DateTime.now();
    final start = _parseTime(startTime);
    final end = _parseTime(endTime);

    if (now.isAfter(end)) {
      return 'Hoàn thành';
    } else if (now.isAfter(start) && now.isBefore(end)) {
      return 'Đang giảng dạy';
    } else {
      return 'Sắp tới';
    }
  }

  DateTime _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
      parts.length > 2 ? int.parse(parts[2]) : 0,
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFF0066FF)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.person, size: 48, color: Colors.white),
                SizedBox(height: 8),
                Text(
                  'Giáo viên',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Trang chủ'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.assignment),
            title: const Text('Yêu cầu dạy bù/nghỉ'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TeacherRequestsPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Thông tin cá nhân'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/teacher/profile');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Đăng xuất'),
            onTap: () {
              Navigator.pop(context);
              _logout();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todayClasses = _getTodayClasses();

    return Scaffold(
      backgroundColor: const Color(0xFFEAF7FF),
      drawer: _buildDrawer(),
      body: _isLoading
          ? const CustomLoading()
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header - bỏ logout, làm nổi bật tiêu đề
                      Row(
                        children: [
                          Builder(
                            builder: (context) => IconButton(
                              icon: const Icon(Icons.menu_rounded,
                                  size: 26, color: Color(0xFF0066FF)),
                              onPressed: () =>
                                  Scaffold.of(context).openDrawer(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Trang chủ',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0066FF),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildCalendarWidget(),
                      const SizedBox(height: 16),
                      _buildTodayClassesCard(todayClasses),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

// ================== CALENDAR WIDGET MỚI ==================
Widget _buildCalendarWidget() {
  return Container(
    width: double.infinity,
    height: 430,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      children: [
        _buildCalendarHeader(),
        const SizedBox(height: 10),
        Expanded(child: _buildCalendarBody()),
      ],
    ),
  );
}

// ================== HEADER CALENDAR ==================
Widget _buildCalendarHeader() {
  String formattedTitle = '';
  if (_calendarView == 'Month') {
    formattedTitle = '${_selectedDate.month}/${_selectedDate.year}';
  } else if (_calendarView == 'Week') {
    final monday = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    formattedTitle = '${monday.day}/${monday.month} - ${sunday.day}/${sunday.month}/${_selectedDate.year}';
  } else {
    formattedTitle = '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}';
  }

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.blue),
          onPressed: _goToPrevious,
        ),
        Text(
          formattedTitle,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        IconButton(
          icon: const Icon(Icons.arrow_forward_ios, color: Colors.blue),
          onPressed: _goToNext,
        ),
      ],
    ),
  );
}

// ================== NÚT CHUYỂN VIEW ==================
Widget _buildViewSwitchButtons() {
  final views = ['Month', 'Week'];
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: views.map((v) {
      final selected = _calendarView == v;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: GestureDetector(
          onTap: () => setState(() => _calendarView = v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? Colors.blueAccent : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              v,
              style: TextStyle(
                color: selected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }).toList(),
  );
}

// ================== CÁC VIEW ==================
Widget _buildCalendarBody() {
  switch (_calendarView) {
    case 'Week':
      return _buildWeekCalendar();
    case 'Day':
      return _buildDayView();
    default:
      return _buildMonthCalendar();
  }
}

// MONTH VIEW
Widget _buildMonthCalendar() {
  final int daysInMonth = DateUtils.getDaysInMonth(_selectedDate.year, _selectedDate.month);
  final firstDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
  final int startingWeekday = firstDayOfMonth.weekday;

  List<Widget> dayTiles = [];

  // Ô trống đầu tháng
  for (int i = 1; i < startingWeekday; i++) {
    dayTiles.add(Container());
  }

  // Ngày trong tháng
  for (int day = 1; day <= daysInMonth; day++) {
    final currentDay = DateTime(_selectedDate.year, _selectedDate.month, day);
    final today = DateTime.now();

    bool isToday = currentDay.year == today.year &&
                  currentDay.month == today.month &&
                  currentDay.day == today.day;

    bool isSelected = _selectedDate.year == currentDay.year &&
                      _selectedDate.month == currentDay.month &&
                      _selectedDate.day == currentDay.day;

    dayTiles.add(
      GestureDetector(
        onTap: () {
          setState(() {
            _selectedDate = currentDay;
          });
          _loadData();
        },
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.lightBlueAccent.withOpacity(0.4)
                : (isToday ? Colors.blueAccent : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.blueAccent : Colors.transparent,
              width: isSelected ? 1.5 : 0,
            ),
          ),
          child: Center(
            child: Text(
              '$day',
              style: TextStyle(
                color: isSelected
                    ? Colors.blueAccent.shade700
                    : (isToday ? Colors.white : Colors.black87),
                fontWeight:
                    (isToday || isSelected) ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  return GridView.count(
    crossAxisCount: 7,
    shrinkWrap: true,
    children: dayTiles,
  );
}

// WEEK VIEW
Widget _buildWeekCalendar() {
  final monday = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
  List<Widget> days = [];

  for (int i = 0; i < 7; i++) {
    final currentDay = monday.add(Duration(days: i));
    bool isToday = currentDay.day == DateTime.now().day &&
                   currentDay.month == DateTime.now().month &&
                   currentDay.year == DateTime.now().year;

    days.add(
      Expanded(
        child: GestureDetector(
          onTap: () {
            setState(() => _selectedDate = currentDay);
            _loadData();
          },
          child: Container(
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isToday ? Colors.blueAccent : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][i],
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isToday ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${currentDay.day}',
                  style: TextStyle(
                    color: isToday ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  return Row(children: days);
}

// DAY VIEW
Widget _buildDayView() {
  final todayClasses = _getTodayClasses();
  if (todayClasses.isEmpty) {
    return const Center(child: Text('Không có buổi học nào'));
  }
  return ListView.builder(
    itemCount: todayClasses.length,
    itemBuilder: (context, index) {
      final item = todayClasses[index];
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: ListTile(
          leading: const Icon(Icons.book, color: Colors.blueAccent),
          title: Text(item['subject_name'] ?? ''),
          subtitle: Text('${item['start_time']} - ${item['end_time']}'),
        ),
      );
    },
  );
}

// ================== CHUYỂN THÁNG / TUẦN / NGÀY ==================
void _goToPrevious() {
  setState(() {
    if (_calendarView == 'Month') {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
    } else if (_calendarView == 'Week') {
      _selectedDate = _selectedDate.subtract(const Duration(days: 7));
    } else {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    }
  });
  _loadData();
}

void _goToNext() {
  setState(() {
    if (_calendarView == 'Month') {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
    } else if (_calendarView == 'Week') {
      _selectedDate = _selectedDate.add(const Duration(days: 7));
    } else {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    }
  });
  _loadData();
}

  Widget _buildTodayClassesCard(List<Map<String, dynamic>> todayClasses) {
    final isToday = _selectedDate.year == DateTime.now().year &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.day == DateTime.now().day;
    final title = isToday
        ? 'Buổi học hôm nay'
        : 'Buổi học ngày ${DateFormat('dd/MM/yyyy').format(_selectedDate)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (todayClasses.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('Không có buổi học nào'),
              ),
            )
          else
            ...todayClasses.map((classItem) => _buildClassCard(classItem)),
        ],
      ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> classItem) {
    final requestStatus = classItem['request_status'];

    String status;
    Color chipColor;
    Color chipTextColor;

    if (requestStatus != null) {
      final requestType = requestStatus['type'];
      if (requestType == 'nghỉ') {
        status = 'Nghỉ';
        chipColor = Colors.red.shade100;
        chipTextColor = Colors.red.shade700;
      } else {
        status = 'Dạy bù';
        chipColor = Colors.orange.shade100;
        chipTextColor = Colors.orange.shade700;
      }
    } else {
      status = _getClassStatus(classItem['start_time'], classItem['end_time']);

      if (status == 'Hoàn thành') {
        chipColor = const Color(0xFFD7FAD2);
        chipTextColor = const Color(0xFF1E9E3F);
      } else if (status == 'Đang giảng dạy') {
        chipColor = const Color(0xFFD2E4FA);
        chipTextColor = const Color(0xFF007AFF);
      } else {
        chipColor = const Color(0xFFF0F0F0);
        chipTextColor = const Color(0xFF555555);
      }
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TeacherClassDetailPage(
              classId: classItem['class_id'],
              className: classItem['class_name'],
              subjectName: classItem['subject_name'],
              startTime: classItem['start_time'],
              endTime: classItem['end_time'],
              room: classItem['room'],
              mode: classItem['mode'],
              studentCount: classItem['student_count'],
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    classItem['subject_name'].toUpperCase(),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('⏰ Thời gian: ${classItem['start_time']} – ${classItem['end_time']}'),
                  Text('📍 Phòng học: ${classItem['room']}'),
                  Text('👨‍🎓 Sinh viên: ${classItem['student_count']}'),
                  Text(
                      '💻 Hình thức: ${classItem['mode'] == 'online' ? 'Online' : 'Offline'}'),
                  if (requestStatus != null) ...[
                    const SizedBox(height: 4),
                    Text('📝 Lý do: ${requestStatus['reason']}',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontStyle: FontStyle.italic)),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: chipColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:
                        Text(status, style: TextStyle(color: chipTextColor, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}
