import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../proprietor/data/owner_staff_profile_repository.dart';
import '../../proprietor/domain/owner_staff_profile_models.dart';
import '../domain/teacher_attendance_models.dart';
import '../domain/teacher_lesson_plan_models.dart';
import '../domain/teacher_performance_models.dart';
import 'teacher_assessment_repository.dart';
import 'teacher_attendance_repository.dart';
import 'teacher_lesson_plan_repository.dart';
import 'teacher_roster.dart';
import 'teacher_syllabus_repository.dart';

class TeacherPerformanceSnapshot {
  const TeacherPerformanceSnapshot({
    required this.metrics,
    required this.classPerformance,
    required this.developmentLog,
    required this.reflections,
    required this.permissions,
    required this.overallScore,
    this.focusMetric,
  });

  final List<TeacherPerformanceMetric> metrics;
  final List<TeacherClassPerformance> classPerformance;
  final List<TeacherDevelopmentLogItem> developmentLog;
  final List<TeacherPrivateReflection> reflections;
  final TeacherPerformancePermissions permissions;

  /// A transparent average of [metrics] - never an opaque scoring algorithm.
  final int overallScore;

  /// The one real metric furthest below its own target, if any are below target.
  final TeacherPerformanceMetric? focusMetric;

  String get scoreLabel => switch (overallScore) {
        >= 90 => 'Excellent',
        >= 75 => 'Good',
        >= 60 => 'Needs attention',
        _ => 'Needs support',
      };
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

/// Every number here is computed from the same real records every other Teacher screen
/// already produces - real attendance registers, real lesson plans, real assessments, real
/// syllabus coverage, real leadership reviews - never a fixed coaching narrative.
class TeacherPerformanceRepository implements TeacherPerformanceDataSource {
  TeacherPerformanceRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required TeacherRoster roster,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _roster = roster,
        _attendance = TeacherAttendanceRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
          roster: roster,
        ),
        _assessments = TeacherAssessmentRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
          roster: roster,
        ),
        _lessonPlans = TeacherLessonPlanRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
          roster: roster,
        ),
        _syllabus = TeacherSyllabusRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
          roster: roster,
        );

  static const _reflectionType = 'teacher_performance_private_reflection';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final TeacherRoster _roster;
  final TeacherAttendanceRepository _attendance;
  final TeacherAssessmentRepository _assessments;
  final TeacherLessonPlanRepository _lessonPlans;
  final TeacherSyllabusRepository _syllabus;

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

    final assignedNames = {for (final c in await _roster.assignedClasses(membership)) c.className};

    final attendanceSnapshot = await _attendance.load();
    final registers = attendanceSnapshot.registers;
    final submittedRegisters = registers
        .where((r) => r.submissionState != TeacherAttendanceSubmissionState.draft)
        .length;
    final attendanceCompletion =
        registers.isEmpty ? 0 : (submittedRegisters * 100 / registers.length).round();
    final attendanceByClass = {for (final r in registers) r.lesson.className: r.presentPercent};

    final lessonPlanSnapshot = await _lessonPlans.load();
    final relevantPlans =
        lessonPlanSnapshot.plans.where((p) => assignedNames.contains(p.className)).toList();
    final advancedPlans =
        relevantPlans.where((p) => p.status != TeacherLessonPlanStatus.draft).length;
    final lessonPlanCompliance =
        relevantPlans.isEmpty ? 0 : (advancedPlans * 100 / relevantPlans.length).round();

    final assessmentSnapshot = await _assessments.load();
    final relevantAssessments = assessmentSnapshot.assessments
        .where((a) => assignedNames.contains(a.className))
        .toList();
    final entryRatios = [
      for (final a in relevantAssessments)
        if (a.totalStudents > 0) a.entered / a.totalStudents,
    ];
    final assessmentCompletion = entryRatios.isEmpty
        ? 0
        : (entryRatios.reduce((a, b) => a + b) / entryRatios.length * 100).round();
    final averagesByClass = <String, List<double>>{};
    for (final a in relevantAssessments) {
      if (a.averagePercent != null) {
        averagesByClass.putIfAbsent(a.className, () => []).add(a.averagePercent!);
      }
    }

    final syllabusSnapshot = await _syllabus.load();
    final syllabusPaceByClass = {
      for (final name in assignedNames) name: syllabusSnapshot.coverageOf(name),
    };
    final syllabusPace = syllabusPaceByClass.isEmpty
        ? 0
        : (syllabusPaceByClass.values.reduce((a, b) => a + b) / syllabusPaceByClass.length)
            .round();

    final metrics = [
      TeacherPerformanceMetric(
        label: 'Attendance completion',
        value: attendanceCompletion,
        target: 95,
        note: '$submittedRegisters of ${registers.length} registers submitted',
      ),
      TeacherPerformanceMetric(
        label: 'Lesson-plan compliance',
        value: lessonPlanCompliance,
        target: 90,
        note: '$advancedPlans of ${relevantPlans.length} plans submitted or further along',
      ),
      TeacherPerformanceMetric(
        label: 'Assessment completion',
        value: assessmentCompletion,
        target: 90,
        note: relevantAssessments.isEmpty
            ? 'No assessment recorded for an assigned class yet'
            : 'Average score-entry completion across ${relevantAssessments.length} real assessments',
      ),
      TeacherPerformanceMetric(
        label: 'Syllabus pace',
        value: syllabusPace,
        target: 75,
        note: assignedNames.isEmpty
            ? 'No assigned class yet'
            : 'Average topic coverage across assigned classes',
      ),
    ];

    final classPerformance = [
      for (final name in assignedNames)
        TeacherClassPerformance(
          name: name,
          average: averagesByClass[name] == null || averagesByClass[name]!.isEmpty
              ? 0
              : (averagesByClass[name]!.reduce((a, b) => a + b) / averagesByClass[name]!.length)
                  .round(),
          attendance: attendanceByClass[name] ?? 0,
          syllabusPace: syllabusPaceByClass[name] ?? 0,
        ),
    ]..sort((a, b) => a.name.compareTo(b.name));

    final overallScore = (metrics.fold<int>(0, (sum, m) => sum + m.value) / metrics.length).round();
    TeacherPerformanceMetric? focusMetric;
    for (final metric in metrics) {
      if (!metric.isAtOrAboveTarget &&
          (focusMetric == null || metric.gapToTarget > focusMetric.gapToTarget)) {
        focusMetric = metric;
      }
    }

    return TeacherPerformanceSnapshot(
      metrics: metrics,
      classPerformance: classPerformance,
      developmentLog: await _developmentLog(membership),
      reflections: reflections,
      permissions: permissionsFor(membership),
      overallScore: overallScore,
      focusMetric: focusMetric,
    );
  }

  Future<List<TeacherDevelopmentLogItem>> _developmentLog(SchoolMembership membership) async {
    final profile = await _linkedStaffProfile(membership);
    if (profile == null) return const [];
    final reviews = [...profile.reviews]..sort((a, b) => b.at.compareTo(a.at));
    return [
      for (final review in reviews)
        TeacherDevelopmentLogItem(
          title: '${review.period} · Rating ${review.rating}/5',
          detail: review.notes,
        ),
    ];
  }

  Future<StaffProfile?> _linkedStaffProfile(SchoolMembership membership) async {
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: OwnerStaffProfileRepository.entityType,
    );
    for (final record in records) {
      final profile = StaffProfile.fromJson(record.payload);
      if (profile.linkedMembershipId == membership.id) return profile;
    }
    return null;
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
