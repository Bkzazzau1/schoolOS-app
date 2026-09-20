import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/teacher_lesson_plan_models.dart';
import 'teacher_lesson_plan_demo_data.dart';

class TeacherLessonPlanSnapshot {
  const TeacherLessonPlanSnapshot({
    required this.plans,
    required this.events,
    required this.permissions,
  });

  final List<TeacherLessonPlan> plans;
  final List<TeacherLessonPlanEvent> events;
  final TeacherLessonPlanPermissions permissions;
}

class TeacherLessonPlanActionResult {
  const TeacherLessonPlanActionResult({
    required this.success,
    required this.message,
    this.plan,
  });

  final bool success;
  final String message;
  final TeacherLessonPlan? plan;
}

class TeacherLessonPlanRepository {
  TeacherLessonPlanRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _planType = 'teacher_lesson_plan';
  static const _eventType = 'teacher_lesson_plan_event';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  TeacherLessonPlanPermissions permissionsFor(SchoolMembership membership) {
    final isTeacher = membership.role == SchoolRole.teacher;
    return TeacherLessonPlanPermissions(
      canViewAssignedPlans: isTeacher,
      canEditDrafts: isTeacher,
      canSubmitForApproval: isTeacher,
      canApprovePlans: false,
      canOverrideReviewerStatus: false,
    );
  }

  Future<TeacherLessonPlanSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    await _seedIfNeeded(membership);

    final planRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _planType,
    );
    final eventRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _eventType,
    );

    final plans = planRecords
        .map((record) => TeacherLessonPlan.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => _planOrder(a.id).compareTo(_planOrder(b.id)));
    final events = eventRecords
        .map((record) => TeacherLessonPlanEvent.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    return TeacherLessonPlanSnapshot(
      plans: plans,
      events: events,
      permissions: permissionsFor(membership),
    );
  }

  Future<TeacherLessonPlanActionResult> saveDraft({
    required TeacherLessonPlan plan,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = permissionsFor(membership);
    if (!permissions.canEditDrafts) {
      return const TeacherLessonPlanActionResult(
        success: false,
        message: 'This membership cannot edit Teacher lesson plans.',
      );
    }

    final existingRecord = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _planType,
      entityId: plan.id,
    );
    if (existingRecord == null) {
      return const TeacherLessonPlanActionResult(
        success: false,
        message: 'Lesson plan not found in the assigned Teacher workspace.',
      );
    }

    final existing = TeacherLessonPlan.fromJson(existingRecord.payload);
    if (!existing.teacherEditable) {
      return TeacherLessonPlanActionResult(
        success: false,
        message: '${teacherLessonPlanStatusLabel(existing.status)} plans are locked for teacher editing until reviewer action.',
      );
    }

    final next = plan.copyWith(
      status: existing.status == TeacherLessonPlanStatus.needsChanges
          ? TeacherLessonPlanStatus.needsChanges
          : TeacherLessonPlanStatus.draft,
      updatedLabel: 'Draft saved · sync pending',
      version: existing.version + 1,
    );
    await _writePlanAndEvent(
      membership: membership,
      plan: next,
      action: TeacherLessonPlanEventAction.savedDraft,
    );

    return TeacherLessonPlanActionResult(
      success: true,
      message: 'Draft saved locally and queued for synchronization.',
      plan: next,
    );
  }

  Future<TeacherLessonPlanActionResult> submit({
    required TeacherLessonPlan plan,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = permissionsFor(membership);
    if (!permissions.canSubmitForApproval) {
      return const TeacherLessonPlanActionResult(
        success: false,
        message: 'This membership cannot submit Teacher lesson plans.',
      );
    }

    final existingRecord = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _planType,
      entityId: plan.id,
    );
    if (existingRecord == null) {
      return const TeacherLessonPlanActionResult(
        success: false,
        message: 'Lesson plan not found in the assigned Teacher workspace.',
      );
    }
    final existing = TeacherLessonPlan.fromJson(existingRecord.payload);
    if (!existing.teacherEditable) {
      return TeacherLessonPlanActionResult(
        success: false,
        message: '${teacherLessonPlanStatusLabel(existing.status)} plans cannot be resubmitted until reviewer action.',
      );
    }

    if (plan.objectives.trim().isEmpty ||
        plan.activities.trim().isEmpty ||
        plan.assessment.trim().isEmpty) {
      return const TeacherLessonPlanActionResult(
        success: false,
        message: 'Add learning objectives, teaching activities and assessment evidence before submission.',
      );
    }

    final next = plan.copyWith(
      status: TeacherLessonPlanStatus.submitted,
      updatedLabel: 'Submitted · sync pending',
      version: existing.version + 1,
    );
    await _writePlanAndEvent(
      membership: membership,
      plan: next,
      action: TeacherLessonPlanEventAction.submitted,
    );

    return TeacherLessonPlanActionResult(
      success: true,
      message: 'Plan submitted locally and queued for approval review. This is not an approval.',
      plan: next,
    );
  }

  Future<void> _writePlanAndEvent({
    required SchoolMembership membership,
    required TeacherLessonPlan plan,
    required TeacherLessonPlanEventAction action,
  }) async {
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _planType,
      entityId: plan.id,
      payload: plan.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _planType,
      entityId: plan.id,
      operation: SyncOperation.update,
      payload: plan.toJson(),
    );

    final now = DateTime.now().toUtc().toIso8601String();
    final event = TeacherLessonPlanEvent(
      id: '${plan.id}-${action.name}-${DateTime.now().microsecondsSinceEpoch}',
      planId: plan.id,
      action: action,
      actorMembershipId: membership.id,
      version: plan.version,
      occurredAt: now,
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _eventType,
      entityId: event.id,
      payload: event.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _eventType,
      entityId: event.id,
      operation: SyncOperation.create,
      payload: event.toJson(),
    );
  }

  Future<void> _seedIfNeeded(SchoolMembership membership) async {
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _planType,
    );
    if (records.isNotEmpty) return;
    for (final plan in teacherLessonPlans) {
      await _localDatabase.upsertLocalRecord(
        tenantId: membership.schoolId,
        entityType: _planType,
        entityId: plan.id,
        payload: plan.toJson(),
      );
    }
  }

  int _planOrder(String id) {
    final index = teacherLessonPlans.indexWhere((plan) => plan.id == id);
    return index < 0 ? teacherLessonPlans.length : index;
  }
}
