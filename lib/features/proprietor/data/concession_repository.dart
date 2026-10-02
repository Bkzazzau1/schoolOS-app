import '../../../core/database/local_database.dart';
import '../../../core/sync/server_confirm.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../finance_office/data/finance_authority.dart';
import '../domain/concession_request.dart';

class ConcessionRepository {
  ConcessionRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    this.confirm,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  /// Set when there is a server: a decision is then sent at once and a refusal is shown. Null on demo data.
  final ServerConfirm? confirm;

  static const entityType = 'concession_request';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  Future<List<ConcessionRequest>> loadRequests() async {
    final membership = _schoolSession.requireActiveMembership();
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: entityType,
    );

    final result = records
        .map(
          (record) => ConcessionRequest.fromJson(
            record.payload,
            serverVersion: record.serverVersion,
          ),
        )
        .toList();
    result.sort((a, b) => b.id.compareTo(a.id));
    return result;
  }

  Future<void> decide({
    required ConcessionRequest request,
    required ConcessionStatus status,
    required String note,
  }) async {
    if (status == ConcessionStatus.pendingApproval) {
      throw ArgumentError('A proprietor decision must approve or decline.');
    }
    if (confirm != null && status == ConcessionStatus.declined && note.trim().isEmpty) {
      throw ArgumentError('Say why the request is declined.');
    }

    final membership = _schoolSession.requireActiveMembership();
    if (!await canManageBilling(_localDatabase, membership)) {
      throw StateError('Only the owner, or someone the owner has given billing authority, can decide a concession request.');
    }
    final decided = request.copyWith(
      status: status,
      decidedBy: 'Proprietor',
      decidedAt: _formatDate(DateTime.now()),
      decisionNote: note.trim().isEmpty ? null : note.trim(),
    );

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: entityType,
      entityId: request.id,
      payload: decided.toJson(),
      serverVersion: request.serverVersion,
      isDirty: true,
    );

    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: entityType,
      entityId: request.id,
      operation: SyncOperation.update,
      payload: decided.toJson(),
      baseVersion: request.serverVersion,
    );
    await confirm?.afterQueued(membership.schoolId, entityType, request.id);
  }
}

String _formatDate(DateTime date) {
  const months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
}
