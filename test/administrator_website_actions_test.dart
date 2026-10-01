import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_website_repository.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_website_models.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const admin = SchoolMembership(id: 'm-admin', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.administrator);
const teacher = SchoolMembership(id: 'm-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;
  late AdministratorWebsiteRepository website;

  Future<void> setUpSchool([SchoolMembership who = admin]) async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([admin, teacher]);
    await session.selectSchool(who);
    website = AdministratorWebsiteRepository(localDatabase: db, schoolSession: session);
  }

  tearDown(() => db.close());

  test('a fresh school has no real homepage settings yet, not a fabricated headline', () async {
    await setUpSchool();
    final snapshot = await website.load();
    expect(snapshot.settings.heroHeadline, isEmpty);
    expect(snapshot.settings.heroSupportingText, isEmpty);
    expect(snapshot.settings.admissionsOpen, isFalse);
    expect(snapshot.settings.admissionSession, isEmpty);
  });

  test('saving real homepage settings round-trips and queues for sync', () async {
    await setUpSchool();
    const settings = AdministratorWebsiteSettings(
      heroHeadline: 'Welcome to BrightGate',
      heroSupportingText: 'A real school, a real website.',
      admissionsOpen: true,
      admissionSession: '2026/2027',
    );
    final result = await website.save(settings);
    expect(result.success, isTrue, reason: result.message);

    final reloaded = await website.load();
    expect(reloaded.settings.heroHeadline, 'Welcome to BrightGate');
    expect(reloaded.settings.heroSupportingText, 'A real school, a real website.');
    expect(reloaded.settings.admissionsOpen, isTrue);
    expect(db.pendingCount(tenantId: admin.schoolId), greaterThan(0));
  });

  test('a blank headline or supporting text is refused', () async {
    await setUpSchool();
    const blankHeadline = AdministratorWebsiteSettings(
      heroHeadline: '  ', heroSupportingText: 'Real text', admissionsOpen: true, admissionSession: '2026/2027',
    );
    expect((await website.save(blankHeadline)).success, isFalse);
    final unchanged = await website.load();
    expect(unchanged.settings.heroHeadline, isEmpty);
  });

  test('only the administrator may manage public website settings', () async {
    await setUpSchool(teacher);
    const settings = AdministratorWebsiteSettings(
      heroHeadline: 'Welcome', heroSupportingText: 'Text', admissionsOpen: true, admissionSession: '2026/2027',
    );
    final result = await website.save(settings);
    expect(result.success, isFalse);
    expect(result.message, contains('cannot manage'));
  });
}
