import '../../../core/database/local_database.dart';
import '../../../core/tenancy/campus_scope.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/administrator_registration_models.dart';
import '../domain/administrator_lifecycle_models.dart';
import '../domain/administrator_students_models.dart';
import 'administrator_academics_repository.dart' show AdministratorAcademicsRepository;
import 'administrator_lifecycle_effects.dart';
import 'administrator_lifecycle_repository.dart';

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
  static const registrationEntityType = 'student_registration';
  static const _registrationEntityType = registrationEntityType;

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
    // The authoritative directory is derived from server-confirmed canonical registrations
    // plus lifecycle history, below; a demo school starts with no directory rows of its own
    // rather than a fabricated roster.
    final directoryRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );

    final students = directoryRecords
        .map((record) => AdministratorStudentRecord.fromJson(record.payload))
        .toList();

    final registrations = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _registrationEntityType,
    );
    for (final record in registrations) {
      final registration = StudentRegistrationRecord.fromJson(record.payload);
      if (!registration.isActive || registration.studentId.trim().isEmpty) {
        continue;
      }
      if (LocalDatabase.blockDemoSeeds && !registration.isCanonicalActive) {
        // A local Active value can still be queued or rejected. The server-owned
        // canonical marker is returned only after Student + Enrollment creation
        // succeeds, so live directories never present queued activation as fact.
        continue;
      }
      if (students.any((student) => student.id == registration.studentId)) {
        continue;
      }
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

    students.sort((a, b) => a.id.compareTo(b.id));

    final lifecycle = (await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: AdministratorLifecycleRepository.entityType,
    ))
        .map((record) => AdministratorLifecycleRecord.fromJson(record.payload))
        .toList();

    final withLifecycle = applyLifecycle(students, lifecycle);
    final campusScope = await campusScopeFor(_localDatabase, membership);
    final visible = campusScope == null
        ? withLifecycle
        : await _restrictToCampus(membership.schoolId, withLifecycle, campusScope);

    return AdministratorStudentsSnapshot(
      students: visible,
      permissions: permissionsFor(membership),
    );
  }

  /// A real class not yet assigned to any campus is never shown to a campus-scoped membership -
  /// isolation defaults to excluding what has not been confirmed as theirs, not including it.
  Future<List<AdministratorStudentRecord>> _restrictToCampus(
    String schoolId,
    List<AdministratorStudentRecord> students,
    String campusId,
  ) async {
    final classRecords = await _localDatabase.getLocalRecords(
      tenantId: schoolId,
      entityType: AdministratorAcademicsRepository.classEntityType,
    );
    final campusByClassName = <String, String>{};
    for (final record in classRecords) {
      final name = record.payload['name'] as String?;
      final classCampusId = record.payload['campusId'] as String?;
      if (name != null && name.isNotEmpty && classCampusId != null && classCampusId.isNotEmpty) {
        campusByClassName[name] = classCampusId;
      }
    }
    return students.where((student) => campusByClassName[student.className] == campusId).toList(growable: false);
  }
}
