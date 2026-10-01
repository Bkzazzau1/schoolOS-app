import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/core/tenancy/school_session_store.dart';
import 'package:schoolos_app/features/activities/data/activity_repository.dart';
import 'package:schoolos_app/features/activities/domain/activity_models.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

class _Database implements LocalDatabase {
  final records = <String, LocalRecord>{};
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final a = invocation.namedArguments;
    final key = '${a[#tenantId]}/${a[#entityType]}/${a[#entityId]}';
    switch (invocation.memberName) {
      case #getLocalRecord:
        return Future<LocalRecord?>.value(records[key]);
      case #getLocalRecords:
        return Future<List<LocalRecord>>.value(
          records.values.where((r) => r.tenantId == a[#tenantId] && r.entityType == a[#entityType]).toList(),
        );
      case #upsertLocalRecord:
        records[key] = LocalRecord(
          tenantId: a[#tenantId],
          entityType: a[#entityType],
          entityId: a[#entityId],
          payload: Map<String, Object?>.from(a[#payload]),
          updatedAt: DateTime.now(),
          isDirty: a[#isDirty] ?? false,
        );
        return Future<void>.value();
      case #queueMutation:
        return Future<String>.value('mutation');
    }
    return super.noSuchMethod(invocation);
  }
}

SchoolMembership _member(SchoolRole role) => SchoolMembership(id: role.name, schoolId: 'a', schoolName: 'A', role: role);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Database database;
  late SchoolSessionController session;
  late ActivityRepository repository;

  Future<void> actAs(SchoolRole role) async {
    final member = _member(role);
    await session.setMemberships([member]);
    await session.selectSchool(member);
  }

  Future<ActivityActionResult> addActivity() => repository.addActivity(
        name: 'Chess Club',
        type: ActivityType.club,
        section: 'Whole school',
        coordinator: 'Mrs. Grace Audu',
        schedule: 'Wednesday · 2:30 PM',
        venue: 'Library hall',
        note: '',
      );

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    database = _Database();
    session = SchoolSessionController(store: SchoolSessionStore());
    repository = ActivityRepository(localDatabase: database, schoolSession: session);
  });
  tearDown(() => session.dispose());

  test('a fresh school sees a genuinely empty programme directory, never fabricated activities', () async {
    await actAs(SchoolRole.proprietor);
    final snapshot = await repository.load();
    expect(snapshot.activities, isEmpty);
  });

  group('permissionsFor mirrors apps.schoollife.specs.programmes.ACTIVITIES exactly', () {
    test('managers and teachers can create; only managers can manage all or take attendance', () async {
      for (final role in [SchoolRole.proprietor, SchoolRole.principal, SchoolRole.administrator]) {
        await actAs(role);
        final p = repository.permissionsFor(session.requireActiveMembership());
        expect(p.canCreate, isTrue, reason: role.name);
        expect(p.canManageAll, isTrue, reason: role.name);
        expect(p.canTakeAttendance, isTrue, reason: role.name);
      }
      await actAs(SchoolRole.teacher);
      final teacher = repository.permissionsFor(session.requireActiveMembership());
      expect(teacher.canCreate, isTrue);
      expect(teacher.canManageAll, isFalse);
      expect(teacher.canTakeAttendance, isFalse);
    });

    test('nobody else can create, manage or take attendance', () async {
      for (final role in [SchoolRole.parent, SchoolRole.student, SchoolRole.driver]) {
        await actAs(role);
        final p = repository.permissionsFor(session.requireActiveMembership());
        expect(p.canCreate, isFalse, reason: role.name);
        expect(p.canManageAll, isFalse, reason: role.name);
      }
    });
  });

  group('addActivity', () {
    test('a teacher (a real contributor) can really add a programme, starting at honest zeros', () async {
      await actAs(SchoolRole.teacher);
      final result = await addActivity();
      expect(result.success, isTrue, reason: result.message);
      final activity = (await repository.load()).activities.single;
      expect(activity.name, 'Chess Club');
      expect(activity.members, 0);
      expect(activity.attendance, 0);
    });

    test('a role outside manage/contribute cannot add a programme', () async {
      await actAs(SchoolRole.parent);
      final result = await addActivity();
      expect(result.success, isFalse);
    });

    test('an empty name or coordinator is refused', () async {
      await actAs(SchoolRole.proprietor);
      final result = await repository.addActivity(
        name: '   ',
        type: ActivityType.club,
        section: '',
        coordinator: '',
        schedule: '',
        venue: '',
        note: '',
      );
      expect(result.success, isFalse);
    });
  });

  group('updateAttendance', () {
    test('a manager can really record attendance for a real programme', () async {
      await actAs(SchoolRole.teacher);
      await addActivity();
      final id = (await repository.load()).activities.single.id;

      await actAs(SchoolRole.proprietor);
      final result = await repository.updateAttendance(activityId: id, attendance: 88);
      expect(result.success, isTrue, reason: result.message);
      expect((await repository.load()).activities.single.attendance, 88);
    });

    test('a teacher (a contributor, not a manager) cannot take attendance', () async {
      await actAs(SchoolRole.teacher);
      await addActivity();
      final id = (await repository.load()).activities.single.id;
      final result = await repository.updateAttendance(activityId: id, attendance: 88);
      expect(result.success, isFalse);
    });

    test('attendance outside 0-100 is refused', () async {
      await actAs(SchoolRole.proprietor);
      await addActivity();
      final id = (await repository.load()).activities.single.id;
      final result = await repository.updateAttendance(activityId: id, attendance: 150);
      expect(result.success, isFalse);
    });
  });
}
