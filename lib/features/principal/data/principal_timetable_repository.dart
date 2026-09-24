import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/principal_timetable_models.dart';
import 'principal_assignments_repository.dart';
import 'principal_timetable_demo_data.dart';

class PrincipalTimetableSnapshot {
  const PrincipalTimetableSnapshot({
    required this.lessons,
    required this.teacherLoads,
    required this.roomUse,
    required this.exceptionStates,
    required this.exceptionEvents,
    required this.permissions,
    required this.termName,
    required this.weekLabel,
  });

  final List<PrincipalTimetableLesson> lessons;
  final List<PrincipalTeacherLoad> teacherLoads;
  final List<PrincipalRoomUtilization> roomUse;
  final List<PrincipalTimetableExceptionState> exceptionStates;
  final List<PrincipalTimetableExceptionEvent> exceptionEvents;
  final PrincipalTimetablePermissions permissions;
  final String termName;
  final String weekLabel;

  List<PrincipalTimetableLesson> get exceptions => lessons
      .where((lesson) => lesson.isException)
      .toList(growable: false);

  bool isHandled(String lessonId) => exceptionStates.any(
        (state) => state.lessonId == lessonId && state.handled,
      );

  int get substitutionCount => lessons
      .where((lesson) => lesson.status == PrincipalTimetableStatus.substitution)
      .length;
  int get uncoveredCount => lessons
      .where((lesson) =>
          lesson.status == PrincipalTimetableStatus.uncovered &&
          !isHandled(lesson.id))
      .length;
  int get clashCount => lessons
      .where((lesson) =>
          lesson.status == PrincipalTimetableStatus.clash &&
          !isHandled(lesson.id))
      .length;
  int get cancelledCount => lessons
      .where((lesson) => lesson.status == PrincipalTimetableStatus.cancelled)
      .length;
}

class PrincipalTimetableActionResult {
  const PrincipalTimetableActionResult({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;
}

String _loadStatus(int periods) {
  if (periods > principalTimetableWeeklyPeriodsTarget) return 'Heavy';
  if (periods < principalTimetableWeeklyPeriodsTarget) return 'Light';
  return 'Balanced';
}

class PrincipalTimetableRepository {
  PrincipalTimetableRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required PrincipalAssignmentsRepository assignments,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _assignments = assignments;

  static const _entryEntity = 'academic_timetable_entry';
  static const _overrideEntity = 'academic_timetable_override';
  static const _termEntity = 'academic_term';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final PrincipalAssignmentsRepository _assignments;

  PrincipalTimetablePermissions permissionsFor(SchoolMembership membership) =>
      PrincipalTimetablePermissions(
        canViewSecondaryTimetable: membership.role == SchoolRole.principal,
        canHandleExceptions: membership.role == SchoolRole.principal,
        canEditScheduleDirectly: false,
        canManagePrimary: false,
      );

  Future<PrincipalTimetableSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = permissionsFor(membership);
    final weekStart = _weekStart(DateTime.now());
    if (!permissions.canViewSecondaryTimetable) {
      return PrincipalTimetableSnapshot(
        lessons: const [],
        teacherLoads: const [],
        roomUse: const [],
        exceptionStates: const [],
        exceptionEvents: const [],
        permissions: permissions,
        termName: '',
        weekLabel: _weekLabel(weekStart),
      );
    }

    final assignmentsSnapshot = await _assignments.load();
    final periodsByTeacher = <String, int>{};
    for (final assignment in assignmentsSnapshot.assignments) {
      periodsByTeacher.update(
        assignment.teacherId,
        (value) => value + assignment.periodsPerWeek,
        ifAbsent: () => assignment.periodsPerWeek,
      );
    }
    final teacherLoads = [
      for (final teacher in assignmentsSnapshot.teachers)
        PrincipalTeacherLoad(
          name: teacher.name,
          lessons: periodsByTeacher[teacher.id] ?? 0,
          target: principalTimetableWeeklyPeriodsTarget,
          status: _loadStatus(periodsByTeacher[teacher.id] ?? 0),
        ),
    ]..sort((a, b) => a.name.compareTo(b.name));

    final activeTerm = await _activeTerm(membership.schoolId);
    final activeTermId = activeTerm?['id'] as String? ?? '';
    final termName = activeTerm?['name'] as String? ?? '';
    final entryRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entryEntity,
    );
    final overrideRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _overrideEntity,
    );
    final entries = [
      for (final record in entryRecords)
        if (record.payload['isActive'] != false &&
            (activeTermId.isEmpty || record.payload['termId'] == activeTermId))
          Map<String, Object?>.from(record.payload),
    ];
    final overrides = [
      for (final record in overrideRecords)
        Map<String, Object?>.from(record.payload),
    ];
    final lessons = _weekLessons(
      entries: entries,
      overrides: overrides,
      weekStart: weekStart,
    );
    final roomUse = _roomUse(entries);

    return PrincipalTimetableSnapshot(
      lessons: lessons,
      teacherLoads: teacherLoads,
      roomUse: roomUse,
      exceptionStates: const [],
      exceptionEvents: const [],
      permissions: permissions,
      termName: termName,
      weekLabel: _weekLabel(weekStart),
    );
  }

  Future<Map<String, Object?>?> _activeTerm(String schoolId) async {
    final records = await _localDatabase.getLocalRecords(
      tenantId: schoolId,
      entityType: _termEntity,
    );
    for (final record in records) {
      if (record.payload['status'] == 'active') {
        return Map<String, Object?>.from(record.payload);
      }
    }
    return null;
  }

  List<PrincipalTimetableLesson> _weekLessons({
    required List<Map<String, Object?>> entries,
    required List<Map<String, Object?>> overrides,
    required DateTime weekStart,
  }) {
    final overridesByOccurrence = <String, Map<String, Object?>>{};
    for (final override in overrides) {
      final date = DateTime.tryParse(override['lessonDate'] as String? ?? '');
      if (date == null || !_inWeek(date, weekStart)) continue;
      final entryId = override['timetableEntryId'] as String? ?? '';
      if (entryId.isNotEmpty) {
        overridesByOccurrence['$entryId|${_isoDate(date)}'] = override;
      }
    }

    final lessons = <PrincipalTimetableLesson>[];
    for (final entry in entries) {
      final dayOfWeek = entry['dayOfWeek'] as int? ?? 0;
      if (dayOfWeek < 1 || dayOfWeek > 7) continue;
      final date = weekStart.add(Duration(days: dayOfWeek - 1));
      final id = entry['id'] as String? ?? '';
      final override = overridesByOccurrence['$id|${_isoDate(date)}'];
      final source = override?['lesson'] is Map
          ? Map<String, Object?>.from(override!['lesson'] as Map)
          : entry;
      final status = override?['status'] as String? ?? source['status'] as String?;
      lessons.add(
        PrincipalTimetableLesson(
          id: id,
          day: source['day'] as String? ?? _dayName(dayOfWeek),
          time: source['time'] as String? ?? '',
          className: source['className'] as String? ?? '',
          subject: source['subject'] as String? ?? '',
          teacher: override?['teacher'] as String? ?? source['teacher'] as String? ?? '',
          room: override?['room'] as String? ?? source['room'] as String? ?? '',
          status: PrincipalTimetableStatus.fromLabel(status),
          termId: source['termId'] as String? ?? '',
          classSubjectId: source['classSubjectId'] as String? ?? '',
          classId: source['classId'] as String? ?? '',
          subjectId: source['subjectId'] as String? ?? '',
          teacherId: override?['teacherId'] as String? ?? source['teacherId'] as String? ?? '',
          periodNumber: source['periodNumber'] as int? ?? 0,
          lessonDate: _isoDate(date),
          note: override?['note'] as String?,
        ),
      );
    }
    lessons.sort((a, b) {
      final byDay = _dayIndex(a.day).compareTo(_dayIndex(b.day));
      if (byDay != 0) return byDay;
      final byTime = a.time.compareTo(b.time);
      if (byTime != 0) return byTime;
      return a.periodNumber.compareTo(b.periodNumber);
    });
    return lessons;
  }

  List<PrincipalRoomUtilization> _roomUse(
    List<Map<String, Object?>> entries,
  ) {
    final counts = <String, int>{};
    for (final entry in entries) {
      final room = (entry['room'] as String? ?? '').trim();
      if (room.isEmpty) continue;
      counts.update(room, (value) => value + 1, ifAbsent: () => 1);
    }
    final total = counts.values.fold<int>(0, (sum, value) => sum + value);
    final rows = [
      for (final item in counts.entries)
        PrincipalRoomUtilization(
          room: item.key,
          lessons: item.value,
          utilization: total == 0 ? 0 : (item.value * 100 / total).round(),
        ),
    ]..sort((a, b) => b.lessons.compareTo(a.lessons));
    return rows;
  }

  Future<PrincipalTimetableActionResult> setExceptionHandled({
    required String lessonId,
    required bool handled,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canHandleExceptions) {
      return const PrincipalTimetableActionResult(
        success: false,
        message:
            'This membership cannot handle Secondary timetable exceptions.',
      );
    }
    return const PrincipalTimetableActionResult(
      success: false,
      message:
          'Timetable exception acknowledgement is not an edit to the canonical schedule. Use the Administrator timetable workflow to correct a clash or uncovered lesson.',
    );
  }

  DateTime _weekStart(DateTime value) {
    final date = DateTime(value.year, value.month, value.day);
    return date.subtract(Duration(days: date.weekday - DateTime.monday));
  }

  bool _inWeek(DateTime date, DateTime weekStart) =>
      !date.isBefore(weekStart) &&
      date.isBefore(weekStart.add(const Duration(days: 7)));

  String _isoDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String _weekLabel(DateTime weekStart) {
    final end = weekStart.add(const Duration(days: 6));
    if (weekStart.month == end.month) {
      return '${weekStart.day}–${end.day} ${_monthName(end.month)} ${end.year}';
    }
    return '${weekStart.day} ${_monthName(weekStart.month)}–${end.day} ${_monthName(end.month)} ${end.year}';
  }

  int _dayIndex(String day) => const {
        'Monday': 1,
        'Tuesday': 2,
        'Wednesday': 3,
        'Thursday': 4,
        'Friday': 5,
        'Saturday': 6,
        'Sunday': 7,
      }[day] ?? 8;

  String _dayName(int weekday) => const {
        1: 'Monday',
        2: 'Tuesday',
        3: 'Wednesday',
        4: 'Thursday',
        5: 'Friday',
        6: 'Saturday',
        7: 'Sunday',
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
