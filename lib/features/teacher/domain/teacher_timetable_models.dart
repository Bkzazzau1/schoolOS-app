enum TeacherTimetableLessonStatus {
  scheduled,
  substitution,
  uncovered,
  clash,
  cancelled,
}

enum TeacherTimetableIntentType { syncRequest, changeRequest, issueReport }

enum TeacherTimetableIntentStatus { queuedForReview }

class TeacherTimetableLesson {
  const TeacherTimetableLesson({
    required this.id,
    required this.day,
    required this.date,
    required this.time,
    required this.className,
    required this.subject,
    required this.topic,
    required this.room,
    required this.status,
    this.note,
    this.sessionId = '',
    this.termId = '',
    this.term = '',
    this.classSubjectId = '',
    this.classId = '',
    this.subjectId = '',
    this.teacherId = '',
    this.periodNumber = 0,
    this.dayOfWeek = 0,
    this.startTime = '',
    this.endTime = '',
  });

  final String id;
  final String day;
  final String date;
  final String time;
  final String className;
  final String subject;
  final String topic;
  final String room;
  final TeacherTimetableLessonStatus status;
  final String? note;

  final String sessionId;
  final String termId;
  final String term;
  final String classSubjectId;
  final String classId;
  final String subjectId;
  final String teacherId;
  final int periodNumber;
  final int dayOfWeek;
  final String startTime;
  final String endTime;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return '$className $subject $topic $room $term'.toLowerCase().contains(q);
  }

  TeacherTimetableLesson copyWith({
    String? id,
    String? day,
    String? date,
    String? time,
    String? className,
    String? subject,
    String? topic,
    String? room,
    TeacherTimetableLessonStatus? status,
    String? note,
    String? sessionId,
    String? termId,
    String? term,
    String? classSubjectId,
    String? classId,
    String? subjectId,
    String? teacherId,
    int? periodNumber,
    int? dayOfWeek,
    String? startTime,
    String? endTime,
  }) =>
      TeacherTimetableLesson(
        id: id ?? this.id,
        day: day ?? this.day,
        date: date ?? this.date,
        time: time ?? this.time,
        className: className ?? this.className,
        subject: subject ?? this.subject,
        topic: topic ?? this.topic,
        room: room ?? this.room,
        status: status ?? this.status,
        note: note ?? this.note,
        sessionId: sessionId ?? this.sessionId,
        termId: termId ?? this.termId,
        term: term ?? this.term,
        classSubjectId: classSubjectId ?? this.classSubjectId,
        classId: classId ?? this.classId,
        subjectId: subjectId ?? this.subjectId,
        teacherId: teacherId ?? this.teacherId,
        periodNumber: periodNumber ?? this.periodNumber,
        dayOfWeek: dayOfWeek ?? this.dayOfWeek,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'day': day,
        'date': date,
        'time': time,
        'className': className,
        'subject': subject,
        'topic': topic,
        'room': room,
        'status': status.name,
        'note': note,
        'sessionId': sessionId,
        'termId': termId,
        'term': term,
        'classSubjectId': classSubjectId,
        'classId': classId,
        'subjectId': subjectId,
        'teacherId': teacherId,
        'periodNumber': periodNumber,
        'dayOfWeek': dayOfWeek,
        'startTime': startTime,
        'endTime': endTime,
      };

  factory TeacherTimetableLesson.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status'] as String? ?? 'scheduled';
    var status = TeacherTimetableLessonStatus.scheduled;
    for (final candidate in TeacherTimetableLessonStatus.values) {
      if (candidate.name == rawStatus) {
        status = candidate;
        break;
      }
    }
    return TeacherTimetableLesson(
      id: json['id'] as String? ?? '',
      day: json['day'] as String? ?? '',
      date: json['date'] as String? ?? '',
      time: json['time'] as String? ?? '',
      className: json['className'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      topic: json['topic'] as String? ?? '',
      room: json['room'] as String? ?? '',
      status: status,
      note: json['note'] as String?,
      sessionId: json['sessionId'] as String? ?? '',
      termId: json['termId'] as String? ?? '',
      term: json['term'] as String? ?? '',
      classSubjectId: json['classSubjectId'] as String? ?? '',
      classId: json['classId'] as String? ?? '',
      subjectId: json['subjectId'] as String? ?? '',
      teacherId: json['teacherId'] as String? ?? '',
      periodNumber: json['periodNumber'] as int? ?? 0,
      dayOfWeek: json['dayOfWeek'] as int? ?? 0,
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
    );
  }
}

class TeacherTimetableKpi {
  const TeacherTimetableKpi({
    required this.label,
    required this.value,
    required this.hint,
  });

  final String label;
  final String value;
  final String hint;
}

class TeacherTimetableNotice {
  const TeacherTimetableNotice({
    required this.title,
    required this.detail,
    this.warning = false,
  });

  final String title;
  final String detail;
  final bool warning;
}

class TeacherTimetableIntent {
  const TeacherTimetableIntent({
    required this.id,
    required this.type,
    required this.status,
    required this.actorMembershipId,
    required this.createdAt,
    this.lessonId,
    this.detail,
  });

  final String id;
  final TeacherTimetableIntentType type;
  final TeacherTimetableIntentStatus status;
  final String actorMembershipId;
  final String createdAt;
  final String? lessonId;
  final String? detail;

  Map<String, Object?> toJson() => {
        'id': id,
        'type': type.name,
        'status': status.name,
        'actorMembershipId': actorMembershipId,
        'createdAt': createdAt,
        'lessonId': lessonId,
        'detail': detail,
      };

  factory TeacherTimetableIntent.fromJson(Map<String, dynamic> json) =>
      TeacherTimetableIntent(
        id: json['id'] as String,
        type: TeacherTimetableIntentType.values.byName(json['type'] as String),
        status: TeacherTimetableIntentStatus.values.byName(
          json['status'] as String,
        ),
        actorMembershipId: json['actorMembershipId'] as String,
        createdAt: json['createdAt'] as String,
        lessonId: json['lessonId'] as String?,
        detail: json['detail'] as String?,
      );
}

class TeacherTimetablePermissions {
  const TeacherTimetablePermissions({
    required this.canViewAssignedTimetable,
    required this.canTakeAttendance,
    required this.canRequestChange,
    required this.canEditTimetableDirectly,
    required this.canConfirmServerSync,
  });

  final bool canViewAssignedTimetable;
  final bool canTakeAttendance;
  final bool canRequestChange;
  final bool canEditTimetableDirectly;
  final bool canConfirmServerSync;
}
