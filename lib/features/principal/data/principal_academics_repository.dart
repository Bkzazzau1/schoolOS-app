import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/principal_academics_models.dart';
import 'principal_academics_demo_data.dart';

class PrincipalAcademicsSnapshot {
  const PrincipalAcademicsSnapshot({
    required this.classes,
    required this.subjects,
    required this.risks,
    required this.permissions,
  });

  final List<PrincipalAcademicClass> classes;
  final List<PrincipalSubjectPerformance> subjects;
  final List<PrincipalAcademicRisk> risks;
  final PrincipalAcademicsPermissions permissions;
}

class PrincipalAcademicsRepository {
  PrincipalAcademicsRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _classType = 'principal_academic_class';
  static const _subjectType = 'principal_academic_subject';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  PrincipalAcademicsPermissions permissionsFor(SchoolMembership membership) => PrincipalAcademicsPermissions(
        canViewSecondaryAcademics: membership.role == SchoolRole.principal,
        canLeadSecondaryInterventions: membership.role == SchoolRole.principal,
        canManagePrimary: false,
        canManageEarlyYears: false,
      );

  Future<PrincipalAcademicsSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    await _seedIfNeeded(membership);

    final classRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _classType,
    );
    final subjectRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _subjectType,
    );

    final classes = classRecords
        .map((record) => PrincipalAcademicClass.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => principalAcademicClasses.indexWhere((row) => row.name == a.name)
          .compareTo(principalAcademicClasses.indexWhere((row) => row.name == b.name)));
    final subjects = subjectRecords
        .map((record) => PrincipalSubjectPerformance.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => principalSubjectPerformance.indexWhere((row) => row.name == a.name)
          .compareTo(principalSubjectPerformance.indexWhere((row) => row.name == b.name)));

    return PrincipalAcademicsSnapshot(
      classes: classes,
      subjects: subjects,
      risks: principalAcademicRisks,
      permissions: permissionsFor(membership),
    );
  }

  Future<void> _seedIfNeeded(SchoolMembership membership) async {
    final existingClasses = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _classType,
    );
    if (existingClasses.isEmpty) {
      for (final row in principalAcademicClasses) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _classType,
          entityId: row.name,
          payload: row.toJson(),
        );
      }
    }

    final existingSubjects = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _subjectType,
    );
    if (existingSubjects.isEmpty) {
      for (final row in principalSubjectPerformance) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _subjectType,
          entityId: row.name,
          payload: row.toJson(),
        );
      }
    }
  }
}
