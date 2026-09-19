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
  });

  final String id;
  final String document;
  final String recordOwner;
  final AdministratorRecordStatus status;
  final String received;
  final String visibility;

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
      };

  factory AdministratorDocumentRecord.fromJson(Map<String, Object?> json) {
    return AdministratorDocumentRecord(
      id: json['id'] as String? ?? '',
      document: json['document'] as String? ?? '',
      recordOwner: json['recordOwner'] as String? ?? '',
      status: AdministratorRecordStatus.fromLabel(json['status'] as String?),
      received: json['received'] as String? ?? '—',
      visibility: json['visibility'] as String? ?? 'Restricted',
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
    'Review on the website is a read-only records-office action. Do not invent document editing, verification approval, file download, deletion or wider sharing until those workflows exist.';
