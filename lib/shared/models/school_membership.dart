enum SchoolRole {
  proprietor,
  administrator,
  principal,
  teacher,
  accountant,
  parent,
  driver,
  student,
  alumni,
  staff,
}

class SchoolMembership {
  const SchoolMembership({
    required this.id,
    required this.schoolId,
    required this.schoolName,
    required this.role,
    this.organizationId,
  });

  final String id;
  final String schoolId;
  final String schoolName;
  final SchoolRole role;

  /// The commercial/account owner above this school tenant when the SaaS layer
  /// is available. Older backends and demo data may omit it safely.
  final String? organizationId;

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
      SchoolRole.alumni => 'Alumni',
      SchoolRole.staff => 'Staff',
    };
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'schoolId': schoolId,
      'schoolName': schoolName,
      'role': role.name,
      if (organizationId != null) 'organizationId': organizationId,
    };
  }

  factory SchoolMembership.fromJson(Map<String, dynamic> json) {
    final rawOrganizationId = json['organizationId'] ?? json['organization_id'];
    return SchoolMembership(
      id: json['id'] as String,
      schoolId: json['schoolId'] as String,
      schoolName: json['schoolName'] as String,
      role: SchoolRole.values.byName(json['role'] as String),
      organizationId: rawOrganizationId is String && rawOrganizationId.trim().isNotEmpty
          ? rawOrganizationId.trim()
          : null,
    );
  }
}
