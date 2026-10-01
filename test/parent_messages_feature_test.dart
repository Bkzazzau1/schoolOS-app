import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_attendance_repository.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/finance_office/data/finance_ledger_repository.dart';
import 'package:schoolos_app/features/parent/data/parent_children_repository.dart';
import 'package:schoolos_app/features/parent/data/parent_messages_repository.dart';
import 'package:schoolos_app/features/parent/domain/parent_messages_models.dart';
import 'package:schoolos_app/features/proprietor/data/concession_repository.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;
import 'core/real_student_fixtures.dart';

const parent = SchoolMembership(id: 'm-parent', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.parent);
const teacher = SchoolMembership(id: 'm-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

void main() {
  LocalDatabase? db;
  late SchoolSessionController session;
  late ParentMessagesRepository messages;

  Future<void> setUpFamily() async {
    final database = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await database.initialize();
    db = database;
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([parent, teacher]);
    await session.selectSchool(parent);
    for (final s in const [
      (id: 'STU-001', name: 'Maryam Abdullahi', className: 'JSS 2A', guardian: 'Alhaji Abdullahi Musa'),
      (id: 'PRI-003', name: 'Hafsa Abdullahi', className: 'Primary 3', guardian: 'Alhaji Abdullahi Sani'),
    ]) {
      await seedRealStudent(database, tenantId: parent.schoolId, id: s.id, name: s.name, className: s.className, guardian: s.guardian);
    }
    final students = AdministratorStudentsRepository(localDatabase: database, schoolSession: session);
    final children = ParentChildrenRepository(
      localDatabase: database,
      schoolSession: session,
      students: students,
      attendance: AdministratorAttendanceRepository(localDatabase: database, schoolSession: session),
      ledger: FinanceLedgerRepository(
        database: database,
        session: session,
        students: students,
        concessions: ConcessionRepository(localDatabase: database, schoolSession: session),
      ),
    );
    await children.replaceLinkedChildren(childIds: const ['STU-001', 'PRI-003']);
    messages = ParentMessagesRepository(
      localDatabase: database,
      schoolSession: session,
      children: children,
    );
  }

  tearDown(() => db?.close());

  test('a fresh family gets one real, empty channel per real linked child, never a fabricated conversation', () async {
    await setUpFamily();
    final snapshot = await messages.load();
    expect(snapshot.threads, hasLength(2));
    expect(snapshot.threads.map((t) => t.childLabel).toSet(), {'Maryam Abdullahi', 'Hafsa Abdullahi'});
    for (final thread in snapshot.threads) {
      expect(thread.approvedParticipant, isTrue);
      expect(thread.messages, isEmpty);
      expect(thread.preview, 'No messages yet');
      expect(thread.unread, isFalse);
    }
    expect(snapshot.unreadCount, 0);
  });

  test('a queued reply is real, persists across a reload, and stays scoped to the right child', () async {
    await setUpFamily();
    final before = await messages.load();
    final maryamThread = before.threads.firstWhere((t) => t.childLabel == 'Maryam Abdullahi');

    final queued = await messages.queueReply(threadId: maryamThread.id, body: 'When is the next PTA meeting?');
    expect(queued.direction, ParentMessageDirection.guardianToSchool);
    expect(queued.state, ParentMessageState.queued);
    expect(queued.authorLabel, 'You');

    final after = await messages.load();
    final maryamAfter = after.threadById(maryamThread.id)!;
    expect(maryamAfter.messages, hasLength(1));
    expect(maryamAfter.messages.single.body, 'When is the next PTA meeting?');
    expect(maryamAfter.preview, 'When is the next PTA meeting?');

    final hafsaAfter = after.threads.firstWhere((t) => t.childLabel == 'Hafsa Abdullahi');
    expect(hafsaAfter.messages, isEmpty, reason: 'a message queued for one child must never leak into a sibling\'s channel');

    expect(db!.pendingCount(tenantId: parent.schoolId), greaterThan(0));
  });

  test('replying to an unknown or unapproved channel is rejected', () async {
    await setUpFamily();
    expect(
      messages.queueReply(threadId: 'not-a-real-channel', body: 'Hello'),
      throwsStateError,
    );
  });

  test('an empty or overlong message body is rejected', () async {
    await setUpFamily();
    final snapshot = await messages.load();
    final threadId = snapshot.threads.first.id;
    expect(
      () => messages.queueReply(threadId: threadId, body: '   '),
      throwsArgumentError,
    );
    expect(
      () => messages.queueReply(threadId: threadId, body: 'x' * 4001),
      throwsArgumentError,
    );
  });

  test('only a Parent membership can load family messages', () async {
    await setUpFamily();
    await session.selectSchool(teacher);
    expect(messages.load(), throwsStateError);
  });

  group('read receipts', () {
    test('a fresh channel with no messages is never unread', () async {
      await setUpFamily();
      final snapshot = await messages.load();
      expect(snapshot.threads.every((t) => !t.unread), isTrue);
      expect(snapshot.unreadCount, 0);
    });

    test('my own message never makes my own view unread', () async {
      await setUpFamily();
      final before = await messages.load();
      final maryamThread = before.threads.firstWhere((t) => t.childLabel == 'Maryam Abdullahi');
      await messages.queueReply(threadId: maryamThread.id, body: 'Hello');
      final after = await messages.load();
      expect(after.threadById(maryamThread.id)!.unread, isFalse);
    });

    test('a real reply from the class teacher makes the thread unread until marked seen', () async {
      await setUpFamily();
      final before = await messages.load();
      final maryamThread = before.threads.firstWhere((t) => t.childLabel == 'Maryam Abdullahi');

      // The exact canonical shape a real sync pull would write for a real teacher reply.
      await db!.upsertLocalRecord(
        tenantId: parent.schoolId,
        entityType: 'parent_message',
        entityId: 'MSG-FROM-TEACHER',
        payload: {
          'id': 'MSG-FROM-TEACHER',
          'threadId': maryamThread.id,
          'body': 'Maryam did very well today.',
          'authorRole': 'teacher',
          'authorMembershipId': teacher.id,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        },
        isDirty: false,
      );

      final afterReply = await messages.load();
      final afterThread = afterReply.threadById(maryamThread.id)!;
      expect(afterThread.unread, isTrue);
      expect(afterReply.unreadCount, 1);

      await messages.markThreadSeen(maryamThread.id);
      final afterSeen = await messages.load();
      expect(afterSeen.threadById(maryamThread.id)!.unread, isFalse);
      expect(afterSeen.unreadCount, 0);
      expect(db!.pendingCount(tenantId: parent.schoolId), greaterThan(0), reason: 'a real receipt was queued');
    });

    test('marking an already-read thread seen again is a harmless no-op', () async {
      await setUpFamily();
      final before = await messages.load();
      await messages.markThreadSeen(before.threads.first.id);
      expect(db!.pendingCount(tenantId: parent.schoolId), 0, reason: 'no receipt should be queued when nothing is unread');
    });

    test('marking an unknown thread seen is rejected', () async {
      await setUpFamily();
      expect(messages.markThreadSeen('not-a-real-channel'), throwsStateError);
    });
  });
}
