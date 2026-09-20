import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/data/administrator_staff_repository.dart';
import '../../administrator/domain/administrator_staff_models.dart';

/// What an authorizer is allowed to do on a payroll run.
const payrollAuthorityLabels = <String, String>{
  'prepare': 'Prepare payroll batch',
  'approve': 'Approve payroll batch',
  'pay': 'Make payment',
  'view': 'View payroll and invoice',
};

class PayrollProfile {
  const PayrollProfile({
    required this.staffId,
    required this.name,
    required this.role,
    required this.gross,
    required this.deductions,
    required this.onPayroll,
    required this.history,
  });

  final String staffId;
  final String name;
  final String role;
  final int gross;
  final int deductions;
  final bool onPayroll;

  /// Append-only record of salary changes: {at, gross, deductions, onPayroll}.
  final List<Map<String, Object?>> history;

  int get net => gross - deductions;

  factory PayrollProfile.fromPayload(Map<String, Object?> json) =>
      PayrollProfile(
        staffId: json['staffId'] as String,
        name: json['name'] as String? ?? '',
        role: json['role'] as String? ?? '',
        gross: json['gross'] as int? ?? 0,
        deductions: json['deductions'] as int? ?? 0,
        onPayroll: json['onPayroll'] as bool? ?? false,
        history: [
          for (final h in (json['history'] as List? ?? const []))
            Map<String, Object?>.from(h as Map),
        ],
      );
}

class PayrollAuthorizer {
  const PayrollAuthorizer({
    required this.id,
    required this.name,
    required this.authorities,
    required this.status,
    this.membershipId,
  });

  final String id;
  final String name;
  final Set<String> authorities;
  final String status;

  /// Set when the person's login is activated and linked to this record.
  final String? membershipId;

  bool get isActive => status == 'pendingActivation' || status == 'active';

  factory PayrollAuthorizer.fromRecord(LocalRecord record) => PayrollAuthorizer(
    id: record.entityId,
    name: record.payload['name'] as String? ?? '',
    authorities: {
      for (final a in (record.payload['authorities'] as List? ?? const []))
        a as String,
    },
    status: record.payload['status'] as String? ?? 'revoked',
    membershipId: record.payload['membershipId'] as String?,
  );
}

class PayrollSnapshot {
  const PayrollSnapshot({
    required this.staff,
    required this.profiles,
    required this.authorizers,
  });

  final List<AdministratorStaffRecord> staff;
  final Map<String, PayrollProfile> profiles;
  final List<PayrollAuthorizer> authorizers;

  Iterable<PayrollProfile> get onPayroll =>
      profiles.values.where((p) => p.onPayroll);
  int get totalGross => onPayroll.fold(0, (sum, p) => sum + p.gross);
  int get totalDeductions => onPayroll.fold(0, (sum, p) => sum + p.deductions);
  int get totalNet => totalGross - totalDeductions;
}

/// Owner-only salary and payroll authority management.
///
/// Authorizers are recorded owner instructions; they are not authenticated
/// access grants and no money is moved from here.
class OwnerPayrollRepository {
  OwnerPayrollRepository({required this.database, required this.session});

  final LocalDatabase database;
  final SchoolSessionController session;

  static const profileType = 'owner_payroll_profile';
  static const authorizerType = 'owner_payroll_authorizer';

  SchoolMembership _owner() {
    final member = session.requireActiveMembership();
    if (member.role != SchoolRole.proprietor) {
      throw StateError('Only the school owner can manage payroll.');
    }
    return member;
  }

  Future<PayrollSnapshot> load() async {
    final owner = _owner();
    final staff = (await AdministratorStaffRepository(
      localDatabase: database,
      schoolSession: session,
    ).load()).staff;
    final profiles = await database.getLocalRecords(
      tenantId: owner.schoolId,
      entityType: profileType,
    );
    final authorizers = await database.getLocalRecords(
      tenantId: owner.schoolId,
      entityType: authorizerType,
    );
    return PayrollSnapshot(
      staff: staff,
      profiles: {
        for (final r in profiles)
          r.entityId: PayrollProfile.fromPayload(r.payload),
      },
      authorizers: authorizers.map(PayrollAuthorizer.fromRecord).toList(),
    );
  }

  Future<void> saveSalary({
    required AdministratorStaffRecord person,
    required int gross,
    required int deductions,
    required bool onPayroll,
  }) async {
    final owner = _owner();
    if (gross < 0 || deductions < 0 || deductions > gross) {
      throw ArgumentError(
        'Enter a gross salary and deductions that do not exceed it.',
      );
    }
    if (onPayroll && gross == 0) {
      throw ArgumentError('Set a gross salary before adding to payroll.');
    }
    final existing = await database.getLocalRecord(
      tenantId: owner.schoolId,
      entityType: profileType,
      entityId: person.id,
    );
    final now = DateTime.now().toUtc().toIso8601String();
    final history = [
      ...((existing?.payload['history'] as List?) ?? const []),
      {
        'at': now,
        'gross': gross,
        'deductions': deductions,
        'onPayroll': onPayroll,
        'byMembershipId': owner.id,
      },
    ];
    await _save(owner, profileType, person.id, {
      'staffId': person.id,
      'name': person.name,
      'role': person.role,
      'gross': gross,
      'deductions': deductions,
      'onPayroll': onPayroll,
      'history': history,
      'updatedAt': now,
    }, existing);
  }

  Future<void> saveAuthorizer({
    required AdministratorStaffRecord person,
    required Set<String> authorities,
  }) async {
    final owner = _owner();
    if (authorities.isEmpty ||
        authorities.any((a) => !payrollAuthorityLabels.containsKey(a))) {
      throw ArgumentError('Choose at least one payroll authority.');
    }
    final existing = await database.getLocalRecord(
      tenantId: owner.schoolId,
      entityType: authorizerType,
      entityId: person.id,
    );
    final now = DateTime.now().toUtc().toIso8601String();
    await _save(owner, authorizerType, person.id, {
      'staffId': person.id,
      'name': person.name,
      'authorities': authorities.toList()..sort(),
      'status': existing?.payload['status'] == 'active'
          ? 'active'
          : 'pendingActivation',
      'membershipId': existing?.payload['membershipId'],
      'grantedByMembershipId': owner.id,
      'createdAt': existing?.payload['createdAt'] ?? now,
      'updatedAt': now,
    }, existing);
  }

  Future<void> revokeAuthorizer(String id) async {
    final owner = _owner();
    final existing = await database.getLocalRecord(
      tenantId: owner.schoolId,
      entityType: authorizerType,
      entityId: id,
    );
    if (existing == null) {
      throw StateError('Authorizer not found in this school.');
    }
    await _save(owner, authorizerType, id, {
      ...existing.payload,
      'status': 'revoked',
      'revokedByMembershipId': owner.id,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    }, existing);
  }

  Future<void> _save(
    SchoolMembership owner,
    String entityType,
    String id,
    Map<String, Object?> payload,
    LocalRecord? existing,
  ) async {
    await database.upsertLocalRecord(
      tenantId: owner.schoolId,
      entityType: entityType,
      entityId: id,
      payload: payload,
      serverVersion: existing?.serverVersion,
      isDirty: true,
    );
    await database.queueMutation(
      tenantId: owner.schoolId,
      membershipId: owner.id,
      entityType: entityType,
      entityId: id,
      operation: existing == null ? SyncOperation.create : SyncOperation.update,
      payload: payload,
      baseVersion: existing?.serverVersion,
    );
  }
}

/// What the signed-in member may do with payroll.
///
/// The owner may do everything. Anyone else, including a finance officer,
/// needs an active authorizer record linked to their membership; without one
/// they have no payroll access.
Set<String> payrollAuthoritiesFor(
  SchoolMembership member,
  Iterable<PayrollAuthorizer> authorizers,
) {
  if (member.role == SchoolRole.proprietor) {
    return payrollAuthorityLabels.keys.toSet();
  }
  return {
    for (final a in authorizers)
      if (a.status == 'active' && a.membershipId == member.id) ...a.authorities,
  };
}

class PayrollView {
  const PayrollView({required this.profiles, required this.authorities});

  final List<PayrollProfile> profiles;
  final Set<String> authorities;

  bool can(String authority) => authorities.contains(authority);
}

/// Payroll data for the finance office, gated by [payrollAuthoritiesFor].
Future<PayrollView> loadPayrollForMember(
  LocalDatabase database,
  SchoolSessionController session,
) async {
  final member = session.requireActiveMembership();
  final authorizers = (await database.getLocalRecords(
    tenantId: member.schoolId,
    entityType: OwnerPayrollRepository.authorizerType,
  )).map(PayrollAuthorizer.fromRecord);
  final authorities = payrollAuthoritiesFor(member, authorizers);
  if (!authorities.contains('view')) {
    return PayrollView(profiles: const [], authorities: authorities);
  }
  final records = await database.getLocalRecords(
    tenantId: member.schoolId,
    entityType: OwnerPayrollRepository.profileType,
  );
  return PayrollView(
    profiles: [
      for (final r in records)
        if (r.payload['onPayroll'] == true) PayrollProfile.fromPayload(r.payload),
    ],
    authorities: authorities,
  );
}
