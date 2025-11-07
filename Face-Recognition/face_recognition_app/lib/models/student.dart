class Student {
  final int id;
  final String studentCode;
  final String fullName;
  final String? email;
  final String? phone;
  final int? year;

  Student({
    required this.id,
    required this.studentCode,
    required this.fullName,
    this.email,
    this.phone,
    this.year,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'],
      studentCode: json['student_code'],
      fullName: json['full_name'],
      email: json['email'],
      phone: json['phone'],
      year: json['year'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_code': studentCode,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'year': year,
    };
  }
}

