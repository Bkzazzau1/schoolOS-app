import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/excursion_models.dart';
import 'excursion_demo_data.dart';

class ExcursionSnapshot {
  const ExcursionSnapshot({required this.trips, required this.permissions});

  final List<SchoolTrip> trips;
  final ExcursionPermissions permissions;
}

class ExcursionActionResult {
  const ExcursionActionResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class ExcursionRepository {
  ExcursionRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _entityType = 'school_excursion';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  ExcursionPermissions permissionsFor(SchoolMembership membership) {
    return ExcursionPermissions(
      canReviewReadiness: membership.role == SchoolRole.proprietor,
    );
  }

  Future<ExcursionSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    var records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );

    if (records.isEmpty) {
      for (final trip in excursionWebsiteSeed) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _entityType,
          entityId: trip.id,
          payload: trip.toJson(),
        );
      }
      records = await _localDatabase.getLocalRecords(
        tenantId: membership.schoolId,
        entityType: _entityType,
      );
    }

    final trips = records
        .map((record) => SchoolTrip.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));

    return ExcursionSnapshot(
      trips: trips,
      permissions: permissionsFor(membership),
    );
  }

  Future<ExcursionActionResult> toggleReadinessReview(String tripId) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canReviewReadiness) {
      return const ExcursionActionResult(
        success: false,
        message: 'This membership cannot review excursion readiness.',
      );
    }

    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: tripId,
    );
    if (record == null) {
      return const ExcursionActionResult(
        success: false,
        message: 'Trip was not found for this school.',
      );
    }

    final current = SchoolTrip.fromJson(record.payload);
    final updated = current.copyWith(
      readinessReviewed: !current.readinessReviewed,
    );

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

    return ExcursionActionResult(
      success: true,
      message: updated.readinessReviewed
          ? 'Readiness review saved offline.'
          : 'Readiness review reopened and queued for sync.',
    );
  }
}
