import 'administrator_academics_models.dart';

class AdministratorTimetableTeacher {
  const AdministratorTimetableTeacher({
    required this.membershipId,
    required this.staffId,
    required this.name,
    required this.section,
  });

  final String membershipId;
  final String staffId;
  final String name;
  final String section;
}

class AdministratorTimetableEntry {
  const AdministratorTimetableEntry({
    required this.id,
    required this.termId,
    required this.classSubjectId,
    required this.classId,
    required this.className,
    required this.subjectId,
    required this.subject,
    required this.teacherId,
    required this.teacher,
    required this.dayOfWeek,
    required this.day,
    required this.periodNumber,
    required this.startTime,
    required this.endTime,
    required this.room,
    required this.status,
    required this.isActive,
    this.pendingSync = false,
  });

  final String id;
  final String termId;
  final String classSubjectId;
  final String classId;
  final String className;
  final String subjectId;
  final String subject;
  final String teacherId;
  final String teacher;
  final int dayOfWeek;
  final String day;
  final int periodNumber;
  final String startTime;
  final String endTime;
  final String room;
  final String status;
  final bool isActive;
  final bool pendingSync;

  String get time => '$startTime–$endTime';

  Map<String, Object?> toMutationJson() => {
        'id': id,
        'termId': termId,
        'classSubjectId': classSubjectId,
        'dayOfWeek': dayOfWeek,
        'periodNumber': periodNumber,
        'startTime': startTime,
        'endTime': endTime,
        'room': room,
        'isActive': isActive,
      };

  factory AdministratorTimetableEntry.fromJson(
    Map<String, Object?> json, {
    bool pendingSync = false,
  }) =>
      AdministratorTimetableEntry(
        id: json['id'] as String? ?? '',
        termId: json['termId'] as String? ?? '',
        classSubjectId: json['classSubjectId'] as String? ?? '',
        classId: json['classId'] as String? ?? '',
        className: json['className'] as String? ?? '',
        subjectId: json['subjectId'] as String? ?? '',
        subject: json['subject'] as String? ?? '',
        teacherId: json['teacherId'] as String? ?? '',
        teacher: json['teacher'] as String? ?? '',
        dayOfWeek: json['dayOfWeek'] as int? ?? 0,
        day: json['day'] as String? ?? '',
        periodNumber: json['periodNumber'] as int? ?? 0,
        startTime: json['startTime'] as String? ?? '',
        endTime: json['endTime'] as String? ?? '',
        room: json['room'] as String? ?? '',
        status: json['status'] as String? ?? 'scheduled',
        isActive: json['isActive'] as bool? ?? true,
        pendingSync: pendingSync,
      );
}

class AdministratorTimetableOverride {
  const AdministratorTimetableOverride({
    required this.id,
    required this.timetableEntryId,
    required this.lessonDate,
    required this.substituteTeacherId,
    required this.teacher,
    required this.room,
    required this.note,
    required this.status,
    required this.isCancelled,
    this.pendingSync = false,
  });

  final String id;
  final String timetableEntryId;
  final String lessonDate;
  final String substituteTeacherId;
  final String teacher;
  final String room;
  final String note;
  final String status;
  final bool isCancelled;
  final bool pendingSync;

  factory AdministratorTimetableOverride.fromJson(
    Map<String, Object?> json, {
    bool pendingSync = false,
  }) =>
      AdministratorTimetableOverride(
        id: json['id'] as String? ?? '',
        timetableEntryId: json['timetableEntryId'] as String? ?? '',
        lessonDate: json['lessonDate'] as String? ?? '',
        substituteTeacherId:
            json['substituteTeacherId'] as String? ?? json['teacherId'] as String? ?? '',
        teacher: json['teacher'] as String? ?? '',
        room: json['room'] as String? ?? '',
        note: json['note'] as String? ?? '',
        status: json['status'] as String? ?? 'scheduled',
        isCancelled: json['isCancelled'] as bool? ?? false,
        pendingSync: pendingSync,
      );
}

class AdministratorTimetableSnapshot {
  const AdministratorTimetableSnapshot({
    required this.activeTerm,
    required this.curriculum,
    required this.entries,
    required this.overrides,
    required this.teachers,
  });

  final AdministratorAcademicTerm? activeTerm;
  final List<AdministratorClassSubject> curriculum;
  final List<AdministratorTimetableEntry> entries;
  final List<AdministratorTimetableOverride> overrides;
  final List<AdministratorTimetableTeacher> teachers;

  List<AdministratorTimetableEntry> entriesForClass(String classId) => entries
      .where((item) => item.classId == classId && item.isActive)
      .toList(growable: false);

  int scheduledCount(String classSubjectId) => entries
      .where((item) => item.classSubjectId == classSubjectId && item.isActive)
      .length;
}
