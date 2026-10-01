import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/visitor_models.dart';

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

  // Mirrors apps.schoollife.specs.campus.VISITORS exactly: manage=MANAGERS, contribute={"staff"} -
  // the front desk logs a visitor, a manager may add or change any of them. The guarded
  // frontDeskReviewed field is MANAGERS too, same as manage itself here (unlike Boarding/Service,
  // whose guarded fields are the narrower LEADERS).
  static const _managers = {SchoolRole.proprietor, SchoolRole.principal, SchoolRole.administrator};
  static const _contributors = {SchoolRole.staff};

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  VisitorPermissions permissionsFor(SchoolMembership membership) {
    final isManager = _managers.contains(membership.role);
    return VisitorPermissions(
      canCreate: isManager || _contributors.contains(membership.role),
      canManageAll: isManager,
      canReviewRecords: isManager,
    );
  }

  Future<VisitorSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );

    final visits = records
        .map((record) => VisitorRecord.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));

    return VisitorSnapshot(
      visits: visits,
      permissions: permissionsFor(membership),
    );
  }

  Future<VisitorActionResult> create({
    required String visitor,
    required String organization,
    required String purpose,
    required String host,
    required String area,
    required String arrival,
    required VisitStatus status,
    required String pass,
    required String note,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canCreate) {
      return const VisitorActionResult(
        success: false,
        message: 'This membership cannot log a visitor.',
      );
    }
    final cleanVisitor = visitor.trim();
    if (cleanVisitor.isEmpty) {
      return const VisitorActionResult(success: false, message: 'Enter the visitor\'s name.');
    }

    final now = DateTime.now().toUtc();
    final record = VisitorRecord(
      id: 'VIS-${now.microsecondsSinceEpoch}',
      visitor: cleanVisitor,
      organization: organization.trim(),
      purpose: purpose.trim(),
      host: host.trim(),
      area: area.trim(),
      arrival: arrival.trim(),
      departure: '—',
      status: status,
      pass: pass.trim(),
      note: note.trim(),
    );
    await _save(record, SyncOperation.create);
    return const VisitorActionResult(success: true, message: 'Visitor logged and queued for sync.');
  }

  Future<VisitorActionResult> edit({
    required String id,
    required String organization,
    required String purpose,
    required String host,
    required String area,
    required String arrival,
    required String departure,
    required VisitStatus status,
    required String pass,
    required String note,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canManageAll) {
      return const VisitorActionResult(
        success: false,
        message: 'This membership cannot edit a visitor record.',
      );
    }
    final current = await _requireRecord(id);
    final updated = current.copyWith(
      organization: organization.trim(),
      purpose: purpose.trim(),
      host: host.trim(),
      area: area.trim(),
      arrival: arrival.trim(),
      departure: departure.trim(),
      status: status,
      pass: pass.trim(),
      note: note.trim(),
    );
    await _save(updated, SyncOperation.update);
    return const VisitorActionResult(success: true, message: 'Visitor record update saved and queued for sync.');
  }

  Future<VisitorActionResult> toggleRecordReview(String visitId) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canReviewRecords) {
      return const VisitorActionResult(
        success: false,
        message: 'This membership cannot review visitor records.',
      );
    }

    final current = await _requireRecord(visitId);
    final updated = current.copyWith(
      frontDeskReviewed: !current.frontDeskReviewed,
    );
    await _save(updated, SyncOperation.update);

    return VisitorActionResult(
      success: true,
      message: updated.frontDeskReviewed
          ? 'Front-desk review saved offline.'
          : 'Front-desk review reopened and queued for sync.',
    );
  }

  Future<VisitorRecord> _requireRecord(String id) async {
    final membership = _schoolSession.requireActiveMembership();
    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: id,
    );
    if (record == null) {
      throw StateError('Visitor record $id was not found for this school.');
    }
    return VisitorRecord.fromJson(record.payload);
  }

  Future<void> _save(VisitorRecord record, SyncOperation operation) async {
    final membership = _schoolSession.requireActiveMembership();
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: record.id,
      payload: record.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _entityType,
      entityId: record.id,
      operation: operation,
      payload: record.toJson(),
    );
  }
}
