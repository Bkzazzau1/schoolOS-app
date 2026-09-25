/// A school's own private record of an unresolved student-account balance -
/// this is never visible to any other school, and never discoverable through
/// TransferVerify, until the Proprietor takes the separate "Publish" action
/// on a status-badDebt record. Mirrors apps.transferverify.models on the
/// backend field for field; see BadDebtClassification's own docstring there
/// for why amounts are a snapshot rather than a reference to a real ledger.
enum BadDebtStatus {
  outstanding,
  recoveryInProgress,
  badDebt,
  resolved;

  String get label => switch (this) {
        BadDebtStatus.outstanding => 'Outstanding',
        BadDebtStatus.recoveryInProgress => 'Recovery in progress',
        BadDebtStatus.badDebt => 'Bad debt / unresolved obligation',
        BadDebtStatus.resolved => 'Resolved',
      };

  String toJson() => switch (this) {
        BadDebtStatus.outstanding => 'outstanding',
        BadDebtStatus.recoveryInProgress => 'recovery_in_progress',
        BadDebtStatus.badDebt => 'bad_debt',
        BadDebtStatus.resolved => 'resolved',
      };

  static BadDebtStatus fromJson(Object? value) => switch (value) {
        'recovery_in_progress' => BadDebtStatus.recoveryInProgress,
        'bad_debt' => BadDebtStatus.badDebt,
        'resolved' => BadDebtStatus.resolved,
        _ => BadDebtStatus.outstanding,
      };
}

/// Factual, neutral reasons a Proprietor may give for publishing a case -
/// never an accusation. Matches apps.transferverify.models.PublicationReason.
enum TransferVerifyPublicationReason {
  withdrewWithoutClearance,
  guardianUnreachable,
  arrangementDefaulted,
  unresolvedAfterWithdrawal,
  transferSuspected,
  other;

  String get label => switch (this) {
        TransferVerifyPublicationReason.withdrewWithoutClearance => 'Withdrew without financial clearance',
        TransferVerifyPublicationReason.guardianUnreachable => 'Guardian unreachable after recovery attempts',
        TransferVerifyPublicationReason.arrangementDefaulted => 'Payment arrangement defaulted',
        TransferVerifyPublicationReason.unresolvedAfterWithdrawal => 'Unresolved balance after withdrawal',
        TransferVerifyPublicationReason.transferSuspected => 'Transfer suspected while balance remains',
        TransferVerifyPublicationReason.other => 'Other documented reason',
      };

  String toJson() => switch (this) {
        TransferVerifyPublicationReason.withdrewWithoutClearance => 'withdrew_without_clearance',
        TransferVerifyPublicationReason.guardianUnreachable => 'guardian_unreachable',
        TransferVerifyPublicationReason.arrangementDefaulted => 'arrangement_defaulted',
        TransferVerifyPublicationReason.unresolvedAfterWithdrawal => 'unresolved_after_withdrawal',
        TransferVerifyPublicationReason.transferSuspected => 'transfer_suspected',
        TransferVerifyPublicationReason.other => 'other',
      };

  static TransferVerifyPublicationReason? fromJson(Object? value) => switch (value) {
        'withdrew_without_clearance' => TransferVerifyPublicationReason.withdrewWithoutClearance,
        'guardian_unreachable' => TransferVerifyPublicationReason.guardianUnreachable,
        'arrangement_defaulted' => TransferVerifyPublicationReason.arrangementDefaulted,
        'unresolved_after_withdrawal' => TransferVerifyPublicationReason.unresolvedAfterWithdrawal,
        'transfer_suspected' => TransferVerifyPublicationReason.transferSuspected,
        'other' => TransferVerifyPublicationReason.other,
        _ => null,
      };

  static const all = TransferVerifyPublicationReason.values;
}

class BadDebtClassification {
  const BadDebtClassification({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.status,
    required this.outstandingAmountMinor,
    this.currentCanonicalBalanceMinor,
    this.reason = '',
    this.notes = '',
    this.evidenceReference = '',
    required this.classifiedByMembershipId,
    required this.classifiedByName,
    required this.classifiedAt,
    this.lastUpdatedByMembershipId,
    this.resolvedByMembershipId,
    this.resolvedAt,
    this.resolutionNote = '',
    this.publishedToTransferVerify = false,
    this.publishedByMembershipId,
    this.publishedAt,
    this.publicationReason,
    this.publicationNote = '',
    this.associationScope = const [],
    this.pendingSync = false,
  });

  final String id;
  final String studentId;
  final String studentName;
  final BadDebtStatus status;

  /// In kobo (minor units), matching apps.billing's own *_minor convention.
  final int outstandingAmountMinor;

  /// Stays null until a real Finance backend exists to refresh it from -
  /// never invented on this record.
  final int? currentCanonicalBalanceMinor;

  final String reason;
  final String notes;
  final String evidenceReference;

  final String classifiedByMembershipId;
  final String classifiedByName;
  final DateTime classifiedAt;
  final String? lastUpdatedByMembershipId;

  final String? resolvedByMembershipId;
  final DateTime? resolvedAt;
  final String resolutionNote;

  final bool publishedToTransferVerify;
  final String? publishedByMembershipId;
  final DateTime? publishedAt;
  final TransferVerifyPublicationReason? publicationReason;
  final String publicationNote;

  /// Reserved for the association-membership phase - always empty until then.
  final List<String> associationScope;

  /// True while this record is still queued for the server to accept -
  /// local-only, never part of the synced payload.
  final bool pendingSync;

  bool get isOpen => status != BadDebtStatus.resolved;
  bool get isEditable => !publishedToTransferVerify && status != BadDebtStatus.resolved;

  BadDebtClassification copyWith({
    BadDebtStatus? status,
    int? outstandingAmountMinor,
    String? reason,
    String? notes,
    String? evidenceReference,
    String? lastUpdatedByMembershipId,
    String? resolvedByMembershipId,
    DateTime? resolvedAt,
    String? resolutionNote,
    bool? publishedToTransferVerify,
    String? publishedByMembershipId,
    DateTime? publishedAt,
    TransferVerifyPublicationReason? publicationReason,
    String? publicationNote,
    bool clearPublication = false,
    bool? pendingSync,
  }) {
    return BadDebtClassification(
      id: id,
      studentId: studentId,
      studentName: studentName,
      status: status ?? this.status,
      outstandingAmountMinor: outstandingAmountMinor ?? this.outstandingAmountMinor,
      currentCanonicalBalanceMinor: currentCanonicalBalanceMinor,
      reason: reason ?? this.reason,
      notes: notes ?? this.notes,
      evidenceReference: evidenceReference ?? this.evidenceReference,
      classifiedByMembershipId: classifiedByMembershipId,
      classifiedByName: classifiedByName,
      classifiedAt: classifiedAt,
      lastUpdatedByMembershipId: lastUpdatedByMembershipId ?? this.lastUpdatedByMembershipId,
      resolvedByMembershipId: resolvedByMembershipId ?? this.resolvedByMembershipId,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolutionNote: resolutionNote ?? this.resolutionNote,
      publishedToTransferVerify: clearPublication ? false : (publishedToTransferVerify ?? this.publishedToTransferVerify),
      publishedByMembershipId: clearPublication ? null : (publishedByMembershipId ?? this.publishedByMembershipId),
      publishedAt: clearPublication ? null : (publishedAt ?? this.publishedAt),
      publicationReason: clearPublication ? null : (publicationReason ?? this.publicationReason),
      publicationNote: clearPublication ? '' : (publicationNote ?? this.publicationNote),
      associationScope: associationScope,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'studentId': studentId,
        'studentName': studentName,
        'status': status.toJson(),
        'outstandingAmountMinor': outstandingAmountMinor,
        'currentCanonicalBalanceMinor': currentCanonicalBalanceMinor,
        'reason': reason,
        'notes': notes,
        'evidenceReference': evidenceReference,
        'classifiedByMembershipId': classifiedByMembershipId,
        'classifiedByName': classifiedByName,
        'classifiedAt': classifiedAt.toUtc().toIso8601String(),
        'lastUpdatedByMembershipId': lastUpdatedByMembershipId,
        'resolvedByMembershipId': resolvedByMembershipId,
        'resolvedAt': resolvedAt?.toUtc().toIso8601String(),
        'resolutionNote': resolutionNote,
        'publishedToTransferVerify': publishedToTransferVerify,
        'publishedByMembershipId': publishedByMembershipId,
        'publishedAt': publishedAt?.toUtc().toIso8601String(),
        'publicationReason': publicationReason?.toJson(),
        'publicationNote': publicationNote,
        'associationScope': associationScope,
      };

  factory BadDebtClassification.fromJson(Map<String, Object?> json) {
    return BadDebtClassification(
      id: json['id'] as String? ?? '',
      studentId: json['studentId'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '',
      status: BadDebtStatus.fromJson(json['status']),
      outstandingAmountMinor: (json['outstandingAmountMinor'] as num?)?.toInt() ?? 0,
      currentCanonicalBalanceMinor: (json['currentCanonicalBalanceMinor'] as num?)?.toInt(),
      reason: json['reason'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      evidenceReference: json['evidenceReference'] as String? ?? '',
      classifiedByMembershipId: json['classifiedByMembershipId'] as String? ?? '',
      classifiedByName: json['classifiedByName'] as String? ?? '',
      classifiedAt: DateTime.tryParse(json['classifiedAt'] as String? ?? '')?.toUtc() ?? DateTime.now().toUtc(),
      lastUpdatedByMembershipId: json['lastUpdatedByMembershipId'] as String?,
      resolvedByMembershipId: json['resolvedByMembershipId'] as String?,
      resolvedAt: DateTime.tryParse(json['resolvedAt'] as String? ?? '')?.toUtc(),
      resolutionNote: json['resolutionNote'] as String? ?? '',
      publishedToTransferVerify: json['publishedToTransferVerify'] as bool? ?? false,
      publishedByMembershipId: json['publishedByMembershipId'] as String?,
      publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? '')?.toUtc(),
      publicationReason: TransferVerifyPublicationReason.fromJson(json['publicationReason']),
      publicationNote: json['publicationNote'] as String? ?? '',
      associationScope: (json['associationScope'] as List?)?.whereType<String>().toList(growable: false) ?? const [],
    );
  }
}

class BadDebtClassificationPermissions {
  const BadDebtClassificationPermissions({required this.canClassify, required this.canPublish});

  /// The owner, or someone the owner specifically gave the
  /// finance.bad_debt_classification duty to.
  final bool canClassify;

  /// The owner alone - never delegable, matching the backend exactly.
  final bool canPublish;
}

class BadDebtClassificationSnapshot {
  const BadDebtClassificationSnapshot({
    required this.items,
    required this.permissions,
    this.canonical = false,
  });

  final List<BadDebtClassification> items;
  final BadDebtClassificationPermissions permissions;
  final bool canonical;

  List<BadDebtClassification> get open => [for (final i in items) if (i.isOpen) i];
  List<BadDebtClassification> get published => [for (final i in items) if (i.publishedToTransferVerify) i];
}

class BadDebtClassificationActionResult {
  const BadDebtClassificationActionResult({required this.success, required this.message, this.item});

  final bool success;
  final String message;
  final BadDebtClassification? item;
}
