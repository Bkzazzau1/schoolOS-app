enum AttendanceStatus {
  present,
  absent,
  late,
  excused,
}

extension AttendanceStatusLabel on AttendanceStatus {
  String get label {
    return switch (this) {
      AttendanceStatus.present => 'Present',
      AttendanceStatus.absent => 'Absent',
      AttendanceStatus.late => 'Late',
      AttendanceStatus.excused => 'Excused',
    };
  }
}

class AttendanceStudent {
  const AttendanceStudent({
    required this.id,
    required this.admissionNumber,
    required this.name,
  });

  final String id;
  final String admissionNumber;
  final String name;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'admissionNumber': admissionNumber,
      'name': name,
    };
  }

  factory AttendanceStudent.fromJson(Map<String, dynamic> json) {
    return AttendanceStudent(
      id: json['id'] as String,
      admissionNumber: json['admissionNumber'] as String,
      name: json['name'] as String,
    );
  }
}

class AttendanceEntry {
  const AttendanceEntry({
    required this.student,
    required this.status,
  });

  final AttendanceStudent student;
  final AttendanceStatus status;

  AttendanceEntry copyWith({AttendanceStatus? status}) {
    return AttendanceEntry(
      student: student,
      status: status ?? this.status,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'studentId': student.id,
      'admissionNumber': student.admissionNumber,
      'studentName': student.name,
      'status': status.name,
    };
  }
}

class AttendanceClass {
  const AttendanceClass({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}
