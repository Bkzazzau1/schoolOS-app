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

  /// The record's own id. For the older records it is the student's id, so a student's id is [studentId] when this is empty.
  final String id;
  final String studentName;
  final String workflow;
  final String change;
  final AdministratorLifecycleStatus status;

  /// The student this change is for.
  final String studentId;

  /// For a class change or promotion: where the student is, and where they move to.
  final String fromClass;
  final String toClass;
  final String requestedAt;
  final String completedAt;

  /// Who approved a promotion (the decision belongs to academic leadership, not administration).
  final String approvedBy;

  /// For a transfer out: the student's records pack has been prepared.
  final bool recordsPackReady;
  final String note;

  String get student => studentId.isEmpty ? id : studentId;

  /// Changes the student's class, once completed.
  bool get movesClass => (isPromotion || isClassChange) && toClass.isNotEmpty;

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
    'Administration executes approved lifecycle changes; academic promotion decisions require authorized academic leadership.';

const administratorLifecycleHistoryBoundary =
    'Historical class and enrollment records must be appended rather than overwritten so prior placement and enrollment history remain auditable.';

const administratorLifecycleOpenBoundary =
    'Open is an operational review on this website surface. It must not be upgraded into an approval, promotion decision, withdrawal decision or destructive class-history rewrite unless a separate authorized workflow explicitly provides that action.';
