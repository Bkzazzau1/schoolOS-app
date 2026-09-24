import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/teacher_timetable_models.dart';
import 'teacher_timetable_demo_data.dart';

class TeacherTimetableSnapshot {
  const TeacherTimetableSnapshot({
    required this.lessons,
    required this.intents,
    required this.permissions,
    required this.notices,
    required this.days,
    required this.termLabel,
    required this.weekLabel,
    required this.canonical,
  });

  final List<TeacherTimetableLesson> lessons;
  final List<TeacherTimetableIntent> intents;
  final TeacherTimetablePermissions permissions;
  final List<TeacherTimetableNotice> notices;
  final List<String> days;
  final String termLabel;
  final String weekLabel;
  final bool canonical;

  List<TeacherTimetableLesson> lessonsForDay(String day) =>
      lessons.where((lesson) => lesson.day == day).toList(growable: false);
}

class TeacherTimetableActionResult {
  const TeacherTimetableActionResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class TeacherTimetableRepository {
  TeacherTimetableRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    Object? roster,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const lessonEntityType = 'teacher_timetable_lesson';
  static const privateScheduleEntityType = 'teacher_timetable_schedule';
  static const intentEntityType = 'teacher_timetable_intent';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  TeacherTimetablePermissions permissionsFor(SchoolMembership membership) =>
      TeacherTimetablePermissions(
        canViewAssignedTimetable: membership.role == SchoolRole.teacher,
        canTakeAttendance: membership.role == SchoolRole.teacher,
        canRequestChange: membership.role == SchoolRole.teacher,
        canEditTimetableDirectly: false,
        canConfirmServerSync: false,
      );

  Future<TeacherTimetableSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    final intents = await _loadIntents(membership);
    if (!LocalDatabase.blockDemoSeeds) {
      await _seedDemoIfNeeded(membership);
      final records = await _localDatabase.getLocalRecords(
        tenantId: membership.schoolId,
        entityType: lessonEntityType,
      );
      final lessons = records
          .map((record) => TeacherTimetableLesson.fromJson(record.payload))
          .toList(growable: false);
      return TeacherTimetableSnapshot(
        lessons: lessons,
        intents: intents,
        permissions: permissionsFor(membership),
        notices: teacherTimetableNotices,
        days: teacherTimetableDays,
        termLabel: teacherTimetableTermLabel,
        weekLabel: teacherTimetableWeekLabel,
        canonical: false,
      );
    }

    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: privateScheduleEntityType,
      entityId: membership.id,
    );
    final payload = record?.payload ?? const <String, Object?>{};
    final entries = _mapList(payload['entries']);
    final overrides = _mapList(payload['overrides']);
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - DateTime.monday));
    final lessons = _canonicalWeek(
      membership: membership,
      entries: entries,
      overrides: overrides,
      weekStart: DateTime(weekStart.year, weekStart.month, weekStart.day),
    );
    final days = <String>[];
    for (var offset = 0; offset < 7; offset++) {
      final date = weekStart.add(Duration(days: offset));
      if (lessons.any((lesson) => lesson.dayOfWeek == date.weekday)) {
        days.add(_dayName(date.weekday));
      }
    }
    if (days.isEmpty) {
      days.addAll(const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']);
    }

    final term = entries.isNotEmpty
        ? entries.first['term'] as String? ?? ''
        : _overrideTerm(overrides);
    return TeacherTimetableSnapshot(
      lessons: lessons,
      intents: intents,
      permissions: permissionsFor(membership),
      notices: _noticesForWeek(
        membership: membership,
        overrides: overrides,
        weekStart: weekStart,
      ),
      days: days,
      termLabel: term.isEmpty ? 'CURRENT TERM' : term.toUpperCase(),
      weekLabel: _weekLabel(weekStart),
      canonical: true,
    );
  }

  Future<List<TeacherTimetableIntent>> _loadIntents(
    SchoolMembership membership,
  ) async {
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: intentEntityType,
    );
    final intents = records
        .map((record) => TeacherTimetableIntent.fromJson(record.payload))
        .where((intent) => intent.actorMembershipId == membership.id)
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return intents;
  }

  List<TeacherTimetableLesson> _canonicalWeek({
    required SchoolMembership membership,
    required List<Map<String, Object?>> entries,
    required List<Map<String, Object?>> overrides,
    required DateTime weekStart,
  }) {
    final result = <TeacherTimetableLesson>[];
    final baseIds = <String>{};
    final overrideByOccurrence = <String, Map<String, Object?>>{};
    for (final override in overrides) {
      final entryId = override['timetableEntryId'] as String? ?? '';
      final date = override['lessonDate'] as String? ?? '';
      if (entryId.isNotEmpty && date.isNotEmpty) {
        overrideByOccurrence['$entryId|$date'] = override;
      }
    }

    for (final entry in entries) {
      if (entry['isActive'] == false) continue;
      final lesson = TeacherTimetableLesson.fromJson(
        Map<String, dynamic>.from(entry),
      );
      if (lesson.dayOfWeek < 1 || lesson.dayOfWeek > 7) continue;
      final date = weekStart.add(Duration(days: lesson.dayOfWeek - 1));
      final dateIso = _isoDate(date);
      baseIds.add(lesson.id);
      final override = overrideByOccurrence['${lesson.id}|$dateIso'];
      result.add(_applyOccurrence(
        lesson: lesson,
        date: date,
        override: override,
      ));
    }

    for (final override in overrides) {
      final date = DateTime.tryParse(override['lessonDate'] as String? ?? '');
      if (date == null || !_inWeek(date, weekStart)) continue;
      if (override['teacherId'] != membership.id) continue;
      final entryId = override['timetableEntryId'] as String? ?? '';
      if (baseIds.contains(entryId)) continue;
      final rawLesson = override['lesson'];
      if (rawLesson is! Map) continue;
      final lesson = TeacherTimetableLesson.fromJson(
        Map<String, dynamic>.from(rawLesson),
      );
      result.add(_applyOccurrence(
        lesson: lesson,
        date: date,
        override: override,
      ));
    }

    result.sort((a, b) {
      final byDay = a.dayOfWeek.compareTo(b.dayOfWeek);
      if (byDay != 0) return byDay;
      final byTime = a.startTime.compareTo(b.startTime);
      if (byTime != 0) return byTime;
      return a.periodNumber.compareTo(b.periodNumber);
    });
    return result;
  }

  TeacherTimetableLesson _applyOccurrence({
    required TeacherTimetableLesson lesson,
    required DateTime date,
    Map<String, Object?>? override,
  }) {
    var status = lesson.status;
    var room = lesson.room;
    String? note = lesson.note;
    var teacherId = lesson.teacherId;
    if (override != null) {
      final rawStatus = override['status'] as String? ?? status.name;
      for (final candidate in TeacherTimetableLessonStatus.values) {
        if (candidate.name == rawStatus) status = candidate;
      }
      room = override['room'] as String? ?? room;
      note = override['note'] as String? ?? note;
      teacherId = override['teacherId'] as String? ?? teacherId;
    }
    return lesson.copyWith(
      date: _shortDate(date),
      day: _dayName(date.weekday),
      room: room,
      status: status,
      note: note,
      teacherId: teacherId,
    );
  }

  List<TeacherTimetableNotice> _noticesForWeek({
    required SchoolMembership membership,
    required List<Map<String, Object?>> overrides,
    required DateTime weekStart,
  }) {
    final notices = <TeacherTimetableNotice>[];
    for (final item in overrides) {
      final date = DateTime.tryParse(item['lessonDate'] as String? ?? '');
      if (date == null || !_inWeek(date, weekStart)) continue;
      final lesson = item['lesson'];
      if (lesson is! Map) continue;
      final base = Map<String, Object?>.from(lesson);
      final className = base['className'] as String? ?? 'Class';
      final subject = base['subject'] as String? ?? 'Lesson';
      final status = item['status'] as String? ?? '';
      if (status == 'cancelled') {
        notices.add(TeacherTimetableNotice(
          title: '${_dayName(date.weekday)} cancellation',
          detail: '$className · $subject has been cancelled for ${_shortDate(date)}.',
          warning: true,
        ));
      } else if (status == 'substitution') {
        final covering = item['teacherId'] == membership.id;
        notices.add(TeacherTimetableNotice(
          title: covering ? 'Substitution assigned' : 'Substitution cover',
          detail: covering
              ? 'You are covering $className · $subject on ${_shortDate(date)}.'
              : '$className · $subject on ${_shortDate(date)} has a substitute teacher.',
          warning: true,
        ));
      } else if ((item['room'] as String? ?? '').isNotEmpty) {
        notices.add(TeacherTimetableNotice(
          title: 'Room change',
          detail: '$className · $subject is in ${item['room']} on ${_shortDate(date)}.',
        ));
      }
    }
    return notices;
  }

  Future<TeacherTimetableActionResult> queueSyncRequest() => _queueIntent(
        type: TeacherTimetableIntentType.syncRequest,
        detail:
            'Refresh my assigned timetable from the authoritative school timetable when connectivity allows.',
      );

  Future<TeacherTimetableActionResult> requestChange() => _queueIntent(
        type: TeacherTimetableIntentType.changeRequest,
        detail:
            'Teacher requested a timetable change review. No timetable row was altered locally.',
      );

  Future<TeacherTimetableActionResult> reportIssue(
    TeacherTimetableLesson lesson,
  ) =>
      _queueIntent(
        type: TeacherTimetableIntentType.issueReport,
        lessonId: lesson.id,
        detail:
            'Issue reported for ${lesson.className} · ${lesson.time}. The scheduled lesson remains unchanged pending review.',
      );

  Future<TeacherTimetableActionResult> _queueIntent({
    required TeacherTimetableIntentType type,
    String? lessonId,
    required String detail,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = permissionsFor(membership);
    if (!permissions.canViewAssignedTimetable) {
      return const TeacherTimetableActionResult(
        success: false,
        message: 'This membership cannot use the Teacher timetable workspace.',
      );
    }
    if (type == TeacherTimetableIntentType.changeRequest &&
        !permissions.canRequestChange) {
      return const TeacherTimetableActionResult(
        success: false,
        message: 'This membership cannot request timetable changes.',
      );
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final id = '${type.name}-${DateTime.now().microsecondsSinceEpoch}';
    final intent = TeacherTimetableIntent(
      id: id,
      type: type,
      status: TeacherTimetableIntentStatus.queuedForReview,
      actorMembershipId: membership.id,
      createdAt: now,
      lessonId: lessonId,
      detail: detail,
    );

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: intentEntityType,
      entityId: id,
      payload: intent.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: intentEntityType,
      entityId: id,
      operation: SyncOperation.create,
      payload: intent.toJson(),
    );

    final message = switch (type) {
      TeacherTimetableIntentType.syncRequest =>
        'Timetable refresh request queued. Your cached server schedule remains unchanged until sync completes.',
      TeacherTimetableIntentType.changeRequest =>
        'Timetable-change request queued for review. No lesson, room or period was changed locally.',
      TeacherTimetableIntentType.issueReport =>
        'Lesson issue queued for review. The scheduled timetable entry remains unchanged.',
    };
    return TeacherTimetableActionResult(success: true, message: message);
  }

  Future<void> _seedDemoIfNeeded(SchoolMembership membership) async {
    final existing = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: lessonEntityType,
    );
    if (existing.isNotEmpty) return;
    for (final lesson in teacherTimetableLessons) {
      await _localDatabase.upsertLocalRecord(
        tenantId: membership.schoolId,
        entityType: lessonEntityType,
        entityId: lesson.id,
        payload: lesson.toJson(),
      );
    }
  }

  List<Map<String, Object?>> _mapList(Object? raw) => [
        for (final item in raw is List ? raw : const [])
          if (item is Map) Map<String, Object?>.from(item),
      ];

  String _overrideTerm(List<Map<String, Object?>> overrides) {
    for (final item in overrides) {
      final lesson = item['lesson'];
      if (lesson is Map) {
        final term = lesson['term'];
        if (term is String && term.isNotEmpty) return term;
      }
    }
    return '';
  }

  bool _inWeek(DateTime date, DateTime weekStart) {
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final end = start.add(const Duration(days: 7));
    return !date.isBefore(start) && date.isBefore(end);
  }

  String _isoDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String _shortDate(DateTime value) =>
      '${value.day} ${_monthName(value.month)}';

  String _weekLabel(DateTime weekStart) {
    final end = weekStart.add(const Duration(days: 6));
    if (weekStart.month == end.month) {
      return '${weekStart.day}–${end.day} ${_monthName(end.month)} ${end.year}';
    }
    return '${weekStart.day} ${_monthName(weekStart.month)}–${end.day} ${_monthName(end.month)} ${end.year}';
  }

  String _dayName(int weekday) => const {
        DateTime.monday: 'Monday',
        DateTime.tuesday: 'Tuesday',
        DateTime.wednesday: 'Wednesday',
        DateTime.thursday: 'Thursday',
        DateTime.friday: 'Friday',
        DateTime.saturday: 'Saturday',
        DateTime.sunday: 'Sunday',
      }[weekday] ?? '';

  String _monthName(int month) => const [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ][month];
}
