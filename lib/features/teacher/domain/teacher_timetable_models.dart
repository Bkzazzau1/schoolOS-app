enum TeacherTimetableLessonStatus { scheduled, substitution }

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

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return '$className $subject $topic $room'.toLowerCase().contains(q);
  }

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
      };

  factory TeacherTimetableLesson.fromJson(Map<String, dynamic> json) => TeacherTimetableLesson(
        id: json['id'] as String,
        day: json['day'] as String,
        date: json['date'] as String,
        time: json['time'] as String,
        className: json['className'] as String,
        subject: json['subject'] as String,
        topic: json['topic'] as String,
        room: json['room'] as String,
        status: TeacherTimetableLessonStatus.values.byName(json['status'] as String),
        note: json['note'] as String?,
      );
}

class TeacherTimetableKpi {
  const TeacherTimetableKpi({required this.label, required this.value, required this.hint});
  final String label;
  final String value;
  final String hint;
}

class TeacherTimetableNotice {
  const TeacherTimetableNotice({required this.title, required this.detail, this.warning = false});
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

  factory TeacherTimetableIntent.fromJson(Map<String, dynamic> json) => TeacherTimetableIntent(
        id: json['id'] as String,
        type: TeacherTimetableIntentType.values.byName(json['type'] as String),
        status: TeacherTimetableIntentStatus.values.byName(json['status'] as String),
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
