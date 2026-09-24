import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../proprietor/data/owner_staff_profile_repository.dart';
import '../domain/class_teacher_models.dart';

class PrincipalClassTeacherPermissions {
  const PrincipalClassTeacherPermissions({required this.canManage});
  final bool canManage;
}

class PrincipalClassTeachersSnapshot {
  const PrincipalClassTeachersSnapshot({
    required this.assignments,
    required this.classOptions,
    required this.teachers,
    required this.activeSessionId,
    required this.activeSessionName,
    required this.permissions,
  });

  final List<ClassTeacherAssignment> assignments;

  /// classId -> className, Secondary only (this Principal's scope).
  final Map<String, String> classOptions;
  final List<({String id, String name})> teachers;
  final String activeSessionId;
  final String activeSessionName;
  final PrincipalClassTeacherPermissions permissions;

  ClassTeacherAssignment? forClass(String classId) {
    for (final item in assignments) {
      if (item.classId == classId && item.sessionId == activeSessionId) return item;
    }
    return null;
  }
}

class PrincipalClassTeacherActionResult {
  const PrincipalClassTeacherActionResult({required this.success, required this.message});
  final bool success;
  final String message;
}

/// A class/form teacher is a whole-class staffing decision, so its write
/// authority mirrors Principal Teaching Assignment exactly: Principal,
/// Secondary only (Proprietor's school-wide equivalent is a separate,
/// not-yet-built screen, matching how Proprietor already manages Teaching
/// Assignments outside this Principal-scoped repository).
class PrincipalClassTeachersRepository {
  PrincipalClassTeachersRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required OwnerStaffProfileRepository staff,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _staff = staff;

  static const _assignmentType = classTeacherAssignmentEntityType;
  static const _sessionType = 'academic_session';
  static const _classType = 'academic_class';
  static const _staffProfileType = 'owner_staff_profile';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final OwnerStaffProfileRepository _staff;

  PrincipalClassTeacherPermissions permissionsFor(SchoolMembership membership) =>
      PrincipalClassTeacherPermissions(canManage: membership.role == SchoolRole.principal);

  Future<PrincipalClassTeachersSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = permissionsFor(membership);
    final session = await _activeSession(membership);
    final classOptions = await _secondaryClassNames(membership);

    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _assignmentType,
    );
    final assignments = records
        .map((r) => ClassTeacherAssignment.fromJson(r.payload))
        .where((item) => item.isActive && classOptions.containsKey(item.classId))
        .toList(growable: false)
      ..sort((a, b) => a.className.compareTo(b.className));

    final teachers = permissions.canManage ? await _secondaryTeachers(membership) : const <({String id, String name})>[];

    return PrincipalClassTeachersSnapshot(
      assignments: assignments,
      classOptions: classOptions,
      teachers: teachers,
      activeSessionId: session.$1,
      activeSessionName: session.$2,
      permissions: permissions,
    );
  }

  Future<PrincipalClassTeacherActionResult> assign({
    required String classId,
    required String className,
    required String section,
    required String sessionId,
    required String sessionName,
    required String teacherId,
    required String teacherName,
    String handoverReason = '',
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canManage) {
      return const PrincipalClassTeacherActionResult(
        success: false,
        message: 'This membership cannot assign a class teacher.',
      );
    }
    if (!LocalDatabase.blockDemoSeeds) {
      return const PrincipalClassTeacherActionResult(
        success: false,
        message: 'Assigning a class teacher is a canonical server workflow in connected mode.',
      );
    }
    if (classId.isEmpty || sessionId.isEmpty || teacherId.isEmpty) {
      return const PrincipalClassTeacherActionResult(success: false, message: 'Choose a class and a teacher.');
    }
    final entityId = 'clsteach-$classId-$sessionId';
    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _assignmentType,
      entityId: entityId,
    );
    final draft = ClassTeacherAssignment(
      id: entityId,
      classId: classId,
      className: className,
      section: section,
      sessionId: sessionId,
      session: sessionName,
      teacherId: teacherId,
      teacherName: teacherName,
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _assignmentType,
      entityId: entityId,
      payload: draft.toJson(),
      serverVersion: existing?.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _assignmentType,
      entityId: entityId,
      operation: existing == null ? SyncOperation.create : SyncOperation.update,
      payload: draft.toMutationJson(handoverReason: handoverReason),
      baseVersion: existing?.isDirty == true ? null : existing?.serverVersion,
    );
    return const PrincipalClassTeacherActionResult(
      success: true,
      message: 'Class-teacher assignment queued for synchronization.',
    );
  }

  Future<(String, String)> _activeSession(SchoolMembership membership) async {
    final records = await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: _sessionType);
    for (final record in records) {
      if (record.payload['status'] == 'active') {
        final id = record.payload['id'] as String? ?? record.entityId;
        final name = record.payload['name'] as String? ?? '';
        return (id, name);
      }
    }
    return ('', '');
  }

  Future<Map<String, String>> _secondaryClassNames(SchoolMembership membership) async {
    final records = await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: _classType);
    final result = <String, String>{};
    for (final record in records) {
      final payload = record.payload;
      if (payload['isActive'] != true) continue;
      if ((payload['section'] as String? ?? '').trim().toLowerCase() != 'secondary') continue;
      final id = payload['id'] as String? ?? record.entityId;
      final name = payload['name'] as String? ?? '';
      if (id.isNotEmpty && name.isNotEmpty) result[id] = name;
    }
    return result;
  }

  Future<List<({String id, String name})>> _secondaryTeachers(SchoolMembership membership) async {
    final all = await _staff.people();
    final teachers = <({String id, String name})>[];
    for (final person in all) {
      if (person.section != 'Secondary' || !person.role.toLowerCase().contains('teacher')) continue;
      final profile = await _localDatabase.getLocalRecord(
        tenantId: membership.schoolId,
        entityType: _staffProfileType,
        entityId: person.id,
      );
      final linkedMembershipId = profile?.payload['linkedMembershipId'] as String? ?? '';
      final systemRole = profile?.payload['systemRole'] as String? ?? '';
      if (linkedMembershipId.isEmpty || systemRole != 'teacher') continue;
      teachers.add((id: linkedMembershipId, name: person.name));
    }
    teachers.sort((a, b) => a.name.compareTo(b.name));
    return teachers;
  }
}
