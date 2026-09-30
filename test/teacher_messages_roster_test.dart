import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_attendance_repository.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/finance_office/data/finance_ledger_repository.dart';
import 'package:schoolos_app/features/parent/data/parent_children_repository.dart';
import 'package:schoolos_app/features/parent/data/parent_messages_repository.dart';
import 'package:schoolos_app/features/proprietor/data/concession_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_messages_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_roster.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_messages_models.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

// Has JSS 2A, JSS 2B and SS1A assigned in TeacherRoster's demo data.
const mathsTeacher = SchoolMembership(id: 'membership-teacher-003', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

// Has no demo class assignment at all.
const newTeacher = SchoolMembership(id: 'm-new-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

// The same demo parent parent_messages_feature_test.dart uses, really linked to STU-001 (Maryam
// Abdullahi), a real student really in JSS 2A.
const parent = SchoolMembership(id: 'm-parent', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.parent);

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;
  late TeacherRoster roster;
  late TeacherMessagesRepository messages;

  late ParentMessagesRepository parentMessages;

  Future<void> setUpSchool(SchoolMembership who) async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([mathsTeacher, newTeacher, parent]);
    await session.selectSchool(who);
    final students = AdministratorStudentsRepository(localDatabase: db, schoolSession: session);
    roster = TeacherRoster(database: db, session: session, students: students);
    messages = TeacherMessagesRepository(localDatabase: db, schoolSession: session, roster: roster);
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

  test('a teacher only sees guardian-group channels for classes they are really assigned to', () async {
    await setUpSchool(mathsTeacher);
    final snapshot = await messages.load();
    final guardianGroups = snapshot.threads.where((t) => t.type == TeacherMessageChannelType.parentGroup);
    expect(guardianGroups.map((t) => t.className).toSet(), {'JSS 2A', 'JSS 2B'});
    // Staff/leadership channels are not class-scoped and remain visible.
    expect(snapshot.threads.any((t) => t.type == TeacherMessageChannelType.staffChannel), isTrue);
    expect(snapshot.threads.any((t) => t.type == TeacherMessageChannelType.schoolLeadership), isTrue);
  });

  test('a teacher with no assigned classes sees only non-class-scoped channels, not a crash', () async {
    await setUpSchool(newTeacher);
    final snapshot = await messages.load();
    expect(snapshot.threads.any((t) => t.type == TeacherMessageChannelType.parentGroup), isFalse);
    expect(snapshot.threads, isNotEmpty, reason: 'staff/leadership channels remain visible to every teacher');
  });

  test('a message cannot be queued to a guardian-group channel outside the teacher\'s real assignment', () async {
    await setUpSchool(newTeacher);
    final result = await messages.queueMessage(threadId: 'class-broadcast-jss-2a', body: 'Hello');
    expect(result.success, isFalse);
    expect(result.message, contains('approved channel you have access to'));
    expect(db.pendingCount(tenantId: newTeacher.schoolId), 0);
  });

  test('a message can be queued to a real, visible channel, and really reaches every real family', () async {
    await setUpSchool(mathsTeacher);
    final snapshot = await messages.load();
    final jss2a = snapshot.threads.firstWhere((t) => t.className == 'JSS 2A');
    final realFamilies = (await roster.studentsIn('JSS 2A')).length;

    final result = await messages.queueMessage(threadId: jss2a.id, body: 'Hello guardians');
    expect(result.success, isTrue, reason: result.message);
    expect(result.message, contains('$realFamilies real famil'));
    expect(db.pendingCount(tenantId: mathsTeacher.schoolId), realFamilies);
  });

  test('a class broadcast really reaches a real guardian\'s own Parent Messages thread', () async {
    await setUpSchool(mathsTeacher);
    final snapshot = await messages.load();
    final jss2a = snapshot.threads.firstWhere((t) => t.className == 'JSS 2A');

    final result = await messages.queueMessage(threadId: jss2a.id, body: 'Field trip permission slips are due Friday.');
    expect(result.success, isTrue, reason: result.message);

    await session.selectSchool(parent);
    final parentSnapshot = await parentMessages.load();
    final maryamThread = parentSnapshot.threadById('channel-STU-001')!;
    expect(maryamThread.messages.single.body, 'Field trip permission slips are due Friday.');
    expect(maryamThread.messages.single.authorLabel, 'Class teacher');
  });

  group('school leadership channel', () {
    test('a teacher has exactly one real leadership thread, scoped to their own membership', () async {
      await setUpSchool(mathsTeacher);
      final snapshot = await messages.load();
      final leadership = snapshot.threads.where((t) => t.type == TeacherMessageChannelType.schoolLeadership);
      expect(leadership, hasLength(1));
      expect(leadership.single.id, 'leadership-thread-${mathsTeacher.id}');
      expect(snapshot.messagesForThread(leadership.single.id), isEmpty);
      expect(leadership.single.unread, 0);
    });

    test('a teacher can message their own real leadership thread', () async {
      await setUpSchool(mathsTeacher);
      final threadId = 'leadership-thread-${mathsTeacher.id}';
      final result = await messages.queueMessage(threadId: threadId, body: 'Requesting guidance on a parent concern.');
      expect(result.success, isTrue, reason: result.message);
      expect(db.pendingCount(tenantId: mathsTeacher.schoolId), greaterThan(0));

      final after = await messages.load();
      final threadMessages = after.messagesForThread(threadId);
      expect(threadMessages.single.body, 'Requesting guidance on a parent concern.');
      expect(threadMessages.single.isOutgoing, isTrue);
    });

    test('a real reply from school leadership makes the thread unread until marked seen', () async {
      await setUpSchool(mathsTeacher);
      final threadId = 'leadership-thread-${mathsTeacher.id}';

      // The exact canonical shape a real sync pull would write for a real leadership reply.
      await db.upsertLocalRecord(
        tenantId: mathsTeacher.schoolId,
        entityType: 'teacher_leadership_message',
        entityId: 'MSG-FROM-PRINCIPAL',
        payload: {
          'id': 'MSG-FROM-PRINCIPAL',
          'threadId': threadId,
          'body': "Noted, let's discuss tomorrow.",
          'authorRole': 'principal',
          'authorMembershipId': 'm-principal',
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        },
        isDirty: false,
      );

      final afterReply = await messages.load();
      final threadAfterReply = afterReply.threads.firstWhere((t) => t.id == threadId);
      expect(threadAfterReply.unread, 1);
      expect(afterReply.messagesForThread(threadId).single.isOutgoing, isFalse);

      await messages.markThreadSeen(threadId);
      final afterSeen = await messages.load();
      expect(afterSeen.threads.firstWhere((t) => t.id == threadId).unread, 0);
    });

    test('a different teacher cannot message someone else\'s leadership thread', () async {
      await setUpSchool(newTeacher);
      final result = await messages.queueMessage(threadId: 'leadership-thread-${mathsTeacher.id}', body: 'Hello');
      expect(result.success, isFalse);
    });
  });

  group('department channel', () {
    const coTeacher = SchoolMembership(id: 'm-co-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

    Future<void> seedCoTeacher() async {
      await session.setMemberships([mathsTeacher, newTeacher, parent, coTeacher]);
      await db.upsertLocalRecord(
        tenantId: 'school-1',
        entityType: TeacherRoster.assignmentType,
        entityId: coTeacher.id,
        payload: {
          'teacherMembershipId': coTeacher.id,
          'classes': [
            const AssignedClass(className: 'JSS 2C', subject: 'Mathematics', subjectCode: 'MATH').toJson(),
          ],
        },
      );
    }

    test('a real peer teaching the same real subject shares the exact same department thread', () async {
      await setUpSchool(mathsTeacher);
      await seedCoTeacher();
      final mathsThread = (await messages.load()).threads.firstWhere((t) => t.type == TeacherMessageChannelType.staffChannel);
      expect(mathsThread.name, 'Mathematics Department');

      await session.selectSchool(coTeacher);
      final coMathsThread = (await messages.load()).threads.firstWhere((t) => t.type == TeacherMessageChannelType.staffChannel);
      expect(coMathsThread.id, mathsThread.id, reason: 'the same real subject is the same real department thread');
    });

    test('a message to the department really reaches the real peer, on the exact same thread', () async {
      await setUpSchool(mathsTeacher);
      await seedCoTeacher();
      final threadId = (await messages.load()).threads.firstWhere((t) => t.type == TeacherMessageChannelType.staffChannel).id;

      final result = await messages.queueMessage(threadId: threadId, body: 'Can we align on the mid-term test date?');
      expect(result.success, isTrue, reason: result.message);

      await session.selectSchool(coTeacher);
      final coSnapshot = await messages.load();
      final coMessages = coSnapshot.messagesForThread(threadId);
      expect(coMessages.single.body, 'Can we align on the mid-term test date?');
      expect(coMessages.single.isOutgoing, isFalse, reason: 'from the peer\'s own side, this was not their message');
    });

    test('a teacher who does not teach this subject has no such department thread and cannot message it', () async {
      await setUpSchool(mathsTeacher);
      await seedCoTeacher();
      final threadId = (await messages.load()).threads.firstWhere((t) => t.type == TeacherMessageChannelType.staffChannel).id;

      await session.selectSchool(newTeacher);
      final newTeacherSnapshot = await messages.load();
      expect(newTeacherSnapshot.threads.any((t) => t.type == TeacherMessageChannelType.staffChannel), isFalse);

      final result = await messages.queueMessage(threadId: threadId, body: 'Hello');
      expect(result.success, isFalse);
    });
  });
}
