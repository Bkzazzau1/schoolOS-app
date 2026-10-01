import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/proprietor/data/owner_staff_profile_repository.dart';
import 'package:schoolos_app/features/proprietor/domain/owner_staff_profile_models.dart';
import 'package:schoolos_app/features/teacher/data/teacher_attendance_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_performance_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_roster.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;
import 'core/real_student_fixtures.dart';

// Has JSS 2A and JSS 2B assigned in TeacherRoster's own demo data.
const mathsTeacher = SchoolMembership(id: 'membership-teacher-003', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

// Has no demo class assignment at all.
const newTeacher = SchoolMembership(id: 'm-new-performance-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;
  late TeacherRoster roster;
  late TeacherPerformanceRepository performance;
  late TeacherAttendanceRepository attendance;

  Future<void> setUpSchool(SchoolMembership who) async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([mathsTeacher, newTeacher]);
    await session.selectSchool(who);
    await seedClassicRoster(db, tenantId: who.schoolId);
    roster = TeacherRoster(
      database: db,
      session: session,
      students: AdministratorStudentsRepository(localDatabase: db, schoolSession: session),
    );
    performance = TeacherPerformanceRepository(localDatabase: db, schoolSession: session, roster: roster);
    attendance = TeacherAttendanceRepository(localDatabase: db, schoolSession: session, roster: roster);
  }

  tearDown(() => db.close());

  test('a teacher with no assigned class gets an honestly empty performance view', () async {
    await setUpSchool(newTeacher);
    final snapshot = await performance.load();
    expect(snapshot.classPerformance, isEmpty);
    expect(snapshot.developmentLog, isEmpty);
    for (final metric in snapshot.metrics) {
      expect(metric.value, 0, reason: metric.label);
    }
    expect(snapshot.overallScore, 0);
  });

  test('attendance completion is a real ratio of real submitted registers, not a fixed number', () async {
    await setUpSchool(mathsTeacher);
    // One real register per real assigned class (JSS 2A, JSS 2B) exists honestly, none submitted yet.
    final before = await performance.load();
    final attendanceMetric = before.metrics.firstWhere((m) => m.label == 'Attendance completion');
    expect(attendanceMetric.value, 0, reason: 'nothing has really been submitted yet');

    // Really submit one of the two real registers.
    final firstLessonId = (await attendance.load()).registers.first.lesson.id;
    await attendance.submit(lessonId: firstLessonId);

    final after = await performance.load();
    final updated = after.metrics.firstWhere((m) => m.label == 'Attendance completion');
    expect(updated.value, 50, reason: '1 of 2 real registers really submitted');
  });

  test('a real linked staff profile supplies a real development log from real leadership reviews', () async {
    await setUpSchool(mathsTeacher);
    final profile = StaffProfile(
      staffId: 'STF-TCH-003',
      linkedMembershipId: mathsTeacher.id,
      reviews: const [
        StaffPerformanceReview(period: '2026 Term 1', rating: 4, notes: 'Strong classroom management.', at: '2026-04-01'),
      ],
    );
    await db.upsertLocalRecord(
      tenantId: mathsTeacher.schoolId,
      entityType: OwnerStaffProfileRepository.entityType,
      entityId: 'STF-TCH-003',
      payload: profile.toJson(),
      isDirty: false,
    );

    final snapshot = await performance.load();
    expect(snapshot.developmentLog, hasLength(1));
    expect(snapshot.developmentLog.single.title, contains('Rating 4/5'));
    expect(snapshot.developmentLog.single.detail, 'Strong classroom management.');
  });
}
