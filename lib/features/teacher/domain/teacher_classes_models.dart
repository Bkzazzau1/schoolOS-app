class TeacherClassCurriculumTopic {
  const TeacherClassCurriculumTopic({
    required this.id,
    required this.sequence,
    required this.title,
    required this.description,
  });

  final String id;
  final int sequence;
  final String title;
  final String description;

  Map<String, Object?> toJson() => {
        'id': id,
        'sequence': sequence,
        'title': title,
        'description': description,
      };

  factory TeacherClassCurriculumTopic.fromJson(Map<String, dynamic> json) =>
      TeacherClassCurriculumTopic(
        id: json['id'] as String? ?? '',
        sequence: json['sequence'] as int? ?? 1,
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
      );
}

class TeacherClassAssignment {
  const TeacherClassAssignment({
    required this.id,
    required this.name,
    required this.subject,
    required this.students,
    required this.room,
    required this.progress,
    required this.attendance,
    required this.classAverage,
    required this.nextLesson,
    required this.topic,
    required this.pendingMarking,
    this.sessionId = '',
    this.sessionName = '',
    this.classId = '',
    this.subjectId = '',
    this.classSubjectId = '',
    this.teachingAssignmentId = '',
    this.periodsPerWeek = 0,
    this.currentTermId = '',
    this.currentTerm = '',
    this.curriculumTopics = const [],
  });

  final String id;
  final String name;
  final String subject;
  final int students;
  final String room;

  /// Legacy summary fields retained for compatibility with existing teacher
  /// screens. They must not be treated as canonical curriculum data.
  final int progress;
  final int attendance;
  final int classAverage;
  final String nextLesson;
  final String topic;
  final int pendingMarking;

  /// Canonical academic identity published by the server-owned
  /// teacher_class_assignment record.
  final String sessionId;
  final String sessionName;
  final String classId;
  final String subjectId;
  final String classSubjectId;
  final String teachingAssignmentId;
  final int periodsPerWeek;
  final String currentTermId;
  final String currentTerm;
  final List<TeacherClassCurriculumTopic> curriculumTopics;

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    final topics = curriculumTopics.map((item) => item.title).join(' ');
    return '$name $subject $sessionName $currentTerm $topics $topic'
        .toLowerCase()
        .contains(normalized);
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'subject': subject,
        'students': students,
        'room': room,
        'progress': progress,
        'attendance': attendance,
        'classAverage': classAverage,
        'nextLesson': nextLesson,
        'topic': topic,
        'pendingMarking': pendingMarking,
        'sessionId': sessionId,
        'sessionName': sessionName,
        'classId': classId,
        'subjectId': subjectId,
        'classSubjectId': classSubjectId,
        'teachingAssignmentId': teachingAssignmentId,
        'periodsPerWeek': periodsPerWeek,
        'currentTermId': currentTermId,
        'currentTerm': currentTerm,
        'curriculumTopics': [
          for (final item in curriculumTopics) item.toJson(),
        ],
      };

  factory TeacherClassAssignment.fromJson(Map<String, dynamic> json) {
    return TeacherClassAssignment(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      students: json['students'] as int? ?? 0,
      room: json['room'] as String? ?? '',
      progress: json['progress'] as int? ?? 0,
      attendance: json['attendance'] as int? ?? 0,
      classAverage: json['classAverage'] as int? ?? 0,
      nextLesson: json['nextLesson'] as String? ?? '',
      topic: json['topic'] as String? ?? '',
      pendingMarking: json['pendingMarking'] as int? ?? 0,
      sessionId: json['sessionId'] as String? ?? '',
      sessionName: json['sessionName'] as String? ?? '',
      classId: json['classId'] as String? ?? '',
      subjectId: json['subjectId'] as String? ?? '',
      classSubjectId: json['classSubjectId'] as String? ?? '',
      teachingAssignmentId: json['teachingAssignmentId'] as String? ?? '',
      periodsPerWeek: json['periodsPerWeek'] as int? ?? 0,
      currentTermId: json['currentTermId'] as String? ?? '',
      currentTerm: json['currentTerm'] as String? ?? '',
      curriculumTopics: [
        for (final item in (json['curriculumTopics'] as List? ?? const []))
          if (item is Map)
            TeacherClassCurriculumTopic.fromJson(
              Map<String, dynamic>.from(item),
            ),
      ],
    );
  }
}

class TeacherClassPermissions {
  const TeacherClassPermissions({
    required this.canViewAssignedClasses,
    required this.canOpenAuthorizedRoster,
    required this.canChangeClassMembership,
    required this.canChangeAcademicMarksFromClassesPage,
    required this.canAccessFinance,
    required this.canAccessSafeguardingDetails,
  });

  final bool canViewAssignedClasses;
  final bool canOpenAuthorizedRoster;
  final bool canChangeClassMembership;
  final bool canChangeAcademicMarksFromClassesPage;
  final bool canAccessFinance;
  final bool canAccessSafeguardingDetails;
}

class TeacherClassesSnapshot {
  const TeacherClassesSnapshot({
    required this.assignments,
    required this.permissions,
  });

  final List<TeacherClassAssignment> assignments;
  final TeacherClassPermissions permissions;

  int get totalStudents =>
      assignments.fold(0, (sum, item) => sum + item.students);
}
