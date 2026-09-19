import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/visitor_models.dart';
import 'visitor_demo_data.dart';

class VisitorSnapshot {
  const VisitorSnapshot({required this.visits, required this.permissions});

  final List<VisitorRecord> visits;
  final VisitorPermissions permissions;
}

class VisitorActionResult {
  const VisitorActionResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class VisitorRepository {
  VisitorRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _entityType = 'visitor_record';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  VisitorPermissions permissionsFor(SchoolMembership membership) {
    return VisitorPermissions(
      canReviewRecords: membership.role == SchoolRole.proprietor,
    );
  }

  Future<VisitorSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    var records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );

    if (records.isEmpty) {
      for (final visit in visitorWebsiteSeed) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _entityType,
          entityId: visit.id,
          payload: visit.toJson(),
        );
      }
      records = await _localDatabase.getLocalRecords(
        tenantId: membership.schoolId,
        entityType: _entityType,
      );
    }

    final visits = records
        .map((record) => VisitorRecord.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));

    return VisitorSnapshot(
      visits: visits,
      permissions: permissionsFor(membership),
    );
  }

  Future<VisitorActionResult> toggleRecordReview(String visitId) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canReviewRecords) {
      return const VisitorActionResult(
        success: false,
        message: 'This membership cannot review visitor records.',
      );
    }

    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: visitId,
    );
    if (record == null) {
      return const VisitorActionResult(
        success: false,
        message: 'Visitor record was not found for this school.',
      );
    }

    final current = VisitorRecord.fromJson(record.payload);
    final updated = current.copyWith(
      frontDeskReviewed: !current.frontDeskReviewed,
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

    return VisitorActionResult(
      success: true,
      message: updated.frontDeskReviewed
          ? 'Front-desk review saved offline.'
          : 'Front-desk review reopened and queued for sync.',
    );
  }
}
