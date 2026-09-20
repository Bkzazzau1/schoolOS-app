enum SchoolRole {
  proprietor,
  administrator,
  principal,
  teacher,
  accountant,
  parent,
  driver,
  student,
  staff,
}

class SchoolMembership {
  const SchoolMembership({
    required this.id,
    required this.schoolId,
    required this.schoolName,
    required this.role,
  });

  final String id;
  final String schoolId;
  final String schoolName;
  final SchoolRole role;

  String get roleLabel {
    return switch (role) {
      SchoolRole.proprietor => 'Proprietor',
      SchoolRole.administrator => 'Administrator',
      SchoolRole.principal => 'Principal',
      SchoolRole.teacher => 'Teacher',
      SchoolRole.accountant => 'Finance Officer',
      SchoolRole.parent => 'Parent',
      SchoolRole.driver => 'Driver',
      SchoolRole.student => 'Student',
      SchoolRole.staff => 'Staff',
    };
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'schoolId': schoolId,
      'schoolName': schoolName,
      'role': role.name,
    };
  }

  factory SchoolMembership.fromJson(Map<String, dynamic> json) {
    return SchoolMembership(
      id: json['id'] as String,
      schoolId: json['schoolId'] as String,
      schoolName: json['schoolName'] as String,
      role: SchoolRole.values.byName(json['role'] as String),
    );
  }
}
