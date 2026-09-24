enum TeacherAttendanceStatus { unmarked, present, absent, late, excused }

enum TeacherAttendanceSubmissionState { draft, submitted }

class TeacherAttendanceTopicOption {
  const TeacherAttendanceTopicOption({required this.id, required this.title});

  final String id;
  final String title;
}

class TeacherAttendanceStudentEntry {
  const TeacherAttendanceStudentEntry({
    required this.id,
    required this.code,
    required this.studentId,
    required this.status,
    required this.note,
    this.attendanceRate = 0,
  });

  final int id;
  final String code;
  final String studentId;
  final TeacherAttendanceStatus status;
  final String note;

  /// Retained only for standalone demo compatibility. Canonical occurrence
  /// attendance does not invent a historical percentage for a student.
  final int attendanceRate;

  TeacherAttendanceStudentEntry copyWith({
    TeacherAttendanceStatus? status,
    String? note,
  }) =>
      TeacherAttendanceStudentEntry(
        id: id,
        code: code,
        studentId: studentId,
        status: status ?? this.status,
        note: note ?? this.note,
        attendanceRate: attendanceRate,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'code': code,
        'studentId': studentId,
        'status': status.name,
        'note': note,
        'attendanceRate': attendanceRate,
      };

  factory TeacherAttendanceStudentEntry.fromJson(Map<String, dynamic> json) {
    final raw = json['status'] as String? ?? 'unmarked';
    final status = TeacherAttendanceStatus.values.firstWhere(
      (item) => item.name == raw,
      orElse: () => TeacherAttendanceStatus.unmarked,
    );
    return TeacherAttendanceStudentEntry(
      id: json['id'] as int? ?? 0,
      code: json['studentName'] as String? ?? json['code'] as String? ?? '',
      studentId: json['studentId'] as String? ?? '',
      status: status,
      note: json['note'] as String? ?? '',
      attendanceRate: json['attendanceRate'] as int? ?? 0,
    );
  }
}

class TeacherAttendanceLesson {
  const TeacherAttendanceLesson({
    required this.id,
    required this.className,
    required this.subject,
    required this.time,
    required this.room,
    required this.topic,
    this.timetableEntryId = '',
    this.lessonDate = '',
    this.classSubjectId = '',
    this.termId = '',
    this.topicId = '',
    this.periodNumber = 0,
    this.topicOptions = const [],
  });

  /// Attendance-register occurrence id, not a class-name-derived identifier.
  final String id;
  final String timetableEntryId;
  final String lessonDate;
  final String classSubjectId;
  final String termId;
  final String className;
  final String subject;
  final String time;
  final String room;
  final int periodNumber;
  final String topicId;
  final String topic;
  final List<TeacherAttendanceTopicOption> topicOptions;

  String get label {
    final date = lessonDate.isEmpty ? '' : ' · $lessonDate';
    final period = periodNumber <= 0 ? '' : ' · Period $periodNumber';
    return '$className · $subject$period$date';
  }

  TeacherAttendanceLesson copyWith({
    String? topicId,
    String? topic,
    List<TeacherAttendanceTopicOption>? topicOptions,
  }) =>
      TeacherAttendanceLesson(
        id: id,
        timetableEntryId: timetableEntryId,
        lessonDate: lessonDate,
        classSubjectId: classSubjectId,
        termId: termId,
        className: className,
        subject: subject,
        time: time,
        room: room,
        periodNumber: periodNumber,
        topicId: topicId ?? this.topicId,
        topic: topic ?? this.topic,
        topicOptions: topicOptions ?? this.topicOptions,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'timetableEntryId': timetableEntryId,
        'lessonDate': lessonDate,
        'classSubjectId': classSubjectId,
        'termId': termId,
        'className': className,
        'subject': subject,
        'time': time,
        'room': room,
        'periodNumber': periodNumber,
        'topicId': topicId,
        'topic': topic,
      };

  factory TeacherAttendanceLesson.fromJson(Map<String, dynamic> json) =>
      TeacherAttendanceLesson(
        id: json['id'] as String? ?? '',
        timetableEntryId: json['timetableEntryId'] as String? ?? '',
        lessonDate: json['lessonDate'] as String? ?? '',
        classSubjectId: json['classSubjectId'] as String? ?? '',
        termId: json['termId'] as String? ?? '',
        className: json['className'] as String? ?? '',
        subject: json['subject'] as String? ?? '',
        time: json['time'] as String? ?? '',
        room: json['room'] as String? ?? '',
        periodNumber: json['periodNumber'] as int? ?? 0,
        topicId: json['topicId'] as String? ?? '',
        topic: json['topic'] as String? ?? '',
      );
}

class TeacherAttendanceRegister {
  const TeacherAttendanceRegister({
    required this.lesson,
    required this.entries,
    required this.submissionState,
    this.submittedAt,
    this.submittedByMembershipId,
    this.pendingSync = false,
  });

  final TeacherAttendanceLesson lesson;
  final List<TeacherAttendanceStudentEntry> entries;
  final TeacherAttendanceSubmissionState submissionState;
  final String? submittedAt;
  final String? submittedByMembershipId;
  final bool pendingSync;

  int count(TeacherAttendanceStatus status) =>
      entries.where((entry) => entry.status == status).length;

  int get unmarkedCount => count(TeacherAttendanceStatus.unmarked);
  int get reviewCount =>
      count(TeacherAttendanceStatus.absent) + count(TeacherAttendanceStatus.late);
  int get markedCount => entries.length - unmarkedCount;
  int get presentPercent => entries.isEmpty
      ? 0
      : ((count(TeacherAttendanceStatus.present) / entries.length) * 100).round();

  TeacherAttendanceRegister copyWith({
    TeacherAttendanceLesson? lesson,
    List<TeacherAttendanceStudentEntry>? entries,
    TeacherAttendanceSubmissionState? submissionState,
    String? submittedAt,
    String? submittedByMembershipId,
    bool? pendingSync,
    bool clearSubmission = false,
  }) =>
      TeacherAttendanceRegister(
        lesson: lesson ?? this.lesson,
        entries: entries ?? this.entries,
        submissionState: submissionState ?? this.submissionState,
        submittedAt: clearSubmission ? null : (submittedAt ?? this.submittedAt),
        submittedByMembershipId: clearSubmission
            ? null
            : (submittedByMembershipId ?? this.submittedByMembershipId),
        pendingSync: pendingSync ?? this.pendingSync,
      );

  /// Canonical sync payload expected by the backend lesson-attendance handler.
  Map<String, Object?> toJson() => {
        'id': lesson.id,
        'timetableEntryId': lesson.timetableEntryId,
        'lessonDate': lesson.lessonDate,
        'topicId': lesson.topicId,
        'state': submissionState.name,
        'entries': [
          for (final entry in entries)
            {
              'studentId': entry.studentId,
              'status': entry.status.name,
              'note': entry.note,
            },
        ],
      };

  /// Rich local cache keeps presentation metadata that the mutation contract
  /// intentionally omits. It is never treated as server acknowledgement.
  Map<String, Object?> toLocalJson() => {
        'lesson': lesson.toJson(),
        'entries': [for (final entry in entries) entry.toJson()],
        'submissionState': submissionState.name,
        'submittedAt': submittedAt,
        'submittedByMembershipId': submittedByMembershipId,
      };

  factory TeacherAttendanceRegister.fromJson(Map<String, dynamic> json) {
    // New canonical payloads are flat; local/demo payloads retain a nested lesson.
    final rawLesson = json['lesson'];
    final lesson = rawLesson is Map
        ? TeacherAttendanceLesson.fromJson(Map<String, dynamic>.from(rawLesson))
        : TeacherAttendanceLesson.fromJson(json);
    final rawEntries = json['entries'] as List? ?? const [];
    final stateRaw = json['state'] as String? ??
        json['submissionState'] as String? ??
        'draft';
    return TeacherAttendanceRegister(
      lesson: lesson,
      entries: [
        for (var i = 0; i < rawEntries.length; i++)
          if (rawEntries[i] is Map)
            TeacherAttendanceStudentEntry.fromJson({
              'id': i + 1,
              ...Map<String, dynamic>.from(rawEntries[i] as Map),
            }),
      ],
      submissionState: TeacherAttendanceSubmissionState.values.firstWhere(
        (item) => item.name == stateRaw,
        orElse: () => TeacherAttendanceSubmissionState.draft,
      ),
      submittedAt: json['submittedAt'] as String?,
      submittedByMembershipId: json['submittedByMembershipId'] as String?,
    );
  }
}

class TeacherAttendanceHistoryItem {
  const TeacherAttendanceHistoryItem({
    required this.className,
    required this.subject,
    required this.day,
    required this.presentSummary,
    required this.rate,
  });

  final String className;
  final String subject;
  final String day;
  final String presentSummary;
  final String rate;
}

class TeacherAttendancePermissions {
  const TeacherAttendancePermissions({
    required this.canViewAssignedRegisters,
    required this.canEditAssignedRegister,
    required this.canSubmitAssignedRegister,
    required this.canEditOtherTeachersRegisters,
    required this.canFinalizeUnsyncedAbsence,
  });

  final bool canViewAssignedRegisters;
  final bool canEditAssignedRegister;
  final bool canSubmitAssignedRegister;
  final bool canEditOtherTeachersRegisters;
  final bool canFinalizeUnsyncedAbsence;
}

class TeacherAttendanceSnapshot {
  const TeacherAttendanceSnapshot({
    required this.registers,
    required this.permissions,
    this.dateLabel = '',
    this.canonical = false,
  });

  final List<TeacherAttendanceRegister> registers;
  final TeacherAttendancePermissions permissions;
  final String dateLabel;
  final bool canonical;
}

String teacherAttendanceStatusLabel(TeacherAttendanceStatus value) => switch (value) {
      TeacherAttendanceStatus.unmarked => 'Unmarked',
      TeacherAttendanceStatus.present => 'Present',
      TeacherAttendanceStatus.absent => 'Absent',
      TeacherAttendanceStatus.late => 'Late',
      TeacherAttendanceStatus.excused => 'Excused',
    };
