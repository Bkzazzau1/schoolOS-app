import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/app/demo_people.dart';
import 'package:schoolos_app/core/access/access_catalog_data.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/proprietor/data/local_owner_access.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';

/// The demo has no server, so the owner's decisions are kept and enforced on the device.
void main() {
  late MemorySyncStore store;
  late SchoolSessionController session;
  late LocalOwnerAccess access;

  final owner = demoMemberships.firstWhere((m) => m.role == SchoolRole.proprietor);
  final teacher = demoMemberships.firstWhere((m) => m.id == 'membership-teacher-002');

  Future<LocalOwnerAccess> start() async {
    final a = LocalOwnerAccess(store: store, session: session);
    await a.restore();
    return a;
  }

  Future<void> signInAs(SchoolMembership m) async {
    await session.setMemberships(access.memberships);
    await session.selectSchool(m);
  }

  setUp(() async {
    store = MemorySyncStore();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships(demoMemberships);
    access = await start();
  });

  tearDown(() => access.dispose());

  test('a role starts on its built-in screens and lists every sample person', () async {
    final people = await access.loadPeople(owner);
    expect(people.length, 11);
    final grace = people.firstWhere((p) => p.membershipId == teacher.id);
    expect(grace.name, 'Mrs. Grace Musa');
    expect(grace.activities, contains('teacher.dashboard'));
    expect(grace.activities, isNot(contains('owner.overview')));
  });

  test('blocking a screen takes it from that person at once, and putting it back returns it', () async {
    await signInAs(teacher);
    final blockable = accessCatalogEntries.firstWhere((e) => e.roles.contains('teacher') && !e.essential).key;
    expect(access.allows(blockable), isTrue);

    await access.setOverride(owner, teacher.id, blockable, block: true, note: 'On leave');
    expect(access.allows(blockable), isFalse);
    final person = (await access.loadPeople(owner)).firstWhere((p) => p.membershipId == teacher.id);
    expect(person.overrideFor(blockable)!.isBlock, isTrue);

    await access.clearOverride(owner, teacher.id, blockable);
    expect(access.allows(blockable), isTrue);
  });

  test('a screen everyone with the role needs cannot be taken away', () async {
    final essential = accessCatalogEntries.firstWhere((e) => e.roles.contains('teacher') && e.essential).key;
    await expectLater(access.setOverride(owner, teacher.id, essential, block: true), throwsA(isA<StateError>()));
    final allowed = {for (final e in accessCatalogEntries) if (e.roles.contains('teacher')) e.key}..remove(essential);
    await expectLater(access.setRole(owner, 'teacher', allowed), throwsA(isA<StateError>()));
  });

  test('changing what a role sees changes it for everyone with that role, and reset restores it', () async {
    await signInAs(teacher);
    final removable = accessCatalogEntries.firstWhere((e) => e.roles.contains('teacher') && !e.essential).key;
    final without = {for (final e in accessCatalogEntries) if (e.roles.contains('teacher')) e.key}..remove(removable);
    await access.setRole(owner, 'teacher', without);
    expect(access.allows(removable), isFalse);
    final roles = await access.loadRoles(owner);
    expect(roles.firstWhere((r) => r.role == 'teacher').customized, isTrue);

    await access.resetRole(owner, 'teacher');
    expect(access.allows(removable), isTrue);
  });

  test('the owner cannot lock themselves out or give away the owner role', () async {
    final screen = accessCatalogEntries.firstWhere((e) => e.roles.contains('proprietor') && !e.essential).key;
    await expectLater(access.setOverride(owner, owner.id, screen, block: true), throwsA(isA<StateError>()));
    await expectLater(access.setRole(owner, 'proprietor', {}), throwsA(isA<StateError>()));
    await expectLater(access.addRole(owner, teacher.id, 'proprietor'), throwsA(isA<StateError>()));
  });

  test('only the owner can change access', () async {
    final principal = demoMemberships.firstWhere((m) => m.role == SchoolRole.principal);
    await expectLater(access.resetRole(principal, 'teacher'), throwsA(isA<StateError>()));
  });

  test('an extra role becomes another membership the person can switch to, and can be taken away', () async {
    await access.addRole(owner, teacher.id, 'parent');
    final extra = session.memberships.firstWhere((m) => m.id == LocalOwnerAccess.extraMembershipId(teacher.id, 'parent'));
    expect(extra.role, SchoolRole.parent);
    expect(extra.schoolId, teacher.schoolId);

    final person = (await access.loadPeople(owner)).firstWhere((p) => p.membershipId == teacher.id);
    expect(person.extraRoles, ['parent']);
    expect(person.activities, contains('parent.dashboard'));

    await expectLater(access.addRole(owner, teacher.id, 'parent'), throwsA(isA<StateError>()));
    await expectLater(access.removeRole(owner, teacher.id, 'teacher'), throwsA(isA<StateError>()));

    await access.removeRole(owner, teacher.id, 'parent');
    expect(session.memberships.any((m) => m.id == extra.id), isFalse);
  });

  test('decisions and extra roles are kept and come back after a restart', () async {
    final blockable = accessCatalogEntries.firstWhere((e) => e.roles.contains('teacher') && !e.essential).key;
    await access.setOverride(owner, teacher.id, blockable, block: true);
    await access.addRole(owner, teacher.id, 'parent');
    access.dispose();

    access = await start();
    final person = (await access.loadPeople(owner)).firstWhere((p) => p.membershipId == teacher.id);
    expect(person.overrideFor(blockable)!.isBlock, isTrue);
    expect(person.extraRoles, ['parent']);
    final history = await access.loadHistory(owner);
    expect(history.map((h) => h.kind), containsAll(['person_block', 'role_added']));
  });

  test('moving a screen takes it from one person and gives it to another', () async {
    final principal = demoMemberships.firstWhere((m) => m.role == SchoolRole.principal);
    final screen = accessCatalogEntries.firstWhere((e) => e.roles.contains('principal') && !e.essential && e.grantable).key;
    await access.reassign(owner, activity: screen, fromMembershipId: principal.id, toMembershipId: teacher.id);
    final people = await access.loadPeople(owner);
    expect(people.firstWhere((p) => p.membershipId == principal.id).activities, isNot(contains(screen)));
    expect(people.firstWhere((p) => p.membershipId == teacher.id).activities, contains(screen));
    expect((await access.loadHistory(owner)).first.kind, 'reassign');
  });

  test('a screen the catalog does not know is never hidden', () async {
    await signInAs(teacher);
    expect(access.allows('teacher.something-new'), isTrue);
  });
}
