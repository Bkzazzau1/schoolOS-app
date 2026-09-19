enum AdministratorLifecycleStatus {
  pending('Pending'),
  completed('Completed');

  const AdministratorLifecycleStatus(this.label);
  final String label;

  static AdministratorLifecycleStatus fromLabel(String? value) {
    return values.firstWhere(
      (item) => item.label == value,
      orElse: () => AdministratorLifecycleStatus.pending,
    );
  }
}

class AdministratorLifecycleRecord {
  const AdministratorLifecycleRecord({
    required this.id,
    required this.studentName,
    required this.workflow,
    required this.change,
    required this.status,
  });

  final String id;
  final String studentName;
  final String workflow;
  final String change;
  final AdministratorLifecycleStatus status;

  bool get isPromotion => workflow == 'Promotion';
  bool get isTransferOut => workflow == 'Transfer out';
  bool get isClassChange => workflow == 'Class change';
  bool get isAlumni => workflow == 'Alumni';
  bool get isPending => status == AdministratorLifecycleStatus.pending;

  Map<String, Object?> toJson() => {
        'id': id,
        'studentName': studentName,
        'workflow': workflow,
        'change': change,
        'status': status.label,
      };

  factory AdministratorLifecycleRecord.fromJson(Map<String, Object?> json) {
    return AdministratorLifecycleRecord(
      id: json['id'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '',
      workflow: json['workflow'] as String? ?? '',
      change: json['change'] as String? ?? '',
      status: AdministratorLifecycleStatus.fromLabel(json['status'] as String?),
    );
  }
}

class AdministratorLifecyclePermissions {
  const AdministratorLifecyclePermissions({
    required this.canViewRegister,
    required this.canOpenOperationalReview,
  });

  final bool canViewRegister;
  final bool canOpenOperationalReview;
}

const administratorLifecycleAuthorityBoundary =
    'Administration executes approved lifecycle changes; academic promotion decisions require authorized academic leadership.';

const administratorLifecycleHistoryBoundary =
    'Historical class and enrollment records must be appended rather than overwritten so prior placement and enrollment history remain auditable.';

const administratorLifecycleOpenBoundary =
    'Open is an operational review on this website surface. It must not be upgraded into an approval, promotion decision, withdrawal decision or destructive class-history rewrite unless a separate authorized workflow explicitly provides that action.';
