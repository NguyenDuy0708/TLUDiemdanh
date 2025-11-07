import 'package:flutter/material.dart';
import '../../services/teacher_request_service.dart';

class CreateRequestDialog extends StatefulWidget {
  final List<dynamic> myClasses;
  final VoidCallback onSuccess;

  const CreateRequestDialog({
    super.key,
    required this.myClasses,
    required this.onSuccess,
  });

  @override
  State<CreateRequestDialog> createState() => _CreateRequestDialogState();
}

class _CreateRequestDialogState extends State<CreateRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _requestService = TeacherRequestService();
  
  String _requestType = 'nghỉ';
  String _reason = '';
  
  // For "nghỉ" request
  int? _classId;
  DateTime? _requestDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  List<Map<String, dynamic>> _availableSchedules = [];
  String? _selectedScheduleKey;
  
  // For "dạy_bù" request
  int? _originalClassId;
  DateTime? _originalDate;
  TimeOfDay? _originalStartTime;
  TimeOfDay? _originalEndTime;
  List<Map<String, dynamic>> _originalSchedules = [];
  String? _originalScheduleKey;
  
  int? _makeupClassId;
  DateTime? _makeupDate;
  TimeOfDay? _makeupStartTime;
  TimeOfDay? _makeupEndTime;
  
  bool _isSubmitting = false;

  String _getDayOfWeekName(int dayOfWeek) {
    const days = ['', 'Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];
    return days[dayOfWeek];
  }

  void _onOriginalClassChanged(int? classId) {
    setState(() {
      _originalClassId = classId;
      if (classId != null) {
        final selectedClass = widget.myClasses.firstWhere((cls) => cls['class_id'] == classId);
        _originalSchedules = (selectedClass['schedules'] as List)
            .map((s) => Map<String, dynamic>.from(s))
            .toList();
      } else {
        _originalSchedules = [];
      }
      _originalScheduleKey = null;
      _originalDate = null;
      _originalStartTime = null;
      _originalEndTime = null;
    });
  }

  void _onOriginalScheduleChanged(String? key) {
    if (key == null) return;
    
    setState(() {
      _originalScheduleKey = key;
    });

    final parts = key.split('_');
    final dayOfWeek = int.parse(parts[2]);
    final start = parts[3];
    final end = parts[4];

    // Find next date with this day_of_week
    final now = DateTime.now();
    int daysToAdd = (dayOfWeek - now.weekday) % 7;
    if (daysToAdd == 0 && now.hour >= int.parse(start.split(':')[0])) {
      daysToAdd = 7;
    }
    final nextDate = now.add(Duration(days: daysToAdd));

    final startParts = start.split(':');
    final endParts = end.split(':');

    setState(() {
      _originalDate = nextDate;
      _originalStartTime = TimeOfDay(
        hour: int.parse(startParts[0]),
        minute: int.parse(startParts[1]),
      );
      _originalEndTime = TimeOfDay(
        hour: int.parse(endParts[0]),
        minute: int.parse(endParts[1]),
      );
    });
  }

  void _onClassChanged(int? classId) {
    setState(() {
      _classId = classId;
      if (classId != null) {
        final selectedClass = widget.myClasses.firstWhere((cls) => cls['class_id'] == classId);
        _availableSchedules = (selectedClass['schedules'] as List)
            .map((s) => Map<String, dynamic>.from(s))
            .toList();
      } else {
        _availableSchedules = [];
      }
      _selectedScheduleKey = null;
      _requestDate = null;
      _startTime = null;
      _endTime = null;
    });
  }

  void _onScheduleChanged(String? key) {
    if (key == null) return;
    
    setState(() {
      _selectedScheduleKey = key;
    });

    final parts = key.split('_');
    final dayOfWeek = int.parse(parts[2]);
    final start = parts[3];
    final end = parts[4];

    final now = DateTime.now();
    int daysToAdd = (dayOfWeek - now.weekday) % 7;
    if (daysToAdd == 0 && now.hour >= int.parse(start.split(':')[0])) {
      daysToAdd = 7;
    }
    final nextDate = now.add(Duration(days: daysToAdd));

    final startParts = start.split(':');
    final endParts = end.split(':');

    setState(() {
      _requestDate = nextDate;
      _startTime = TimeOfDay(
        hour: int.parse(startParts[0]),
        minute: int.parse(startParts[1]),
      );
      _endTime = TimeOfDay(
        hour: int.parse(endParts[0]),
        minute: int.parse(endParts[1]),
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    _formKey.currentState!.save();

    setState(() {
      _isSubmitting = true;
    });

    Map<String, dynamic> requestData = {
      'request_type': _requestType,
      'reason': _reason,
    };

    if (_requestType == 'nghỉ') {
      if (_classId == null || _requestDate == null || _startTime == null || _endTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin')),
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      requestData.addAll({
        'class_id': _classId,
        'request_date': '${_requestDate!.year}-${_requestDate!.month.toString().padLeft(2, '0')}-${_requestDate!.day.toString().padLeft(2, '0')}',
        'start_time': '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}:00',
        'end_time': '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}:00',
      });
    } else {
      // dạy_bù
      if (_originalClassId == null || _originalDate == null || _originalStartTime == null || _originalEndTime == null ||
          _makeupClassId == null || _makeupDate == null || _makeupStartTime == null || _makeupEndTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin cho cả lớp nghỉ và lớp dạy bù')),
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      requestData.addAll({
        'original_class_id': _originalClassId,
        'original_date': '${_originalDate!.year}-${_originalDate!.month.toString().padLeft(2, '0')}-${_originalDate!.day.toString().padLeft(2, '0')}',
        'original_start_time': '${_originalStartTime!.hour.toString().padLeft(2, '0')}:${_originalStartTime!.minute.toString().padLeft(2, '0')}:00',
        'original_end_time': '${_originalEndTime!.hour.toString().padLeft(2, '0')}:${_originalEndTime!.minute.toString().padLeft(2, '0')}:00',
        'makeup_class_id': _makeupClassId,
        'makeup_date': '${_makeupDate!.year}-${_makeupDate!.month.toString().padLeft(2, '0')}-${_makeupDate!.day.toString().padLeft(2, '0')}',
        'makeup_start_time': '${_makeupStartTime!.hour.toString().padLeft(2, '0')}:${_makeupStartTime!.minute.toString().padLeft(2, '0')}:00',
        'makeup_end_time': '${_makeupEndTime!.hour.toString().padLeft(2, '0')}:${_makeupEndTime!.minute.toString().padLeft(2, '0')}:00',
      });
    }

    final result = await _requestService.createRequest(requestData);

    setState(() {
      _isSubmitting = false;
    });

    if (!mounted) return;

    if (result['success']) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tạo yêu cầu thành công')),
      );
      widget.onSuccess();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'])),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tạo yêu cầu mới'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Request type
              DropdownButtonFormField<String>(
                value: _requestType,
                decoration: const InputDecoration(labelText: 'Loại yêu cầu'),
                items: const [
                  DropdownMenuItem(value: 'nghỉ', child: Text('Nghỉ')),
                  DropdownMenuItem(value: 'dạy_bù', child: Text('Dạy bù')),
                ],
                onChanged: (value) {
                  setState(() {
                    _requestType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Reason
              TextFormField(
                decoration: const InputDecoration(labelText: 'Lý do'),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập lý do';
                  }
                  return null;
                },
                onSaved: (value) {
                  _reason = value!;
                },
              ),
              const SizedBox(height: 16),

              // For "nghỉ" request
              if (_requestType == 'nghỉ') ..._buildNghiFields(),

              // For "dạy_bù" request
              if (_requestType == 'dạy_bù') ..._buildDayBuFields(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Tạo'),
        ),
      ],
    );
  }

  List<Widget> _buildNghiFields() {
    return [
      // Class selection
      DropdownButtonFormField<int>(
        value: _classId,
        decoration: const InputDecoration(labelText: 'Lớp học'),
        items: widget.myClasses.map<DropdownMenuItem<int>>((cls) {
          return DropdownMenuItem<int>(
            value: cls['class_id'],
            child: Text('${cls['class_name']} - ${cls['subject_name']}'),
          );
        }).toList(),
        onChanged: _onClassChanged,
        validator: (value) => value == null ? 'Vui lòng chọn lớp' : null,
      ),
      const SizedBox(height: 16),

      // Schedule selection
      if (_availableSchedules.isNotEmpty) ...[
        DropdownButtonFormField<String>(
          value: _selectedScheduleKey,
          decoration: const InputDecoration(labelText: 'Chọn buổi học'),
          items: _availableSchedules.asMap().entries.map((entry) {
            final index = entry.key;
            final schedule = entry.value;
            final dayOfWeek = _getDayOfWeekName(schedule['day_of_week']);
            final start = schedule['start_time'];
            final end = schedule['end_time'];
            return DropdownMenuItem<String>(
              value: '${_classId}_${index}_${schedule['day_of_week']}_${start}_$end',
              child: Text('$dayOfWeek: $start - $end'),
            );
          }).toList(),
          onChanged: _onScheduleChanged,
          validator: (value) => value == null ? 'Vui lòng chọn buổi học' : null,
        ),
        const SizedBox(height: 16),
      ],

      // Display selected date/time
      if (_requestDate != null && _startTime != null && _endTime != null) ...[
        Text(
          'Ngày: ${_requestDate!.day}/${_requestDate!.month}/${_requestDate!.year}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          'Giờ: ${_startTime!.hour}:${_startTime!.minute.toString().padLeft(2, '0')} - ${_endTime!.hour}:${_endTime!.minute.toString().padLeft(2, '0')}',
        ),
      ],
    ];
  }

  List<Widget> _buildDayBuFields() {
    return [
      // Original class (being cancelled)
      const Text(
        '1. Lớp bị nghỉ (cần bù):',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      const SizedBox(height: 8),
      
      DropdownButtonFormField<int>(
        value: _originalClassId,
        decoration: const InputDecoration(labelText: 'Lớp học bị nghỉ'),
        items: widget.myClasses.map<DropdownMenuItem<int>>((cls) {
          return DropdownMenuItem<int>(
            value: cls['class_id'],
            child: Text('${cls['class_name']} - ${cls['subject_name']}'),
          );
        }).toList(),
        onChanged: _onOriginalClassChanged,
        validator: (value) => value == null ? 'Vui lòng chọn lớp' : null,
      ),
      const SizedBox(height: 8),

      if (_originalSchedules.isNotEmpty) ...[
        DropdownButtonFormField<String>(
          value: _originalScheduleKey,
          decoration: const InputDecoration(labelText: 'Chọn buổi học bị nghỉ'),
          items: _originalSchedules.asMap().entries.map((entry) {
            final index = entry.key;
            final schedule = entry.value;
            final dayOfWeek = _getDayOfWeekName(schedule['day_of_week']);
            final start = schedule['start_time'];
            final end = schedule['end_time'];
            return DropdownMenuItem<String>(
              value: '${_originalClassId}_${index}_${schedule['day_of_week']}_${start}_$end',
              child: Text('$dayOfWeek: $start - $end'),
            );
          }).toList(),
          onChanged: _onOriginalScheduleChanged,
          validator: (value) => value == null ? 'Vui lòng chọn buổi học' : null,
        ),
      ],

      if (_originalDate != null && _originalStartTime != null && _originalEndTime != null) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ngày: ${_originalDate!.day}/${_originalDate!.month}/${_originalDate!.year}'),
              Text('Giờ: ${_originalStartTime!.hour}:${_originalStartTime!.minute.toString().padLeft(2, '0')} - ${_originalEndTime!.hour}:${_originalEndTime!.minute.toString().padLeft(2, '0')}'),
            ],
          ),
        ),
      ],

      const SizedBox(height: 24),

      // Makeup class (replacement)
      const Text(
        '2. Lớp dạy bù:',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      const SizedBox(height: 8),

      DropdownButtonFormField<int>(
        value: _makeupClassId,
        decoration: const InputDecoration(labelText: 'Lớp học dạy bù'),
        items: widget.myClasses.map<DropdownMenuItem<int>>((cls) {
          return DropdownMenuItem<int>(
            value: cls['class_id'],
            child: Text('${cls['class_name']} - ${cls['subject_name']}'),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _makeupClassId = value;
          });
        },
        validator: (value) => value == null ? 'Vui lòng chọn lớp' : null,
      ),
      const SizedBox(height: 8),

      // Makeup date picker
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          _makeupDate == null
              ? 'Chọn ngày dạy bù'
              : 'Ngày: ${_makeupDate!.day}/${_makeupDate!.month}/${_makeupDate!.year}',
        ),
        trailing: const Icon(Icons.calendar_today),
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: _makeupDate ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
          );
          if (date != null) {
            setState(() {
              _makeupDate = date;
            });
          }
        },
      ),

      // Makeup start time picker
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          _makeupStartTime == null
              ? 'Chọn giờ bắt đầu'
              : 'Giờ bắt đầu: ${_makeupStartTime!.hour}:${_makeupStartTime!.minute.toString().padLeft(2, '0')}',
        ),
        trailing: const Icon(Icons.access_time),
        onTap: () async {
          final time = await showTimePicker(
            context: context,
            initialTime: _makeupStartTime ?? TimeOfDay.now(),
          );
          if (time != null) {
            setState(() {
              _makeupStartTime = time;
            });
          }
        },
      ),

      // Makeup end time picker
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          _makeupEndTime == null
              ? 'Chọn giờ kết thúc'
              : 'Giờ kết thúc: ${_makeupEndTime!.hour}:${_makeupEndTime!.minute.toString().padLeft(2, '0')}',
        ),
        trailing: const Icon(Icons.access_time),
        onTap: () async {
          final time = await showTimePicker(
            context: context,
            initialTime: _makeupEndTime ?? TimeOfDay.now(),
          );
          if (time != null) {
            setState(() {
              _makeupEndTime = time;
            });
          }
        },
      ),

      if (_makeupDate != null && _makeupStartTime != null && _makeupEndTime != null) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ngày: ${_makeupDate!.day}/${_makeupDate!.month}/${_makeupDate!.year}'),
              Text('Giờ: ${_makeupStartTime!.hour}:${_makeupStartTime!.minute.toString().padLeft(2, '0')} - ${_makeupEndTime!.hour}:${_makeupEndTime!.minute.toString().padLeft(2, '0')}'),
            ],
          ),
        ),
      ],
    ];
  }
}

