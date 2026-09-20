enum TeacherAttendanceStatus { present, absent, late, excused }

enum TeacherAttendanceSubmissionState {
  draft,
  submitted,
}

class TeacherAttendanceStudentEntry {
  const TeacherAttendanceStudentEntry({
    required this.id,
    required this.code,
    required this.studentId,
    required this.status,
    required this.note,
    required this.attendanceRate,
  });

  final int id;
  final String code;
  final String studentId;
  final TeacherAttendanceStatus status;
  final String note;
  final int attendanceRate;

  TeacherAttendanceStudentEntry copyWith({
    TeacherAttendanceStatus? status,
    String? note,
  }) {
    return TeacherAttendanceStudentEntry(
      id: id,
      code: code,
      studentId: studentId,
      status: status ?? this.status,
      note: note ?? this.note,
      attendanceRate: attendanceRate,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'code': code,
        'studentId': studentId,
        'status': status.name,
        'note': note,
        'attendanceRate': attendanceRate,
      };

  factory TeacherAttendanceStudentEntry.fromJson(Map<String, dynamic> json) {
    return TeacherAttendanceStudentEntry(
      id: json['id'] as int,
      code: json['code'] as String,
      studentId: json['studentId'] as String,
      status: TeacherAttendanceStatus.values.byName(json['status'] as String),
      note: json['note'] as String,
      attendanceRate: json['attendanceRate'] as int,
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
  });

  final String id;
  final String className;
  final String subject;
  final String time;
  final String room;
  final String topic;

  String get label => '$className · $subject · $time AM';

  Map<String, Object?> toJson() => {
        'id': id,
        'className': className,
        'subject': subject,
        'time': time,
        'room': room,
        'topic': topic,
      };

  factory TeacherAttendanceLesson.fromJson(Map<String, dynamic> json) {
    return TeacherAttendanceLesson(
      id: json['id'] as String,
      className: json['className'] as String,
      subject: json['subject'] as String,
      time: json['time'] as String,
      room: json['room'] as String,
      topic: json['topic'] as String,
    );
  }
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

  int get reviewCount =>
      count(TeacherAttendanceStatus.absent) + count(TeacherAttendanceStatus.late);

  int get presentPercent => entries.isEmpty
      ? 0
      : ((count(TeacherAttendanceStatus.present) / entries.length) * 100).round();

  TeacherAttendanceRegister copyWith({
    List<TeacherAttendanceStudentEntry>? entries,
    TeacherAttendanceSubmissionState? submissionState,
    String? submittedAt,
    String? submittedByMembershipId,
    bool? pendingSync,
    bool clearSubmission = false,
  }) {
    return TeacherAttendanceRegister(
      lesson: lesson,
      entries: entries ?? this.entries,
      submissionState: submissionState ?? this.submissionState,
      submittedAt: clearSubmission ? null : (submittedAt ?? this.submittedAt),
      submittedByMembershipId:
          clearSubmission ? null : (submittedByMembershipId ?? this.submittedByMembershipId),
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }

  Map<String, Object?> toJson() => {
        'lesson': lesson.toJson(),
        'entries': entries.map((entry) => entry.toJson()).toList(growable: false),
        'submissionState': submissionState.name,
        'submittedAt': submittedAt,
        'submittedByMembershipId': submittedByMembershipId,
      };

  factory TeacherAttendanceRegister.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'] as List<dynamic>;
    return TeacherAttendanceRegister(
      lesson: TeacherAttendanceLesson.fromJson(
        Map<String, dynamic>.from(json['lesson'] as Map),
      ),
      entries: rawEntries
          .map(
            (entry) => TeacherAttendanceStudentEntry.fromJson(
              Map<String, dynamic>.from(entry as Map),
            ),
          )
          .toList(growable: false),
      submissionState:
          TeacherAttendanceSubmissionState.values.byName(json['submissionState'] as String),
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
  });

  final List<TeacherAttendanceRegister> registers;
  final TeacherAttendancePermissions permissions;
}

String teacherAttendanceStatusLabel(TeacherAttendanceStatus value) => switch (value) {
      TeacherAttendanceStatus.present => 'Present',
      TeacherAttendanceStatus.absent => 'Absent',
      TeacherAttendanceStatus.late => 'Late',
      TeacherAttendanceStatus.excused => 'Excused',
    };
