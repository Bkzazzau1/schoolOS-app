import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/teacher_ai_models.dart';
import 'teacher_ai_demo_data.dart';

class TeacherAiSnapshot {
  const TeacherAiSnapshot({
    required this.history,
    required this.permissions,
  });

  final List<TeacherAiPromptHistoryItem> history;
  final TeacherAiPermissions permissions;
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
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _historyType = 'teacher_ai_prompt_history';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

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

  Future<TeacherAiSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    await _seedIfNeeded(membership);
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _historyType,
    );
    final history = records
        .map((record) => TeacherAiPromptHistoryItem.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return TeacherAiSnapshot(
      history: history.take(6).toList(growable: false),
      permissions: permissionsFor(membership),
    );
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
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _historyType,
      entityId: item.id,
      payload: item.toJson(),
    );

    return TeacherAiAskResult(
      success: true,
      response: teacherAiResponseFor(context: context, prompt: trimmed),
      historyItem: item,
    );
  }

  Future<void> _seedIfNeeded(SchoolMembership membership) async {
    final existing = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _historyType,
    );
    if (existing.isNotEmpty) return;
    for (final item in teacherAiInitialHistory) {
      await _localDatabase.upsertLocalRecord(
        tenantId: membership.schoolId,
        entityType: _historyType,
        entityId: item.id,
        payload: item.toJson(),
      );
    }
  }
}
