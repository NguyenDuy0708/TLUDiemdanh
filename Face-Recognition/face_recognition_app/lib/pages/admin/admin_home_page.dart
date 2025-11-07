import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../constants/api_constants.dart';
import '../../widgets/custom_loading.dart';
import 'admin_students_page.dart';
import 'admin_teachers_page.dart';
import 'admin_classes_page.dart';
import 'admin_subjects_page.dart';
import 'admin_requests_page.dart';
import '../login_page.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final _authService = AuthService();
  bool _isLoading = true;
  Map<String, dynamic>? _userInfo;
  Map<String, dynamic> _stats = {};

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

      // Get user info
      final userResponse = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/auth/me'),
        headers: {'session-id': sessionId},
      );

      if (userResponse.statusCode == 200) {
        _userInfo = json.decode(userResponse.body);
      }

      // Get statistics
      final statsResponse = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/admin/stats'),
        headers: {'session-id': sessionId},
      );

      if (statsResponse.statusCode == 200) {
        _stats = json.decode(statsResponse.body);
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
      backgroundColor: const Color(0xFFEAF4FB),
      appBar: AppBar(
        title: const Text('Quản trị hệ thống'),
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
                    // Header - Admin Info
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.red.shade100,
                              child: Icon(
                                Icons.admin_panel_settings,
                                size: 45,
                                color: Colors.red.shade700,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _userInfo?['full_name'] ?? 'Admin',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Phòng đào tạo',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Statistics
                    Text(
                      'Thống kê hệ thống',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      children: [
                        _buildStatCard(
                          'Sinh viên',
                          _stats['total_students']?.toString() ?? '0',
                          Icons.people,
                          Colors.blue,
                        ),
                        _buildStatCard(
                          'Giáo viên',
                          _stats['total_teachers']?.toString() ?? '0',
                          Icons.school,
                          Colors.green,
                        ),
                        _buildStatCard(
                          'Lớp học',
                          _stats['total_classes']?.toString() ?? '0',
                          Icons.class_,
                          Colors.orange,
                        ),
                        _buildStatCard(
                          'Môn học',
                          _stats['total_subjects']?.toString() ?? '0',
                          Icons.book,
                          Colors.purple,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Management Menu
                    Text(
                      'Quản lý',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildMenuCard(
                      'Quản lý sinh viên',
                      'Thêm, sửa, xóa sinh viên',
                      Icons.people,
                      Colors.blue,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminStudentsPage(),
                          ),
                        );
                      },
                    ),
                    _buildMenuCard(
                      'Quản lý giáo viên',
                      'Thêm, sửa, xóa giáo viên',
                      Icons.school,
                      Colors.green,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminTeachersPage(),
                          ),
                        );
                      },
                    ),
                    _buildMenuCard(
                      'Quản lý lớp học',
                      'Tạo lớp, phân công giáo viên, thêm sinh viên',
                      Icons.class_,
                      Colors.orange,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminClassesPage(),
                          ),
                        );
                      },
                    ),
                    _buildMenuCard(
                      'Quản lý môn học',
                      'Thêm, sửa, xóa môn học',
                      Icons.book,
                      Colors.purple,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminSubjectsPage(),
                          ),
                        );
                      },
                    ),
                    _buildMenuCard(
                      'Quản lý yêu cầu dạy bù/nghỉ',
                      'Duyệt yêu cầu của giáo viên',
                      Icons.assignment,
                      Colors.teal,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminRequestsPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400),
      ),
    );
  }
}
