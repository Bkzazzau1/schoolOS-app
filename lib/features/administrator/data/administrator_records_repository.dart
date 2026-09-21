import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/administrator_records_models.dart';
import 'administrator_demo_school.dart';
import 'administrator_records_demo_data.dart';

class AdministratorRecordsSnapshot {
  const AdministratorRecordsSnapshot({
    required this.records,
    required this.permissions,
  });

  final List<AdministratorDocumentRecord> records;
  final AdministratorRecordsPermissions permissions;
}

class AdministratorRecordsRepository {
  AdministratorRecordsRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _entityType = 'administrator_document_record';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  AdministratorRecordsPermissions permissionsFor(SchoolMembership membership) {
    final allowed = membership.role == SchoolRole.administrator;
    return AdministratorRecordsPermissions(
      canViewRegister: allowed,
      canReviewRestrictedMetadata: allowed,
    );
  }

  Future<AdministratorRecordsSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    var records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );

    if (records.isEmpty) {
      for (final item in [...administratorRecordsWebsiteSeed, ...administratorRecordsDemoExtras]) {
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
        .map((record) => AdministratorDocumentRecord.fromJson(record.payload))
        .toList();
    final websiteOrder = <String, int>{
      for (var i = 0; i < administratorRecordsWebsiteSeed.length; i++)
        administratorRecordsWebsiteSeed[i].id: i,
    };
    items.sort((a, b) {
      final aOrder = websiteOrder[a.id] ?? 9999;
      final bOrder = websiteOrder[b.id] ?? 9999;
      final order = aOrder.compareTo(bOrder);
      return order != 0 ? order : a.id.compareTo(b.id);
    });

    return AdministratorRecordsSnapshot(
      records: items,
      permissions: permissionsFor(membership),
    );
  }

  /// Who a document can belong to.
  static const kinds = ['Student', 'Family', 'Staff'];

  /// The documents a school office usually asks for.
  static const documentTypes = [
    'Birth certificate',
    'Previous school report',
    'Guardian ID',
    'Passport photograph',
    'Immunisation record',
    'Transfer letter',
    'Staff qualification',
    'Staff ID',
  ];

  SchoolMembership _requireOffice() {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canReviewRestrictedMetadata) {
      throw StateError('Only the records office can change document records.');
    }
    return membership;
  }

  static String _today() {
    final n = DateTime.now();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${n.day} ${months[n.month - 1]} ${n.year}';
  }

  /// What can be done to a document that is in this state, in words for the button.
  static List<String> actionsFor(AdministratorRecordStatus status) => switch (status) {
        AdministratorRecordStatus.missing => const ['Mark received'],
        AdministratorRecordStatus.pending => const ['Verify', 'Send back'],
        AdministratorRecordStatus.draft => const ['Issue'],
        AdministratorRecordStatus.verified => const ['Reopen'],
      };

  /// Starts tracking a document that the school expects. It begins as missing until it is received.
  Future<AdministratorRecordActionResult> add({
    required String owner,
    required String document,
    required String kind,
    String visibility = 'Restricted',
  }) async {
    final SchoolMembership membership;
    try {
      membership = _requireOffice();
    } on StateError catch (error) {
      return AdministratorRecordActionResult(success: false, message: error.message);
    }
    if (owner.trim().isEmpty || document.trim().isEmpty) {
      return const AdministratorRecordActionResult(success: false, message: 'Say whose document it is and which document.');
    }
    if (!kinds.contains(kind)) {
      return const AdministratorRecordActionResult(success: false, message: 'Choose whether it is a student, family or staff document.');
    }
    final existing = (await load()).records;
    final duplicate = existing.any(
      (r) =>
          r.recordOwner.trim().toLowerCase() == owner.trim().toLowerCase() &&
          r.document.trim().toLowerCase() == document.trim().toLowerCase(),
    );
    if (duplicate) {
      return AdministratorRecordActionResult(success: false, message: '${owner.trim()} already has a ${document.trim().toLowerCase()} on record.');
    }
    final record = AdministratorDocumentRecord(
      id: 'REC-${DateTime.now().microsecondsSinceEpoch}',
      document: document.trim(),
      recordOwner: owner.trim(),
      status: AdministratorRecordStatus.missing,
      received: '—',
      visibility: visibility,
      kind: kind,
      history: [_step('Added', membership, 'Expected from ${owner.trim()}')],
    );
    await _save(membership, record, isNew: true);
    return AdministratorRecordActionResult(success: true, message: '${record.document} added for ${record.recordOwner}.', record: record);
  }

  /// Moves a document one step: Mark received, Verify, Send back, Issue or Reopen. Sending back and reopening need a reason.
  Future<AdministratorRecordActionResult> act(AdministratorDocumentRecord record, String action, {String note = ''}) async {
    final SchoolMembership membership;
    try {
      membership = _requireOffice();
    } on StateError catch (error) {
      return AdministratorRecordActionResult(success: false, message: error.message);
    }
    if (!actionsFor(record.status).contains(action)) {
      return AdministratorRecordActionResult(success: false, message: 'A ${record.status.label.toLowerCase()} document cannot be "${action.toLowerCase()}".');
    }
    if ((action == 'Send back' || action == 'Reopen') && note.trim().isEmpty) {
      return AdministratorRecordActionResult(success: false, message: 'Say why before you ${action.toLowerCase()} this document.');
    }
    final who = membership.id;
    final updated = switch (action) {
      'Mark received' => record.copyWith(status: AdministratorRecordStatus.pending, received: _today()),
      'Verify' => record.copyWith(status: AdministratorRecordStatus.verified, verifiedBy: who),
      'Issue' => record.copyWith(status: AdministratorRecordStatus.verified, received: _today(), verifiedBy: who),
      'Send back' => record.copyWith(status: AdministratorRecordStatus.missing, received: '—', verifiedBy: ''),
      _ => record.copyWith(status: AdministratorRecordStatus.pending, verifiedBy: ''), // Reopen
    };
    final withHistory = updated.copyWith(history: [...record.history, _step(action, membership, note.trim())]);
    await _save(membership, withHistory, isNew: false);
    return AdministratorRecordActionResult(success: true, message: '${record.document}: ${withHistory.status.label.toLowerCase()}.', record: withHistory);
  }

  Map<String, Object?> _step(String action, SchoolMembership by, String note) => {
        'at': DateTime.now().toUtc().toIso8601String(),
        'action': action,
        'by': by.id,
        'note': note,
      };

  Future<void> _save(SchoolMembership membership, AdministratorDocumentRecord record, {required bool isNew}) async {
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

class AdministratorRecordActionResult {
  const AdministratorRecordActionResult({required this.success, required this.message, this.record});

  final bool success;
  final String message;
  final AdministratorDocumentRecord? record;
}
