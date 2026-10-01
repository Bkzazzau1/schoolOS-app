enum AlumniPledgeCategory { volunteering, mentoring, supplies, speaking, other }

extension AlumniPledgeCategoryLabel on AlumniPledgeCategory {
  String get label => switch (this) {
        AlumniPledgeCategory.volunteering => 'Volunteering',
        AlumniPledgeCategory.mentoring => 'Mentoring',
        AlumniPledgeCategory.supplies => 'Supplies & Materials',
        AlumniPledgeCategory.speaking => 'Guest Speaking',
        AlumniPledgeCategory.other => 'Other',
      };
}

enum AlumniPledgeStatus { offered, acknowledged, fulfilled, withdrawn }

extension AlumniPledgeStatusLabel on AlumniPledgeStatus {
  String get label => switch (this) {
        AlumniPledgeStatus.offered => 'Offered',
        AlumniPledgeStatus.acknowledged => 'Acknowledged',
        AlumniPledgeStatus.fulfilled => 'Fulfilled',
        AlumniPledgeStatus.withdrawn => 'Withdrawn',
      };
}

/// A real, non-monetary offer of help from a real alumnus (`apps/alumni/models.py: AlumniPledge`) -
/// one-sided: the alumnus puts this forward, school management reviews it. Never real money.
class AlumniPledge {
  const AlumniPledge({
    required this.id,
    required this.alumniMembershipId,
    required this.alumniName,
    required this.category,
    required this.description,
    required this.status,
    required this.schoolNote,
    required this.createdAt,
  });

  final String id;
  final String alumniMembershipId;
  final String alumniName;
  final AlumniPledgeCategory category;
  final String description;
  final AlumniPledgeStatus status;
  final String schoolNote;
  final String createdAt;

  bool get canWithdraw => status == AlumniPledgeStatus.offered || status == AlumniPledgeStatus.acknowledged;

  factory AlumniPledge.fromJson(Map<String, dynamic> json) => AlumniPledge(
        id: json['id'] as String? ?? '',
        alumniMembershipId: json['alumniMembershipId'] as String? ?? '',
        alumniName: json['alumniName'] as String? ?? '',
        category: AlumniPledgeCategory.values.firstWhere(
          (item) => item.name == json['category'],
          orElse: () => AlumniPledgeCategory.other,
        ),
        description: json['description'] as String? ?? '',
        status: AlumniPledgeStatus.values.firstWhere(
          (item) => item.name == json['status'],
          orElse: () => AlumniPledgeStatus.offered,
        ),
        schoolNote: json['schoolNote'] as String? ?? '',
        createdAt: json['createdAt'] as String? ?? '',
      );
}
