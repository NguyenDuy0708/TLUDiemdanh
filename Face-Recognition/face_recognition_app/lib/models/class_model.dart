import 'teacher.dart';

class ClassModel {
  final int id;
  final String classCode;
  final String className;
  final int teacherId;
  final String? semester;
  final int? year;
  final Teacher? teacher;
  final int? studentCount;

  ClassModel({
    required this.id,
    required this.classCode,
    required this.className,
    required this.teacherId,
    this.semester,
    this.year,
    this.teacher,
    this.studentCount,
  });

  factory ClassModel.fromJson(Map<String, dynamic> json) {
    return ClassModel(
      id: json['id'],
      classCode: json['class_code'],
      className: json['class_name'],
      teacherId: json['teacher_id'],
      semester: json['semester'],
      year: json['year'],
      teacher: json['teacher'] != null ? Teacher.fromJson(json['teacher']) : null,
      studentCount: json['student_count'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'class_code': classCode,
      'class_name': className,
      'teacher_id': teacherId,
      'semester': semester,
      'year': year,
      'teacher': teacher?.toJson(),
      'student_count': studentCount,
    };
  }
}

