import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
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

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;
  late TeacherRoster roster;
  late TeacherMessagesRepository messages;

  Future<void> setUpSchool(SchoolMembership who) async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([mathsTeacher, newTeacher]);
    await session.selectSchool(who);
    roster = TeacherRoster(
      database: db,
      session: session,
      students: AdministratorStudentsRepository(localDatabase: db, schoolSession: session),
    );
    messages = TeacherMessagesRepository(localDatabase: db, schoolSession: session, roster: roster);
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
    final result = await messages.queueMessage(threadId: 'thread-1', body: 'Hello');
    expect(result.success, isFalse);
    expect(result.message, contains('approved channel you have access to'));
    expect(db.pendingCount(tenantId: newTeacher.schoolId), 0);
  });

  test('a message can be queued to a real, visible channel', () async {
    await setUpSchool(mathsTeacher);
    final result = await messages.queueMessage(threadId: 'thread-1', body: 'Hello guardians');
    expect(result.success, isTrue, reason: result.message);
    expect(db.pendingCount(tenantId: mathsTeacher.schoolId), greaterThan(0));
  });
}
