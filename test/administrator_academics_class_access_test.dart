// AdministratorAcademicsRepository.saveClass: an Administrator may save a class
// in any section. A Principal may too, by default - but, matching the server
// (apps.owner.jobs.access.require_stage_access), only their own Secondary. Every
// other save (saveSession, ...) stays Administrator-only, for both roles.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/core/tenancy/school_session_store.dart';
import 'package:schoolos_app/features/administrator/data/administrator_academics_repository.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_academics_models.dart';
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
        return Future<String>.value('mutation-1');
    }
    return super.noSuchMethod(invocation);
  }
}

SchoolMembership _m(String id, SchoolRole role) => SchoolMembership(id: id, schoolId: 'a', schoolName: 'A', role: role);

final _admin = _m('admin', SchoolRole.administrator);
final _principal = _m('principal', SchoolRole.principal);
final _accountant = _m('accountant', SchoolRole.accountant);

AdministratorAcademicClass _class({String id = 'C1', String section = 'Secondary'}) => AdministratorAcademicClass(
      id: id,
      code: '1A',
      name: '1A',
      section: section,
      levelOrder: 1,
      stream: '',
      nextClassId: '',
      isTerminal: false,
      isActive: true,
    );

AdministratorAcademicSession _session() => const AdministratorAcademicSession(
      id: 'S1', code: 'S1', name: '2026/2027', startsOn: '2026-09-08', endsOn: '2027-07-10', status: 'planned',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final sessions = <SchoolSessionController>[];
  tearDown(() {
    for (final s in sessions) {
      s.dispose();
    }
    sessions.clear();
  });

  Future<AdministratorAcademicsRepository> repoFor(_Database db, SchoolMembership who) async {
    FlutterSecureStorage.setMockInitialValues({});
    final session = SchoolSessionController(store: SchoolSessionStore());
    await session.setMemberships([_admin, _principal, _accountant]);
    await session.selectSchool(who);
    sessions.add(session);
    return AdministratorAcademicsRepository(localDatabase: db, schoolSession: session);
  }

  test('an administrator may save a class in any section', () async {
    final db = _Database();
    final repo = await repoFor(db, _admin);
    for (final section in ['Secondary', 'Primary', 'Nursery']) {
      await repo.saveClass(_class(id: section, section: section));
    }
    expect(db.records.keys, containsAll(['a/academic_class/Secondary', 'a/academic_class/Primary', 'a/academic_class/Nursery']));
  });

  test('a principal may save only their own secondary class', () async {
    final db = _Database();
    final repo = await repoFor(db, _principal);
    await repo.saveClass(_class(section: 'Secondary'));
    expect(db.records.containsKey('a/academic_class/C1'), isTrue);
    for (final section in ['Primary', 'Nursery']) {
      expect(() => repo.saveClass(_class(section: section)), throwsStateError);
    }
  });

  test('an accountant may not save a class at all', () async {
    final db = _Database();
    final repo = await repoFor(db, _accountant);
    expect(() => repo.saveClass(_class()), throwsStateError);
  });

  test('a principal may still not save a session - only an administrator can', () async {
    final db = _Database();
    final principal = await repoFor(db, _principal);
    expect(() => principal.saveSession(_session()), throwsStateError);
    final admin = await repoFor(db, _admin);
    await admin.saveSession(_session());
    expect(db.records.containsKey('a/academic_session/S1'), isTrue);
  });
}
