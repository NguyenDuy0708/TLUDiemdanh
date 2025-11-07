import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../services/teacher_request_service.dart';
import '../../constants/api_constants.dart';
import '../../widgets/custom_loading.dart';
import 'create_request_dialog.dart';

class TeacherRequestsPage extends StatefulWidget {
  const TeacherRequestsPage({super.key});

  @override
  State<TeacherRequestsPage> createState() => _TeacherRequestsPageState();
}

class _TeacherRequestsPageState extends State<TeacherRequestsPage> {
  final _requestService = TeacherRequestService();
  final _authService = AuthService();
  bool _isLoading = true;
  List<dynamic> _requests = [];
  List<dynamic> _myClasses = [];
  String? _filterStatus;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadRequests(), _loadMyClasses()]);
  }

  Future<void> _loadMyClasses() async {
    try {
      final sessionId = await _authService.getSessionId();
      if (sessionId == null) return;

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/my-classes'),
        headers: {'session-id': sessionId},
      );

      if (response.statusCode == 200) {
        setState(() {
          _myClasses = json.decode(response.body);
        });
      }
    } catch (e) {
      print('Error loading classes: $e');
    }
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
    });

    final result = await _requestService.getRequests(status: _filterStatus);

    if (result['success']) {
      setState(() {
        _requests = result['data'];
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result['message'])));
      }
    }
  }

  Future<void> _downloadAttendanceReport() async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final result = await _requestService.downloadAttendanceReport();

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['success']
                ? '${result['message']}\nĐã lưu tại: ${result['filePath']}'
                : result['message'],
          ),
          backgroundColor: result['success'] ? Colors.green : Colors.red,
          duration: const Duration(seconds: 5),
          action: result['success']
              ? SnackBarAction(
                  label: 'OK',
                  textColor: Colors.white,
                  onPressed: () {},
                )
              : null,
        ),
      );
    }
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (context) =>
          CreateRequestDialog(myClasses: _myClasses, onSuccess: _loadRequests),
    );
  }

  Future<void> _deleteRequest(int requestId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Bạn có chắc muốn xóa yêu cầu này?'),
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

    if (confirm == true) {
      final result = await _requestService.deleteRequest(requestId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result['message'])));
        if (result['success']) {
          _loadRequests();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF7FF),
      appBar: AppBar(
        title: const Text('Yêu cầu dạy bù/nghỉ'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Tải báo cáo chuyên cần',
            onPressed: _downloadAttendanceReport,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _filterStatus = value == 'all' ? null : value;
              });
              _loadRequests();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('Tất cả')),
              const PopupMenuItem(value: 'pending', child: Text('Chờ duyệt')),
              const PopupMenuItem(value: 'approved', child: Text('Đã duyệt')),
              const PopupMenuItem(value: 'rejected', child: Text('Từ chối')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: Colors.blue.shade700,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const CustomLoading()
          : RefreshIndicator(
              onRefresh: _loadRequests,
              child: _requests.isEmpty
                  ? const Center(child: Text('Chưa có yêu cầu nào'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _requests.length,
                      itemBuilder: (context, index) {
                        final request = _requests[index];
                        return _buildRequestCard(request);
                      },
                    ),
            ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final status = request['status'];
    Color statusColor;
    String statusText;

    if (status == 'pending') {
      statusColor = Colors.orange;
      statusText = 'Chờ duyệt';
    } else if (status == 'approved') {
      statusColor = Colors.green;
      statusText = 'Đã duyệt';
    } else {
      statusColor = Colors.red;
      statusText = 'Từ chối';
    }

    final requestType = request['request_type'];
    final isNghi = requestType == 'nghỉ';
    final isDayBu = requestType == 'dạy_bù';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  requestType == 'nghỉ' ? 'Nghỉ' : 'Dạy bù',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Lý do: ${request['reason']}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),

            // For "nghỉ" request - show single set of info
            if (isNghi) ...[
              if (request['class_name'] != null)
                Text('Lớp: ${request['class_name']}'),
              if (request['request_date'] != null)
                Text('Ngày: ${request['request_date']}'),
              if (request['start_time'] != null && request['end_time'] != null)
                Text(
                  'Thời gian: ${request['start_time']} - ${request['end_time']}',
                ),
            ],

            // For "dạy_bù" request - show both original and makeup info
            if (isDayBu) ...[
              const Text(
                'Lớp bị nghỉ:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              if (request['original_class_name'] != null)
                Text('  • Lớp: ${request['original_class_name']}'),
              if (request['original_date'] != null)
                Text('  • Ngày: ${request['original_date']}'),
              if (request['original_start_time'] != null &&
                  request['original_end_time'] != null)
                Text(
                  '  • Giờ: ${request['original_start_time']} - ${request['original_end_time']}',
                ),

              const SizedBox(height: 8),
              const Text(
                'Lớp dạy bù:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              if (request['makeup_class_name'] != null)
                Text('  • Lớp: ${request['makeup_class_name']}'),
              if (request['makeup_date'] != null)
                Text('  • Ngày: ${request['makeup_date']}'),
              if (request['makeup_start_time'] != null &&
                  request['makeup_end_time'] != null)
                Text(
                  '  • Giờ: ${request['makeup_start_time']} - ${request['makeup_end_time']}',
                ),
            ],

            if (request['admin_note'] != null) ...[
              const SizedBox(height: 8),
              Text(
                'Ghi chú: ${request['admin_note']}',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
            if (status == 'pending') ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteRequest(request['id']),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
