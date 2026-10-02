import '../../../core/database/local_database.dart';
import '../../../shared/models/school_membership.dart';

/// Mirrors `apps.owner.jobs.access.JOB` - read here only, never written; the proprietor gives a
/// duty through the existing Owner Jobs screen.
const financeJobAssignmentEntityType = 'owner_job_assignment';

/// Mirrors `apps.receivables.constants.BILLING_AUTHORITY_DUTY`: the duty that lets someone decide
/// what families owe - fee schedules, due dates, discounts, scholarships, waivers. The proprietor
/// always has it; anyone else has it only because the proprietor gave it to them through a job
/// assignment. It is never implied by a job title such as Accountant.
const financeBillingAuthorityDuty = 'finance.billing_authority';

/// Mirrors `apps.receivables.constants.OPERATE_DUTIES`: duties that let someone work the ledger
/// (look at it, record and correct a payment) without deciding what families owe.
const financeOperateDuties = <String>[
  'finance.billing_authority',
  'finance.reconciliation',
  'finance.accounts',
  'finance.collections',
];

/// Mirrors `apps.concessions.constants.SUBMIT_DUTY`: the duty that lets someone raise a
/// concession request without deciding it.
const financeConcessionsSubmitDuty = 'finance.concessions';

/// Whether [membership] currently holds [duty] through an active job assignment the proprietor
/// gave them - the same real entity and shape `apps.owner.jobs.access.has_duty` reads.
Future<bool> hasFinanceDuty(
  LocalDatabase database,
  SchoolMembership membership,
  String duty,
) async {
  final records = await database.getLocalRecords(
    tenantId: membership.schoolId,
    entityType: financeJobAssignmentEntityType,
  );
  return records.any((record) {
    final payload = record.payload;
    final duties = payload['duties'];
    return payload['status'] == 'active' &&
        payload['membershipId'] == membership.id &&
        duties is List &&
        duties.contains(duty);
  });
}

/// Whether [membership] holds any one of [duties].
Future<bool> hasAnyFinanceDuty(
  LocalDatabase database,
  SchoolMembership membership,
  List<String> duties,
) async {
  for (final duty in duties) {
    if (await hasFinanceDuty(database, membership, duty)) return true;
  }
  return false;
}

/// Mirrors `apps.receivables.permissions.can_manage_billing`: whether [membership] may decide
/// what families owe. A job title never carries this on its own - not even Accountant.
Future<bool> canManageBilling(LocalDatabase database, SchoolMembership membership) async =>
    membership.role == SchoolRole.proprietor ||
    await hasFinanceDuty(database, membership, financeBillingAuthorityDuty);

/// Mirrors `apps.receivables.permissions.can_operate_receivables`: whether [membership] may work
/// the ledger (record and correct payments) without deciding what families owe.
Future<bool> canOperateReceivables(LocalDatabase database, SchoolMembership membership) async =>
    membership.role == SchoolRole.proprietor ||
    membership.role == SchoolRole.accountant ||
    await hasAnyFinanceDuty(database, membership, financeOperateDuties);

/// Mirrors `apps.concessions.handler.can_submit`: whether [membership] may raise a concession
/// request.
Future<bool> canSubmitConcession(LocalDatabase database, SchoolMembership membership) async =>
    membership.role == SchoolRole.proprietor ||
    membership.role == SchoolRole.accountant ||
    await hasFinanceDuty(database, membership, financeConcessionsSubmitDuty);
