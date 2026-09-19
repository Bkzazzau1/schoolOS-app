import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/service_models.dart';
import 'service_demo_data.dart';

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

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  ServicePermissions permissionsFor(SchoolMembership membership) {
    return ServicePermissions(
      canVerifyRecords: membership.role == SchoolRole.proprietor,
    );
  }

  Future<ServiceSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    var records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );

    if (records.isEmpty) {
      for (final project in serviceWebsiteSeed) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _entityType,
          entityId: project.id,
          payload: project.toJson(),
        );
      }
      records = await _localDatabase.getLocalRecords(
        tenantId: membership.schoolId,
        entityType: _entityType,
      );
    }

    final projects = records
        .map((record) => ServiceProject.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));

    return ServiceSnapshot(
      projects: projects,
      permissions: permissionsFor(membership),
    );
  }

  Future<ServiceActionResult> toggleVerification(String projectId) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canVerifyRecords) {
      return const ServiceActionResult(
        success: false,
        message: 'This membership cannot verify service records.',
      );
    }

    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: projectId,
    );
    if (record == null) {
      return const ServiceActionResult(
        success: false,
        message: 'Service project was not found for this school.',
      );
    }

    final current = ServiceProject.fromJson(record.payload);
    final updated = current.copyWith(verified: !current.verified);

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: updated.id,
      payload: updated.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _entityType,
      entityId: updated.id,
      operation: SyncOperation.update,
      payload: updated.toJson(),
    );

    return ServiceActionResult(
      success: true,
      message: updated.verified
          ? 'Service record verified offline and queued for sync.'
          : 'Service verification reopened and queued for sync.',
    );
  }
}
