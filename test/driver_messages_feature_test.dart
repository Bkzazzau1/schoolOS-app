import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/driver/data/driver_dashboard_repository.dart';
import 'package:schoolos_app/features/driver/data/driver_messages_repository.dart';
import 'package:schoolos_app/features/driver/domain/driver_messages_models.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const driver = SchoolMembership(
  id: 'membership-driver-001',
  schoolId: 'school-1',
  schoolName: 'BrightGate',
  role: SchoolRole.driver,
);

void main() {
  LocalDatabase? db;
  late SchoolSessionController session;
  late DriverMessagesRepository messages;

  Future<void> setUpDriver() async {
    final database = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await database.initialize();
    db = database;
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([driver]);
    await session.selectSchool(driver);
    // The route and assignment exist first (a real school has them from the server).
    await DriverDashboardRepository(localDatabase: database, schoolSession: session).load();
    messages = DriverMessagesRepository(localDatabase: database, schoolSession: session);
  }

  tearDown(() => db?.close());

  test('a fresh Driver gets one real, empty channel to Transport Control, never a fabricated conversation', () async {
    await setUpDriver();
    final snapshot = await messages.load();
    expect(snapshot.threads, hasLength(1));
    final thread = snapshot.threads.single;
    expect(thread.approvedOperationalChannel, isTrue);
    expect(thread.messages, isEmpty);
    expect(thread.preview, 'No messages yet');
    expect(thread.participantName, 'Transport Control');
    expect(snapshot.routeId, isNotEmpty, reason: "still scoped to the Driver's real route");
  });

  test('operational alerts have no real backend yet and honestly stay empty', () async {
    await setUpDriver();
    final snapshot = await messages.load();
    expect(snapshot.alerts, isEmpty);
    expect(messages.markAlertRead('anything'), throwsStateError);
  });

  test('a queued message is real and persists across a reload', () async {
    await setUpDriver();
    final before = await messages.load();
    final threadId = before.threads.single.id;

    final queued = await messages.queueReply(threadId: threadId, body: 'Running ten minutes late.');
    expect(queued.direction, DriverMessageDirection.driverToSchool);
    expect(queued.state, DriverMessageState.queued);
    expect(queued.authorLabel, 'You');

    final after = await messages.load();
    final thread = after.threads.single;
    expect(thread.messages.single.body, 'Running ten minutes late.');
    expect(thread.preview, 'Running ten minutes late.');

    expect(db!.pendingCount(tenantId: driver.schoolId), greaterThan(0));
  });

  test('replying to an unknown channel or an empty/overlong body is rejected', () async {
    await setUpDriver();
    final before = await messages.load();
    final threadId = before.threads.single.id;
    expect(messages.queueReply(threadId: 'not-a-real-channel', body: 'Hello'), throwsStateError);
    expect(() => messages.queueReply(threadId: threadId, body: '   '), throwsArgumentError);
    expect(() => messages.queueReply(threadId: threadId, body: 'x' * 2001), throwsArgumentError);
  });

  test('only a Driver membership can load or reply to Driver messages', () async {
    await setUpDriver();
    const teacher = SchoolMembership(id: 'm-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);
    await session.setMemberships([driver, teacher]);
    await session.selectSchool(teacher);
    expect(messages.load(), throwsStateError);
  });
}
