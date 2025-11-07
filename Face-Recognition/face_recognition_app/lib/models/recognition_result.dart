class RecognitionResult {
  final bool recognized;
  final int? studentId;
  final String? studentCode;
  final String? studentName;
  final double? confidence;
  final int? shift;
  final String? shiftName;
  final String? message;

  RecognitionResult({
    required this.recognized,
    this.studentId,
    this.studentCode,
    this.studentName,
    this.confidence,
    this.shift,
    this.shiftName,
    this.message,
  });

  factory RecognitionResult.fromJson(Map<String, dynamic> json) {
    return RecognitionResult(
      recognized: json['recognized'] ?? false,
      studentId: json['student_id'],
      studentCode: json['student_code'],
      studentName: json['student_name'],
      confidence: json['confidence']?.toDouble(),
      shift: json['shift'],
      shiftName: json['shift_name'],
      message: json['message'],
    );
  }
}

