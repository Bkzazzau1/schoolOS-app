import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/core/tenancy/school_session_store.dart';
import 'package:schoolos_app/features/events/data/event_repository.dart';
import 'package:schoolos_app/features/events/domain/event_models.dart';
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
  late EventRepository repository;

  Future<void> actAs(SchoolRole role) async {
    final member = _member(role);
    await session.setMemberships([member]);
    await session.selectSchool(member);
  }

  Future<EventActionResult> addEvent() => repository.addEvent(
        title: 'Inter-House Sports Day',
        type: SchoolEventType.sports,
        audience: 'Whole school',
        date: '24 Sep 2026',
        time: '8:00 AM',
        venue: 'Main field',
        owner: 'Sports Committee',
        status: SchoolEventStatus.registrationOpen,
        note: '',
      );

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    database = _Database();
    session = SchoolSessionController(store: SchoolSessionStore());
    repository = EventRepository(localDatabase: database, schoolSession: session);
  });
  tearDown(() => session.dispose());

  test('a fresh school sees a genuinely empty calendar, never fabricated events', () async {
    await actAs(SchoolRole.proprietor);
    final snapshot = await repository.load();
    expect(snapshot.events, isEmpty);
  });

  group('permissionsFor mirrors apps.schoollife.specs.calendar.EVENTS exactly', () {
    test('managers and teachers can create', () async {
      for (final role in [SchoolRole.proprietor, SchoolRole.principal, SchoolRole.administrator, SchoolRole.teacher]) {
        await actAs(role);
        expect(repository.permissionsFor(session.requireActiveMembership()).canCreate, isTrue, reason: role.name);
      }
    });

    test('nobody else can create an event', () async {
      for (final role in [SchoolRole.parent, SchoolRole.student, SchoolRole.driver]) {
        await actAs(role);
        expect(repository.permissionsFor(session.requireActiveMembership()).canCreate, isFalse, reason: role.name);
      }
    });
  });

  group('addEvent', () {
    test('a teacher (a real contributor) can really add an event', () async {
      await actAs(SchoolRole.teacher);
      final result = await addEvent();
      expect(result.success, isTrue, reason: result.message);
      final event = (await repository.load()).events.single;
      expect(event.title, 'Inter-House Sports Day');
      expect(event.status, SchoolEventStatus.registrationOpen);
    });

    test('a role outside manage/contribute cannot add an event', () async {
      await actAs(SchoolRole.parent);
      final result = await addEvent();
      expect(result.success, isFalse);
    });

    test('an empty title or audience is refused', () async {
      await actAs(SchoolRole.proprietor);
      final result = await repository.addEvent(
        title: '   ',
        type: SchoolEventType.sports,
        audience: '',
        date: '',
        time: '',
        venue: '',
        owner: '',
        status: SchoolEventStatus.scheduled,
        note: '',
      );
      expect(result.success, isFalse);
    });
  });
}
