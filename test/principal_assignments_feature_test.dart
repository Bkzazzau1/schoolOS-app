import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/principal/data/principal_assignments_demo_data.dart';
import 'package:schoolos_app/features/principal/domain/principal_assignments_models.dart';

void main() {
  test('website assignment seed preserves six teachers and eight assignments', () {
    expect(principalAssignmentTeachers.length, 6);
    expect(principalAssignmentSeed.length, 8);
    expect(principalAssignmentTeachers.first.name, 'Mrs. Amina Yusuf');
    expect(principalAssignmentTeachers.last.name, 'Mr. Samuel Bello');
    expect(principalAssignmentSeed.first.className, 'JSS 1A');
    expect(principalAssignmentSeed.last.subject, 'Computer Studies');
  });

  test('website unassigned list preserves three exact class-subject gaps', () {
    expect(principalUnassignedSubjects.length, 3);
    expect(principalUnassignedSubjects[0].className, 'JSS 2B');
    expect(principalUnassignedSubjects[0].subject, 'Mathematics');
    expect(principalUnassignedSubjects[1].subject, 'Further Mathematics');
    expect(principalUnassignedSubjects[2].subject, 'Literature');
  });

  test('website teacher qualification and heavy-load behavior are preserved', () {
    expect(principalAssignmentTeachers.where((teacher) => teacher.weeklyPeriods > 24).single.name, 'Mrs. Fatima Bello');
    expect(principalAssignmentTeachers.first.canTeach('Further Mathematics'), isTrue);
    expect(principalAssignmentTeachers.first.canTeach('Physics'), isFalse);
    expect(principalAssignmentTeachers[3].canTeach('Physics'), isTrue);
  });

  test('assignment serialization preserves teacher and version lineage', () {
    const assignment = PrincipalTeachingAssignment(
      id: 'ASN-X',
      className: 'JSS 2B',
      subject: 'Mathematics',
      teacherId: 'TCH-001',
      periodsPerWeek: 5,
      version: 3,
    );
    final restored = PrincipalTeachingAssignment.fromJson(assignment.toJson());
    expect(restored.teacherId, 'TCH-001');
    expect(restored.version, 3);
    final transferred = restored.copyWith(teacherId: 'TCH-002', version: 4);
    expect(transferred.teacherId, 'TCH-002');
    expect(transferred.version, 4);
    expect(restored.teacherId, 'TCH-001');
  });

  test('transfer event preserves old and new teacher rather than overwriting history', () {
    const transfer = PrincipalAssignmentTransfer(
      id: 'TRN-1',
      assignmentId: 'ASN-003',
      className: 'JSS 2A',
      subject: 'Mathematics',
      fromTeacherId: 'TCH-001',
      toTeacherId: 'TCH-002',
      reason: 'Workload balancing',
      transferredByMembershipId: 'membership-principal-001',
      transferredAt: '2026-09-19T12:00:00Z',
      recordScope: principalTransferRecordScope,
      previousAssignmentVersion: 1,
      newAssignmentVersion: 2,
    );
    final restored = PrincipalAssignmentTransfer.fromJson(transfer.toJson());
    expect(restored.fromTeacherId, 'TCH-001');
    expect(restored.toTeacherId, 'TCH-002');
    expect(restored.previousAssignmentVersion, 1);
    expect(restored.newAssignmentVersion, 2);
  });

  test('incoming teacher receives complete teaching-work continuity scope', () {
    expect(principalTransferRecordScope.length, 6);
    expect(principalTransferRecordScope.join(' '), contains('Lesson plans'));
    expect(principalTransferRecordScope.join(' '), contains('Syllabus'));
    expect(principalTransferRecordScope.join(' '), contains('Assessment'));
    expect(principalTransferRecordScope.join(' '), contains('Class teaching notes'));
    expect(principalTransferRecordScope.join(' '), contains('Timetable'));
    expect(principalTransferRecordScope.join(' '), contains('Assignment history'));
  });

  test('record access grant can target existing or provisional staff', () {
    const grant = PrincipalTeachingRecordAccess(
      id: 'ACCESS-ASN-003-PST-1',
      assignmentId: 'ASN-003',
      teacherId: 'PST-1',
      className: 'JSS 2A',
      subject: 'Mathematics',
      recordScope: principalTransferRecordScope,
      grantedByMembershipId: 'membership-principal-001',
      grantedAt: '2026-09-19T12:00:00Z',
      provisionalTarget: true,
    );
    final restored = PrincipalTeachingRecordAccess.fromJson(grant.toJson());
    expect(restored.provisionalTarget, isTrue);
    expect(restored.recordScope, principalTransferRecordScope);
  });

  test('transfer privacy boundary excludes previous teacher private records', () {
    expect(principalTransferPrivacyBoundary, contains('private leadership notes'));
    expect(principalTransferPrivacyBoundary, contains('payroll'));
    expect(principalTransferPrivacyBoundary, contains('bank'));
    expect(principalTransferPrivacyBoundary, contains('medical'));
    expect(principalTransferPrivacyBoundary, contains('unrelated HR'));
  });

  test('Principal assignment permissions remain Secondary scoped', () {
    expect(principalAssignmentPermissions.canManageSecondaryAssignments, isTrue);
    expect(principalAssignmentPermissions.canTransferWork, isTrue);
    expect(principalAssignmentPermissions.canCreateProvisionalTargets, isTrue);
    expect(principalAssignmentPermissions.canManagePrimary, isFalse);
    expect(principalAssignmentScopeBoundary, contains('Secondary School'));
    expect(principalAssignmentScopeBoundary, contains('Primary'));
  });
}
