import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/tenancy/campus_scope.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

/// Seeds a real, active (or not) `owner_job_assignment` record linked to [membership] - the same
/// real entity the Proprietor's Job Assignments screen writes, and the server forges the real
/// `membershipId` link for once a staff invitation is accepted.
Future<void> seedJobAssignment(
  LocalDatabase db, {
  required SchoolMembership membership,
  String id = 'JOB-1',
  String status = 'active',
  String? campusId,
  String? sectionId,
  List<String> duties = const ['administration.students'],
}) =>
    db.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: campusScopeJobAssignmentEntityType,
      entityId: id,
      payload: {
        'membershipId': membership.id,
        'duties': duties,
        'status': status,
        if (campusId != null) 'campusId': campusId,
        if (sectionId != null) 'sectionId': sectionId,
      },
    );

/// Seeds a real `apps.structure` `academic_section` record, optionally with its own real campus.
Future<void> seedStructureSection(LocalDatabase db, {required String tenantId, required String id, String? campusId}) =>
    db.upsertLocalRecord(
      tenantId: tenantId,
      entityType: campusScopeSectionEntityType,
      entityId: id,
      payload: {'id': id, if (campusId != null) 'campusId': campusId},
    );
