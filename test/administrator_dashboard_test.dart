import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/auth/app_capability.dart';
import 'package:schoolos_app/features/administrator/data/administrator_dashboard_demo_data.dart';
import 'package:schoolos_app/features/administrator/data/administrator_overview.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_admissions_models.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_lifecycle_models.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_records_models.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_staff_models.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_students_models.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

void main() {
  test('the desk is worked out from real records, and an empty school shows zeros and an empty queue', () {
    final o = buildAdministratorOverview(students: const [], applicants: const [], records: const [], lifecycle: const [], staff: const []);
    expect(o.kpis.map((k) => k.value), ['0', '0', '0', '0', '0']);
    expect(o.queue, isEmpty);
    expect(o.pipeline.length, 6);
  });

  test('students, admissions, records, lifecycle changes and staff files each show up on the desk', () {
    final o = buildAdministratorOverview(
      students: const [
        AdministratorStudentRecord(id: 'S1', name: 'Ahmed Yusuf', className: 'Primary 3', primaryGuardian: 'Amina', status: AdministratorStudentStatus.active),
        AdministratorStudentRecord(id: 'S2', name: 'Sani Bello', className: 'Primary 4', primaryGuardian: 'Bello', status: AdministratorStudentStatus.transferPending),
      ],
      applicants: const [
        AdmissionApplicant(
          reference: 'ADM-1', name: 'Aisha Sani', section: 'Primary', className: 'Primary 2', guardian: 'Sani', phone: '0803',
          stage: AdmissionStage.documents, submitted: '1 Sep', source: 'Website',
          birthCertificate: AdmissionDocumentStatus.pending, previousSchoolReport: AdmissionDocumentStatus.received, guardianId: AdmissionDocumentStatus.received,
          documentRequestQueued: false,
        ),
        AdmissionApplicant(
          reference: 'ADM-2', name: 'Umar Faruq', section: 'Primary', className: 'Primary 1', guardian: 'Faruq', phone: '0804',
          stage: AdmissionStage.registered, submitted: '2 Sep', source: 'Walk-in',
          birthCertificate: AdmissionDocumentStatus.received, previousSchoolReport: AdmissionDocumentStatus.received, guardianId: AdmissionDocumentStatus.received,
          documentRequestQueued: false,
        ),
      ],
      records: const [
        AdministratorDocumentRecord(id: 'DOC-1', document: 'Birth certificate', recordOwner: 'Ahmed Yusuf', status: AdministratorRecordStatus.missing, received: '', visibility: 'Office'),
        AdministratorDocumentRecord(id: 'DOC-2', document: 'Report card', recordOwner: 'Sani Bello', status: AdministratorRecordStatus.verified, received: '2 Sep', visibility: 'Office'),
      ],
      lifecycle: const [
        AdministratorLifecycleRecord(id: 'L1', studentName: 'Sani Bello', workflow: 'Transfer out', change: 'To Al-Hikma', status: AdministratorLifecycleStatus.pending),
      ],
      staff: const [
        AdministratorStaffRecord(id: 'STAFF-1', name: 'Mr. Ahmad Sani', role: 'Teacher', section: 'Primary', fileStatus: AdministratorStaffFileStatus.missingDocument),
        AdministratorStaffRecord(id: 'STAFF-2', name: 'Mrs. Grace Musa', role: 'Teacher', section: 'Primary', fileStatus: AdministratorStaffFileStatus.complete),
      ],
    );
    String kpi(String label) => o.kpis.firstWhere((k) => k.label == label).value;
    expect(kpi('Active students'), '1');
    expect(kpi('Admissions in progress'), '1');
    expect(kpi('Records tasks'), '1');
    expect(kpi('Transfers / withdrawals'), '1');
    expect(kpi('Staff files'), '2');
    final titles = [for (final q in o.queue) q.title];
    expect(titles, contains('Admission awaiting documents: Aisha Sani'));
    expect(titles, contains('Transfer out pending: Sani Bello'));
    expect(titles, contains('Birth certificate is missing'));
    expect(titles, contains('Staff file incomplete: Mr. Ahmad Sani'));
    expect(o.queue.length, 4);
    expect(o.pipeline.firstWhere((p) => p.title == 'Documents').detail, '1');
    expect(o.pipeline.firstWhere((p) => p.title == 'Registered').detail, '1');
  });

  test('administrator workspace exposes the twelve website destinations plus Staff Profiles', () {
    expect(administratorNavigation, hasLength(13));
    expect(
      administratorNavigation.map((item) => item.label).toList(),
      [
        'Dashboard',
        'Admissions Pipeline',
        'Website Manager',
        'Student Registration',
        'Students & Families',
        'Staff Records',
        'Staff Profiles',
        'Staff Attendance',
        'Records & Documents',
        'Transfers & Promotion',
        'Attendance Desk',
        'Operations',
        'Notices',
      ],
    );
  });

  test('administrator quick actions preserve proprietor approval boundary', () {
    expect(administratorQuickActions, hasLength(5));
    final concession = administratorQuickActions
        .firstWhere((action) => action.key == 'scholarships');
    expect(concession.description, contains('Only the Proprietor can approve'));
  });

  test('administrator is a first-class serializable school membership role', () {
    const membership = SchoolMembership(
      id: 'admin-1',
      schoolId: 'school-a',
      schoolName: 'School A',
      role: SchoolRole.administrator,
    );
    final restored = SchoolMembership.fromJson(membership.toJson());
    expect(restored.role, SchoolRole.administrator);
    expect(restored.roleLabel, 'Administrator');
  });

  test('administrator receives operations access without governance powers', () {
    expect(
      RolePermissions.can(SchoolRole.administrator, AppCapability.administration),
      isTrue,
    );
    expect(
      RolePermissions.can(SchoolRole.administrator, AppCapability.students),
      isTrue,
    );
    expect(
      RolePermissions.can(SchoolRole.administrator, AppCapability.attendance),
      isTrue,
    );
    expect(
      RolePermissions.can(SchoolRole.administrator, AppCapability.academics),
      isFalse,
    );
    expect(
      RolePermissions.can(SchoolRole.administrator, AppCapability.finance),
      isFalse,
    );
    expect(administratorAuthorityBoundary, contains('cannot finalize academic results'));
    expect(administratorAuthorityBoundary, contains('cannot finalize academic results'));
    expect(administratorAuthorityBoundary, contains('approve a scholarship or discount'));
  });
}
