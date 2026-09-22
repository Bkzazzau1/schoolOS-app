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
  });

  /// Always empty: no real per-period class schedule is recorded anywhere in the app yet
  /// (real teaching assignments track a weekly period count, not which day or time a class
  /// meets), so there is nothing real to show in a lesson grid.
  final List<PrincipalTimetableLesson> lessons;

  /// Each real Secondary teacher's real weekly periods, summed from real teaching
  /// assignments, bucketed against a fixed target.
  final List<PrincipalTeacherLoad> teacherLoads;

  /// Always empty: no real source records which room a class uses.
  final List<PrincipalRoomUtilization> roomUse;
  final List<PrincipalTimetableExceptionState> exceptionStates;
  final List<PrincipalTimetableExceptionEvent> exceptionEvents;
  final PrincipalTimetablePermissions permissions;

  List<PrincipalTimetableLesson> get exceptions => lessons.where((lesson) => lesson.isException).toList(growable: false);

  bool isHandled(String lessonId) => exceptionStates.any((state) => state.lessonId == lessonId && state.handled);

  int get substitutionCount => lessons.where((lesson) => lesson.status == PrincipalTimetableStatus.substitution).length;
  int get uncoveredCount => lessons.where((lesson) => lesson.status == PrincipalTimetableStatus.uncovered && !isHandled(lesson.id)).length;
  int get clashCount => lessons.where((lesson) => lesson.status == PrincipalTimetableStatus.clash && !isHandled(lesson.id)).length;
}

class PrincipalTimetableActionResult {
  const PrincipalTimetableActionResult({required this.success, required this.message});
  final bool success;
  final String message;
}

String _loadStatus(int periods) {
  if (periods > principalTimetableWeeklyPeriodsTarget) return 'Heavy';
  if (periods < principalTimetableWeeklyPeriodsTarget) return 'Light';
  return 'Balanced';
}

class PrincipalTimetableRepository {
  /// [localDatabase] is accepted for constructor consistency with every other Principal
  /// repository, even though this one is a pure read-side roll-up of real assignment data and
  /// never touches the local database directly.
  PrincipalTimetableRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required PrincipalAssignmentsRepository assignments,
  })  : _schoolSession = schoolSession,
        _assignments = assignments;

  final SchoolSessionController _schoolSession;
  final PrincipalAssignmentsRepository _assignments;

  PrincipalTimetablePermissions permissionsFor(SchoolMembership membership) => PrincipalTimetablePermissions(
        canViewSecondaryTimetable: membership.role == SchoolRole.principal,
        canHandleExceptions: membership.role == SchoolRole.principal,
        canEditScheduleDirectly: false,
        canManagePrimary: false,
      );

  Future<PrincipalTimetableSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = permissionsFor(membership);
    if (!permissions.canViewSecondaryTimetable) {
      return PrincipalTimetableSnapshot(lessons: const [], teacherLoads: const [], roomUse: const [], exceptionStates: const [], exceptionEvents: const [], permissions: permissions);
    }

    final assignmentsSnapshot = await _assignments.load();
    final periodsByTeacher = <String, int>{};
    for (final assignment in assignmentsSnapshot.assignments) {
      periodsByTeacher.update(assignment.teacherId, (value) => value + assignment.periodsPerWeek, ifAbsent: () => assignment.periodsPerWeek);
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

    return PrincipalTimetableSnapshot(
      lessons: const [],
      teacherLoads: teacherLoads,
      roomUse: const [],
      exceptionStates: const [],
      exceptionEvents: const [],
      permissions: permissions,
    );
  }

  Future<PrincipalTimetableActionResult> setExceptionHandled({
    required String lessonId,
    required bool handled,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canHandleExceptions) {
      return const PrincipalTimetableActionResult(success: false, message: 'This membership cannot handle Secondary timetable exceptions.');
    }
    return const PrincipalTimetableActionResult(
      success: false,
      message: 'No real timetable exceptions exist yet to handle: no real class-period schedule is recorded anywhere in the app.',
    );
  }
}
