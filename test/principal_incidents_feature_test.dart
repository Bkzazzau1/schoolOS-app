import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';
import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;
import 'package:schoolos_app/features/principal/data/principal_incidents_repository.dart';
import 'package:schoolos_app/features/principal/domain/principal_incidents_models.dart';
import 'package:schoolos_app/features/principal/presentation/principal_incidents_page.dart';

const principal = SchoolMembership(
  id: 'p',
  schoolId: 's',
  schoolName: 'School',
  role: SchoolRole.principal,
);
void main() {
  LocalDatabase? db;
  late SchoolSessionController session;
  late PrincipalIncidentsRepository repo;
  Future<void> setUpSchool([SchoolMembership member = principal]) async {
    db = LocalDatabase(
      cipher: PayloadCipher(secureStorage: MemorySecureStorage()),
      databasePath: ':memory:',
    );
    await db!.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([member]);
    await session.selectSchool(member);
    repo = PrincipalIncidentsRepository(
      localDatabase: db!,
      schoolSession: session,
    );
  }

  tearDown(() => db?.close());
  Future<void> record({
    String context = 'JSS 2A',
    String tenant = 's',
    String type = 'principal_recorded_incident_case',
  }) async {
    final item = PrincipalIncident(
      id: 'case',
      title: 'Recorded concern',
      category: PrincipalIncidentCategory.property,
      severity: PrincipalIncidentSeverity.low,
      status: PrincipalIncidentStatus.open,
      person: 'Reported by staff',
      context: context,
      reportedBy: 'p',
      owner: 'p',
      reportedAt: '2026-09-22',
      location: 'Classroom',
      guardianContact: PrincipalGuardianContact.notRequired,
      evidenceCount: 0,
      summary: 'A staff-entered report.',
      nextAction: 'Review evidence',
    );
    await db!.upsertLocalRecord(
      tenantId: tenant,
      entityType: type,
      entityId: 'case',
      payload: item.toJson(),
      isDirty: true,
    );
  }

  test('fresh demo has no allegations or fabricated activity', () async {
    await setUpSchool();
    final s = await repo.load();
    expect(s.cases, isEmpty);
    expect(s.audit, isEmpty);
    expect(s.openCases, 0);
    expect(s.safeguarding, 0);
  });
  test('old seeded cases stay quarantined', () async {
    await setUpSchool();
    await record(type: 'principal_incident_case');
    expect((await repo.load()).cases, isEmpty);
    expect(
      (await repo.saveNote(incidentId: 'case', note: 'Review')).success,
      isFalse,
    );
  });
  for (final scope in ['Primary 3', 'Nursery', 'Other']) {
    test('rejects outside Secondary scope $scope', () async {
      await setUpSchool();
      await record(context: scope);
      expect((await repo.load()).cases, isEmpty);
      expect(
        (await repo.changeStatus(
          incidentId: 'case',
          status: PrincipalIncidentStatus.resolved,
        )).success,
        isFalse,
      );
    });
  }
  test('other schools remain isolated', () async {
    await setUpSchool();
    await record(tenant: 'other');
    expect((await repo.load()).cases, isEmpty);
  });
  test('recorded case note is attributed without changing severity', () async {
    await setUpSchool();
    await record();
    expect(
      (await repo.saveNote(
        incidentId: 'case',
        note: 'Evidence reviewed',
      )).success,
      isTrue,
    );
    final s = await repo.load();
    expect(s.audit.single.actorMembershipId, 'p');
    expect(s.cases.single.severity, PrincipalIncidentSeverity.low);
  });
  test('resolution retains case and appends audit', () async {
    await setUpSchool();
    await record();
    await repo.changeStatus(
      incidentId: 'case',
      status: PrincipalIncidentStatus.resolved,
    );
    final s = await repo.load();
    expect(s.cases.single.status, PrincipalIncidentStatus.resolved);
    expect(s.openCases, 0);
    expect(s.audit.single.previousStatus, PrincipalIncidentStatus.open);
  });
  test('empty note is rejected without writes', () async {
    await setUpSchool();
    await record();
    expect(
      (await repo.saveNote(incidentId: 'case', note: ' ')).success,
      isFalse,
    );
    expect(db!.pendingCount(tenantId: 's'), 0);
  });
  test('non principal cannot view or mutate cases', () async {
    await setUpSchool(
      const SchoolMembership(
        id: 't',
        schoolId: 's',
        schoolName: 'School',
        role: SchoolRole.teacher,
      ),
    );
    await record();
    expect((await repo.load()).cases, isEmpty);
    expect(
      (await repo.saveNote(incidentId: 'case', note: 'x')).success,
      isFalse,
    );
  });
  testWidgets('empty incidents render safely', (tester) async {
    await tester.runAsync(() => setUpSchool());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrincipalIncidentsPage(repository: repo, onNavigate: (_) {}),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No recorded Secondary incidents.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
