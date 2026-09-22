import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';
import 'package:schoolos_app/features/principal/data/principal_communication_repository.dart';
import 'package:schoolos_app/features/principal/domain/principal_communication_models.dart';
import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const principal = SchoolMembership(
  id: 'p',
  schoolId: 's',
  schoolName: 'School',
  role: SchoolRole.principal,
);
void main() {
  LocalDatabase? db;
  late SchoolSessionController session;
  late PrincipalCommunicationRepository repo;
  Future<void> setup([SchoolMembership member = principal]) async {
    db = LocalDatabase(
      cipher: PayloadCipher(secureStorage: MemorySecureStorage()),
      databasePath: ':memory:',
    );
    await db!.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([member]);
    await session.selectSchool(member);
    repo = PrincipalCommunicationRepository(
      localDatabase: db!,
      schoolSession: session,
    );
  }

  tearDown(() => db?.close());

  Future<PrincipalCommunicationActionResult> queue({
    PrincipalCommunicationAudience audience =
        PrincipalCommunicationAudience.staff,
    String subject = 'Notice',
    String message = 'Meeting',
    PrincipalCommunicationChannel channel =
        PrincipalCommunicationChannel.portal,
  }) => repo.queueAnnouncement(
    audience: audience,
    channel: channel,
    subject: subject,
    message: message,
  );
  test(
    'fresh inbox has no fabricated conversations or delivery metrics',
    () async {
      await setup();
      final s = await repo.load();
      expect(s.threads, isEmpty);
      expect(s.announcements, isEmpty);
      expect(s.followUps, isEmpty);
      expect(s.unreadCount, 0);
    },
  );
  test(
    'saved announcement reloads with real content and unconfirmed delivery',
    () async {
      await setup();
      expect((await queue()).success, isTrue);
      final s = await repo.load();
      expect(s.queuedCount, 1);
      expect(s.outgoing.single.message, 'Meeting');
      expect(s.announcements.single.title, 'Notice');
      expect(s.announcements.single.delivered, 'Not confirmed');
      expect(s.announcements.single.read, 'Not recorded');
    },
  );
  for (final audience in [
    PrincipalCommunicationAudience.classGuardians,
    PrincipalCommunicationAudience.individual,
    PrincipalCommunicationAudience.wholeSchool,
  ]) {
    test('unconnected recipient scope ${audience.name} rejected', () async {
      await setup();
      expect((await queue(audience: audience)).success, isFalse);
      expect((await repo.load()).outgoing, isEmpty);
    });
  }
  test('blank content rejected', () async {
    await setup();
    expect((await queue(subject: ' ')).success, isFalse);
    expect((await queue(message: ' ')).success, isFalse);
  });
  test('external channels never claim delivery', () async {
    await setup();
    await queue(channel: PrincipalCommunicationChannel.sms);
    expect(
      (await repo.load()).outgoing.single.deliveryState,
      PrincipalDeliveryState.queued,
    );
  });
  test('old fabricated inbox record cannot be replied to', () async {
    await setup();
    await db!.upsertLocalRecord(
      tenantId: 's',
      entityType: 'principal_communication_thread',
      entityId: 'MSG-201',
      payload: {'id': 'MSG-201'},
    );
    expect((await repo.load()).threads, isEmpty);
    expect(
      (await repo.queueReply(threadId: 'MSG-201', message: 'Reply')).success,
      isFalse,
    );
  });
  test(
    'other principal in same school cannot read private outgoing content',
    () async {
      await setup();
      await queue();
      const other = SchoolMembership(
        id: 'other',
        schoolId: 's',
        schoolName: 'School',
        role: SchoolRole.principal,
      );
      await session.setMemberships([principal, other]);
      await session.selectSchool(other);
      expect((await repo.load()).outgoing, isEmpty);
    },
  );
  test('other school cannot read outgoing content', () async {
    await setup();
    await queue();
    const other = SchoolMembership(
      id: 'other',
      schoolId: 'other',
      schoolName: 'Other',
      role: SchoolRole.principal,
    );
    await session.setMemberships([principal, other]);
    await session.selectSchool(other);
    expect((await repo.load()).outgoing, isEmpty);
  });
  test('nonprincipal cannot queue or read messages', () async {
    await setup(
      const SchoolMembership(
        id: 't',
        schoolId: 's',
        schoolName: 'School',
        role: SchoolRole.teacher,
      ),
    );
    expect((await queue()).success, isFalse);
    expect((await repo.load()).outgoing, isEmpty);
  });
}
