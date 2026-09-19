import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/principal/data/principal_attendance_demo_data.dart';
import 'package:schoolos_app/features/principal/domain/principal_attendance_models.dart';

void main() {
  test('website attendance seed preserves six class rows and exact totals', () {
    expect(principalAttendanceClasses.length, 6);
    expect(principalAttendanceTotalStudents, 238);
    expect(principalAttendancePresentStudents, 221);
    expect(principalAttendanceAbsentStudents, 9);
    expect(principalAttendanceLateStudents, 7);
    expect(principalAttendanceOverallRate, 93);
    expect(principalAttendanceClasses[2].className, 'JSS 2B');
    expect(principalAttendanceClasses[2].rate, 85);
    expect(principalAttendanceClasses[2].trend, -5.7);
    expect(principalAttendanceClasses[2].status, PrincipalAttendanceHealth.needsAttention);
  });

  test('website staff attendance preserves five rows and one late teacher', () {
    expect(principalAttendanceStaff.length, 5);
    expect(principalAttendanceStaffPresent, 4);
    expect(principalAttendanceStaffLate, 1);
    expect(principalAttendanceStaff[2].name, 'Mrs. Fatima Bello');
    expect(principalAttendanceStaff[2].punctuality, PrincipalAttendancePunctuality.late);
    expect(principalAttendanceStaff[3].name, 'Mr. Peter James');
    expect(principalAttendanceStaff[3].status, PrincipalAttendanceStaffStatus.absent);
  });

  test('website follow-up queue and weekly trend remain exact', () {
    expect(principalAttendanceFollowUps.length, 4);
    expect(principalAttendanceFollowUps.first.id, 'ATT-001');
    expect(principalAttendanceFollowUps.first.severity, PrincipalAttendanceSeverity.high);
    expect(principalAttendanceFollowUps[2].person, 'Mr. Peter James');
    expect(principalAttendanceWeekTrend.map((item) => item.rate).toList(), [94, 93, 92, 91, 93]);
  });

  test('offline extension includes palm and fingerprint scanners', () {
    expect(principalBiometricScanners.length, 3);
    expect(principalBiometricScanners.any((scanner) => scanner.modality == PrincipalBiometricModality.palm), isTrue);
    expect(principalBiometricScanners.any((scanner) => scanner.modality == PrincipalBiometricModality.fingerprint), isTrue);
    final pending = principalBiometricScanners.singleWhere((scanner) => scanner.id == 'SCN-FP-02');
    expect(pending.status, PrincipalScannerStatus.syncPending);
    expect(pending.pendingEvents, 12);
  });

  test('biometric attendance stores opaque template references, not raw images', () {
    expect(principalBiometricSeedEvents, isNotEmpty);
    for (final event in principalBiometricSeedEvents) {
      expect(event.templateReference, startsWith('tpl:'));
      expect(event.templateReference.toLowerCase(), isNot(contains('image')));
      expect(event.matchScore, inInclusiveRange(0, 1));
    }
    expect(principalAttendanceBiometricPrivacyRule, contains('not reusable raw fingerprint/palm images'));
  });

  test('biometric event serialization preserves local idempotency fields', () {
    const event = PrincipalBiometricAttendanceEvent(
      id: 'SCN-PALM-01-991',
      personReference: 'STU-001',
      personType: PrincipalAttendancePersonType.student,
      classOrRole: 'JSS 2A',
      scannerId: 'SCN-PALM-01',
      modality: PrincipalBiometricModality.palm,
      capturedAt: '2026-09-19T08:00:00+01:00',
      localSequence: 991,
      templateReference: 'tpl:student:STU-001:palm:v1',
      matchScore: 0.98,
      matchStatus: PrincipalBiometricMatchStatus.matched,
      synced: false,
    );
    final restored = PrincipalBiometricAttendanceEvent.fromJson(event.toJson());
    expect(restored.scannerId, 'SCN-PALM-01');
    expect(restored.localSequence, 991);
    expect(restored.templateReference, event.templateReference);
    expect(restored.synced, isFalse);
  });

  test('follow-up serialization preserves offline resolution audit fields', () {
    final resolved = principalAttendanceFollowUps.first.copyWith(
      resolved: true,
      resolvedAt: '2026-09-19T08:01:00Z',
      resolvedByMembershipId: 'membership-principal-001',
    );
    final restored = PrincipalAttendanceFollowUp.fromJson(resolved.toJson());
    expect(restored.resolved, isTrue);
    expect(restored.resolvedByMembershipId, 'membership-principal-001');
    expect(restored.resolvedAt, isNotNull);
  });

  test('offline integrity rules block cloud dependency and blind absence decisions', () {
    expect(principalAttendanceOfflineRule, contains('zero internet dependency'));
    expect(principalAttendanceOfflineRule, contains('sync is deferred'));
    expect(principalAttendanceIntegrityRule, contains('human review'));
    expect(principalAttendanceIntegrityRule, contains('unsynchronized attendance events'));
  });

  test('Principal attendance authority remains Secondary scoped', () {
    expect(principalAttendancePermissions.canViewSecondaryAttendance, isTrue);
    expect(principalAttendancePermissions.canResolveFollowUps, isTrue);
    expect(principalAttendancePermissions.canIngestOfflineBiometricEvents, isTrue);
    expect(principalAttendancePermissions.canManagePrimary, isFalse);
    expect(principalAttendanceScopeBoundary, contains('Secondary'));
    expect(principalAttendanceScopeBoundary, contains('Primary'));
  });
}
