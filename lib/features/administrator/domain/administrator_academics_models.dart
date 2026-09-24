class AdministratorAcademicSession {
  const AdministratorAcademicSession({
    required this.id,
    required this.code,
    required this.name,
    required this.startsOn,
    required this.endsOn,
    required this.status,
    this.pendingSync = false,
  });

  final String id;
  final String code;
  final String name;
  final String startsOn;
  final String endsOn;
  final String status;
  final bool pendingSync;

  bool get isActive => status == 'active';
  bool get isClosed => status == 'closed';

  Map<String, Object?> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'startsOn': startsOn,
        'endsOn': endsOn,
        'status': status,
      };

  factory AdministratorAcademicSession.fromJson(
    Map<String, Object?> json, {
    bool pendingSync = false,
  }) =>
      AdministratorAcademicSession(
        id: json['id'] as String? ?? '',
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        startsOn: json['startsOn'] as String? ?? '',
        endsOn: json['endsOn'] as String? ?? '',
        status: json['status'] as String? ?? 'planned',
        pendingSync: pendingSync,
      );
}

class AdministratorAcademicTerm {
  const AdministratorAcademicTerm({
    required this.id,
    required this.sessionId,
    required this.code,
    required this.name,
    required this.sequence,
    required this.startsOn,
    required this.endsOn,
    required this.status,
    this.pendingSync = false,
  });

  final String id;
  final String sessionId;
  final String code;
  final String name;
  final int sequence;
  final String startsOn;
  final String endsOn;
  final String status;
  final bool pendingSync;

  Map<String, Object?> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'code': code,
        'name': name,
        'sequence': sequence,
        'startsOn': startsOn,
        'endsOn': endsOn,
        'status': status,
      };

  factory AdministratorAcademicTerm.fromJson(
    Map<String, Object?> json, {
    bool pendingSync = false,
  }) =>
      AdministratorAcademicTerm(
        id: json['id'] as String? ?? '',
        sessionId: json['sessionId'] as String? ?? '',
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        sequence: json['sequence'] as int? ?? 1,
        startsOn: json['startsOn'] as String? ?? '',
        endsOn: json['endsOn'] as String? ?? '',
        status: json['status'] as String? ?? 'planned',
        pendingSync: pendingSync,
      );
}

class AdministratorAcademicClass {
  const AdministratorAcademicClass({
    required this.id,
    required this.code,
    required this.name,
    required this.section,
    required this.levelOrder,
    required this.stream,
    required this.nextClassId,
    required this.isTerminal,
    required this.isActive,
    this.pendingSync = false,
  });

  final String id;
  final String code;
  final String name;
  final String section;
  final int levelOrder;
  final String stream;
  final String nextClassId;
  final bool isTerminal;
  final bool isActive;
  final bool pendingSync;

  Map<String, Object?> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'section': section,
        'levelOrder': levelOrder,
        'stream': stream,
        'nextClassId': nextClassId,
        'isTerminal': isTerminal,
        'isActive': isActive,
      };

  factory AdministratorAcademicClass.fromJson(
    Map<String, Object?> json, {
    bool pendingSync = false,
  }) =>
      AdministratorAcademicClass(
        id: json['id'] as String? ?? '',
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        section: json['section'] as String? ?? '',
        levelOrder: json['levelOrder'] as int? ?? 1,
        stream: json['stream'] as String? ?? '',
        nextClassId: json['nextClassId'] as String? ?? '',
        isTerminal: json['isTerminal'] as bool? ?? false,
        isActive: json['isActive'] as bool? ?? true,
        pendingSync: pendingSync,
      );
}

class AdministratorSubject {
  const AdministratorSubject({
    required this.id,
    required this.code,
    required this.name,
    required this.shortName,
    required this.section,
    required this.isActive,
    this.pendingSync = false,
  });

  final String id;
  final String code;
  final String name;
  final String shortName;
  final String section;
  final bool isActive;
  final bool pendingSync;

  Map<String, Object?> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'shortName': shortName,
        'section': section,
        'isActive': isActive,
      };

  factory AdministratorSubject.fromJson(
    Map<String, Object?> json, {
    bool pendingSync = false,
  }) =>
      AdministratorSubject(
        id: json['id'] as String? ?? '',
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        shortName: json['shortName'] as String? ?? '',
        section: json['section'] as String? ?? '',
        isActive: json['isActive'] as bool? ?? true,
        pendingSync: pendingSync,
      );
}

class AdministratorClassSubject {
  const AdministratorClassSubject({
    required this.id,
    required this.sessionId,
    required this.classId,
    required this.subjectId,
    required this.requirement,
    required this.periodsPerWeek,
    required this.isActive,
    this.className = '',
    this.subjectCode = '',
    this.subject = '',
    this.pendingSync = false,
  });

  final String id;
  final String sessionId;
  final String classId;
  final String className;
  final String subjectId;
  final String subjectCode;
  final String subject;
  final String requirement;
  final int periodsPerWeek;
  final bool isActive;
  final bool pendingSync;

  bool get compulsory => requirement == 'compulsory';

  Map<String, Object?> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'classId': classId,
        'subjectId': subjectId,
        'requirement': requirement,
        'periodsPerWeek': periodsPerWeek,
        'isActive': isActive,
      };

  factory AdministratorClassSubject.fromJson(
    Map<String, Object?> json, {
    bool pendingSync = false,
  }) =>
      AdministratorClassSubject(
        id: json['id'] as String? ?? '',
        sessionId: json['sessionId'] as String? ?? '',
        classId: json['classId'] as String? ?? '',
        className: json['className'] as String? ?? '',
        subjectId: json['subjectId'] as String? ?? '',
        subjectCode: json['subjectCode'] as String? ?? '',
        subject: json['subject'] as String? ?? '',
        requirement: json['requirement'] as String? ?? 'compulsory',
        periodsPerWeek: json['periodsPerWeek'] as int? ?? 1,
        isActive: json['isActive'] as bool? ?? true,
        pendingSync: pendingSync,
      );
}

class AdministratorCurriculumTopic {
  const AdministratorCurriculumTopic({
    required this.id,
    required this.classSubjectId,
    required this.termId,
    required this.sequence,
    required this.title,
    required this.description,
    this.pendingSync = false,
  });

  final String id;
  final String classSubjectId;
  final String termId;
  final int sequence;
  final String title;
  final String description;
  final bool pendingSync;

  Map<String, Object?> toJson() => {
        'id': id,
        'classSubjectId': classSubjectId,
        'termId': termId,
        'sequence': sequence,
        'title': title,
        'description': description,
      };

  factory AdministratorCurriculumTopic.fromJson(
    Map<String, Object?> json, {
    bool pendingSync = false,
  }) =>
      AdministratorCurriculumTopic(
        id: json['id'] as String? ?? '',
        classSubjectId: json['classSubjectId'] as String? ?? '',
        termId: json['termId'] as String? ?? '',
        sequence: json['sequence'] as int? ?? 1,
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        pendingSync: pendingSync,
      );
}

class AdministratorProgressionDecision {
  const AdministratorProgressionDecision({
    required this.studentId,
    required this.studentName,
    required this.outcome,
    required this.targetClassId,
    required this.recordsPackReady,
    required this.note,
  });

  final String studentId;
  final String studentName;
  final String outcome;
  final String targetClassId;
  final bool recordsPackReady;
  final String note;

  Map<String, Object?> toJson() => {
        'studentId': studentId,
        'outcome': outcome,
        'targetClassId': targetClassId,
        'recordsPackReady': recordsPackReady,
        'note': note,
      };

  factory AdministratorProgressionDecision.fromJson(Map<String, Object?> json) =>
      AdministratorProgressionDecision(
        studentId: json['studentId'] as String? ?? '',
        studentName: json['studentName'] as String? ?? '',
        outcome: json['outcome'] as String? ?? 'hold',
        targetClassId: json['targetClassId'] as String? ?? '',
        recordsPackReady: json['recordsPackReady'] as bool? ?? false,
        note: json['note'] as String? ?? '',
      );
}

class AdministratorProgressionBatch {
  const AdministratorProgressionBatch({
    required this.id,
    required this.fromSessionId,
    required this.toSessionId,
    required this.sourceClassId,
    required this.status,
    required this.approvedBy,
    required this.note,
    required this.decisions,
    this.appliedAt,
    this.pendingSync = false,
  });

  final String id;
  final String fromSessionId;
  final String toSessionId;
  final String sourceClassId;
  final String status;
  final String approvedBy;
  final String note;
  final List<AdministratorProgressionDecision> decisions;
  final String? appliedAt;
  final bool pendingSync;

  bool get isApplied => status == 'applied' && !pendingSync && appliedAt != null;
  bool get queuedForApply => status == 'applied' && pendingSync;

  Map<String, Object?> toJson() => {
        'id': id,
        'fromSessionId': fromSessionId,
        'toSessionId': toSessionId,
        'sourceClassId': sourceClassId,
        'status': status,
        'approvedBy': approvedBy,
        'note': note,
        'decisions': decisions.map((item) => item.toJson()).toList(),
      };

  factory AdministratorProgressionBatch.fromJson(
    Map<String, Object?> json, {
    bool pendingSync = false,
  }) =>
      AdministratorProgressionBatch(
        id: json['id'] as String? ?? '',
        fromSessionId: json['fromSessionId'] as String? ?? '',
        toSessionId: json['toSessionId'] as String? ?? '',
        sourceClassId: json['sourceClassId'] as String? ?? '',
        status: json['status'] as String? ?? 'draft',
        approvedBy: json['approvedBy'] as String? ?? '',
        note: json['note'] as String? ?? '',
        appliedAt: json['appliedAt'] as String?,
        decisions: [
          for (final item in (json['decisions'] as List? ?? const []))
            if (item is Map)
              AdministratorProgressionDecision.fromJson(
                Map<String, Object?>.from(item),
              ),
        ],
        pendingSync: pendingSync,
      );
}

class AdministratorAcademicsSnapshot {
  const AdministratorAcademicsSnapshot({
    required this.sessions,
    required this.terms,
    required this.classes,
    required this.subjects,
    required this.classSubjects,
    required this.topics,
    required this.batches,
  });

  final List<AdministratorAcademicSession> sessions;
  final List<AdministratorAcademicTerm> terms;
  final List<AdministratorAcademicClass> classes;
  final List<AdministratorSubject> subjects;
  final List<AdministratorClassSubject> classSubjects;
  final List<AdministratorCurriculumTopic> topics;
  final List<AdministratorProgressionBatch> batches;

  AdministratorAcademicSession? get activeSession =>
      sessions.where((item) => item.isActive).firstOrNull;

  AdministratorAcademicTerm? activeTermFor(String sessionId) => terms
      .where((item) => item.sessionId == sessionId && item.status == 'active')
      .firstOrNull;

  List<AdministratorClassSubject> subjectsForClass(
    String sessionId,
    String classId,
  ) =>
      classSubjects
          .where(
            (item) =>
                item.sessionId == sessionId &&
                item.classId == classId &&
                item.isActive,
          )
          .toList(growable: false);
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
