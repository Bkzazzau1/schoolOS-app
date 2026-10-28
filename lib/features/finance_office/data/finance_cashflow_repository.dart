import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/finance_cashflow_models.dart';
import 'finance_authority.dart';

class CashflowActionResult {
  const CashflowActionResult({required this.success, required this.message});

  final bool success;
  final String message;
}

/// The school's own income and spending, outside the fee ledger entirely. Income posts the moment it
/// is recorded; an expense needs a billing authority's decision before it counts as spent.
class FinanceCashflowRepository {
  FinanceCashflowRepository({required this.database, required this.session});

  final LocalDatabase database;
  final SchoolSessionController session;

  static const entryType = 'finance_cashflow_entry';

  Future<SchoolMembership> _operator() async {
    final m = session.requireActiveMembership();
    if (!await canOperateReceivables(database, m)) {
      throw StateError('Only the owner or the Finance Office can do this.');
    }
    return m;
  }

  Future<bool> canApprove() async => canManageBilling(database, session.requireActiveMembership());

  Future<List<CashflowEntry>> entries() async {
    final m = session.requireActiveMembership();
    final records = await database.getLocalRecords(tenantId: m.schoolId, entityType: entryType);
    final list = [for (final r in records) CashflowEntry.fromJson(r.payload)];
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<CashflowActionResult> recordEntry({
    required DateTime date,
    required String description,
    required CashflowType type,
    required String category,
    required int amount,
    DateTime? now,
  }) async {
    final SchoolMembership m;
    try {
      m = await _operator();
    } on StateError catch (e) {
      return CashflowActionResult(success: false, message: e.message);
    }
    final trimmedDescription = description.trim();
    if (trimmedDescription.isEmpty) return const CashflowActionResult(success: false, message: 'Say what this is for.');
    if (amount <= 0) return const CashflowActionResult(success: false, message: 'Enter an amount above zero.');
    if (!cashflowCategories.contains(category)) return const CashflowActionResult(success: false, message: 'Choose a category.');

    final day = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final at = now ?? DateTime.now();
    final entry = CashflowEntry(
      id: 'CSH-${at.microsecondsSinceEpoch}',
      date: day, description: trimmedDescription, type: type, category: category, amount: amount,
      status: type == CashflowType.income ? CashflowStatus.posted : CashflowStatus.pendingApproval,
      recordedBy: m.id, createdAt: at.toUtc().toIso8601String(),
    );
    await _put(m, entry.id, entry.toJson());
    return CashflowActionResult(
      success: true,
      message: type == CashflowType.income
          ? '$trimmedDescription posted.'
          : '$trimmedDescription sent to a billing authority for approval.',
    );
  }

  Future<CashflowActionResult> decide(CashflowEntry entry, {required bool approve, String note = ''}) async {
    final m = session.requireActiveMembership();
    if (!await canManageBilling(database, m)) {
      return const CashflowActionResult(
        success: false,
        message: 'Only the owner, or someone the owner has given billing authority, can decide an expense.',
      );
    }
    if (!entry.isPending) {
      return CashflowActionResult(success: false, message: 'This expense was already ${entry.status == CashflowStatus.approved ? 'approved' : 'declined'}.');
    }
    if (!approve && note.trim().isEmpty) {
      return const CashflowActionResult(success: false, message: 'Say why the expense is declined.');
    }
    final decided = CashflowEntry(
      id: entry.id, date: entry.date, description: entry.description, type: entry.type,
      category: entry.category, amount: entry.amount,
      status: approve ? CashflowStatus.approved : CashflowStatus.declined,
      recordedBy: entry.recordedBy, createdAt: entry.createdAt,
      decidedBy: m.id, decidedAt: DateTime.now().toUtc().toIso8601String(),
      decisionNote: note.trim().isEmpty ? null : note.trim(),
    );
    await _put(m, decided.id, decided.toJson());
    return CashflowActionResult(success: true, message: '${entry.description} ${approve ? 'approved' : 'declined'}.');
  }

  Future<void> _put(SchoolMembership m, String id, Map<String, Object?> payload) async {
    final existing = await database.getLocalRecord(tenantId: m.schoolId, entityType: entryType, entityId: id);
    await database.upsertLocalRecord(
      tenantId: m.schoolId, entityType: entryType, entityId: id, payload: payload,
      serverVersion: existing?.serverVersion, isDirty: true,
    );
    await database.queueMutation(
      tenantId: m.schoolId, membershipId: m.id, entityType: entryType, entityId: id,
      operation: existing == null ? SyncOperation.create : SyncOperation.update,
      payload: payload, baseVersion: existing?.serverVersion,
    );
  }
}
