import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/driver/data/driver_dashboard_repository.dart';
import 'package:schoolos_app/features/driver/data/driver_messages_repository.dart';
import 'package:schoolos_app/features/driver/domain/driver_dashboard_models.dart';
import 'package:schoolos_app/features/driver/domain/driver_messages_models.dart';
import 'package:schoolos_app/features/transport/data/transport_route_management_repository.dart';
import 'package:schoolos_app/features/transport/domain/transport_models.dart';
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
    // A real route and a real, active assignment linking this Driver to it - what a real
    // school's server-confirmed data would already have in place before a Driver ever opens
    // the app. Writing the raw records directly (rather than through TransportRepository's own
    // create/assign flow) keeps this focused on DriverMessagesRepository, the thing actually
    // under test here.
    const route = SchoolTransportRoute(
      id: 'BUS-02',
      name: 'Barnawa / Kakuri Route',
      vehicle: 'Toyota Hiace · BGA-02',
      driver: 'Driver',
      assistant: 'Not recorded yet',
      riders: 0,
      stops: 0,
      morning: 'Not started',
      afternoon: 'Not started',
      status: TransportRouteStatus.preparing,
      note: '',
    );
    await database.upsertLocalRecord(
      tenantId: driver.schoolId,
      entityType: TransportRouteManagementRepository.routeEntityType,
      entityId: route.id,
      payload: route.toJson(),
      isDirty: false,
    );
    const assignment = DriverTransportAssignment(
      membershipId: 'membership-driver-001',
      routeId: 'BUS-02',
      driverDisplayName: 'Driver',
    );
    await database.upsertLocalRecord(
      tenantId: driver.schoolId,
      entityType: DriverDashboardRepository.assignmentEntityType,
      entityId: assignment.membershipId,
      payload: assignment.toJson(),
      isDirty: false,
    );
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

  group('operational alerts', () {
    Map<String, Object?> alertPayload(String id, {String priority = 'important', String createdAt = ''}) => {
          'id': id,
          'title': 'Road closure',
          'body': 'Market Road closed; use the bypass.',
          'priority': priority,
          'scopeLabel': 'All Routes',
          'createdAt': createdAt.isEmpty ? DateTime.now().toUtc().toIso8601String() : createdAt,
          'senderMembershipId': 'm-admin',
        };

    test('a fresh Driver has no fabricated alerts', () async {
      await setUpDriver();
      final snapshot = await messages.load();
      expect(snapshot.alerts, isEmpty);
    });

    test('a real alert from Transport Control is read, never fabricated', () async {
      await setUpDriver();
      // The exact canonical shape a real sync pull would write for a real alert.
      await db!.upsertLocalRecord(
        tenantId: driver.schoolId,
        entityType: 'driver_alert',
        entityId: 'ALERT-1',
        payload: alertPayload('ALERT-1'),
        isDirty: false,
      );
      final snapshot = await messages.load();
      final alert = snapshot.alerts.single;
      expect(alert.title, 'Road closure');
      expect(alert.priority, DriverAlertPriority.important);
      expect(alert.read, isFalse);
      expect(snapshot.unreadAlerts, 1);
    });

    test('marking a real alert read queues a real receipt and persists', () async {
      await setUpDriver();
      await db!.upsertLocalRecord(
        tenantId: driver.schoolId,
        entityType: 'driver_alert',
        entityId: 'ALERT-1',
        payload: alertPayload('ALERT-1'),
        isDirty: false,
      );
      await messages.markAlertRead('ALERT-1');
      final after = await messages.load();
      expect(after.alerts.single.read, isTrue);
      expect(after.unreadAlerts, 0);
      expect(db!.pendingCount(tenantId: driver.schoolId), greaterThan(0), reason: 'a real receipt was queued');
    });

    test('marking an unknown alert id is refused', () async {
      await setUpDriver();
      expect(messages.markAlertRead('ghost'), throwsStateError);
    });

    test('marking an already-read alert again is a harmless no-op', () async {
      await setUpDriver();
      await db!.upsertLocalRecord(
        tenantId: driver.schoolId,
        entityType: 'driver_alert',
        entityId: 'ALERT-1',
        payload: alertPayload('ALERT-1'),
        isDirty: false,
      );
      await messages.markAlertRead('ALERT-1');
      final pendingAfterFirst = db!.pendingCount(tenantId: driver.schoolId);
      await messages.markAlertRead('ALERT-1');
      expect(db!.pendingCount(tenantId: driver.schoolId), pendingAfterFirst);
    });

    test('alerts show newest first', () async {
      await setUpDriver();
      await db!.upsertLocalRecord(
        tenantId: driver.schoolId,
        entityType: 'driver_alert',
        entityId: 'OLD',
        payload: alertPayload('OLD', createdAt: '2026-01-01T00:00:00Z'),
        isDirty: false,
      );
      await db!.upsertLocalRecord(
        tenantId: driver.schoolId,
        entityType: 'driver_alert',
        entityId: 'NEW',
        payload: alertPayload('NEW', createdAt: '2026-02-01T00:00:00Z'),
        isDirty: false,
      );
      final snapshot = await messages.load();
      expect(snapshot.alerts.map((a) => a.id).toList(), ['NEW', 'OLD']);
    });
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

  group('read receipts', () {
    test('a fresh channel with no messages is never unread', () async {
      await setUpDriver();
      final snapshot = await messages.load();
      expect(snapshot.threads.single.unread, isFalse);
    });

    test('my own message never makes my own view unread', () async {
      await setUpDriver();
      final threadId = (await messages.load()).threads.single.id;
      await messages.queueReply(threadId: threadId, body: 'Running ten minutes late.');
      expect((await messages.load()).threads.single.unread, isFalse);
    });

    test('a real reply from Transport Control makes the channel unread until marked seen', () async {
      await setUpDriver();
      final threadId = (await messages.load()).threads.single.id;

      // The exact canonical shape a real sync pull would write for a real Transport Control reply.
      await db!.upsertLocalRecord(
        tenantId: driver.schoolId,
        entityType: 'driver_message',
        entityId: 'MSG-FROM-CONTROL',
        payload: {
          'messageId': 'MSG-FROM-CONTROL',
          'threadId': threadId,
          'body': 'Please confirm the afternoon vehicle check.',
          'senderRole': 'administrator',
          'senderMembershipId': 'm-admin',
          'receivedAt': DateTime.now().toUtc().toIso8601String(),
        },
        isDirty: false,
      );

      final afterReply = await messages.load();
      expect(afterReply.threads.single.unread, isTrue);
      expect(afterReply.unreadThreads, 1);

      await messages.markThreadSeen(threadId);
      final afterSeen = await messages.load();
      expect(afterSeen.threads.single.unread, isFalse);
      expect(db!.pendingCount(tenantId: driver.schoolId), greaterThan(0), reason: 'a real receipt was queued');
    });

    test('marking an already-read channel seen again is a harmless no-op', () async {
      await setUpDriver();
      final threadId = (await messages.load()).threads.single.id;
      await messages.markThreadSeen(threadId);
      expect(db!.pendingCount(tenantId: driver.schoolId), 0, reason: 'no receipt should be queued when nothing is unread');
    });
  });
}
