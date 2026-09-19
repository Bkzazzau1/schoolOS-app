import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/administrator/data/administrator_staff_demo_data.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_staff_models.dart';

void main() {
  test('website seed preserves four exact staff records', () {
    expect(administratorStaffWebsiteSeed, hasLength(4));

    final first = administratorStaffWebsiteSeed.first;
    expect(first.id, 'STAFF-001');
    expect(first.name, 'Mrs. Amina Yusuf');
    expect(first.role, 'Teacher');
    expect(first.section, 'Secondary');
    expect(first.fileStatus, AdministratorStaffFileStatus.complete);

    final primary = administratorStaffWebsiteSeed[1];
    expect(primary.id, 'STAFF-009');
    expect(primary.name, 'Mrs. Khadija Musa');
    expect(primary.role, 'Class Teacher');
    expect(primary.section, 'Primary');
  });

  test('directory has three complete files and one missing document', () {
    expect(administratorCompleteStaffFiles(), 3);
    expect(administratorStaffFilesNeedingAttention(), 1);

    final attention = administratorStaffWebsiteSeed.singleWhere(
      (item) => item.needsAttention,
    );
    expect(attention.id, 'STAFF-014');
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
    final original = administratorStaffWebsiteSeed[2];
    final restored = AdministratorStaffRecord.fromJson(original.toJson());
    expect(restored.id, 'STAFF-014');
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
