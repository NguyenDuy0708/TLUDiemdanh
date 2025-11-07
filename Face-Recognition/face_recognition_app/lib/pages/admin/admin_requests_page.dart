import 'package:flutter/material.dart';
import '../../services/admin_request_service.dart';
import '../../widgets/custom_loading.dart';

class AdminRequestsPage extends StatefulWidget {
  const AdminRequestsPage({super.key});

  @override
  State<AdminRequestsPage> createState() => _AdminRequestsPageState();
}

class _AdminRequestsPageState extends State<AdminRequestsPage> {
  final _requestService = AdminRequestService();
  bool _isLoading = true;
  List<dynamic> _requests = [];
  String? _filterStatus;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
    });

    final result = await _requestService.getAllRequests(status: _filterStatus);

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

  Future<void> _approveRequest(int requestId) async {
    final noteController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duyệt yêu cầu'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(
            labelText: 'Ghi chú (tùy chọn)',
            hintText: 'Nhập ghi chú...',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Duyệt'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await _requestService.approveRequest(
        requestId: requestId,
        adminNote: noteController.text.isEmpty ? null : noteController.text,
      );

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

  Future<void> _rejectRequest(int requestId) async {
    final noteController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Từ chối yêu cầu'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(
            labelText: 'Lý do từ chối',
            hintText: 'Nhập lý do...',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Từ chối'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await _requestService.rejectRequest(
        requestId: requestId,
        adminNote: noteController.text.isEmpty ? null : noteController.text,
      );

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

  Future<void> _downloadStatistics() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final result = await _requestService.downloadAttendanceStatistics();

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          action: result['success']
              ? SnackBarAction(label: 'OK', onPressed: () {})
              : null,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF4FB),
      appBar: AppBar(
        title: const Text('Quản lý yêu cầu'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    request['teacher_name'] ?? 'N/A',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    statusText,
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: statusColor,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Chip(
                  label: Text(
                    request['request_type'] == 'nghỉ' ? 'Nghỉ' : 'Dạy bù',
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Lý do: ${request['reason']}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 4),
            // Display based on request type
            if (request['request_type'] == 'nghỉ') ...[
              Text('Ngày nghỉ: ${request['request_date'] ?? 'N/A'}'),
              Text(
                'Thời gian: ${request['start_time'] ?? 'N/A'} - ${request['end_time'] ?? 'N/A'}',
              ),
              if (request['class_name'] != null)
                Text('Lớp: ${request['class_name']}'),
              if (request['subject_name'] != null)
                Text('Môn: ${request['subject_name']}'),
            ] else if (request['request_type'] == 'dạy_bù') ...[
              // Original class info
              const SizedBox(height: 4),
              const Text(
                '📅 Lớp bị hủy:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              if (request['original_class_name'] != null)
                Text('  Lớp: ${request['original_class_name']}'),
              if (request['original_date'] != null)
                Text('  Ngày: ${request['original_date']}'),
              if (request['original_start_time'] != null &&
                  request['original_end_time'] != null)
                Text(
                  '  Thời gian: ${request['original_start_time']} - ${request['original_end_time']}',
                ),
              // Makeup class info
              const SizedBox(height: 8),
              const Text(
                '🔄 Lớp dạy bù:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              if (request['makeup_class_name'] != null)
                Text('  Lớp: ${request['makeup_class_name']}'),
              if (request['makeup_date'] != null)
                Text('  Ngày: ${request['makeup_date']}'),
              if (request['makeup_start_time'] != null &&
                  request['makeup_end_time'] != null)
                Text(
                  '  Thời gian: ${request['makeup_start_time']} - ${request['makeup_end_time']}',
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
                  ElevatedButton.icon(
                    onPressed: () => _rejectRequest(request['id']),
                    icon: const Icon(Icons.close),
                    label: const Text('Từ chối'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _approveRequest(request['id']),
                    icon: const Icon(Icons.check),
                    label: const Text('Duyệt'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
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
