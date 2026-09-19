import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../domain/lesson_plan_models.dart';

class SavedLessonPlan {
  const SavedLessonPlan({
    required this.id,
    required this.request,
    required this.draft,
    required this.savedAt,
    required this.pendingSync,
  });

  final String id;
  final LessonPlanRequest request;
  final LessonPlanDraft draft;
  final DateTime savedAt;
  final bool pendingSync;
}

class LessonPlanRepository {
  LessonPlanRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  Future<String> saveDraft({
    required LessonPlanRequest request,
    required LessonPlanDraft draft,
    bool queueForSync = false,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (request.schoolId != membership.schoolId) {
      throw StateError('Lesson plan school does not match the active school.');
    }

    final entityId = _entityId(request);
    final savedAt = DateTime.now().toUtc();
    final payload = <String, Object?>{
      'id': entityId,
      'request': request.toJson(),
      'draft': draft.toJson(),
      'savedAt': savedAt.toIso8601String(),
      'savedByMembershipId': membership.id,
    };

    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: 'lesson_plan',
      entityId: entityId,
    );

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: 'lesson_plan',
      entityId: entityId,
      payload: payload,
      serverVersion: existing?.serverVersion,
      isDirty: queueForSync,
    );

    if (queueForSync) {
      await _localDatabase.queueMutation(
        tenantId: membership.schoolId,
        membershipId: membership.id,
        entityType: 'lesson_plan',
        entityId: entityId,
        operation:
            existing == null ? SyncOperation.create : SyncOperation.update,
        payload: payload,
        baseVersion: existing?.serverVersion,
      );
    }

    return entityId;
  }

  Future<SavedLessonPlan?> loadDraft(LessonPlanRequest request) async {
    final membership = _schoolSession.requireActiveMembership();
    if (request.schoolId != membership.schoolId) return null;

    final entityId = _entityId(request);
    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: 'lesson_plan',
      entityId: entityId,
    );
    if (record == null) return null;

    final rawDraft = record.payload['draft'];
    if (rawDraft is! Map) return null;

    final savedAtValue = record.payload['savedAt'];
    final savedAt = savedAtValue is String
        ? DateTime.tryParse(savedAtValue)?.toLocal() ?? record.updatedAt.toLocal()
        : record.updatedAt.toLocal();

    return SavedLessonPlan(
      id: entityId,
      request: request,
      draft: LessonPlanDraft.fromJson(rawDraft.cast<String, dynamic>()),
      savedAt: savedAt,
      pendingSync: record.isDirty,
    );
  }

  String _entityId(LessonPlanRequest request) {
    return [
      request.term,
      'week-${request.week}',
      request.className,
      request.subject,
    ].map(_normalize).join(':');
  }
}

String _normalize(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}
