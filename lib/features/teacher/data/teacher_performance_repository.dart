import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/teacher_performance_models.dart';
import 'teacher_performance_demo_data.dart';
import 'teacher_roster.dart';

class TeacherPerformanceSnapshot {
  const TeacherPerformanceSnapshot({
    required this.metrics,
    required this.classPerformance,
    required this.developmentLog,
    required this.reflections,
    required this.permissions,
  });

  final List<TeacherPerformanceMetric> metrics;
  final List<TeacherClassPerformance> classPerformance;
  final List<TeacherDevelopmentLogItem> developmentLog;
  final List<TeacherPrivateReflection> reflections;
  final TeacherPerformancePermissions permissions;
}

class TeacherPerformanceActionResult {
  const TeacherPerformanceActionResult({
    required this.success,
    required this.message,
    this.reflection,
  });

  final bool success;
  final String message;
  final TeacherPrivateReflection? reflection;
}

abstract interface class TeacherPerformanceDataSource {
  TeacherPerformancePermissions permissionsFor(SchoolMembership membership);
  Future<TeacherPerformanceSnapshot> load();
  Future<TeacherPerformanceActionResult> addPrivateReflection(String body);
}

class TeacherPerformanceRepository implements TeacherPerformanceDataSource {
  TeacherPerformanceRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required TeacherRoster roster,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _roster = roster;

  static const _reflectionType = 'teacher_performance_private_reflection';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final TeacherRoster _roster;

  @override
  TeacherPerformancePermissions permissionsFor(SchoolMembership membership) {
    final teacher = membership.role == SchoolRole.teacher;
    return TeacherPerformancePermissions(
      canViewOwnPerformance: teacher,
      canAddPrivateReflection: teacher,
      canViewOtherTeachersPerformance: false,
      canAutomaticallyDiscipline: false,
      canAutomaticallyReward: false,
      canTreatClassOutcomesAsSoleCausation: false,
    );
  }

  @override
  Future<TeacherPerformanceSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    final reflectionRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _reflectionType,
    );
    final reflections = reflectionRecords
        .map((record) => TeacherPrivateReflection.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final assigned = {for (final c in await _roster.assignedClasses(membership)) c.className};
    final classPerformance = teacherClassPerformance.where((item) => assigned.contains(item.name)).toList(growable: false);

    return TeacherPerformanceSnapshot(
      metrics: teacherPerformanceMetrics,
      classPerformance: classPerformance,
      developmentLog: teacherDevelopmentLog,
      reflections: reflections,
      permissions: permissionsFor(membership),
    );
  }

  @override
  Future<TeacherPerformanceActionResult> addPrivateReflection(String body) async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = permissionsFor(membership);
    if (!permissions.canAddPrivateReflection) {
      return const TeacherPerformanceActionResult(
        success: false,
        message: 'This membership cannot add a Teacher performance reflection.',
      );
    }

    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return const TeacherPerformanceActionResult(
        success: false,
        message: 'Write a reflection before saving.',
      );
    }

    final now = DateTime.now().toUtc();
    final reflection = TeacherPrivateReflection(
      id: 'reflection-${now.microsecondsSinceEpoch}',
      body: trimmed,
      createdAt: now.toIso8601String(),
    );
    // This is real teacher-authored data, kept device-only on purpose (never queued for sync). isDirty: true
    // marks it as real, so the demo-seed block (LocalDatabase.blockDemoSeeds) never silently discards it once
    // a real backend is configured; it just never gets pushed anywhere, which is the intended behavior here.
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _reflectionType,
      entityId: reflection.id,
      payload: reflection.toJson(),
      isDirty: true,
    );

    return TeacherPerformanceActionResult(
      success: true,
      message: 'Private reflection saved on this device. It was not sent to leadership or added to the sync queue.',
      reflection: reflection,
    );
  }
}
