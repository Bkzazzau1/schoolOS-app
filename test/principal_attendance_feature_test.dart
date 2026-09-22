import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_attendance_repository.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/principal/data/principal_attendance_demo_data.dart';
import 'package:schoolos_app/features/principal/data/principal_attendance_repository.dart';
import 'package:schoolos_app/features/principal/domain/principal_attendance_models.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const principal = SchoolMembership(id: 'm-principal', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.principal);
const teacher = SchoolMembership(id: 'm-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

void main() {
  LocalDatabase? db;
  late SchoolSessionController session;
  late PrincipalAttendanceRepository principalAttendance;

  Future<void> setUpSchool([SchoolMembership who = principal]) async {
    final database = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await database.initialize();
    db = database;
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([principal, teacher]);
    await session.selectSchool(who);
    principalAttendance = PrincipalAttendanceRepository(
      localDatabase: database,
      schoolSession: session,
      students: AdministratorStudentsRepository(localDatabase: database, schoolSession: session),
      attendance: AdministratorAttendanceRepository(localDatabase: database, schoolSession: session),
    );
  }

  tearDown(() => db?.close());

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

  test('offline integrity rules block cloud dependency and blind absence decisions', () {
    expect(principalAttendanceOfflineRule, contains('zero internet dependency'));
    expect(principalAttendanceOfflineRule, contains('sync is deferred'));
    expect(principalAttendanceIntegrityRule, contains('human review'));
    expect(principalAttendanceIntegrityRule, contains('unsynchronized attendance events'));
  });

  test('Principal attendance authority remains Secondary scoped', () {
    expect(principalAttendanceScopeBoundary, contains('Secondary'));
    expect(principalAttendanceScopeBoundary, contains('Primary'));
  });

  test('class attendance is real, computed from the real register and today\'s real gate-scan events, Secondary only', () async {
    await setUpSchool();
    final snapshot = await principalAttendance.load();
    expect(snapshot.classes, isNotEmpty);
    // The real register's Primary/Nursery classes must never appear here.
    expect(snapshot.classes.any((c) => c.className.toLowerCase().startsWith('primary')), isFalse);
    expect(snapshot.classes.any((c) => c.className.toLowerCase().startsWith('nursery')), isFalse);
    for (final row in snapshot.classes) {
      expect(row.present + row.absent + row.excused, row.total);
      expect(row.rate, inInclusiveRange(0, 100));
      expect(row.trend, 0, reason: 'the real source only keeps today\'s record, so there is no real day-over-day trend yet');
    }
    // classes are sorted and unique.
    final names = snapshot.classes.map((c) => c.className).toList();
    expect(names, names.toSet().toList()..sort());
  });

  test('staff attendance and follow-ups are honestly empty: no real per-day feed or multi-day history exists yet', () async {
    await setUpSchool();
    final snapshot = await principalAttendance.load();
    expect(snapshot.staff, isEmpty);
    expect(snapshot.followUps, isEmpty);
  });

  test('resolving a follow-up is refused honestly since none are real yet', () async {
    await setUpSchool();
    final result = await principalAttendance.resolveFollowUp('ATT-001');
    expect(result.success, isFalse);
  });

  test('a valid offline biometric match is accepted and queued for sync', () async {
    await setUpSchool();
    await principalAttendance.load(); // seeds the scanners
    final result = await principalAttendance.ingestOfflineBiometricMatch(
      scannerId: 'SCN-PALM-01',
      localSequence: 5000,
      personType: PrincipalAttendancePersonType.student,
      personReference: 'STU-001',
      classOrRole: 'JSS 2A',
      templateReference: 'tpl:student:STU-001:palm:v2',
      matchScore: 0.97,
      capturedAt: '2026-09-20T07:30:00+01:00',
    );
    expect(result.success, isTrue, reason: result.message);
    expect(db!.pendingCount(tenantId: principal.schoolId), greaterThan(0));
  });

  test('a raw image reference is refused', () async {
    await setUpSchool();
    await principalAttendance.load(); // seeds the scanners
    final result = await principalAttendance.ingestOfflineBiometricMatch(
      scannerId: 'SCN-PALM-01',
      localSequence: 5001,
      personType: PrincipalAttendancePersonType.student,
      personReference: 'STU-001',
      classOrRole: 'JSS 2A',
      templateReference: 'raw-image-data',
      matchScore: 0.97,
      capturedAt: '2026-09-20T07:30:00+01:00',
    );
    expect(result.success, isFalse);
  });

  test('only the principal has Secondary attendance authority', () async {
    await setUpSchool(teacher);
    final result = await principalAttendance.resolveFollowUp('ATT-001');
    expect(result.success, isFalse);
  });
}
