import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/transport_models.dart';
import 'transport_demo_data.dart';

class TransportSnapshot {
  const TransportSnapshot({required this.routes, required this.permissions});

  final List<SchoolTransportRoute> routes;
  final TransportPermissions permissions;
}

class TransportActionResult {
  const TransportActionResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class TransportRepository {
  TransportRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _entityType = 'school_transport_route';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  TransportPermissions permissionsFor(SchoolMembership membership) {
    return TransportPermissions(
      canReviewRoutes: membership.role == SchoolRole.proprietor,
    );
  }

  Future<TransportSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    var records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );

    if (records.isEmpty) {
      for (final route in transportWebsiteSeed) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _entityType,
          entityId: route.id,
          payload: route.toJson(),
        );
      }
      records = await _localDatabase.getLocalRecords(
        tenantId: membership.schoolId,
        entityType: _entityType,
      );
    }

    final routes = records
        .map((record) => SchoolTransportRoute.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));

    return TransportSnapshot(
      routes: routes,
      permissions: permissionsFor(membership),
    );
  }

  Future<TransportActionResult> toggleRouteReview(String routeId) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canReviewRoutes) {
      return const TransportActionResult(
        success: false,
        message: 'This membership cannot review transport routes.',
      );
    }

    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: routeId,
    );
    if (record == null) {
      return const TransportActionResult(
        success: false,
        message: 'Transport route was not found for this school.',
      );
    }

    final current = SchoolTransportRoute.fromJson(record.payload);
    final updated = current.copyWith(reviewed: !current.reviewed);

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

    return TransportActionResult(
      success: true,
      message: updated.reviewed
          ? 'Route review saved offline.'
          : 'Route review reopened and queued for sync.',
    );
  }
}
