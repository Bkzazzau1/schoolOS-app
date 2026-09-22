import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_attendance_repository.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/awards/data/award_repository.dart';
import 'package:schoolos_app/features/awards/domain/award_models.dart';
import 'package:schoolos_app/features/events/data/event_repository.dart';
import 'package:schoolos_app/features/finance_office/data/finance_ledger_repository.dart';
import 'package:schoolos_app/features/meals/data/meal_repository.dart';
import 'package:schoolos_app/features/parent/data/parent_children_repository.dart';
import 'package:schoolos_app/features/parent/data/parent_school_life_repository.dart';
import 'package:schoolos_app/features/proprietor/data/concession_repository.dart';
import 'package:schoolos_app/features/transport/data/transport_rider_assignment_repository.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const parent = SchoolMembership(id: 'm-parent', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.parent);
const teacher = SchoolMembership(id: 'm-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);
const proprietor = SchoolMembership(id: 'm-owner', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.proprietor);

const _weekdayNames = {1: 'Monday', 2: 'Tuesday', 3: 'Wednesday', 4: 'Thursday', 5: 'Friday'};

void main() {
  LocalDatabase? db;
  late SchoolSessionController session;
  late ParentSchoolLifeRepository schoolLife;

  Future<void> setUpFamily() async {
    final database = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await database.initialize();
    db = database;
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([parent, teacher, proprietor]);
    await session.selectSchool(parent);
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
    schoolLife = ParentSchoolLifeRepository(
      localDatabase: database,
      schoolSession: session,
      children: children,
      events: EventRepository(localDatabase: database, schoolSession: session),
      meals: MealRepository(localDatabase: database, schoolSession: session),
      awards: AwardRepository(localDatabase: database, schoolSession: session),
      transport: TransportRiderAssignmentRepository(localDatabase: database, schoolSession: session),
    );
  }

  tearDown(() => db?.close());

  test('events are the real, upcoming, school-wide events, never a disconnected fixed list', () async {
    await setUpFamily();
    final snapshot = await schoolLife.load();
    await session.selectSchool(proprietor);
    final realEvents = await EventRepository(localDatabase: db!, schoolSession: session).load();
    await session.selectSchool(parent);

    final realUpcomingTitles = realEvents.events.where((e) => e.isUpcoming).map((e) => e.title).toSet();
    expect(snapshot.events.map((e) => e.title).toSet(), realUpcomingTitles);
    expect(snapshot.events, isNotEmpty, reason: 'the seeded demo school always has real upcoming events');
  });

  test('transport reflects the real per-student assignment: only the really-seeded rider shows active', () async {
    await setUpFamily();
    final snapshot = await schoolLife.load();
    final maryam = snapshot.transport.firstWhere((t) => t.childName == 'Maryam Abdullahi');
    final hafsa = snapshot.transport.firstWhere((t) => t.childName == 'Hafsa Abdullahi');

    expect(maryam.status, 'Active');
    expect(maryam.serviceCode, 'BUS-02', reason: 'Maryam is really seeded onto BUS-02 in the driver morning-run data');
    expect(hafsa.status, 'Not assigned');
    expect(hafsa.serviceCode, 'Not recorded yet');
  });

  test('today\'s meal matches the real whole-school weekly menu, or is honest on a day with no service', () async {
    await setUpFamily();
    final snapshot = await schoolLife.load();
    final meals = await MealRepository(localDatabase: db!, schoolSession: session).load();
    final todayName = _weekdayNames[DateTime.now().weekday];

    if (todayName == null) {
      expect(snapshot.todayMeal, 'Not recorded yet');
      expect(snapshot.todayMealService, 'Not recorded yet');
    } else {
      final today = meals.meals.firstWhere((m) => m.day == todayName);
      expect(snapshot.todayMeal, '${today.breakfast} · ${today.lunch} · ${today.snack}');
      expect(snapshot.todayMealService, today.status.label);
    }
  });

  test('no real per-student activity roster or meal-plan source exists yet, so both stay honestly empty', () async {
    await setUpFamily();
    final snapshot = await schoolLife.load();
    expect(snapshot.activities, isEmpty);
    expect(snapshot.mealPlans, isEmpty);
  });

  test('recognition is honestly empty when no real award names a linked child', () async {
    await setUpFamily();
    final snapshot = await schoolLife.load();
    expect(snapshot.recognition, isEmpty);
  });

  test('an internal-only award draft naming a real child never leaks to the family', () async {
    await setUpFamily();
    await session.selectSchool(proprietor);
    final result = await AwardRepository(localDatabase: db!, schoolSession: session).addDraft(
      title: 'Reading Effort Recognition',
      recipient: 'Maryam Abdullahi',
      recipientType: AwardRecipientType.student,
      section: 'JSS 2A',
      category: 'Reading',
      citation: 'Consistent reading effort this term.',
      issuer: 'Class Teacher',
    );
    expect(result.success, isTrue, reason: result.message);
    await session.selectSchool(parent);

    final snapshot = await schoolLife.load();
    expect(snapshot.recognition, isEmpty, reason: 'a proprietor draft is internal-only until a real publish step exists');
  });

  test('only a Parent membership can load school life', () async {
    await setUpFamily();
    await session.selectSchool(teacher);
    expect(schoolLife.load(), throwsStateError);
  });
}
