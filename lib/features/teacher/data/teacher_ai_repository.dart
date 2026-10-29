import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/teacher_ai_models.dart';
import '../domain/teacher_assessment_models.dart';
import 'teacher_ai_demo_data.dart';
import 'teacher_assessment_repository.dart';
import 'teacher_assignment_repository.dart';
import 'teacher_roster.dart';

class TeacherAiSnapshot {
  const TeacherAiSnapshot({
    required this.history,
    required this.contextOptions,
    required this.permissions,
    this.suggestedActions = const [],
  });

  final List<TeacherAiPromptHistoryItem> history;

  /// The working contexts (class + subject) the teacher may really use, limited to their real assigned classes.
  final List<TeacherAiContext> contextOptions;

  final TeacherAiPermissions permissions;

  /// Real, rules-based flags from this teacher's own assignments and assessments - never a
  /// fabricated or AI-generated claim. Empty, not sample content, when nothing real applies.
  final List<TeacherAiSuggestedAction> suggestedActions;
}

class TeacherAiAskResult {
  const TeacherAiAskResult({
    required this.success,
    required this.response,
    this.historyItem,
  });

  final bool success;
  final String response;
  final TeacherAiPromptHistoryItem? historyItem;
}

class TeacherAiRepository {
  TeacherAiRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required TeacherRoster roster,
    required TeacherAssignmentRepository assignments,
    required TeacherAssessmentRepository assessments,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _roster = roster,
        _assignments = assignments,
        _assessments = assessments;

  static const _historyType = 'teacher_ai_prompt_history';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final TeacherRoster _roster;
  final TeacherAssignmentRepository _assignments;
  final TeacherAssessmentRepository _assessments;

  TeacherAiPermissions permissionsFor(SchoolMembership membership) {
    final teacher = membership.role == SchoolRole.teacher;
    return TeacherAiPermissions(
      canUseAssignedClassContext: teacher,
      canDraftTeachingContent: teacher,
      canSuggestSupport: teacher,
      canRetrieveUnrelatedClasses: false,
      canAccessFinance: false,
      canAccessStaffConfidentialData: false,
      canAccessOtherSchools: false,
      canAlterMarks: false,
      canAlterAttendance: false,
      canSendMessages: false,
      canTakeConsequentialAction: false,
    );
  }

  Future<List<TeacherAiContext>> _contextOptions(SchoolMembership membership) async {
    final classes = await _roster.assignedClasses(membership);
    final classNames = {for (final c in classes) c.className};
    return TeacherAiContext.values.where((context) => classNames.contains(context.className)).toList(growable: false);
  }

  Future<TeacherAiSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    final contextOptions = await _contextOptions(membership);
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _historyType,
    );
    final history = records
        .map((record) => TeacherAiPromptHistoryItem.fromJson(record.payload))
        .where((item) => contextOptions.contains(item.context))
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return TeacherAiSnapshot(
      history: history.take(6).toList(growable: false),
      contextOptions: contextOptions,
      permissions: permissionsFor(membership),
      suggestedActions: membership.role == SchoolRole.teacher ? await _suggestedActions() : const [],
    );
  }

  /// Real flags from this teacher's own real assignments and assessments - pending marking and
  /// incomplete score entry. Never a syllabus-pace or "improving" claim: no reliable real signal
  /// for either exists yet (syllabus "behind" is disabled even on a real backend pending a
  /// decision on trusting server-derived lesson-delivery progress; see memory/docs).
  Future<List<TeacherAiSuggestedAction>> _suggestedActions() async {
    final actions = <TeacherAiSuggestedAction>[];

    final assignments = (await _assignments.load()).assignments;
    for (final assignment in assignments) {
      if (!assignment.serverPublished || assignment.unmarked <= 0) continue;
      actions.add(
        TeacherAiSuggestedAction(
          title: '${assignment.title} · ${assignment.className}',
          description: assignment.unmarked == 1
              ? '1 submission still needs marking.'
              : '${assignment.unmarked} submissions still need marking.',
          destination: 'assignments',
          actionLabel: 'Open assignments',
        ),
      );
    }

    final assessments = (await _assessments.load()).assessments;
    for (final assessment in assessments) {
      if (assessment.state != TeacherAssessmentState.published) continue;
      final remaining = assessment.totalStudents - assessment.entered;
      if (remaining <= 0) continue;
      actions.add(
        TeacherAiSuggestedAction(
          title: '${assessment.title} · ${assessment.className}',
          description: remaining == 1
              ? '1 score still needs entering.'
              : '$remaining scores still need entering.',
          destination: 'assessments',
          actionLabel: 'Open assessments',
        ),
      );
    }

    return actions;
  }

  Future<TeacherAiAskResult> ask({
    required TeacherAiContext context,
    required String prompt,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = permissionsFor(membership);
    final trimmed = prompt.trim();
    if (!permissions.canUseAssignedClassContext ||
        !permissions.canDraftTeachingContent) {
      return const TeacherAiAskResult(
        success: false,
        response: 'This membership cannot use the Teacher AI workspace.',
      );
    }
    if (!(await _contextOptions(membership)).contains(context)) {
      return const TeacherAiAskResult(
        success: false,
        response: 'This working context is not one of your assigned classes.',
      );
    }
    if (trimmed.isEmpty) {
      return const TeacherAiAskResult(
        success: false,
        response: 'Enter a teaching question or choose a suggested prompt.',
      );
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final item = TeacherAiPromptHistoryItem(
      id: 'teacher-ai-${DateTime.now().microsecondsSinceEpoch}',
      prompt: trimmed,
      context: context,
      createdAt: now,
    );
    // Real, teacher-authored prompt history, kept device-only on purpose (never queued for sync). isDirty: true
    // marks it as real, so it is never mistaken for seed data and silently dropped once a real backend connects.
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _historyType,
      entityId: item.id,
      payload: item.toJson(),
      isDirty: true,
    );

    return TeacherAiAskResult(
      success: true,
      response: teacherAiResponseFor(context: context, prompt: trimmed),
      historyItem: item,
    );
  }
}
