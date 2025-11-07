import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../constants/api_constants.dart';

class TeacherProfilePage extends StatefulWidget {
  const TeacherProfilePage({super.key});

  @override
  State<TeacherProfilePage> createState() => _TeacherProfilePageState();
}

class _TeacherProfilePageState extends State<TeacherProfilePage> {
  final _authService = AuthService();
  bool _isLoading = true;
  Map<String, dynamic>? _userInfo;
  List<dynamic> _myClasses = [];

  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _selectedDepartment = 'Công Nghệ Thông Tin';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final sessionId = await _authService.getSessionId();
      if (sessionId == null) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final userResponse = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/auth/me'),
        headers: {'session-id': sessionId},
      );

      if (userResponse.statusCode == 200) {
        _userInfo = json.decode(userResponse.body);
        _fullNameController.text = _userInfo?['full_name'] ?? '';
        _phoneController.text = _userInfo?['phone'] ?? '';
        _selectedDepartment = _userInfo?['department'] ?? 'Công Nghệ Thông Tin';
      }

      final classesResponse = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/my-classes'),
        headers: {'session-id': sessionId},
      );

      if (classesResponse.statusCode == 200) {
        _myClasses = json.decode(classesResponse.body);
      }
    } catch (e) {
      debugPrint('Error: $e');
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _saveProfile() async {
    try {
      final sessionId = await _authService.getSessionId();
      if (sessionId == null) return;

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/teacher/profile'),
        headers: {'session-id': sessionId, 'Content-Type': 'application/json'},
        body: json.encode({
          'full_name': _fullNameController.text,
          'phone': _phoneController.text,
          'department': _selectedDepartment,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Cập nhật thành công!')),
        );
        await _loadData(); // Reload data
      } else {
        final error = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error['detail'] ?? 'Cập nhật thất bại!')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _changePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Mật khẩu mới không khớp!')));
      return;
    }

    try {
      final sessionId = await _authService.getSessionId();
      if (sessionId == null) return;

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/teacher/change-password'),
        headers: {'session-id': sessionId, 'Content-Type': 'application/json'},
        body: json.encode({
          'old_password': _oldPasswordController.text,
          'new_password': _newPasswordController.text,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Đổi mật khẩu thành công!'),
          ),
        );
        _oldPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      } else {
        final error = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error['detail'] ?? 'Đổi mật khẩu thất bại!')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFEAF7FF),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEAF7FF),
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: const Color(0xFFEAF7FF),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Thông tin cá nhân',
                style: TextStyle(color: Color(0xFF0F172A)),
              ),
            ),
      drawer: isDesktop ? null : _buildDrawer(),
      body: isDesktop
          ? Row(
              children: [
                _buildSidebar(),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(flex: 1, child: _buildLeftColumn()),
                      Expanded(flex: 1, child: _buildRightColumn()),
                    ],
                  ),
                ),
              ],
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildLeftColumn(),
                  const SizedBox(height: 16),
                  _buildRightColumn(),
                ],
              ),
            ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 220,
      color: const Color(0xFFDCEFF7),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.school, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 24),
          _buildMenuItem(Icons.home_outlined, 'Trang chủ', false, () {
            Navigator.pushReplacementNamed(context, '/teacher-home');
          }),
          _buildMenuItem(Icons.class_outlined, 'Lớp của tôi', false, () {
            Navigator.pushReplacementNamed(context, '/teacher-home');
          }),
          _buildMenuItem(Icons.qr_code_scanner, 'Điểm danh', false, () {}),
          _buildMenuItem(Icons.bar_chart_outlined, 'Thống kê', false, () {}),
          _buildMenuItem(Icons.person_outline, 'Hồ sơ', true, () {}),
          const Spacer(),
          _buildMenuItem(
            Icons.logout,
            'Sign out',
            false,
            _logout,
            isLogout: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title,
    bool isActive,
    VoidCallback onTap, {
    bool isLogout = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFCFE7F3) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          size: 22,
          color: isLogout ? const Color(0xFFEF4444) : const Color(0xFF0F172A),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: isLogout ? const Color(0xFFEF4444) : const Color(0xFF0F172A),
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        dense: true,
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(color: const Color(0xFFDCEFF7), child: _buildSidebar()),
    );
  }

  Widget _buildLeftColumn() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildProfileCard(),
          const SizedBox(height: 16),
          _buildClassList(),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 2),
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'Hồ sơ Giảng Viên',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          CircleAvatar(
            radius: 36,
            backgroundColor: Colors.blue.shade100,
            child: Icon(Icons.person, size: 40, color: Colors.blue.shade700),
          ),
          const SizedBox(height: 12),
          Text(
            _userInfo?['full_name'] ?? '',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            _userInfo?['email'] ?? '',
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 4),
          Text(
            'MSGV: ${_userInfo?['teacher_code'] ?? ''}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
          ),
        ],
      ),
    );
  }

  Widget _buildClassList() {
    final displayClasses = _myClasses.take(3).toList();
    return Column(
      children: displayClasses
          .map((classItem) => _buildClassItem(classItem))
          .toList(),
    );
  }

  Widget _buildClassItem(Map<String, dynamic> classItem) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${classItem['subject_name']} | ${classItem['subject_code']}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Lớp: ${classItem['class_name']}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
        ],
      ),
    );
  }

  Widget _buildRightColumn() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildPersonalInfoCard(),
          const SizedBox(height: 16),
          _buildChangePasswordCard(),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 2),
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.badge_outlined, size: 20, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              const Text(
                'Thông tin cá nhân',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField('Họ và tên', _fullNameController),
          const SizedBox(height: 12),
          _buildTextField(
            'Email',
            TextEditingController(text: _userInfo?['email'] ?? ''),
            readOnly: true,
          ),
          const SizedBox(height: 12),
          _buildTextField('Số điện thoại', _phoneController),
          const SizedBox(height: 12),
          _buildDropdownField(),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111827),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Lưu', style: TextStyle(fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangePasswordCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 2),
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline, size: 20, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              const Text(
                'Thay đổi mật khẩu',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            'Mật khẩu hiện tại',
            _oldPasswordController,
            isPassword: true,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            'Mật khẩu mới',
            _newPasswordController,
            isPassword: true,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            'Nhập lại mật khẩu',
            _confirmPasswordController,
            isPassword: true,
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _changePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111827),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Lưu', style: TextStyle(fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool readOnly = false,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          obscureText: isPassword,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF93C5FD)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bộ môn',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedDepartment,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          items: const [
            DropdownMenuItem(
              value: 'Công Nghệ Thông Tin',
              child: Text('Công Nghệ Thông Tin'),
            ),
            DropdownMenuItem(
              value: 'Điện - Điện tử',
              child: Text('Điện - Điện tử'),
            ),
            DropdownMenuItem(value: 'Cơ khí', child: Text('Cơ khí')),
            DropdownMenuItem(value: 'Xây dựng', child: Text('Xây dựng')),
          ],
          onChanged: (value) {
            setState(() {
              _selectedDepartment = value ?? 'Công Nghệ Thông Tin';
            });
          },
        ),
      ],
    );
  }
}
