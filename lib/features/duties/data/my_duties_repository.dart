import '../../../core/database/local_database.dart';
import '../../../shared/models/school_membership.dart';

/// Mirrors `apps.owner.jobs.access`'s own entity type and payload shape - read here only, never
/// written; the proprietor gives a duty through the existing Job Assignments screen.
const myDutiesJobAssignmentEntityType = 'owner_job_assignment';

/// The four duties that unlock Mandates & Direct Debit - never implied by a job title, only ever
/// held because the proprietor explicitly gave one. Mirrors `apps.mandates`'s duty catalog.
const myDutiesMandateDuties = <String>[
  'finance.mandate_provider_manage',
  'finance.mandate_manage',
  'finance.mandate_prepare',
  'finance.mandate_approve',
];

/// The four duties that unlock Smart Money Collection. Mirrors `apps.bankconnect`/`apps.smartcollect`'s
/// duty catalog.
const myDutiesCollectionDuties = <String>[
  'finance.collection_provider_manage',
  'finance.collection_policy_manage',
  'finance.collection_prepare',
  'finance.collection_approve',
];

/// What a person's own, real job-assignment duties unlock elsewhere in the app - read-only, for the
/// "My Duties" screen every non-Finance/Proprietor workspace offers. A duty can be held by anyone in
/// the school's staff directory, whatever role they log in as, so this is never role-gated itself;
/// it simply shows nothing when the person holds none of the duties it recognises.
class MyDutiesRepository {
  MyDutiesRepository({required this.database, required this.membership});

  final LocalDatabase database;
  final SchoolMembership membership;

  /// The real, active duties this person was actually given - never a role's implied set.
  Future<Set<String>> activeDuties() async {
    final records = await database.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: myDutiesJobAssignmentEntityType,
    );
    final duties = <String>{};
    for (final record in records) {
      final payload = record.payload;
      if (payload['status'] != 'active' || payload['membershipId'] != membership.id) continue;
      final list = payload['duties'];
      if (list is List) duties.addAll(list.whereType<String>());
    }
    return duties;
  }

  Future<bool> hasMandatesAccess() async =>
      (await activeDuties()).any(myDutiesMandateDuties.contains);

  Future<bool> hasCollectionsAccess() async =>
      (await activeDuties()).any(myDutiesCollectionDuties.contains);

  /// Whether this screen has anything at all to show this person.
  Future<bool> hasAnyHubAccess() async {
    final duties = await activeDuties();
    return duties.any(myDutiesMandateDuties.contains) || duties.any(myDutiesCollectionDuties.contains);
  }
}
