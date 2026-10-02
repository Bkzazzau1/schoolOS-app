import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/features/finance_office/data/finance_authority.dart';
import 'package:schoolos_app/features/finance_office/data/finance_billing.dart';
import 'package:schoolos_app/features/finance_office/data/finance_ledger_repository.dart';
import 'package:schoolos_app/features/finance_office/domain/finance_ledger_models.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

/// Writes the same sensible starting fee structure the app's old, now-removed auto-seed used to
/// create automatically - now an explicit fixture, the same real entity
/// [FinanceLedgerRepository.structures] reads.
Future<void> seedFeeStructures(
  LocalDatabase db, {
  required String tenantId,
  String term = financeCurrentTerm,
}) async {
  for (final section in financeSections) {
    final s = FeeStructure(term: term, section: section, items: defaultFeeItems(section));
    await db.upsertLocalRecord(
      tenantId: tenantId,
      entityType: FinanceLedgerRepository.structureType,
      entityId: s.id,
      payload: s.toJson(),
    );
  }
}

/// Gives [membership] the real `finance.billing_authority` duty through a real `owner_job_assignment`
/// record, the same real entity the owner's own Job Assignments screen writes.
Future<void> seedBillingAuthority(
  LocalDatabase db, {
  required SchoolMembership membership,
  List<String> duties = const [financeBillingAuthorityDuty],
}) async {
  await db.upsertLocalRecord(
    tenantId: membership.schoolId,
    entityType: financeJobAssignmentEntityType,
    entityId: 'JOB-${membership.id}',
    payload: {'membershipId': membership.id, 'duties': duties, 'status': 'active'},
  );
}
