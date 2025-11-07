class Teacher {
  final int id;
  final String teacherCode;
  final String fullName;
  final String? email;
  final String? phone;
  final String? department;

  Teacher({
    required this.id,
    required this.teacherCode,
    required this.fullName,
    this.email,
    this.phone,
    this.department,
  });

  factory Teacher.fromJson(Map<String, dynamic> json) {
    return Teacher(
      id: json['id'],
      teacherCode: json['teacher_code'],
      fullName: json['full_name'],
      email: json['email'],
      phone: json['phone'],
      department: json['department'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'teacher_code': teacherCode,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'department': department,
    };
  }
}

