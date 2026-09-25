import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/core/tenancy/school_session_store.dart';
import 'package:schoolos_app/features/transport/data/transport_incident_defect_control_repository.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

class _Database implements LocalDatabase {
  final records = <String, LocalRecord>{};
  final queued = <({String entityType, String entityId})>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final a = invocation.namedArguments;
    final key = '${a[#tenantId]}/${a[#entityType]}/${a[#entityId]}';
    switch (invocation.memberName) {
      case #getLocalRecord:
        return Future<LocalRecord?>.value(records[key]);
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
        queued.add((entityType: a[#entityType] as String, entityId: a[#entityId] as String));
        return Future<String>.value('mutation');
    }
    return super.noSuchMethod(invocation);
  }
}

// A real membership id is a UUID, which is what makes ids built from one long.
const _adminId = '3f2b8c1e-9a4d-4e6b-8c2a-1d5e7f9a0b3c';
const _driverId = '7a1c9e2d-5b3f-4d8a-9e6c-2f4b8d1a3c5e';

/// The server accepts an entityId of at most 128 letters, digits and `. _ : -`.
final _serverEntityId = RegExp(r'^[A-Za-z0-9._:\-]{1,128}$');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Database database;
  late SchoolSessionController session;
  late TransportIncidentDefectControlRepository repository;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    database = _Database();
    session = SchoolSessionController(store: SchoolSessionStore());
    const admin = SchoolMembership(id: _adminId, schoolId: 'a', schoolName: 'A', role: SchoolRole.administrator);
    await session.setMemberships([admin]);
    await session.selectSchool(admin);
    repository = TransportIncidentDefectControlRepository(localDatabase: database, schoolSession: session);
  });
  tearDown(() => session.dispose());

  test('a defect review event id stays within what the server accepts, even for the longest defect id', () async {
    // The longest real defect id: an afternoon check, on the longest-named item.
    const defectId = '$_driverId:vehicle-check:2026-09-25:afternoon:fire_extinguisher';
    database.records['a/driver_vehicle_defect/$defectId'] = LocalRecord(
      tenantId: 'a',
      entityType: 'driver_vehicle_defect',
      entityId: defectId,
      payload: {
        'id': defectId,
        'routeId': 'BUS-01',
        'vehicle': 'Bus 1',
        'status': 'reported',
        'reportedByMembershipId': _driverId,
      },
      updatedAt: DateTime.now(),
      isDirty: false,
    );

    final result = await repository.reviewDefect(defectId, note: 'Booked in.');
    expect(result.success, isTrue, reason: result.message);

    final events = database.queued.where((m) => m.entityType == 'transport_case_event').toList();
    expect(events, isNotEmpty);
    for (final event in events) {
      expect(_serverEntityId.hasMatch(event.entityId), isTrue,
          reason: '${event.entityId} (${event.entityId.length} chars) would be rejected by the server');
    }
    // Every other mutation this action queues is checked the same way.
    for (final mutation in database.queued) {
      expect(_serverEntityId.hasMatch(mutation.entityId), isTrue, reason: mutation.entityId);
    }
  });
}
