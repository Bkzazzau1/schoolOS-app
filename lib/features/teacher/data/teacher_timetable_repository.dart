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
  });

  final List<TeacherTimetableLesson> lessons;
  final List<TeacherTimetableIntent> intents;
  final TeacherTimetablePermissions permissions;

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
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const lessonEntityType = 'teacher_timetable_lesson';
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
    await _seedIfNeeded(membership);

    final lessonRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: lessonEntityType,
    );
    final intentRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: intentEntityType,
    );

    final lessons = lessonRecords
        .map((record) => TeacherTimetableLesson.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => _lessonOrder(a.id).compareTo(_lessonOrder(b.id)));
    final intents = intentRecords
        .map((record) => TeacherTimetableIntent.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return TeacherTimetableSnapshot(
      lessons: lessons,
      intents: intents,
      permissions: permissionsFor(membership),
    );
  }

  Future<TeacherTimetableActionResult> queueSyncRequest() => _queueIntent(
        type: TeacherTimetableIntentType.syncRequest,
        detail: 'Refresh assigned timetable from the authoritative school timetable service when connectivity allows.',
      );

  Future<TeacherTimetableActionResult> requestChange() => _queueIntent(
        type: TeacherTimetableIntentType.changeRequest,
        detail: 'Teacher requested a timetable change review. No timetable row was altered locally.',
      );

  Future<TeacherTimetableActionResult> reportIssue(TeacherTimetableLesson lesson) => _queueIntent(
        type: TeacherTimetableIntentType.issueReport,
        lessonId: lesson.id,
        detail: 'Issue reported for ${lesson.className} · ${lesson.time}. The scheduled lesson remains unchanged pending review.',
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
    if (type == TeacherTimetableIntentType.changeRequest && !permissions.canRequestChange) {
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
        'Timetable refresh request queued offline. The cached timetable remains authoritative until a server response is received.',
      TeacherTimetableIntentType.changeRequest =>
        'Timetable-change request queued for review. No lesson, room or period was changed locally.',
      TeacherTimetableIntentType.issueReport =>
        'Lesson issue queued for review. The scheduled timetable entry remains unchanged.',
    };
    return TeacherTimetableActionResult(success: true, message: message);
  }

  Future<void> _seedIfNeeded(SchoolMembership membership) async {
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

  int _lessonOrder(String id) => teacherTimetableLessons.indexWhere((item) => item.id == id);
}
