import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/service_models.dart';

class ServiceSnapshot {
  const ServiceSnapshot({required this.projects, required this.permissions});

  final List<ServiceProject> projects;
  final ServicePermissions permissions;
}

class ServiceActionResult {
  const ServiceActionResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class ServiceRepository {
  ServiceRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _entityType = 'service_project';

  // Mirrors apps.schoollife.specs.programmes.SERVICE exactly: manage=MANAGERS, contribute={"teacher"},
  // but the guarded "verified" field is narrower still - LEADERS only (proprietor, principal - never
  // administrator).
  static const _managers = {SchoolRole.proprietor, SchoolRole.principal, SchoolRole.administrator};
  static const _contributors = {SchoolRole.teacher};
  static const _leaders = {SchoolRole.proprietor, SchoolRole.principal};

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  ServicePermissions permissionsFor(SchoolMembership membership) {
    final isManager = _managers.contains(membership.role);
    return ServicePermissions(
      canCreate: isManager || _contributors.contains(membership.role),
      canManageAll: isManager,
      canVerifyRecords: _leaders.contains(membership.role),
    );
  }

  Future<ServiceSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );

    final projects = records
        .map((record) => ServiceProject.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));

    return ServiceSnapshot(
      projects: projects,
      permissions: permissionsFor(membership),
    );
  }

  Future<ServiceActionResult> create({
    required String title,
    required String type,
    required String audience,
    required String coordinator,
    required String date,
    required ServiceProjectStatus status,
    required String beneficiary,
    required String note,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canCreate) {
      return const ServiceActionResult(
        success: false,
        message: 'This membership cannot add a service project.',
      );
    }
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      return const ServiceActionResult(success: false, message: 'Enter a project title.');
    }

    final now = DateTime.now().toUtc();
    final project = ServiceProject(
      id: 'SV-${now.microsecondsSinceEpoch}',
      title: cleanTitle,
      type: type.trim(),
      audience: audience.trim(),
      coordinator: coordinator.trim(),
      date: date.trim(),
      participants: 0,
      hours: 0,
      status: status,
      beneficiary: beneficiary.trim(),
      note: note.trim(),
    );
    await _save(project, SyncOperation.create);
    return const ServiceActionResult(success: true, message: 'Project added and queued for sync.');
  }

  Future<ServiceActionResult> edit({
    required String id,
    required String type,
    required String audience,
    required String coordinator,
    required String date,
    required int participants,
    required int hours,
    required ServiceProjectStatus status,
    required String beneficiary,
    required String note,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canManageAll) {
      return const ServiceActionResult(
        success: false,
        message: 'This membership cannot edit a service project.',
      );
    }
    final current = await _requireProject(id);
    final updated = current.copyWith(
      type: type.trim(),
      audience: audience.trim(),
      coordinator: coordinator.trim(),
      date: date.trim(),
      participants: participants < 0 ? 0 : participants,
      hours: hours < 0 ? 0 : hours,
      status: status,
      beneficiary: beneficiary.trim(),
      note: note.trim(),
    );
    await _save(updated, SyncOperation.update);
    return const ServiceActionResult(success: true, message: 'Project update saved and queued for sync.');
  }

  Future<ServiceActionResult> toggleVerification(String projectId) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canVerifyRecords) {
      return const ServiceActionResult(
        success: false,
        message: 'This membership cannot verify service records.',
      );
    }

    final current = await _requireProject(projectId);
    final updated = current.copyWith(verified: !current.verified);
    await _save(updated, SyncOperation.update);

    return ServiceActionResult(
      success: true,
      message: updated.verified
          ? 'Service record verified offline and queued for sync.'
          : 'Service verification reopened and queued for sync.',
    );
  }

  Future<ServiceProject> _requireProject(String id) async {
    final membership = _schoolSession.requireActiveMembership();
    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: id,
    );
    if (record == null) {
      throw StateError('Service project $id was not found for this school.');
    }
    return ServiceProject.fromJson(record.payload);
  }

  Future<void> _save(ServiceProject project, SyncOperation operation) async {
    final membership = _schoolSession.requireActiveMembership();
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: project.id,
      payload: project.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _entityType,
      entityId: project.id,
      operation: operation,
      payload: project.toJson(),
    );
  }
}
