import '../database/local_database.dart';
import '../../shared/models/school_membership.dart';

/// Mirrors `apps.owner.jobs.access`'s own entity type and payload shape - read here only, never
/// written; the proprietor gives a scoped assignment through the existing Job Assignments screen.
const campusScopeJobAssignmentEntityType = 'owner_job_assignment';

/// The same real `apps.structure` entity type `AcademicSection`/`Campus` already sync as - read
/// here only to resolve a sectionHead assignment's own real campus.
const campusScopeSectionEntityType = 'academic_section';

/// The one real campus this membership's authority is limited to, from a real active job
/// assignment the owner gave them - either a direct campus grant, or a sectionHead assignment
/// whose own section has a real campus. Null means whole-school: the default for everyone until
/// the owner sets a scoped assignment up, so nothing changes for a school that never does.
/// Mirrors `apps.owner.jobs.access.campus_scope_for` exactly - keep both in sync.
Future<String?> campusScopeFor(LocalDatabase database, SchoolMembership membership) async {
  final records = await database.getLocalRecords(
    tenantId: membership.schoolId,
    entityType: campusScopeJobAssignmentEntityType,
  );
  for (final record in records) {
    final payload = record.payload;
    if (payload['status'] != 'active' || payload['membershipId'] != membership.id) continue;
    final campusId = payload['campusId'] as String?;
    if (campusId != null && campusId.isNotEmpty) return campusId;
    final sectionId = payload['sectionId'] as String?;
    if (sectionId == null || sectionId.isEmpty) continue;
    final section = await database.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: campusScopeSectionEntityType,
      entityId: sectionId,
    );
    final sectionCampusId = section?.payload['campusId'] as String?;
    if (sectionCampusId != null && sectionCampusId.isNotEmpty) return sectionCampusId;
  }
  return null;
}
