import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/administrator_lifecycle_models.dart';
import '../domain/administrator_students_models.dart';
import 'administrator_demo_school.dart';
import 'administrator_lifecycle_demo_data.dart';

class AdministratorLifecycleSnapshot {
  const AdministratorLifecycleSnapshot({
    required this.records,
    required this.permissions,
  });

  final List<AdministratorLifecycleRecord> records;
  final AdministratorLifecyclePermissions permissions;
}

class AdministratorLifecycleRepository {
  AdministratorLifecycleRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const entityType = 'administrator_student_lifecycle';
  static const _entityType = entityType;

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  AdministratorLifecyclePermissions permissionsFor(SchoolMembership membership) {
    final allowed = membership.role == SchoolRole.administrator;
    return AdministratorLifecyclePermissions(
      canViewRegister: allowed,
      canOpenOperationalReview: allowed,
    );
  }

  Future<AdministratorLifecycleSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    var records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );

    if (records.isEmpty) {
      for (final item in [...administratorLifecycleWebsiteSeed, ...administratorLifecycleDemoExtras]) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _entityType,
          entityId: item.id,
          payload: item.toJson(),
        );
      }
      records = await _localDatabase.getLocalRecords(
        tenantId: membership.schoolId,
        entityType: _entityType,
      );
    }

    final items = records
        .map((record) => AdministratorLifecycleRecord.fromJson(record.payload))
        .toList();

    final websiteOrder = <String, int>{
      for (var i = 0; i < administratorLifecycleWebsiteSeed.length; i++)
        administratorLifecycleWebsiteSeed[i].id: i,
    };
    items.sort((a, b) {
      final aOrder = websiteOrder[a.id] ?? 9999;
      final bOrder = websiteOrder[b.id] ?? 9999;
      final order = aOrder.compareTo(bOrder);
      return order != 0 ? order : a.id.compareTo(b.id);
    });

    return AdministratorLifecycleSnapshot(
      records: items,
      permissions: permissionsFor(membership),
    );
  }

  /// The workflows an administrator can start from this desk.
  static const requestable = ['Class change', 'Promotion', 'Transfer out'];

  SchoolMembership _requireAdministrator() {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canOpenOperationalReview) {
      throw StateError("Only an administrator can change a student's class or status here.");
    }
    return membership;
  }

  AdministratorLifecycleActionResult _refused(StateError error) =>
      AdministratorLifecycleActionResult(success: false, message: error.message);

  /// Starts a change for a student. Class changes and promotions name the class the student moves to.
  ///
  /// [student] is the student as they stand now (after earlier changes).
  Future<AdministratorLifecycleActionResult> request({
    required AdministratorStudentRecord student,
    required String workflow,
    String toClass = '',
    String note = '',
  }) async {
    final SchoolMembership membership;
    try {
      membership = _requireAdministrator();
    } on StateError catch (error) {
      return _refused(error);
    }
    if (!requestable.contains(workflow)) {
      return const AdministratorLifecycleActionResult(success: false, message: 'Choose what kind of change this is.');
    }
    if (student.status == AdministratorStudentStatus.transferredOut) {
      return AdministratorLifecycleActionResult(success: false, message: '${student.name} has already left the school.');
    }
    final target = toClass.trim();
    final movesClass = workflow != 'Transfer out';
    if (movesClass) {
      if (target.isEmpty) {
        return const AdministratorLifecycleActionResult(success: false, message: 'Say which class the student moves to.');
      }
      if (target.toLowerCase() == student.className.trim().toLowerCase()) {
        return AdministratorLifecycleActionResult(success: false, message: '${student.name} is already in $target.');
      }
    }
    final existing = (await load()).records;
    if (existing.any((r) => r.isPending && r.student == student.id && r.workflow == workflow)) {
      return AdministratorLifecycleActionResult(
        success: false,
        message: '${student.name} already has a pending ${workflow.toLowerCase()}.',
      );
    }

    final now = DateTime.now();
    final record = AdministratorLifecycleRecord(
      id: 'LC-${now.microsecondsSinceEpoch}',
      studentName: student.name,
      workflow: workflow,
      change: movesClass ? '${student.className} → $target' : (note.trim().isEmpty ? 'Awaiting records pack' : note.trim()),
      status: AdministratorLifecycleStatus.pending,
      studentId: student.id,
      fromClass: movesClass ? student.className : '',
      toClass: movesClass ? target : '',
      requestedAt: now.toUtc().toIso8601String(),
      note: note.trim(),
    );
    await _save(membership, record, isNew: true);
    return AdministratorLifecycleActionResult(success: true, message: '$workflow started for ${student.name}.', record: record);
  }

  /// A transfer out can only be completed once the student's records pack has been prepared.
  Future<AdministratorLifecycleActionResult> markRecordsPackReady(AdministratorLifecycleRecord record) async {
    final SchoolMembership membership;
    try {
      membership = _requireAdministrator();
    } on StateError catch (error) {
      return _refused(error);
    }
    if (!record.isPending || !record.isTransferOut) {
      return const AdministratorLifecycleActionResult(success: false, message: 'Only a pending transfer has a records pack.');
    }
    final updated = record.copyWith(recordsPackReady: true, change: 'Records pack ready');
    await _save(membership, updated, isNew: false);
    return AdministratorLifecycleActionResult(success: true, message: 'Records pack marked ready.', record: updated);
  }

  /// Carries out a pending change. A promotion needs the name of who approved it (academic leadership decides, the
  /// administrator only processes it); a transfer out needs the records pack to be ready.
  Future<AdministratorLifecycleActionResult> complete(AdministratorLifecycleRecord record, {String approvedBy = ''}) async {
    final SchoolMembership membership;
    try {
      membership = _requireAdministrator();
    } on StateError catch (error) {
      return _refused(error);
    }
    if (!record.isPending) {
      return const AdministratorLifecycleActionResult(success: false, message: 'This change is not pending.');
    }
    if (record.isPromotion && approvedBy.trim().isEmpty) {
      return const AdministratorLifecycleActionResult(
        success: false,
        message: 'A promotion is an academic decision. Enter who approved it before processing it.',
      );
    }
    if (record.isTransferOut && !record.recordsPackReady) {
      return const AdministratorLifecycleActionResult(success: false, message: 'Prepare the records pack before completing the transfer.');
    }
    if (record.isAlumni) {
      return const AdministratorLifecycleActionResult(success: false, message: 'Alumni are managed from Alumni Management.');
    }
    final updated = record.copyWith(
      status: AdministratorLifecycleStatus.completed,
      completedAt: DateTime.now().toUtc().toIso8601String(),
      approvedBy: approvedBy.trim(),
      change: record.movesClass ? record.change : 'Completed',
    );
    await _save(membership, updated, isNew: false);
    return AdministratorLifecycleActionResult(
      success: true,
      message: '${record.workflow} completed for ${record.studentName}.',
      record: updated,
    );
  }

  /// Stops a pending change. The record is kept, with the reason, so the history stays complete.
  Future<AdministratorLifecycleActionResult> cancel(AdministratorLifecycleRecord record, String reason) async {
    final SchoolMembership membership;
    try {
      membership = _requireAdministrator();
    } on StateError catch (error) {
      return _refused(error);
    }
    if (!record.isPending) {
      return const AdministratorLifecycleActionResult(success: false, message: 'This change is not pending.');
    }
    final updated = record.copyWith(
      status: AdministratorLifecycleStatus.cancelled,
      completedAt: DateTime.now().toUtc().toIso8601String(),
      note: reason.trim().isEmpty ? record.note : reason.trim(),
      change: 'Cancelled',
    );
    await _save(membership, updated, isNew: false);
    return AdministratorLifecycleActionResult(success: true, message: '${record.workflow} cancelled.', record: updated);
  }

  Future<void> _save(SchoolMembership membership, AdministratorLifecycleRecord record, {required bool isNew}) async {
    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: record.id,
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: record.id,
      payload: record.toJson(),
      serverVersion: existing?.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _entityType,
      entityId: record.id,
      operation: isNew && existing == null ? SyncOperation.create : SyncOperation.update,
      payload: record.toJson(),
      baseVersion: existing?.serverVersion,
    );
  }
}

class AdministratorLifecycleActionResult {
  const AdministratorLifecycleActionResult({required this.success, required this.message, this.record});

  final bool success;
  final String message;
  final AdministratorLifecycleRecord? record;
}
