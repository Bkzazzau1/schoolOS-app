import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/driver/data/driver_messages_repository.dart';
import 'package:schoolos_app/features/driver/domain/driver_messages_models.dart';
import 'package:schoolos_app/features/transport/data/transport_messages_repository.dart';
import 'package:schoolos_app/features/transport/data/transport_repository.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const admin = SchoolMembership(id: 'm-admin', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.administrator);
const principal = SchoolMembership(id: 'm-principal', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.principal);
const teacher = SchoolMembership(id: 'm-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);
const driver = SchoolMembership(id: 'membership-driver-009', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.driver);

void main() {
  LocalDatabase? db;
  late SchoolSessionController session;
  late TransportMessagesRepository transportMessages;
  late DriverMessagesRepository driverMessages;

  Future<void> setUpSchool() async {
    final database = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await database.initialize();
    db = database;
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([admin, principal, teacher, driver]);
    await session.selectSchool(admin);

    // A real route and a real, currently active assignment - the same shape a school's own
    // server would have published, not a fabricated seed.
    await database.upsertLocalRecord(
      tenantId: 'school-1',
      entityType: 'school_transport_route',
      entityId: 'BUS-09',
      payload: {
        'id': 'BUS-09', 'name': 'Bus 9', 'vehicle': 'Bus 9 - Toyota Hiace', 'driver': 'Unassigned',
        'assistant': '', 'riders': 0, 'stops': 0, 'morning': 'x', 'afternoon': 'x', 'status': 'preparing', 'note': '',
      },
      isDirty: false,
    );
    await database.upsertLocalRecord(
      tenantId: 'school-1',
      entityType: 'driver_transport_assignment',
      entityId: driver.id,
      payload: {'membershipId': driver.id, 'routeId': 'BUS-09', 'driverDisplayName': 'A Real Driver', 'staffId': '', 'active': true},
      isDirty: false,
    );

    final transport = TransportRepository(localDatabase: database, schoolSession: session);
    transportMessages = TransportMessagesRepository(localDatabase: database, schoolSession: session, transport: transport);
    driverMessages = DriverMessagesRepository(localDatabase: database, schoolSession: session);
  }

  tearDown(() => db?.close());

  test('threads are the real, currently assigned drivers - nothing fabricated', () async {
    await setUpSchool();
    final snapshot = await transportMessages.load();
    expect(snapshot.threads, hasLength(1));
    final thread = snapshot.threads.single;
    expect(thread.id, 'driver-thread-${driver.id}');
    expect(thread.participantName, 'A Real Driver');
    expect(thread.messages, isEmpty);
    expect(thread.preview, 'No messages yet');
    expect(snapshot.canReply, isTrue);
  });

  test('a read-only Principal can view the real thread but not reply', () async {
    await setUpSchool();
    await session.selectSchool(principal);
    final snapshot = await transportMessages.load();
    expect(snapshot.threads, hasLength(1));
    expect(snapshot.canReply, isFalse);
    expect(transportMessages.queueReply(threadId: snapshot.threads.single.id, body: 'Hello'), throwsStateError);
  });

  test('an unrelated role sees no transport messages at all', () async {
    await setUpSchool();
    await session.selectSchool(teacher);
    final snapshot = await transportMessages.load();
    expect(snapshot.threads, isEmpty);
    expect(snapshot.canReply, isFalse);
  });

  test('a Driver message and a Transport Control reply are each real to the other, on the exact same thread', () async {
    await setUpSchool();
    await session.selectSchool(driver);
    final driverQueued = await driverMessages.queueReply(threadId: 'driver-thread-${driver.id}', body: 'Running ten minutes late.');
    expect(driverQueued.authorLabel, 'You');

    await session.selectSchool(admin);
    final fromControlSide = await transportMessages.load();
    final thread = fromControlSide.threads.single;
    expect(thread.messages.single.body, 'Running ten minutes late.');
    expect(thread.messages.single.isDriverMessage, isTrue, reason: 'this message was really sent by the Driver');
    expect(thread.messages.single.authorLabel, 'Driver');

    await transportMessages.queueReply(threadId: thread.id, body: 'Noted, thank you.');

    await session.selectSchool(driver);
    final fromDriverSide = await driverMessages.load();
    final driverThread = fromDriverSide.threads.single;
    expect(driverThread.messages.length, 2);
    final reply = driverThread.messages.last;
    expect(reply.isDriverMessage, isFalse, reason: 'this message was really sent by Transport Control, not the Driver');
    expect(reply.authorLabel, 'Transport Control');
  });

  test('replying to an unknown thread or an empty/overlong body is rejected', () async {
    await setUpSchool();
    expect(transportMessages.queueReply(threadId: 'driver-thread-unknown', body: 'Hi'), throwsStateError);
    final snapshot = await transportMessages.load();
    final threadId = snapshot.threads.single.id;
    expect(() => transportMessages.queueReply(threadId: threadId, body: '   '), throwsArgumentError);
    expect(() => transportMessages.queueReply(threadId: threadId, body: 'x' * 2001), throwsArgumentError);
  });

  group('read receipts', () {
    test('a fresh thread is never unread', () async {
      await setUpSchool();
      final snapshot = await transportMessages.load();
      expect(snapshot.threads.single.unread, isFalse);
    });

    test('a real Driver message makes the thread unread for Transport Control until marked seen', () async {
      await setUpSchool();
      await session.selectSchool(driver);
      await driverMessages.queueReply(threadId: 'driver-thread-${driver.id}', body: 'Running ten minutes late.');

      await session.selectSchool(admin);
      final afterMessage = await transportMessages.load();
      final threadId = afterMessage.threads.single.id;
      expect(afterMessage.threads.single.unread, isTrue);

      await transportMessages.markThreadSeen(threadId);
      final afterSeen = await transportMessages.load();
      expect(afterSeen.threads.single.unread, isFalse);
    });

    test('Transport Control marking a thread seen never affects the Driver\'s own unread state, and vice versa', () async {
      await setUpSchool();
      await session.selectSchool(driver);
      await driverMessages.queueReply(threadId: 'driver-thread-${driver.id}', body: 'Running ten minutes late.');

      await session.selectSchool(admin);
      final threadId = (await transportMessages.load()).threads.single.id;
      await transportMessages.markThreadSeen(threadId);
      await transportMessages.queueReply(threadId: threadId, body: 'Noted, thank you.');

      await session.selectSchool(driver);
      final driverView = await driverMessages.load();
      expect(driverView.threads.single.unread, isTrue, reason: 'the Driver never marked Transport Control\'s new reply seen');
    });
  });

  group('operational alerts', () {
    test('no alert has been sent yet', () async {
      await setUpSchool();
      final snapshot = await transportMessages.load();
      expect(snapshot.alerts, isEmpty);
    });

    test('Transport Control can send a real alert and every real Driver receives it', () async {
      await setUpSchool();
      await transportMessages.queueAlert(
        title: 'Road closure',
        body: 'Market Road closed; use the bypass.',
        priority: DriverAlertPriority.urgent,
        scopeLabel: 'All Routes',
      );
      final fromControlSide = await transportMessages.load();
      expect(fromControlSide.alerts.single.title, 'Road closure');
      expect(fromControlSide.alerts.single.priority, DriverAlertPriority.urgent);

      await session.selectSchool(driver);
      final fromDriverSide = await driverMessages.load();
      expect(fromDriverSide.alerts.single.title, 'Road closure');
      expect(fromDriverSide.alerts.single.read, isFalse);
    });

    test('a read-only Principal cannot send an alert', () async {
      await setUpSchool();
      await session.selectSchool(principal);
      expect(
        transportMessages.queueAlert(
          title: 'Road closure', body: 'Market Road closed.', priority: DriverAlertPriority.routine, scopeLabel: '',
        ),
        throwsStateError,
      );
    });

    test('an empty title, empty body, or overlong body is rejected', () async {
      await setUpSchool();
      expect(
        () => transportMessages.queueAlert(title: '  ', body: 'y', priority: DriverAlertPriority.routine, scopeLabel: ''),
        throwsArgumentError,
      );
      expect(
        () => transportMessages.queueAlert(title: 'x', body: '  ', priority: DriverAlertPriority.routine, scopeLabel: ''),
        throwsArgumentError,
      );
      expect(
        () => transportMessages.queueAlert(title: 'x', body: 'y' * 2001, priority: DriverAlertPriority.routine, scopeLabel: ''),
        throwsArgumentError,
      );
    });

    test('an empty scope label defaults to "All Routes"', () async {
      await setUpSchool();
      await transportMessages.queueAlert(title: 'x', body: 'y', priority: DriverAlertPriority.routine, scopeLabel: '   ');
      final snapshot = await transportMessages.load();
      expect(snapshot.alerts.single.scopeLabel, 'All Routes');
    });
  });
}
