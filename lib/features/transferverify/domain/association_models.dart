/// Mirrors apps.transferverify.models.AssociationStatus - whether SchoolOS
/// staff have verified this association enough to accept members.
enum TransferVerifyAssociationStatus {
  pendingVerification,
  active,
  suspended;

  String get label => switch (this) {
        TransferVerifyAssociationStatus.pendingVerification => 'Pending verification',
        TransferVerifyAssociationStatus.active => 'Active',
        TransferVerifyAssociationStatus.suspended => 'Suspended',
      };

  static TransferVerifyAssociationStatus fromJson(Object? value) => switch (value) {
        'active' => TransferVerifyAssociationStatus.active,
        'suspended' => TransferVerifyAssociationStatus.suspended,
        _ => TransferVerifyAssociationStatus.pendingVerification,
      };
}

/// A real, verified network of schools a Proprietor may ask their school to
/// join - never SchoolOS's own commercial organizations.Organization.
class TransferVerifyAssociation {
  const TransferVerifyAssociation({
    required this.id,
    required this.name,
    this.registrationReference = '',
    this.geographicScope = '',
    this.description = '',
    required this.status,
    required this.isOpenForMembership,
  });

  final String id;
  final String name;
  final String registrationReference;
  final String geographicScope;
  final String description;
  final TransferVerifyAssociationStatus status;
  final bool isOpenForMembership;

  factory TransferVerifyAssociation.fromJson(Map<String, Object?> json) {
    return TransferVerifyAssociation(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      registrationReference: json['registrationReference'] as String? ?? '',
      geographicScope: json['geographicScope'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: TransferVerifyAssociationStatus.fromJson(json['status']),
      isOpenForMembership: json['isOpenForMembership'] as bool? ?? false,
    );
  }
}

/// Mirrors apps.transferverify.models.AssociationMembershipStatus.
enum AssociationMembershipStatus {
  pending,
  active,
  suspended,
  exited;

  String get label => switch (this) {
        AssociationMembershipStatus.pending => 'Pending approval',
        AssociationMembershipStatus.active => 'Active',
        AssociationMembershipStatus.suspended => 'Suspended',
        AssociationMembershipStatus.exited => 'Exited',
      };

  static AssociationMembershipStatus fromJson(Object? value) => switch (value) {
        'active' => AssociationMembershipStatus.active,
        'suspended' => AssociationMembershipStatus.suspended,
        'exited' => AssociationMembershipStatus.exited,
        _ => AssociationMembershipStatus.pending,
      };
}

/// This school's own membership in one association - the only kind of row a
/// Proprietor may pick from when publishing a case (see
/// BadDebtClassification.associationScope on the backend).
class SchoolAssociationMembershipRecord {
  const SchoolAssociationMembershipRecord({
    required this.id,
    required this.associationId,
    required this.associationName,
    required this.schoolId,
    required this.status,
    required this.requestedAt,
    this.decidedAt,
    this.decisionNote = '',
    this.suspendedAt,
    this.exitedAt,
  });

  final String id;
  final String associationId;
  final String associationName;
  final String schoolId;
  final AssociationMembershipStatus status;
  final DateTime requestedAt;
  final DateTime? decidedAt;
  final String decisionNote;
  final DateTime? suspendedAt;
  final DateTime? exitedAt;

  bool get isActive => status == AssociationMembershipStatus.active;

  factory SchoolAssociationMembershipRecord.fromJson(Map<String, Object?> json) {
    return SchoolAssociationMembershipRecord(
      id: json['id'] as String? ?? '',
      associationId: json['associationId'] as String? ?? '',
      associationName: json['associationName'] as String? ?? '',
      schoolId: json['schoolId'] as String? ?? '',
      status: AssociationMembershipStatus.fromJson(json['status']),
      requestedAt: DateTime.tryParse(json['requestedAt'] as String? ?? '')?.toUtc() ?? DateTime.now().toUtc(),
      decidedAt: DateTime.tryParse(json['decidedAt'] as String? ?? '')?.toUtc(),
      decisionNote: json['decisionNote'] as String? ?? '',
      suspendedAt: DateTime.tryParse(json['suspendedAt'] as String? ?? '')?.toUtc(),
      exitedAt: DateTime.tryParse(json['exitedAt'] as String? ?? '')?.toUtc(),
    );
  }
}
