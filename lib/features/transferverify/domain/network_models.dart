/// A candidate-only match found by guardian phone - never sufficient alone
/// to confirm identity. Mirrors apps.transferverify.network.serialize_alert_candidate.
class TransferVerifyCandidateMatch {
  const TransferVerifyCandidateMatch({
    required this.transferAlertId,
    required this.confidence,
    required this.matchedOn,
    required this.sourceSchoolName,
    required this.status,
    required this.reason,
    required this.publishedAt,
  });

  final String transferAlertId;

  /// Always "candidate_match" until a stronger signal (biometric) exists -
  /// shown to the person as plain words, never trusted as confirmation.
  final String confidence;
  final String matchedOn;
  final String sourceSchoolName;
  final String status;
  final String reason;
  final DateTime publishedAt;

  factory TransferVerifyCandidateMatch.fromJson(Map<String, Object?> json) {
    return TransferVerifyCandidateMatch(
      transferAlertId: json['transferAlertId'] as String? ?? '',
      confidence: json['confidence'] as String? ?? 'candidate_match',
      matchedOn: json['matchedOn'] as String? ?? '',
      sourceSchoolName: json['sourceSchoolName'] as String? ?? '',
      status: json['status'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? '')?.toUtc() ?? DateTime.now().toUtc(),
    );
  }
}

/// Mirrors apps.transferverify.models.TransferVerificationRequestStatus.
enum TransferVerificationStatus {
  pending,
  confirmed,
  rejected,
  cancelled,
  expired;

  String get label => switch (this) {
        TransferVerificationStatus.pending => 'Pending',
        TransferVerificationStatus.confirmed => 'Confirmed',
        TransferVerificationStatus.rejected => 'Rejected',
        TransferVerificationStatus.cancelled => 'Cancelled',
        TransferVerificationStatus.expired => 'Expired',
      };

  static TransferVerificationStatus fromJson(Object? value) => switch (value) {
        'confirmed' => TransferVerificationStatus.confirmed,
        'rejected' => TransferVerificationStatus.rejected,
        'cancelled' => TransferVerificationStatus.cancelled,
        'expired' => TransferVerificationStatus.expired,
        _ => TransferVerificationStatus.pending,
      };
}

/// One factual question asked of a source school about a candidate match -
/// mirrors apps.transferverify.verification.serialize_request.
class TransferVerificationRequestRecord {
  const TransferVerificationRequestRecord({
    required this.id,
    required this.transferAlertId,
    required this.requestingSchoolName,
    required this.sourceSchoolName,
    required this.status,
    this.note = '',
    required this.requestedAt,
    this.respondedAt,
    this.responseNote = '',
    this.responseStatusSnapshot = '',
  });

  final String id;
  final String transferAlertId;
  final String requestingSchoolName;
  final String sourceSchoolName;
  final TransferVerificationStatus status;
  final String note;
  final DateTime requestedAt;
  final DateTime? respondedAt;
  final String responseNote;
  final String responseStatusSnapshot;

  factory TransferVerificationRequestRecord.fromJson(Map<String, Object?> json) {
    return TransferVerificationRequestRecord(
      id: json['id'] as String? ?? '',
      transferAlertId: json['transferAlertId'] as String? ?? '',
      requestingSchoolName: json['requestingSchoolName'] as String? ?? '',
      sourceSchoolName: json['sourceSchoolName'] as String? ?? '',
      status: TransferVerificationStatus.fromJson(json['status']),
      note: json['note'] as String? ?? '',
      requestedAt: DateTime.tryParse(json['requestedAt'] as String? ?? '')?.toUtc() ?? DateTime.now().toUtc(),
      respondedAt: DateTime.tryParse(json['respondedAt'] as String? ?? '')?.toUtc(),
      responseNote: json['responseNote'] as String? ?? '',
      responseStatusSnapshot: json['responseStatusSnapshot'] as String? ?? '',
    );
  }
}
