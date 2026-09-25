/// Mirrors apps.transferverify.models.DisputeReason - a factual description
/// only, never an accusation or an admission baked into the choice itself.
enum TransferDisputeReason {
  notTheSameFamily,
  alreadyPaid,
  amountDisputed,
  neverEnrolledHere,
  arrangementHonored,
  other;

  String get label => switch (this) {
        TransferDisputeReason.notTheSameFamily => 'This is not our family',
        TransferDisputeReason.alreadyPaid => 'The balance has already been paid',
        TransferDisputeReason.amountDisputed => 'The amount is incorrect',
        TransferDisputeReason.neverEnrolledHere => 'This student was never enrolled at that school',
        TransferDisputeReason.arrangementHonored => 'A payment arrangement is being honored',
        TransferDisputeReason.other => 'Other documented reason',
      };

  String toJson() => switch (this) {
        TransferDisputeReason.notTheSameFamily => 'not_the_same_family',
        TransferDisputeReason.alreadyPaid => 'already_paid',
        TransferDisputeReason.amountDisputed => 'amount_disputed',
        TransferDisputeReason.neverEnrolledHere => 'never_enrolled_here',
        TransferDisputeReason.arrangementHonored => 'arrangement_honored',
        TransferDisputeReason.other => 'other',
      };

  static const all = TransferDisputeReason.values;
}

enum TransferDisputeStatus {
  opened,
  accepted,
  rejected;

  String get label => switch (this) {
        TransferDisputeStatus.opened => 'Opened',
        TransferDisputeStatus.accepted => 'Accepted',
        TransferDisputeStatus.rejected => 'Rejected',
      };

  static TransferDisputeStatus fromJson(Object? value) => switch (value) {
        'accepted' => TransferDisputeStatus.accepted,
        'rejected' => TransferDisputeStatus.rejected,
        _ => TransferDisputeStatus.opened,
      };
}

class TransferVerifyDispute {
  const TransferVerifyDispute({
    required this.id,
    required this.transferAlertId,
    required this.reason,
    this.explanation = '',
    required this.status,
    required this.openedAt,
    this.reviewedAt,
    this.resolutionNote = '',
  });

  final String id;
  final String transferAlertId;
  final String reason;
  final String explanation;
  final TransferDisputeStatus status;
  final DateTime openedAt;
  final DateTime? reviewedAt;
  final String resolutionNote;

  factory TransferVerifyDispute.fromJson(Map<String, Object?> json) {
    return TransferVerifyDispute(
      id: json['id'] as String? ?? '',
      transferAlertId: json['transferAlertId'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
      status: TransferDisputeStatus.fromJson(json['status']),
      openedAt: DateTime.tryParse(json['openedAt'] as String? ?? '')?.toUtc() ?? DateTime.now().toUtc(),
      reviewedAt: DateTime.tryParse(json['reviewedAt'] as String? ?? '')?.toUtc(),
      resolutionNote: json['resolutionNote'] as String? ?? '',
    );
  }
}

enum TransferClearanceStatus {
  active,
  revoked;

  String get label => this == TransferClearanceStatus.active ? 'Active' : 'Revoked';

  static TransferClearanceStatus fromJson(Object? value) =>
      value == 'revoked' ? TransferClearanceStatus.revoked : TransferClearanceStatus.active;
}

class TransferVerifyClearance {
  const TransferVerifyClearance({
    required this.id,
    required this.issuingSchoolName,
    required this.verificationToken,
    required this.status,
    required this.issuedAt,
    this.revokedAt,
  });

  final String id;
  final String issuingSchoolName;
  final String verificationToken;
  final TransferClearanceStatus status;
  final DateTime issuedAt;
  final DateTime? revokedAt;

  factory TransferVerifyClearance.fromJson(Map<String, Object?> json) {
    return TransferVerifyClearance(
      id: json['id'] as String? ?? '',
      issuingSchoolName: json['issuingSchoolName'] as String? ?? '',
      verificationToken: json['verificationToken'] as String? ?? '',
      status: TransferClearanceStatus.fromJson(json['status']),
      issuedAt: DateTime.tryParse(json['issuedAt'] as String? ?? '')?.toUtc() ?? DateTime.now().toUtc(),
      revokedAt: DateTime.tryParse(json['revokedAt'] as String? ?? '')?.toUtc(),
    );
  }
}

/// A guardian's own read-only view of one published case concerning their
/// child - mirrors apps.transferverify.disputes.case_status_for_guardian.
class TransferVerifyCaseStatus {
  const TransferVerifyCaseStatus({
    required this.transferAlertId,
    required this.studentName,
    required this.state,
    required this.status,
    required this.reason,
    required this.publishedAt,
    required this.hasOpenDispute,
    required this.hasActiveClearance,
  });

  final String transferAlertId;
  final String studentName;
  final String state;
  final String status;
  final String reason;
  final DateTime publishedAt;
  final bool hasOpenDispute;
  final bool hasActiveClearance;

  factory TransferVerifyCaseStatus.fromJson(Map<String, Object?> json) {
    return TransferVerifyCaseStatus(
      transferAlertId: json['transferAlertId'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '',
      state: json['state'] as String? ?? '',
      status: json['status'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? '')?.toUtc() ?? DateTime.now().toUtc(),
      hasOpenDispute: json['hasOpenDispute'] as bool? ?? false,
      hasActiveClearance: json['hasActiveClearance'] as bool? ?? false,
    );
  }
}
