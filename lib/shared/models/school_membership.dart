enum SchoolRole {
  proprietor,
  principal,
  teacher,
  accountant,
  parent,
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
      SchoolRole.principal => 'Principal',
      SchoolRole.teacher => 'Teacher',
      SchoolRole.accountant => 'Accountant',
      SchoolRole.parent => 'Parent',
      SchoolRole.student => 'Student',
      SchoolRole.staff => 'Staff',
    };
  }
}
