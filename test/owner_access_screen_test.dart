import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:schoolos_app/core/appearance/school_appearance_controller.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/network/api_exceptions.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/proprietor/data/owner_access_scope.dart';
import 'package:schoolos_app/features/proprietor/presentation/proprietor_workspace_page.dart';
import 'package:schoolos_app/features/proprietor/data/owner_access_controller.dart';
import 'package:schoolos_app/features/proprietor/data/owner_access_repository.dart';
import 'package:schoolos_app/features/proprietor/domain/owner_access_models.dart';
import 'package:schoolos_app/features/proprietor/presentation/owner_access_history_tabs.dart';
import 'package:schoolos_app/features/proprietor/presentation/owner_access_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';

const owner = SchoolMembership(
  id: '55555555-5555-5555-5555-555555555555',
  schoolId: '22222222-2222-2222-2222-222222222222',
  schoolName: 'BrightGate',
  role: SchoolRole.proprietor,
);

const musaId = '66666666-6666-6666-6666-666666666666';
const aishaId = '77777777-7777-7777-7777-777777777777';

Map<String, Object?> activity(String key, String label, {bool essential = false, bool grantable = true, bool sensitive = false, List<String> roles = const []}) => {
      'key': key,
      'label': label,
      'essential': essential,
      'grantable': grantable,
      'sensitive': sensitive,
      'defaultRoles': roles,
      'rolesInThisSchool': roles,
    };

final catalogJson = {
  'groups': [
    {
      'area': 'Teacher',
      'activities': [
        activity('teacher.dashboard', 'Dashboard', essential: true, roles: ['teacher']),
        activity('teacher.students', 'Students', roles: ['teacher']),
        activity('teacher.cbt', 'CBT Practice', roles: ['teacher']),
        activity('teacher.payroll', 'Payroll Handoff', sensitive: true, roles: ['accountant']),
      ],
    },
    {
      'area': 'Owner',
      'activities': [activity('owner.access', 'Access & Activities', grantable: false, roles: ['proprietor'])],
    },
  ],
};

Map<String, Object?> person(String id, String name, String role, List<String> activities, {List<Map<String, Object?>> overrides = const []}) => {
      'membershipId': id,
      'email': '${name.toLowerCase()}@school.ng',
      'name': name,
      'role': role,
      'activities': activities,
      'overrides': overrides,
    };

Map<String, Object?> setting({String activity = 'teacher.students', String effect = 'block', String state = 'in_force', String? takesEffectBy, String? expiresAt, String note = ''}) => {
      'activity': activity,
      'effect': effect,
      'state': state,
      'expiresAt': expiresAt,
      'takesEffectBy': takesEffectBy,
      'note': note,
      'setAt': '2026-09-20T09:00:00Z',
    };

class Data {
  List<Map<String, Object?>> people = [
    person(musaId, 'Musa', 'teacher', ['teacher.dashboard', 'teacher.students', 'teacher.cbt']),
    person(aishaId, 'Aisha', 'teacher', ['teacher.dashboard', 'teacher.students']),
  ];
  List<Map<String, Object?>> roles = [
    {'role': 'teacher', 'activities': ['teacher.dashboard', 'teacher.students', 'teacher.cbt'], 'customized': false, 'editable': true},
    {'role': 'accountant', 'activities': ['teacher.payroll'], 'customized': true, 'editable': true},
  ];
  List<Map<String, Object?>> history = [];
  http.Response? refuse;          // answered to the next change
  bool offline = false;
}

/// A server for the owner endpoints. Every request is kept in [FakeServer.requests].
FakeServer serverFor(Data data) => FakeServer((r) async {
      if (data.offline) throw const ApiOfflineException();
      final path = r.url.path;
      if (r.method == 'GET') {
        if (path.endsWith('/catalog/')) return jsonResponse(catalogJson);
        if (path.endsWith('/roles/')) return jsonResponse({'roles': data.roles});
        if (path.endsWith('/people/')) return jsonResponse({'people': data.people});
        if (path.endsWith('/audit/')) return jsonResponse({'changes': data.history});
      }
      final refusal = data.refuse;
      if (refusal != null) {
        data.refuse = null;
        return refusal;
      }
      return r.method == 'DELETE' ? http.Response('', 204) : jsonResponse({'ok': true});
    });

OwnerAccessController controllerFor(FakeServer server) =>
    OwnerAccessController(repository: OwnerAccessRepository(api: apiFor(server)), owner: owner);

List<http.Request> changes(FakeServer server) => server.requests.where((r) => r.method != 'GET').toList();

void main() {
  group('the requests the screen makes', () {
    test('every call names the owner\'s membership and goes to the owner endpoints', () async {
      final server = serverFor(Data());
      final repo = OwnerAccessRepository(api: apiFor(server));
      await repo.loadCatalog(owner);
      await repo.loadRoles(owner);
      await repo.loadPeople(owner);
      await repo.loadHistory(owner, limit: 20);
      final base = '/api/v1/owner/schools/${owner.schoolId}/access';
      expect(server.requests.map((r) => r.url.path), ['$base/catalog/', '$base/roles/', '$base/people/', '$base/audit/']);
      expect(server.requests.every((r) => r.url.queryParameters['membership'] == owner.id), isTrue);
      expect(server.requests.last.url.queryParameters['limit'], '20');
    });

    test('granting, blocking, resetting, moving and setting a role send what the server expects', () async {
      final server = serverFor(Data());
      final repo = OwnerAccessRepository(api: apiFor(server));
      await repo.setOverride(owner, musaId, 'teacher.payroll', block: false, expiresAt: DateTime.utc(2026, 10, 1), note: '  Covering  ');
      await repo.setOverride(owner, musaId, 'teacher.cbt', block: true, immediately: true);
      await repo.clearOverride(owner, musaId, 'teacher.cbt');
      await repo.reassign(owner, activity: 'teacher.cbt', fromMembershipId: musaId, toMembershipId: aishaId, note: 'Cover');
      await repo.setRole(owner, 'teacher', {'teacher.students', 'teacher.dashboard'});
      await repo.resetRole(owner, 'teacher');

      final sent = changes(server);
      expect(sent.map((r) => '${r.method} ${r.url.path.split('/access').last}'), [
        'PUT /people/$musaId/activities/teacher.payroll/',
        'PUT /people/$musaId/activities/teacher.cbt/',
        'DELETE /people/$musaId/activities/teacher.cbt/',
        'POST /reassign/',
        'PUT /roles/teacher/',
        'DELETE /roles/teacher/',
      ]);
      expect(body(sent[0]), {'effect': 'grant', 'mode': 'after_sync', 'expiresAt': '2026-10-01T00:00:00.000Z', 'note': 'Covering'});
      expect(body(sent[1]), {'effect': 'block', 'mode': 'immediate', 'expiresAt': null, 'note': ''});
      expect(body(sent[3]), {'activity': 'teacher.cbt', 'fromMembershipId': musaId, 'toMembershipId': aishaId, 'mode': 'after_sync', 'note': 'Cover'});
      expect(body(sent[4]), {'activities': ['teacher.dashboard', 'teacher.students']});
    });
  });

  group('the controller', () {
    test('reads everything, and a change reads it back', () async {
      final data = Data();
      final server = serverFor(data);
      final controller = controllerFor(server);
      await controller.load();
      expect((controller.loaded, controller.people.length, controller.roles.length), (true, 2, 2));
      expect(controller.catalog!.labelOf('teacher.cbt'), 'CBT Practice');
      expect(controller.person(musaId)!.displayName, 'Musa');

      data.people = [person(musaId, 'Musa', 'teacher', ['teacher.dashboard'])];
      final problem = await controller.change((repo, o) => repo.clearOverride(o, musaId, 'teacher.cbt'));
      expect(problem, isNull);
      expect(controller.people.length, 1);          // it read the school again
    });

    test('a refused change comes back as the server\'s words and nothing is reloaded', () async {
      final data = Data()..refuse = jsonResponse({'code': 'access_error', 'message': 'A landing screen cannot be taken away.'}, 400);
      final controller = controllerFor(serverFor(data));
      await controller.load();
      final problem = await controller.change((repo, o) => repo.setOverride(o, musaId, 'teacher.dashboard', block: true));
      expect(problem, 'A landing screen cannot be taken away.');
    });

    test('offline and a ended sign-in are explained plainly', () async {
      final data = Data()..offline = true;
      final controller = controllerFor(serverFor(data));
      await controller.load();
      expect(controller.loaded, isFalse);
      expect(controller.loadError, contains('need a connection'));
      expect(OwnerAccessController.describe(const SessionExpiredException()), contains('sign-in has ended'));
      expect(OwnerAccessController.describe(StateError('x')), 'x');
      expect(OwnerAccessController.describe(Object()), contains('Something went wrong'));
    });

    test('waiting blocks are worked out from the people', () async {
      final data = Data()
        ..people = [
          person(musaId, 'Musa', 'teacher', ['teacher.students'], overrides: [
            setting(state: 'waiting_for_sync', takesEffectBy: '2026-09-23T00:00:00Z'),
            setting(activity: 'teacher.cbt', state: 'in_force'),
          ]),
        ];
      final controller = controllerFor(serverFor(data));
      await controller.load();
      expect(controller.waiting.map((w) => w.block.activity), ['teacher.students']);
    });

    test('history is worded for a person', () {
      final catalog = AccessCatalogData.fromJson(Map<String, dynamic>.from(catalogJson));
      String say(String kind, {String activity = 'teacher.cbt', String role = '', String? forWho = 'musa@school.ng', Map<String, Object?> detail = const {}}) =>
          describeChange(AccessChangeEntry(at: DateTime.utc(2026, 9, 20), kind: kind, activity: activity, role: role, by: 'owner', forPerson: forWho, detail: detail), catalog);
      expect(say('person_grant', detail: {'note': 'Covering'}), 'Gave musa@school.ng CBT Practice ("Covering")');
      expect(say('person_block'), 'Took CBT Practice from musa@school.ng');
      expect(say('person_clear'), contains('back on their role'));
      expect(say('reassign'), 'Moved CBT Practice to musa@school.ng');
      expect(say('role_set', role: 'teacher', activity: '', detail: {'added': ['teacher.cbt'], 'removed': <String>[]}), 'Changed the screens for Teacher. Added: teacher.cbt');
      expect(say('role_reset', role: 'teacher', activity: ''), 'Put Teacher back on the built-in screens');
    });
  });

  group('the owner workspace', () {
    Future<void> openMenu(WidgetTester tester, {required bool backend}) async {
      tester.view.physicalSize = const Size(420, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final db = _Database();
      final session = SchoolSessionController(store: FakeSessionStore());
      await session.setMemberships([owner]);
      await session.selectSchool(owner);
      Widget home = ProprietorWorkspacePage(
        membership: owner,
        localDatabase: db,
        schoolSession: session,
        schoolAppearance: SchoolAppearanceController(localDatabase: db, schoolSession: session),
      );
      if (backend) home = OwnerAccessScope(repository: OwnerAccessRepository(api: apiFor(serverFor(Data()))), child: home);
      await tester.pumpWidget(MaterialApp(home: home));
      await tester.pump();
      await tester.tap(find.byTooltip('Owner workspace'));
      await tester.pumpAndSettle();
    }

    testWidgets('offers Access & Activities when there is a server', (tester) async {
      await openMenu(tester, backend: true);
      expect(find.text('Access & Activities'), findsWidgets);
    });

    testWidgets('does not offer it on demo data, where nothing could decide access', (tester) async {
      await openMenu(tester, backend: false);
      expect(find.text('School Life'), findsWidgets);
      expect(find.text('Access & Activities'), findsNothing);
    });
  });

  group('the screen', () {
    late Data data;
    late FakeServer server;
    late OwnerAccessController controller;

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(700, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      server = serverFor(data);
      controller = controllerFor(server);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: OwnerAccessPage(controller: controller))));
      await tester.pumpAndSettle();
    }

    Future<void> openPerson(WidgetTester tester, String name) async {
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
    }

    setUp(() => data = Data());

    testWidgets('lists the people with their role and what they have been given', (tester) async {
      data.people = [
        person(musaId, 'Musa', 'teacher', ['teacher.dashboard', 'teacher.students'], overrides: [
          setting(activity: 'teacher.payroll', effect: 'grant'),
          setting(activity: 'teacher.cbt', state: 'waiting_for_sync', takesEffectBy: '2026-09-23T00:00:00Z'),
        ]),
        person(aishaId, 'Aisha', 'teacher', ['teacher.dashboard']),
      ];
      await open(tester);
      expect(find.text('Musa'), findsOneWidget);
      expect(find.text('Teacher · 2 screens · 1 given · 1 taken away'), findsOneWidget);
      expect(find.text('Teacher · 1 screens'), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);       // Musa has a change waiting
    });

    testWidgets('search narrows the list', (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField).first, 'aish');
      await tester.pump();
      expect(find.text('Aisha'), findsOneWidget);
      expect(find.text('Musa'), findsNothing);
      await tester.enterText(find.byType(TextField).first, 'nobody');
      await tester.pump();
      expect(find.text('No one matches.'), findsOneWidget);
    });

    testWidgets('a person\'s screens show why they have them, and landing screens are locked', (tester) async {
      data.people = [
        person(musaId, 'Musa', 'teacher', ['teacher.dashboard', 'teacher.students', 'teacher.payroll'], overrides: [
          setting(activity: 'teacher.payroll', effect: 'grant', expiresAt: '2026-10-01T00:00:00Z'),
        ]),
      ];
      await open(tester);
      await openPerson(tester, 'Musa');
      expect(find.text('Has it · role default'), findsWidgets);
      expect(find.textContaining('Given by you · until 1 Oct 2026'), findsOneWidget);
      expect(find.text('Not available'), findsOneWidget);          // CBT Practice: their role has it, they do not
      // Their landing screen and the access screen itself have a lock, not a switch.
      final dashboard = find.byKey(const ValueKey('activity-teacher.dashboard'));
      expect(find.descendant(of: dashboard, matching: find.byType(Switch)), findsNothing);
      expect(find.descendant(of: dashboard, matching: find.byIcon(Icons.lock_outline_rounded)), findsOneWidget);
      final access = find.byKey(const ValueKey('activity-owner.access'));
      expect(find.descendant(of: access, matching: find.byType(Switch)), findsNothing);
    });

    testWidgets('taking a screen away asks how, and sends a block that waits for their next sync', (tester) async {
      await open(tester);
      await openPerson(tester, 'Musa');
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('activity-teacher.cbt')), matching: find.byType(Switch)));
      await tester.pumpAndSettle();
      expect(find.text('Take CBT Practice from Musa?'), findsOneWidget);
      expect(find.text('After they next sync'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Not this term');
      await tester.tap(find.text('Take it away'));
      await tester.pumpAndSettle();

      final sent = changes(server).single;
      expect(sent.method, 'PUT');
      expect(sent.url.path, endsWith('/people/$musaId/activities/teacher.cbt/'));
      expect(body(sent), {'effect': 'block', 'mode': 'after_sync', 'expiresAt': null, 'note': 'Not this term'});
    });

    testWidgets('"right now" is offered and sent as immediate', (tester) async {
      await open(tester);
      await openPerson(tester, 'Musa');
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('activity-teacher.cbt')), matching: find.byType(Switch)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Right now'));
      await tester.tap(find.text('Take it away'));
      await tester.pumpAndSettle();
      expect(body(changes(server).single)['mode'], 'immediate');
    });

    testWidgets('cancelling the dialog changes nothing', (tester) async {
      await open(tester);
      await openPerson(tester, 'Musa');
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('activity-teacher.cbt')), matching: find.byType(Switch)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(changes(server), isEmpty);
    });

    testWidgets('giving a sensitive screen warns first, then sends a grant', (tester) async {
      await open(tester);
      await openPerson(tester, 'Musa');
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('activity-teacher.payroll')), matching: find.byType(Switch)));
      await tester.pumpAndSettle();
      expect(find.text('Give Musa Payroll Handoff?'), findsOneWidget);
      expect(find.textContaining('shows money or personal information'), findsOneWidget);
      await tester.tap(find.text('Give access'));
      await tester.pumpAndSettle();
      final sent = changes(server).single;
      expect(body(sent)['effect'], 'grant');
      expect(sent.url.path, endsWith('/activities/teacher.payroll/'));
    });

    testWidgets('a screen that is not sensitive has no warning', (tester) async {
      data.people = [person(musaId, 'Musa', 'teacher', ['teacher.dashboard'])];
      await open(tester);
      await openPerson(tester, 'Musa');
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('activity-teacher.students')), matching: find.byType(Switch)));
      await tester.pumpAndSettle();
      expect(find.textContaining('shows money'), findsNothing);
    });

    testWidgets('a refusal from the server is shown in its own words', (tester) async {
      await open(tester);
      await openPerson(tester, 'Musa');
      data.refuse = jsonResponse({'code': 'access_error', 'message': 'You cannot give someone the access screen.'}, 400);
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('activity-teacher.cbt')), matching: find.byType(Switch)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take it away'));
      await tester.pumpAndSettle();
      expect(find.text('You cannot give someone the access screen.'), findsOneWidget);
    });

    testWidgets('Reset removes what the owner set for this person', (tester) async {
      data.people = [
        person(musaId, 'Musa', 'teacher', ['teacher.dashboard'], overrides: [setting(activity: 'teacher.students')]),
      ];
      await open(tester);
      await openPerson(tester, 'Musa');
      expect(find.textContaining('Taken away by you'), findsOneWidget);
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      final sent = changes(server).single;
      expect(sent.method, 'DELETE');
      expect(sent.url.path, endsWith('/people/$musaId/activities/teacher.students/'));
    });

    testWidgets('a block still waiting is described, and can be reversed by turning the screen back on', (tester) async {
      data.people = [
        person(musaId, 'Musa', 'teacher', ['teacher.dashboard', 'teacher.students'], overrides: [
          setting(state: 'waiting_for_sync', takesEffectBy: '2026-09-23T00:00:00Z'),
        ]),
      ];
      await open(tester);
      await openPerson(tester, 'Musa');
      expect(find.textContaining('Being taken away · after their next sync, and by 23 Sep 2026'), findsOneWidget);
      // They still have it, so the switch is on; turning it back on cancels the block and, as their role has it, needs no grant.
      final row = find.byKey(const ValueKey('activity-teacher.students'));
      expect(tester.widget<Switch>(find.descendant(of: row, matching: find.byType(Switch))).value, isTrue);
    });

    testWidgets('moving a screen to someone else', (tester) async {
      await open(tester);
      await openPerson(tester, 'Musa');
      final row = find.byKey(const ValueKey('activity-teacher.cbt'));
      await tester.tap(find.descendant(of: row, matching: find.byType(PopupMenuButton<String>)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move to someone else...'));
      await tester.pumpAndSettle();
      expect(find.text('Move CBT Practice'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aisha · Teacher').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move it'));
      await tester.pumpAndSettle();
      final sent = changes(server).single;
      expect(sent.url.path, endsWith('/reassign/'));
      expect(body(sent), {'activity': 'teacher.cbt', 'fromMembershipId': musaId, 'toMembershipId': aishaId, 'mode': 'after_sync', 'note': ''});
      expect(find.text('CBT Practice moved.'), findsOneWidget);
    });

    testWidgets('roles: the built-in ones and the ones you changed', (tester) async {
      await open(tester);
      await tester.tap(find.text('Roles'));
      await tester.pumpAndSettle();
      expect(find.text('Teacher'), findsOneWidget);
      expect(find.text('3 screens · 2 people'), findsOneWidget);
      expect(find.text('Finance officer'), findsOneWidget);
      expect(find.text('Changed'), findsOneWidget);
    });

    testWidgets('editing a role: landing screen stays on, saving asks first and sends the chosen set', (tester) async {
      await open(tester);
      await tester.tap(find.text('Roles'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('role-teacher')));
      await tester.pumpAndSettle();

      final landing = find.byKey(const ValueKey('role-activity-teacher.dashboard'));
      expect(tester.widget<CheckboxListTile>(landing).onChanged, isNull);         // cannot be switched off
      expect(find.text('Save changes'), findsNothing);                            // nothing changed yet

      await tester.tap(find.byKey(const ValueKey('role-activity-teacher.cbt')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(find.text('Save changes for Teacher?'), findsOneWidget);
      expect(find.textContaining('all 2 people'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final sent = changes(server).single;
      expect(sent.method, 'PUT');
      expect(sent.url.path, endsWith('/roles/teacher/'));
      expect(body(sent), {'activities': ['teacher.dashboard', 'teacher.students']});
      expect(find.text('Teacher updated.'), findsOneWidget);
    });

    testWidgets('a changed role can go back to the built-in screens', (tester) async {
      await open(tester);
      await tester.tap(find.text('Roles'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('role-accountant')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Go back'));
      await tester.pumpAndSettle();
      final sent = changes(server).single;
      expect(sent.method, 'DELETE');
      expect(sent.url.path, endsWith('/roles/accountant/'));
    });

    testWidgets('waiting: shows each block that has not taken effect and can cancel it', (tester) async {
      data.people = [
        person(musaId, 'Musa', 'teacher', ['teacher.students'], overrides: [
          setting(state: 'waiting_for_sync', takesEffectBy: '2026-09-23T00:00:00Z'),
        ]),
      ];
      await open(tester);
      await tester.tap(find.text('Waiting'));
      await tester.pumpAndSettle();
      expect(find.text('Musa: Students'), findsOneWidget);
      expect(find.textContaining('by 23 Sep 2026 at the latest'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(changes(server).single.method, 'DELETE');
      expect(find.textContaining('Musa keeps Students'), findsOneWidget);
    });

    testWidgets('waiting: says so when nothing is waiting', (tester) async {
      await open(tester);
      await tester.tap(find.text('Waiting'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Nothing is waiting'), findsOneWidget);
    });

    testWidgets('history: reads as sentences with who and when', (tester) async {
      data.history = [
        {'at': '2026-09-20T09:30:00Z', 'kind': 'person_block', 'activity': 'teacher.cbt', 'role': '', 'by': 'owner@school.ng', 'for': 'musa@school.ng', 'detail': {'note': 'Not this term'}},
      ];
      await open(tester);
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('Took CBT Practice from musa@school.ng ("Not this term")'), findsOneWidget);
      expect(find.textContaining('by owner@school.ng'), findsOneWidget);
    });

    testWidgets('with no connection it says so and can try again', (tester) async {
      data.offline = true;
      await open(tester);
      expect(find.textContaining('need a connection'), findsOneWidget);
      data.offline = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Musa'), findsOneWidget);
    });
  });
}

class _Database implements LocalDatabase {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getLocalRecord) return Future<LocalRecord?>.value(null);
    if (invocation.memberName == #getLocalRecords) return Future<List<LocalRecord>>.value([]);
    if (invocation.memberName == #pendingCount) return 0;
    return super.noSuchMethod(invocation);
  }
}
