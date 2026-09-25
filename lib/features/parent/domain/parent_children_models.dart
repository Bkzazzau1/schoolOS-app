class ParentChildSubjectProgress {
  const ParentChildSubjectProgress({
    required this.subject,
    required this.progress,
  });

  final String subject;
  final String progress;

  Map<String, Object?> toJson() => {
        'subject': subject,
        'progress': progress,
      };

  factory ParentChildSubjectProgress.fromJson(Map<String, dynamic> json) =>
      ParentChildSubjectProgress(
        subject: json['subject'] as String,
        progress: json['progress'] as String,
      );
}

class ParentChildTimelineEvent {
  const ParentChildTimelineEvent({
    required this.dateLabel,
    required this.description,
  });

  final String dateLabel;
  final String description;

  Map<String, Object?> toJson() => {
        'dateLabel': dateLabel,
        'description': description,
      };

  factory ParentChildTimelineEvent.fromJson(Map<String, dynamic> json) =>
      ParentChildTimelineEvent(
        dateLabel: json['dateLabel'] as String,
        description: json['description'] as String,
      );
}

class ParentLinkedChild {
  const ParentLinkedChild({
    required this.id,
    this.canonicalStudentId = '',
    required this.name,
    required this.initials,
    required this.className,
    required this.section,
    required this.admissionNumber,
    required this.classTeacher,
    required this.attendanceLabel,
    required this.learningLabel,
    required this.house,
    required this.currentBalance,
    required this.transport,
    required this.paymentAccount,
    required this.paymentPlan,
    required this.activities,
    required this.subjects,
    required this.timeline,
    this.active = true,
    this.presentToday = true,
  });

  final String id;

  /// The real, canonical Student.id the backend keys everything on - set
  /// only in canonical (server-connected) mode where the server actually
  /// sends it; empty in demo mode, honestly, since no such identity exists
  /// there. Cross-tenant features (like TransferVerify) must use this, never
  /// [id], which is a per-school student code, not a stable cross-school key.
  final String canonicalStudentId;
  final String name;
  final String initials;
  final String className;
  final String section;
  final String admissionNumber;
  final String classTeacher;
  final String attendanceLabel;
  final String learningLabel;
  final String house;
  final int currentBalance;
  final String transport;
  final String paymentAccount;
  final String paymentPlan;
  final String activities;
  final List<ParentChildSubjectProgress> subjects;
  final List<ParentChildTimelineEvent> timeline;
  final bool active;
  final bool presentToday;

  bool get isPrimary => section.toLowerCase() == 'primary';

  String get learningMetricLabel =>
      isPrimary ? 'Learning context' : 'Academic average';

  String get familyLearningContext => isPrimary
      ? 'Primary learning descriptors are contextual and revisable. They are not permanent ability labels or rankings.'
      : 'Academic results are shown with attendance and classroom context rather than as a permanent ability label.';

  Map<String, Object?> toJson() => {
        'id': id,
        'canonicalStudentId': canonicalStudentId,
        'name': name,
        'initials': initials,
        'className': className,
        'section': section,
        'admissionNumber': admissionNumber,
        'classTeacher': classTeacher,
        'attendanceLabel': attendanceLabel,
        'learningLabel': learningLabel,
        'house': house,
        'currentBalance': currentBalance,
        'transport': transport,
        'paymentAccount': paymentAccount,
        'paymentPlan': paymentPlan,
        'activities': activities,
        'subjects': subjects.map((item) => item.toJson()).toList(),
        'timeline': timeline.map((item) => item.toJson()).toList(),
        'active': active,
        'presentToday': presentToday,
      };

  factory ParentLinkedChild.fromJson(Map<String, dynamic> json) => ParentLinkedChild(
        id: json['id'] as String,
        canonicalStudentId: json['canonicalStudentId'] as String? ?? '',
        name: json['name'] as String,
        initials: json['initials'] as String,
        className: json['className'] as String,
        section: json['section'] as String,
        admissionNumber: json['admissionNumber'] as String,
        classTeacher: json['classTeacher'] as String,
        attendanceLabel: json['attendanceLabel'] as String,
        learningLabel: json['learningLabel'] as String,
        house: json['house'] as String,
        currentBalance: json['currentBalance'] as int,
        transport: json['transport'] as String,
        paymentAccount: json['paymentAccount'] as String,
        paymentPlan: json['paymentPlan'] as String,
        activities: json['activities'] as String,
        subjects: (json['subjects'] as List<dynamic>)
            .map(
              (item) => ParentChildSubjectProgress.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(growable: false),
        timeline: (json['timeline'] as List<dynamic>)
            .map(
              (item) => ParentChildTimelineEvent.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(growable: false),
        active: json['active'] as bool? ?? true,
        presentToday: json['presentToday'] as bool? ?? true,
      );
}

class ParentChildrenSnapshot {
  const ParentChildrenSnapshot({
    required this.familyAccountId,
    required this.academicPeriod,
    required this.children,
  });

  final String familyAccountId;
  final String academicPeriod;
  final List<ParentLinkedChild> children;

  Map<String, Object?> toJson() => {
        'familyAccountId': familyAccountId,
        'academicPeriod': academicPeriod,
        'children': children.map((child) => child.toJson()).toList(),
      };

  factory ParentChildrenSnapshot.fromJson(Map<String, dynamic> json) =>
      ParentChildrenSnapshot(
        familyAccountId: json['familyAccountId'] as String,
        academicPeriod: json['academicPeriod'] as String,
        children: (json['children'] as List<dynamic>)
            .map(
              (item) => ParentLinkedChild.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(growable: false),
      );
}
