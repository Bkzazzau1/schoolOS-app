import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_attendance_desk.dart' show sectionOfClass;
import 'package:schoolos_app/features/administrator/data/administrator_attendance_repository.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_students_models.dart';
import 'package:schoolos_app/features/finance_office/data/finance_ledger_repository.dart';
import 'package:schoolos_app/features/parent/data/parent_children_repository.dart';
import 'package:schoolos_app/features/parent/data/parent_messages_repository.dart';
import 'package:schoolos_app/features/administrator/data/administrator_staff_repository.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_staff_models.dart';
import 'package:schoolos_app/features/proprietor/data/concession_repository.dart';
import 'package:schoolos_app/features/proprietor/data/owner_staff_profile_repository.dart';
import 'package:schoolos_app/features/proprietor/domain/owner_staff_profile_models.dart';
import 'package:schoolos_app/features/teacher/data/teacher_messages_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_roster.dart';
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

  const parent = SchoolMembership(id: 'm-parent', schoolId: 's', schoolName: 'School', role: SchoolRole.parent);

  test('a portal announcement to guardians really reaches every real Secondary family', () async {
    await setup();
    final register = (await AdministratorStudentsRepository(localDatabase: db!, schoolSession: session).load()).students;
    final secondaryCount = register
        .where((s) => s.status == AdministratorStudentStatus.active && sectionOfClass(s.className) == 'Secondary')
        .length;
    expect(secondaryCount, greaterThan(0));

    final result = await queue(audience: PrincipalCommunicationAudience.guardians, message: 'PTA meeting Friday.');
    expect(result.success, isTrue, reason: result.message);
    expect(result.message, contains('Queued for $secondaryCount real Secondary famil'));
    // One real parent_message per real Secondary family, plus the Principal's own local
    // principal_outgoing_communication "sent" record.
    expect(db!.pendingCount(tenantId: 's'), secondaryCount + 1);
  });

  test('a portal announcement to guardians with no Secondary students on the register is refused', () async {
    await setup();
    LocalDatabase.blockDemoSeeds = true;
    addTearDown(() => LocalDatabase.blockDemoSeeds = false);
    final result = await queue(audience: PrincipalCommunicationAudience.guardians);
    expect(result.success, isFalse);
    expect(result.message, contains('No Secondary students'));
  });

  test('a non-portal channel to guardians stays local-only, not a real send', () async {
    await setup();
    final result = await queue(audience: PrincipalCommunicationAudience.guardians, channel: PrincipalCommunicationChannel.sms);
    expect(result.success, isTrue, reason: result.message);
    expect(db!.pendingCount(tenantId: 's'), 1, reason: 'only the local principal_outgoing_communication record, no real parent_message fan-out');
  });

  test('a real guardian announcement really lands in a real guardian\'s own Parent Messages thread', () async {
    await setup();
    final result = await queue(audience: PrincipalCommunicationAudience.guardians, message: 'PTA meeting Friday.');
    expect(result.success, isTrue, reason: result.message);

    await session.setMemberships([principal, parent]);
    await session.selectSchool(parent);
    final students = AdministratorStudentsRepository(localDatabase: db!, schoolSession: session);
    final children = ParentChildrenRepository(
      localDatabase: db!,
      schoolSession: session,
      students: students,
      attendance: AdministratorAttendanceRepository(localDatabase: db!, schoolSession: session),
      ledger: FinanceLedgerRepository(
        database: db!,
        session: session,
        students: students,
        concessions: ConcessionRepository(localDatabase: db!, schoolSession: session),
      ),
    );
    final parentMessages = ParentMessagesRepository(localDatabase: db!, schoolSession: session, children: children);
    final snapshot = await parentMessages.load();
    final maryamThread = snapshot.threadById('channel-STU-001')!;
    expect(maryamThread.messages.single.body, 'PTA meeting Friday.');
    expect(maryamThread.messages.single.authorLabel, 'Principal');
  });

  group('school leadership reply-thread inbox', () {
    const teacher = SchoolMembership(id: 'm-teacher', schoolId: 's', schoolName: 'School', role: SchoolRole.teacher);
    final leadershipThreadId = 'leadership-thread-${teacher.id}';

    Future<TeacherMessagesRepository> setUpTeacher() async {
      await session.setMemberships([principal, teacher]);
      final students = AdministratorStudentsRepository(localDatabase: db!, schoolSession: session);
      final roster = TeacherRoster(database: db!, session: session, students: students);
      return TeacherMessagesRepository(localDatabase: db!, schoolSession: session, roster: roster);
    }

    test('an inbox with no real leadership messages stays honestly empty', () async {
      await setup();
      expect((await repo.load()).threads, isEmpty);
    });

    test("a real teacher's leadership message really reaches the Principal's own inbox", () async {
      await setup();
      final teacherMessages = await setUpTeacher();
      await session.selectSchool(teacher);
      await teacherMessages.queueMessage(threadId: leadershipThreadId, body: 'Requesting guidance on a parent concern.');

      await session.selectSchool(principal);
      final snapshot = await repo.load();
      final thread = snapshot.threads.singleWhere((t) => t.id == leadershipThreadId);
      expect(thread.messages.single.body, 'Requesting guidance on a parent concern.');
      expect(thread.messages.single.isOutgoing, isFalse, reason: 'from the Principal\'s own side, this was the teacher\'s message');
    });

    test('the Principal\'s own reply really reaches the real teacher\'s own Teacher Messages thread', () async {
      await setup();
      final teacherMessages = await setUpTeacher();
      await session.selectSchool(teacher);
      await teacherMessages.queueMessage(threadId: leadershipThreadId, body: 'Requesting guidance on a parent concern.');

      await session.selectSchool(principal);
      final result = await repo.queueReply(threadId: leadershipThreadId, message: "Let's discuss tomorrow morning.");
      expect(result.success, isTrue, reason: result.message);

      await session.selectSchool(teacher);
      final teacherSnapshot = await teacherMessages.load();
      final teacherThreadMessages = teacherSnapshot.messagesForThread(leadershipThreadId);
      expect(teacherThreadMessages.last.body, "Let's discuss tomorrow morning.");
      expect(teacherThreadMessages.last.isOutgoing, isFalse, reason: 'from the teacher\'s own side, this was the Principal\'s message');
    });

    test('a real teacher message makes the thread unread for the Principal until marked seen', () async {
      await setup();
      final teacherMessages = await setUpTeacher();
      await session.selectSchool(teacher);
      await teacherMessages.queueMessage(threadId: leadershipThreadId, body: 'Requesting guidance on a parent concern.');

      await session.selectSchool(principal);
      final before = await repo.load();
      expect(before.threads.singleWhere((t) => t.id == leadershipThreadId).unread, isTrue);
      expect(before.unreadCount, 1);

      await repo.markThreadSeen(leadershipThreadId);
      final after = await repo.load();
      expect(after.threads.singleWhere((t) => t.id == leadershipThreadId).unread, isFalse);
    });

    test('a thread shows the real teacher\'s real name from the real staff directory', () async {
      await setup();
      final teacherMessages = await setUpTeacher();
      await session.selectSchool(teacher);
      await teacherMessages.queueMessage(threadId: leadershipThreadId, body: 'Hello');

      await db!.upsertLocalRecord(
        tenantId: 's',
        entityType: AdministratorStaffRepository.directoryEntityType,
        entityId: 'STAFF-1',
        payload: const AdministratorStaffRecord(
          id: 'STAFF-1', name: 'Mrs Amina Bello', role: 'Teacher', section: 'Secondary',
          fileStatus: AdministratorStaffFileStatus.complete,
        ).toJson(),
      );
      await db!.upsertLocalRecord(
        tenantId: 's',
        entityType: OwnerStaffProfileRepository.entityType,
        entityId: 'STAFF-1',
        payload: StaffProfile(staffId: 'STAFF-1', systemRole: 'teacher', linkedMembershipId: teacher.id).toJson(),
      );

      await session.selectSchool(principal);
      final thread = (await repo.load()).threads.singleWhere((t) => t.id == leadershipThreadId);
      expect(thread.title, 'Mrs Amina Bello');
      expect(thread.person, 'Mrs Amina Bello');
    });

    test('a non-principal cannot reply, and a reply to an unknown thread is refused', () async {
      await setup();
      final teacherMessages = await setUpTeacher();
      await session.selectSchool(teacher);
      await teacherMessages.queueMessage(threadId: leadershipThreadId, body: 'Hello');

      await session.selectSchool(principal);
      expect((await repo.queueReply(threadId: 'leadership-thread-ghost', message: 'Hi')).success, isFalse);

      await session.selectSchool(teacher);
      expect((await repo.queueReply(threadId: leadershipThreadId, message: 'Hi')).success, isFalse);
    });
  });
}
