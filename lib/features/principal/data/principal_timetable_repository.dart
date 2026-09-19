import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/principal_timetable_models.dart';
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

  final List<PrincipalTimetableLesson> lessons;
  final List<PrincipalTeacherLoad> teacherLoads;
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

class PrincipalTimetableRepository {
  PrincipalTimetableRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _lessonType = 'principal_timetable_lesson';
  static const _teacherLoadType = 'principal_timetable_teacher_load';
  static const _roomType = 'principal_timetable_room_use';
  static const _exceptionStateType = 'principal_timetable_exception_state';
  static const _exceptionEventType = 'principal_timetable_exception_event';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  PrincipalTimetablePermissions permissionsFor(SchoolMembership membership) => PrincipalTimetablePermissions(
        canViewSecondaryTimetable: membership.role == SchoolRole.principal,
        canHandleExceptions: membership.role == SchoolRole.principal,
        canEditScheduleDirectly: false,
        canManagePrimary: false,
      );

  Future<PrincipalTimetableSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    await _seedIfNeeded(membership);

    final lessonRecords = await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: _lessonType);
    final teacherRecords = await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: _teacherLoadType);
    final roomRecords = await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: _roomType);
    final stateRecords = await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: _exceptionStateType);
    final eventRecords = await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: _exceptionEventType);

    final lessons = lessonRecords.map((record) => PrincipalTimetableLesson.fromJson(record.payload)).toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));
    final teacherLoads = teacherRecords.map((record) => PrincipalTeacherLoad.fromJson(record.payload)).toList(growable: false)
      ..sort((a, b) => _teacherOrder(a.name).compareTo(_teacherOrder(b.name)));
    final roomUse = roomRecords.map((record) => PrincipalRoomUtilization.fromJson(record.payload)).toList(growable: false)
      ..sort((a, b) => _roomOrder(a.room).compareTo(_roomOrder(b.room)));
    final exceptionStates = stateRecords.map((record) => PrincipalTimetableExceptionState.fromJson(record.payload)).toList(growable: false);
    final exceptionEvents = eventRecords.map((record) => PrincipalTimetableExceptionEvent.fromJson(record.payload)).toList(growable: false)
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    return PrincipalTimetableSnapshot(
      lessons: lessons,
      teacherLoads: teacherLoads,
      roomUse: roomUse,
      exceptionStates: exceptionStates,
      exceptionEvents: exceptionEvents,
      permissions: permissionsFor(membership),
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

    final lessonRecord = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _lessonType,
      entityId: lessonId,
    );
    if (lessonRecord == null) {
      return const PrincipalTimetableActionResult(success: false, message: 'Timetable lesson not found.');
    }
    final lesson = PrincipalTimetableLesson.fromJson(lessonRecord.payload);
    if (!lesson.isException) {
      return const PrincipalTimetableActionResult(success: false, message: 'Scheduled lessons do not require exception handling.');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final state = PrincipalTimetableExceptionState(
      lessonId: lessonId,
      handled: handled,
      updatedByMembershipId: membership.id,
      updatedAt: now,
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _exceptionStateType,
      entityId: lessonId,
      payload: state.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _exceptionStateType,
      entityId: lessonId,
      operation: SyncOperation.update,
      payload: state.toJson(),
    );

    final event = PrincipalTimetableExceptionEvent(
      id: '$lessonId-${DateTime.now().microsecondsSinceEpoch}',
      lessonId: lessonId,
      action: handled ? PrincipalTimetableExceptionAction.handled : PrincipalTimetableExceptionAction.reopened,
      actorMembershipId: membership.id,
      occurredAt: now,
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _exceptionEventType,
      entityId: event.id,
      payload: event.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _exceptionEventType,
      entityId: event.id,
      operation: SyncOperation.create,
      payload: event.toJson(),
    );

    return PrincipalTimetableActionResult(
      success: true,
      message: handled
          ? 'Exception marked handled offline and queued for synchronization. The lesson schedule itself was not changed.'
          : 'Exception reopened offline and queued for synchronization.',
    );
  }

  Future<void> _seedIfNeeded(SchoolMembership membership) async {
    if ((await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: _lessonType)).isEmpty) {
      for (final lesson in principalTimetableLessons) {
        await _localDatabase.upsertLocalRecord(tenantId: membership.schoolId, entityType: _lessonType, entityId: lesson.id, payload: lesson.toJson());
      }
    }
    if ((await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: _teacherLoadType)).isEmpty) {
      for (final teacher in principalTeacherLoads) {
        await _localDatabase.upsertLocalRecord(tenantId: membership.schoolId, entityType: _teacherLoadType, entityId: teacher.name, payload: teacher.toJson());
      }
    }
    if ((await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: _roomType)).isEmpty) {
      for (final room in principalRoomUtilization) {
        await _localDatabase.upsertLocalRecord(tenantId: membership.schoolId, entityType: _roomType, entityId: room.room, payload: room.toJson());
      }
    }
    if ((await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: _exceptionStateType)).isEmpty) {
      for (final lesson in principalTimetableLessons.where((item) => item.isException)) {
        final state = PrincipalTimetableExceptionState(lessonId: lesson.id, handled: false);
        await _localDatabase.upsertLocalRecord(tenantId: membership.schoolId, entityType: _exceptionStateType, entityId: lesson.id, payload: state.toJson());
      }
    }
  }

  int _teacherOrder(String name) => principalTeacherLoads.indexWhere((item) => item.name == name);
  int _roomOrder(String room) => principalRoomUtilization.indexWhere((item) => item.room == room);
}
