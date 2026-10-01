import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/administrator/data/administrator_staff_policy_copy.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_staff_models.dart';

const _fixtureStaff = <AdministratorStaffRecord>[
  AdministratorStaffRecord(
    id: 'STAFF-FIX-001',
    name: 'Mrs. Amina Yusuf',
    role: 'Teacher',
    section: 'Secondary',
    fileStatus: AdministratorStaffFileStatus.complete,
  ),
  AdministratorStaffRecord(
    id: 'STAFF-FIX-009',
    name: 'Mrs. Khadija Musa',
    role: 'Class Teacher',
    section: 'Primary',
    fileStatus: AdministratorStaffFileStatus.complete,
  ),
  AdministratorStaffRecord(
    id: 'STAFF-FIX-014',
    name: 'Mr. Ahmad Sani',
    role: 'Teacher',
    section: 'Secondary',
    fileStatus: AdministratorStaffFileStatus.missingDocument,
  ),
  AdministratorStaffRecord(
    id: 'STAFF-FIX-021',
    name: 'Mrs. Safiya Ahmad',
    role: 'Teacher',
    section: 'Primary',
    fileStatus: AdministratorStaffFileStatus.complete,
  ),
];

void main() {
  test('a fixture staff record carries exact name, role, section and file-status fields', () {
    expect(_fixtureStaff, hasLength(4));

    final first = _fixtureStaff.first;
    expect(first.name, 'Mrs. Amina Yusuf');
    expect(first.role, 'Teacher');
    expect(first.section, 'Secondary');
    expect(first.fileStatus, AdministratorStaffFileStatus.complete);

    final primary = _fixtureStaff[1];
    expect(primary.name, 'Mrs. Khadija Musa');
    expect(primary.role, 'Class Teacher');
    expect(primary.section, 'Primary');
  });

  test('a fixture directory has three complete files and one missing document', () {
    expect(_fixtureStaff.where((item) => item.fileStatus == AdministratorStaffFileStatus.complete).length, 3);
    expect(_fixtureStaff.where((item) => item.needsAttention).length, 1);

    final attention = _fixtureStaff.singleWhere(
      (item) => item.needsAttention,
    );
    expect(attention.name, 'Mr. Ahmad Sani');
    expect(attention.fileStatus, AdministratorStaffFileStatus.missingDocument);
  });

  test('website onboarding checklist preserves all three groups', () {
    expect(administratorStaffOnboardingChecklist, hasLength(3));
    expect(administratorStaffOnboardingChecklist[0].title, 'Identity & contact');
    expect(administratorStaffOnboardingChecklist[0].detail, contains('emergency contact'));
    expect(administratorStaffOnboardingChecklist[1].title, 'Qualifications');
    expect(administratorStaffOnboardingChecklist[1].detail, contains('professional registration'));
    expect(administratorStaffOnboardingChecklist[2].title, 'Employment documents');
    expect(administratorStaffOnboardingChecklist[2].detail, contains('assigned section'));
  });

  test('staff record serialization preserves directory fields', () {
    final original = _fixtureStaff[2];
    final restored = AdministratorStaffRecord.fromJson(original.toJson());
    expect(restored.id, 'STAFF-FIX-014');
    expect(restored.name, 'Mr. Ahmad Sani');
    expect(restored.role, 'Teacher');
    expect(restored.section, 'Secondary');
    expect(restored.fileStatus, AdministratorStaffFileStatus.missingDocument);
  });

  test('restricted boundary excludes payroll medical and employment decisions', () {
    expect(administratorStaffRestrictedBoundary, contains('salary'));
    expect(administratorStaffRestrictedBoundary, contains('bank details'));
    expect(administratorStaffRestrictedBoundary, contains('private medical'));
    expect(administratorStaffRestrictedBoundary, contains('employment decisions'));
  });

  test('review boundary remains operational and does not invent editing', () {
    expect(administratorStaffReviewBoundary, contains('operational file check'));
    expect(administratorStaffReviewBoundary, contains('does not expose an inline edit'));
    expect(administratorStaffReviewBoundary, contains('must not invent one'));
  });
}
