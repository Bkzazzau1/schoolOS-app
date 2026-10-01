enum AlumniOpportunityType { fullTime, partTime, internship, contract, other }

extension AlumniOpportunityTypeLabel on AlumniOpportunityType {
  String get label => switch (this) {
        AlumniOpportunityType.fullTime => 'Full-time',
        AlumniOpportunityType.partTime => 'Part-time',
        AlumniOpportunityType.internship => 'Internship',
        AlumniOpportunityType.contract => 'Contract',
        AlumniOpportunityType.other => 'Other',
      };

  /// The backend's own wire value - `full_time`/`part_time`, never `AlumniOpportunityType.name`
  /// (`fullTime`), since the server's `AlumniOpportunityType` choices are snake_case.
  String get wireValue => switch (this) {
        AlumniOpportunityType.fullTime => 'full_time',
        AlumniOpportunityType.partTime => 'part_time',
        AlumniOpportunityType.internship => 'internship',
        AlumniOpportunityType.contract => 'contract',
        AlumniOpportunityType.other => 'other',
      };

  static AlumniOpportunityType fromWire(String value) => switch (value) {
        'full_time' => AlumniOpportunityType.fullTime,
        'part_time' => AlumniOpportunityType.partTime,
        'internship' => AlumniOpportunityType.internship,
        'contract' => AlumniOpportunityType.contract,
        _ => AlumniOpportunityType.other,
      };
}

enum AlumniOpportunityStatus { open, closed }

extension AlumniOpportunityStatusLabel on AlumniOpportunityStatus {
  String get label => switch (this) {
        AlumniOpportunityStatus.open => 'Open',
        AlumniOpportunityStatus.closed => 'Closed',
      };
}

/// A real job/opportunity posting from a real alumnus to fellow alumni
/// (`apps/alumni/models.py: AlumniOpportunity`) - a posting board, not an application-tracking
/// system: interested alumni follow up directly through [contactInfo].
class AlumniOpportunity {
  const AlumniOpportunity({
    required this.id,
    required this.postedByMembershipId,
    required this.postedByName,
    required this.title,
    required this.organisation,
    required this.type,
    required this.locationText,
    required this.description,
    required this.contactInfo,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String postedByMembershipId;
  final String postedByName;
  final String title;
  final String organisation;
  final AlumniOpportunityType type;
  final String locationText;
  final String description;
  final String contactInfo;
  final AlumniOpportunityStatus status;
  final String createdAt;

  factory AlumniOpportunity.fromJson(Map<String, dynamic> json) => AlumniOpportunity(
        id: json['id'] as String? ?? '',
        postedByMembershipId: json['postedByMembershipId'] as String? ?? '',
        postedByName: json['postedByName'] as String? ?? '',
        title: json['title'] as String? ?? '',
        organisation: json['organisation'] as String? ?? '',
        type: AlumniOpportunityTypeLabel.fromWire(json['opportunityType'] as String? ?? ''),
        locationText: json['locationText'] as String? ?? '',
        description: json['description'] as String? ?? '',
        contactInfo: json['contactInfo'] as String? ?? '',
        status: AlumniOpportunityStatus.values.firstWhere(
          (item) => item.name == json['status'],
          orElse: () => AlumniOpportunityStatus.open,
        ),
        createdAt: json['createdAt'] as String? ?? '',
      );
}
