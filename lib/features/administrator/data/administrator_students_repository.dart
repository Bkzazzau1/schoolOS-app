import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/administrator_registration_models.dart';
import '../domain/administrator_students_models.dart';
import 'administrator_students_demo_data.dart';

class AdministratorStudentsSnapshot {
  const AdministratorStudentsSnapshot({
    required this.students,
    required this.permissions,
  });

  final List<AdministratorStudentRecord> students;
  final AdministratorStudentsPermissions permissions;
}

class AdministratorStudentsRepository {
  AdministratorStudentsRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _entityType = 'administrator_student_directory';
  static const _registrationEntityType = 'student_registration';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  AdministratorStudentsPermissions permissionsFor(SchoolMembership membership) {
    final allowed = membership.role == SchoolRole.administrator;
    return AdministratorStudentsPermissions(
      canViewDirectory: allowed,
      canOpenOperationalSummary: allowed,
    );
  }

  Future<AdministratorStudentsSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    var records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );

    if (records.isEmpty) {
      for (final student in administratorStudentsWebsiteSeed) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _entityType,
          entityId: student.id,
          payload: student.toJson(),
        );
      }
      records = await _localDatabase.getLocalRecords(
        tenantId: membership.schoolId,
        entityType: _entityType,
      );
    }

    final students = records
        .map((record) => AdministratorStudentRecord.fromJson(record.payload))
        .toList();

    final registrations = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _registrationEntityType,
    );
    for (final record in registrations) {
      final registration = StudentRegistrationRecord.fromJson(record.payload);
      if (!registration.isActive || registration.studentId.trim().isEmpty) continue;
      if (students.any((student) => student.id == registration.studentId)) continue;
      students.add(
        AdministratorStudentRecord(
          id: registration.studentId,
          name: registration.fullName,
          className: registration.proposedClass,
          primaryGuardian: registration.primaryGuardian,
          status: AdministratorStudentStatus.active,
        ),
      );
    }

    final websiteOrder = <String, int>{
      for (var i = 0; i < administratorStudentsWebsiteSeed.length; i++)
        administratorStudentsWebsiteSeed[i].id: i,
    };
    students.sort((a, b) {
      final aOrder = websiteOrder[a.id];
      final bOrder = websiteOrder[b.id];
      if (aOrder != null && bOrder != null) return aOrder.compareTo(bOrder);
      if (aOrder != null) return -1;
      if (bOrder != null) return 1;
      return a.id.compareTo(b.id);
    });

    return AdministratorStudentsSnapshot(
      students: students,
      permissions: permissionsFor(membership),
    );
  }
}
