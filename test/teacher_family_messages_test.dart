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
import 'package:schoolos_app/features/teacher/data/teacher_family_messages_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_roster.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

// The demo teacher already used by teacher_students_roster_test.dart: really assigned to JSS 2A
// (Mathematics) and JSS 2B (Mathematics) via teacher_roster.dart's own demo assignment record.
const teacher = SchoolMembership(id: 'membership-teacher-003', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);
const newTeacher = SchoolMembership(id: 'm-new-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);
// The same demo parent parent_messages_feature_test.dart uses, really linked to STU-001 (Maryam
// Abdullahi, JSS 2A) - the one child this demo teacher and this demo parent really share.
const parent = SchoolMembership(id: 'm-parent', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.parent);

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;
  late TeacherRoster roster;
  late TeacherFamilyMessagesRepository familyMessages;
  late ParentMessagesRepository parentMessages;

  Future<void> setUpSchool() async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([teacher, newTeacher, parent]);
    await session.selectSchool(teacher);

    final students = AdministratorStudentsRepository(localDatabase: db, schoolSession: session);
    roster = TeacherRoster(database: db, session: session, students: students);
    familyMessages = TeacherFamilyMessagesRepository(localDatabase: db, schoolSession: session, roster: roster);

    final children = ParentChildrenRepository(
      localDatabase: db,
      schoolSession: session,
      students: students,
      attendance: AdministratorAttendanceRepository(localDatabase: db, schoolSession: session),
      ledger: FinanceLedgerRepository(
        database: db,
        session: session,
        students: students,
        concessions: ConcessionRepository(localDatabase: db, schoolSession: session),
      ),
    );
    parentMessages = ParentMessagesRepository(localDatabase: db, schoolSession: session, children: children);
  }

  tearDown(() => db.close());

  test('threads are the real students in the real assigned classes, deduplicated across subjects', () async {
    await setUpSchool();
    final snapshot = await familyMessages.load();

    final expectedIds = <String>{};
    for (final assignedClass in await roster.assignedClasses(teacher)) {
      for (final student in await roster.studentsIn(assignedClass.className)) {
        expectedIds.add('channel-${student.id}');
      }
    }
    expect(expectedIds, isNotEmpty);
    expect(snapshot.threads.map((t) => t.id).toSet(), expectedIds);
    expect(snapshot.threads.length, expectedIds.length, reason: 'no duplicate thread even though the teacher teaches more than one subject to some of these classes');
    for (final thread in snapshot.threads) {
      expect(thread.approvedParticipant, isTrue);
      expect(thread.messages, isEmpty);
      expect(thread.preview, 'No messages yet');
    }
  });

  test('a teacher with no assigned classes gets no family threads at all', () async {
    await setUpSchool();
    await session.selectSchool(newTeacher);
    final snapshot = await familyMessages.load();
    expect(snapshot.threads, isEmpty);
  });

  test('a queued reply is real, persists across a reload, and stays scoped to the right family', () async {
    await setUpSchool();
    final before = await familyMessages.load();
    final thread = before.threadById('channel-STU-001')!;
    final sibling = before.threads.firstWhere((t) => t.id != thread.id);

    final queued = await familyMessages.queueReply(threadId: thread.id, body: "Maryam did very well in today's test.");
    expect(queued.isGuardianMessage, isFalse);
    expect(queued.state, ParentMessageState.queued);
    expect(queued.authorLabel, 'You');

    final after = await familyMessages.load();
    final afterThread = after.threadById(thread.id)!;
    expect(afterThread.messages.single.body, "Maryam did very well in today's test.");
    expect(afterThread.preview, "Maryam did very well in today's test.");

    final siblingAfter = after.threadById(sibling.id)!;
    expect(siblingAfter.messages, isEmpty, reason: 'a reply for one family must never leak into another');

    expect(db.pendingCount(tenantId: teacher.schoolId), greaterThan(0));
  });

  test('replying into an unknown or unassigned family thread is rejected', () async {
    await setUpSchool();
    expect(familyMessages.queueReply(threadId: 'channel-STU-999', body: 'Hello'), throwsStateError);
    expect(familyMessages.queueReply(threadId: 'not-a-real-channel', body: 'Hello'), throwsStateError);
  });

  test('an empty or overlong reply is rejected', () async {
    await setUpSchool();
    final snapshot = await familyMessages.load();
    final threadId = snapshot.threads.first.id;
    expect(() => familyMessages.queueReply(threadId: threadId, body: '   '), throwsArgumentError);
    expect(() => familyMessages.queueReply(threadId: threadId, body: 'x' * 4001), throwsArgumentError);
  });

  test('only a Teacher membership can load or reply to family messages', () async {
    await setUpSchool();
    await session.selectSchool(parent);
    expect(familyMessages.load(), throwsStateError);
    expect(familyMessages.queueReply(threadId: 'channel-STU-001', body: 'Hello'), throwsStateError);
  });

  test('a guardian message and a teacher reply are each real to the other, on the exact same thread', () async {
    await setUpSchool();

    await session.selectSchool(parent);
    final parentQueued = await parentMessages.queueReply(threadId: 'channel-STU-001', body: 'Please confirm the PTA date.');
    expect(parentQueued.authorLabel, 'You');

    await session.selectSchool(teacher);
    final teacherView = await familyMessages.load();
    final fromTeacherSide = teacherView.threadById('channel-STU-001')!;
    expect(fromTeacherSide.messages.single.body, 'Please confirm the PTA date.');
    expect(fromTeacherSide.messages.single.isGuardianMessage, isTrue, reason: 'this message was really authored by the guardian');
    expect(fromTeacherSide.messages.single.authorLabel, 'Guardian');

    await familyMessages.queueReply(threadId: 'channel-STU-001', body: 'Confirmed for next Friday.');

    await session.selectSchool(parent);
    final parentView = await parentMessages.load();
    final fromParentSide = parentView.threadById('channel-STU-001')!;
    expect(fromParentSide.messages.length, 2);
    final reply = fromParentSide.messages.last;
    expect(reply.isGuardianMessage, isFalse, reason: 'this message was really authored by the class teacher, not a guardian');
    expect(reply.authorLabel, 'Class teacher');
  });

  group('read receipts', () {
    test('a fresh family thread is never unread', () async {
      await setUpSchool();
      final snapshot = await familyMessages.load();
      expect(snapshot.threads.every((t) => !t.unread), isTrue);
    });

    test('my own reply never makes my own view unread', () async {
      await setUpSchool();
      await familyMessages.queueReply(threadId: 'channel-STU-001', body: 'Hello');
      final after = await familyMessages.load();
      expect(after.threadById('channel-STU-001')!.unread, isFalse);
    });

    test('a real guardian message makes the family thread unread for the teacher until marked seen', () async {
      await setUpSchool();
      await session.selectSchool(parent);
      await parentMessages.queueReply(threadId: 'channel-STU-001', body: 'Please confirm the PTA date.');

      await session.selectSchool(teacher);
      final afterMessage = await familyMessages.load();
      expect(afterMessage.threadById('channel-STU-001')!.unread, isTrue);

      await familyMessages.markThreadSeen('channel-STU-001');
      final afterSeen = await familyMessages.load();
      expect(afterSeen.threadById('channel-STU-001')!.unread, isFalse);
    });

    test('the teacher marking a thread seen never affects the guardian\'s own unread state, and vice versa', () async {
      await setUpSchool();
      await session.selectSchool(parent);
      await parentMessages.queueReply(threadId: 'channel-STU-001', body: 'Please confirm the PTA date.');

      await session.selectSchool(teacher);
      await familyMessages.markThreadSeen('channel-STU-001');
      await familyMessages.queueReply(threadId: 'channel-STU-001', body: 'Confirmed for next Friday.');

      await session.selectSchool(parent);
      final parentView = await parentMessages.load();
      expect(parentView.threadById('channel-STU-001')!.unread, isTrue, reason: 'the guardian never marked the teacher\'s new reply seen');
    });
  });
}
