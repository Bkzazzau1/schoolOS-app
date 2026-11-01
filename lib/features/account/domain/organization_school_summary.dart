/// One school in an organization's own roster, as a billing administrator sees it - never a
/// [SchoolMembership]: holding this does not imply any school-level role or operational
/// permission (Phase D Stage 1.5, Task 5).
class OrganizationSchoolSummary {
  const OrganizationSchoolSummary({
    required this.id,
    required this.name,
    this.organizationId,
    this.schoolType = '',
    this.location = '',
    this.isActive = true,
  });

  final String id;
  final String? organizationId;
  final String name;
  final String schoolType;
  final String location;
  final bool isActive;

  factory OrganizationSchoolSummary.fromJson(Map<String, dynamic> json) =>
      OrganizationSchoolSummary(
        id: json['id'] as String? ?? '',
        organizationId: json['organizationId'] as String?,
        name: json['name'] as String? ?? 'School',
        schoolType: json['schoolType'] as String? ?? '',
        location: json['location'] as String? ?? '',
        isActive: json['isActive'] as bool? ?? true,
      );
}
