enum AdministratorRecordStatus {
  verified('Verified'),
  pending('Pending'),
  missing('Missing'),
  draft('Draft');

  const AdministratorRecordStatus(this.label);
  final String label;

  static AdministratorRecordStatus fromLabel(String? value) {
    return values.firstWhere(
      (item) => item.label == value,
      orElse: () => AdministratorRecordStatus.pending,
    );
  }
}

class AdministratorDocumentRecord {
  const AdministratorDocumentRecord({
    required this.id,
    required this.document,
    required this.recordOwner,
    required this.status,
    required this.received,
    required this.visibility,
    this.kind = 'Student',
    this.verifiedBy = '',
    this.history = const [],
  });

  final String id;
  final String document;
  final String recordOwner;
  final AdministratorRecordStatus status;
  final String received;
  final String visibility;

  /// Whose document it is: Student, Family or Staff.
  final String kind;
  final String verifiedBy;

  /// Every step taken on this document, oldest first: {at, action, by, note}. Steps are added, never removed.
  final List<Map<String, Object?>> history;

  AdministratorDocumentRecord copyWith({
    AdministratorRecordStatus? status,
    String? received,
    String? verifiedBy,
    List<Map<String, Object?>>? history,
  }) =>
      AdministratorDocumentRecord(
        id: id,
        document: document,
        recordOwner: recordOwner,
        status: status ?? this.status,
        received: received ?? this.received,
        visibility: visibility,
        kind: kind,
        verifiedBy: verifiedBy ?? this.verifiedBy,
        history: history ?? this.history,
      );

  bool get needsAttention =>
      status == AdministratorRecordStatus.pending ||
      status == AdministratorRecordStatus.missing;

  Map<String, Object?> toJson() => {
        'id': id,
        'document': document,
        'recordOwner': recordOwner,
        'status': status.label,
        'received': received,
        'visibility': visibility,
        'kind': kind,
        'verifiedBy': verifiedBy,
        'history': history,
      };

  factory AdministratorDocumentRecord.fromJson(Map<String, Object?> json) {
    return AdministratorDocumentRecord(
      id: json['id'] as String? ?? '',
      document: json['document'] as String? ?? '',
      recordOwner: json['recordOwner'] as String? ?? '',
      status: AdministratorRecordStatus.fromLabel(json['status'] as String?),
      received: json['received'] as String? ?? '—',
      visibility: json['visibility'] as String? ?? 'Restricted',
      kind: json['kind'] as String? ?? 'Student',
      verifiedBy: json['verifiedBy'] as String? ?? '',
      history: [
        for (final h in (json['history'] as List? ?? const [])) Map<String, Object?>.from(h as Map),
      ],
    );
  }
}

class AdministratorRecordsPermissions {
  const AdministratorRecordsPermissions({
    required this.canViewRegister,
    required this.canReviewRestrictedMetadata,
  });

  final bool canViewRegister;
  final bool canReviewRestrictedMetadata;
}

const administratorRecordsVisibilityBoundary =
    'Documents use minimum-necessary visibility. Administration storing a document does not make it visible to every teacher, parent or leader.';

const administratorRecordsReviewBoundary =
    'The records office tracks where each document stands: missing, received, verified. Every step is kept in the document\'s history and nothing is deleted. Files are not stored here yet, and a document is not shared more widely than its visibility allows.';
