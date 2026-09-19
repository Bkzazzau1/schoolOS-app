import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../domain/concession_request.dart';

class ConcessionRepository {
  ConcessionRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const entityType = 'concession_request';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  Future<List<ConcessionRequest>> loadRequests() async {
    final membership = _schoolSession.requireActiveMembership();
    var records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: entityType,
    );

    if (records.isEmpty) {
      for (final request in _seed) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: entityType,
          entityId: request.id,
          payload: request.toJson(),
          isDirty: false,
        );
      }
      records = await _localDatabase.getLocalRecords(
        tenantId: membership.schoolId,
        entityType: entityType,
      );
    }

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

    final membership = _schoolSession.requireActiveMembership();
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
  }
}

String _formatDate(DateTime date) {
  const months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
}

const _seed = <ConcessionRequest>[
  ConcessionRequest(
    id: 'CNC-2026-041',
    student: 'Yusuf Bello',
    className: 'JSS 2B',
    type: ConcessionType.scholarship,
    grossFee: 185000,
    amount: 75000,
    reason: 'Founder Scholarship · BrightGate Founder Fund',
    requestedBy: 'Finance Office',
    requestedByRole: 'Finance Office',
    requestedAt: '02 Sep 2026',
    status: ConcessionStatus.approved,
    decidedBy: 'Proprietor',
    decidedAt: '03 Sep 2026',
    decisionNote: 'Approved per founder fund allocation.',
  ),
  ConcessionRequest(
    id: 'CNC-2026-042',
    student: 'Hafsa Abdullahi',
    className: 'Primary 3',
    type: ConcessionType.discount,
    grossFee: 145000,
    amount: 10000,
    reason: 'Sibling Discount · school policy',
    requestedBy: 'Finance Office',
    requestedByRole: 'Finance Office',
    requestedAt: '10 Sep 2026',
    status: ConcessionStatus.pendingApproval,
  ),
  ConcessionRequest(
    id: 'CNC-2026-043',
    student: 'Muhammad Kabir',
    className: 'Primary 5',
    type: ConcessionType.scholarship,
    grossFee: 145000,
    amount: 50000,
    reason: 'Academic Scholarship · BrightGate Scholarship Fund',
    requestedBy: 'Finance Office',
    requestedByRole: 'Finance Office',
    requestedAt: '05 Sep 2026',
    status: ConcessionStatus.approved,
    decidedBy: 'Proprietor',
    decidedAt: '06 Sep 2026',
    decisionNote: 'Approved based on academic performance review.',
  ),
  ConcessionRequest(
    id: 'CNC-2026-044',
    student: 'Aisha Ibrahim',
    className: 'Nursery 2',
    type: ConcessionType.discount,
    grossFee: 117500,
    amount: 23500,
    reason: 'Staff Child Discount · staff benefit policy',
    requestedBy: 'Administrator',
    requestedByRole: 'Administrator',
    requestedAt: '12 Sep 2026',
    status: ConcessionStatus.pendingApproval,
  ),
];
