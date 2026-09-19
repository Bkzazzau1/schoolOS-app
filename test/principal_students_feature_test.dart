import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/principal/data/principal_students_demo_data.dart';
import 'package:schoolos_app/features/principal/domain/principal_students_models.dart';

void main() {
  test('website student oversight preserves six exact Secondary rows', () {
    expect(principalStudentSummaries.length, 6);
    expect(principalStudentSummaries.first.id, 'STU-001');
    expect(principalStudentSummaries.first.name, 'Maryam Abdullahi');
    expect(principalStudentSummaries[2].name, 'Yusuf Bello');
    expect(principalStudentSummaries.last.name, 'Zainab Aliyu');
  });

  test('website headline risk counts are preserved', () {
    expect(principalStudentSummaries.where((s) => s.risk == PrincipalStudentRisk.atRisk).length, 1);
    expect(principalStudentSummaries.where((s) => s.risk == PrincipalStudentRisk.watch).length, 1);
    expect(principalStudentSummaries.where((s) => s.attendance < 85).length, 1);
    expect(principalStudentSummaries.where((s) => s.behaviour == PrincipalStudentBehaviour.needsAttention).length, 1);
  });

  test('Yusuf remains the strongest combined intervention signal', () {
    final yusuf = principalStudentSummaries.singleWhere((s) => s.id == 'STU-003');
    expect(yusuf.average, 48);
    expect(yusuf.attendance, 79);
    expect(yusuf.trend, -8.4);
    expect(yusuf.incidents, 2);
    expect(yusuf.interventions, 2);
    expect(yusuf.risk, PrincipalStudentRisk.atRisk);
  });

  test('student summary serialization preserves oversight evidence', () {
    final source = principalStudentSummaries[1];
    final restored = PrincipalStudentSummary.fromJson(source.toJson());
    expect(restored.id, 'STU-002');
    expect(restored.average, 61);
    expect(restored.attendance, 88);
    expect(restored.risk, PrincipalStudentRisk.watch);
  });

  test('full student profile exposes all eleven website tabs', () {
    expect(principalStudentProfileTabs.length, 11);
    expect(principalStudentProfileTabs.first, 'Overview');
    expect(principalStudentProfileTabs, contains('Status & Promotion'));
    expect(principalStudentProfileTabs.last, 'Notes');
  });

  test('Maryam detailed profile preserves website identity and evidence', () {
    final profile = principalStudentProfileFor(principalStudentSummaries.first);
    expect(profile.admissionNo, 'BGA/2023/SEC/001');
    expect(profile.classTeacher, 'Mrs. Amina Yusuf');
    expect(profile.familyAccountId, 'FAM-ABD-0041');
    expect(profile.subjects.first.score, 88);
    expect(profile.attendanceSummary.first.value, '96%');
    expect(profile.documents.length, 3);
  });

  test('Yusuf detailed profile preserves intervention and privacy context', () {
    final profile = principalStudentProfileFor(principalStudentSummaries[2]);
    expect(profile.admissionNo, 'BGA/2023/SEC/003');
    expect(profile.classTeacher, 'Mr. Sani Bello');
    expect(profile.subjects.first.score, 42);
    expect(profile.attendanceSummary.last.value, '6');
    expect(profile.medicalInstruction, contains('No diagnosis'));
    expect(profile.timeline.last.visibility, 'Leadership only');
  });

  test('generated profile keeps directory evidence consistent', () {
    final source = principalStudentSummaries.singleWhere((s) => s.id == 'STU-005');
    final profile = principalStudentProfileFor(source);
    expect(profile.summary.name, 'Abdullahi Umar');
    expect(profile.summary.className, 'SS 1A');
    expect(profile.summary.average, 68);
    expect(profile.summary.attendance, 91);
    expect(profile.classTeacher, 'Mr. Umar Faruq');
  });

  test('student profile serialization preserves lifecycle-safe records', () {
    final source = principalStudentProfileFor(principalStudentSummaries[2]);
    final restored = PrincipalStudentProfile.fromJson(source.toJson());
    expect(restored.summary.id, 'STU-003');
    expect(restored.enrollmentStatus, PrincipalStudentEnrollmentStatus.active);
    expect(restored.promotionHistory.length, 2);
    expect(restored.documents.first.visibility, 'Leadership + Records');
  });

  test('Principal student authority remains Secondary and finance restricted', () {
    expect(principalStudentPermissions.canViewSecondaryStudents, isTrue);
    expect(principalStudentPermissions.canAddLeadershipNote, isTrue);
    expect(principalStudentPermissions.canCreateLifecycleProposal, isTrue);
    expect(principalStudentPermissions.canManagePrimary, isFalse);
    expect(principalStudentPermissions.canViewConfidentialFinance, isFalse);
    expect(principalStudentsScopeBoundary, contains('Secondary School'));
    expect(principalStudentsScopeBoundary, contains('Primary'));
  });

  test('notes, lifecycle, health and AI boundaries prevent silent high-impact actions', () {
    expect(principalStudentNoteBoundary, contains('internal'));
    expect(principalStudentNoteBoundary, contains('guardian'));
    expect(principalStudentLifecycleBoundary, contains('append-only'));
    expect(principalStudentLifecycleBoundary, contains('not silently overwritten'));
    expect(principalStudentHealthBoundary, contains('never be used to infer a diagnosis'));
    expect(principalStudentAiBoundary, contains('must not automatically'));
    expect(principalStudentAiBoundary, contains('punish'));
  });
}
