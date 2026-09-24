enum AdministratorLifecycleStatus {
  pending('Pending'),
  completed('Completed'),
  cancelled('Cancelled');

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
    this.studentId = '',
    this.fromClass = '',
    this.toClass = '',
    this.requestedAt = '',
    this.completedAt = '',
    this.approvedBy = '',
    this.recordsPackReady = false,
    this.note = '',
  });

  final String id;
  final String studentName;
  final String workflow;
  final String change;
  final AdministratorLifecycleStatus status;
  final String studentId;
  final String fromClass;
  final String toClass;
  final String requestedAt;
  final String completedAt;
  final String approvedBy;
  final bool recordsPackReady;
  final String note;

  String get student => studentId.isEmpty ? id : studentId;

  /// Promotion/class change moves to another class. Repeat opens a new
  /// enrollment period in the same class and is therefore not a class move.
  bool get movesClass => (isPromotion || isClassChange) && toClass.isNotEmpty;
  bool get isAcademicProgression => isPromotion || isRepeat;

  AdministratorLifecycleRecord copyWith({
    String? change,
    AdministratorLifecycleStatus? status,
    String? completedAt,
    String? approvedBy,
    bool? recordsPackReady,
    String? note,
  }) =>
      AdministratorLifecycleRecord(
        id: id,
        studentName: studentName,
        workflow: workflow,
        change: change ?? this.change,
        status: status ?? this.status,
        studentId: student,
        fromClass: fromClass,
        toClass: toClass,
        requestedAt: requestedAt,
        completedAt: completedAt ?? this.completedAt,
        approvedBy: approvedBy ?? this.approvedBy,
        recordsPackReady: recordsPackReady ?? this.recordsPackReady,
        note: note ?? this.note,
      );

  bool get isPromotion => workflow == 'Promotion';
  bool get isRepeat => workflow == 'Repeat';
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
        'studentId': student,
        'fromClass': fromClass,
        'toClass': toClass,
        'requestedAt': requestedAt,
        'completedAt': completedAt,
        'approvedBy': approvedBy,
        'recordsPackReady': recordsPackReady,
        'note': note,
      };

  factory AdministratorLifecycleRecord.fromJson(Map<String, Object?> json) {
    return AdministratorLifecycleRecord(
      id: json['id'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '',
      workflow: json['workflow'] as String? ?? '',
      change: json['change'] as String? ?? '',
      status: AdministratorLifecycleStatus.fromLabel(json['status'] as String?),
      studentId: json['studentId'] as String? ?? '',
      fromClass: json['fromClass'] as String? ?? '',
      toClass: json['toClass'] as String? ?? '',
      requestedAt: json['requestedAt'] as String? ?? '',
      completedAt: json['completedAt'] as String? ?? '',
      approvedBy: json['approvedBy'] as String? ?? '',
      recordsPackReady: json['recordsPackReady'] as bool? ?? false,
      note: json['note'] as String? ?? '',
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
    'Administration executes approved lifecycle changes; promotion and repeat decisions require authorized academic leadership.';

const administratorLifecycleHistoryBoundary =
    'Historical class and enrollment records must be appended rather than overwritten so prior placement and progression history remain auditable.';

const administratorLifecycleOpenBoundary =
    'Open is an operational review on this website surface. It must not be upgraded into an approval, promotion/repeat decision, withdrawal decision or destructive class-history rewrite unless a separate authorized workflow explicitly provides that action.';
