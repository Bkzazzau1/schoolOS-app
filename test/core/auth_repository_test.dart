import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/auth/auth_repository.dart';
import 'package:schoolos_app/core/auth/token_store.dart';
import 'package:schoolos_app/core/network/api_exceptions.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'backend_test_support.dart';

const _me = {
  'id': 'u-1',
  'email': 'musa@school.ng',
  'name': 'Musa Ibrahim',
  'memberships': [
    {
      'id': 'm-1',
      'schoolId': 's-1',
      'schoolName': 'BrightGate',
      'role': 'teacher',
    },
    {'id': 'm-2', 'schoolId': 's-2', 'schoolName': 'Other', 'role': 'parent'},
  ],
};

void main() {
  late MemoryTokenStore tokens;
  late FakeSessionStore sessionStore;
  late SchoolSessionController session;

  setUp(() {
    tokens = MemoryTokenStore();
    sessionStore = FakeSessionStore();
    session = SchoolSessionController(store: sessionStore);
  });

  AuthRepository repo(FakeServer server) => AuthRepository(
    api: apiFor(server, tokens: tokens),
    tokens: tokens,
    schoolSession: session,
  );

  test(
    'signing in keeps the tokens and the schools the person can act in',
    () async {
      final server = FakeServer((r) async {
        if (r.url.path.endsWith('auth/token/')) {
          return jsonResponse({'access': 'a-1', 'refresh': 'r-1'});
        }
        return jsonResponse(_me);
      });
      final profile = await repo(
        server,
      ).signIn('  Musa@School.NG ', 'a-good-password');

      expect(body(server.to('auth/token/').single), {
        'email': 'musa@school.ng',
        'password': 'a-good-password',
      });
      expect(
        server.to('auth/token/').single.headers.containsKey('Authorization'),
        isFalse,
      );
      expect(server.to('me/').single.headers['Authorization'], 'Bearer a-1');
      expect((tokens.tokens!.access, tokens.tokens!.refresh), ('a-1', 'r-1'));
      expect((profile.name, profile.email), ('Musa Ibrahim', 'musa@school.ng'));
      expect(session.memberships.map((m) => (m.id, m.role)), [
        ('m-1', SchoolRole.teacher),
        ('m-2', SchoolRole.parent),
      ]);
      expect(sessionStore.memberships.length, 2);
    },
  );

  test('wrong details give the servers message and keep nothing', () async {
    final server = FakeServer(
      (r) async => jsonResponse({
        'detail': 'No active account found with the given credentials',
      }, 401),
    );
    await expectLater(
      repo(server).signIn('a@b.ng', 'wrong'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('No active account'),
        ),
      ),
    );
    expect(tokens.tokens, isNull);
    expect(session.memberships, isEmpty);
  });

  test(
    'a role this version of the app does not know is skipped, not a crash',
    () async {
      final server = FakeServer(
        (r) async => jsonResponse({
          ..._me,
          'memberships': [
            {
              'id': 'm-1',
              'schoolId': 's-1',
              'schoolName': 'BrightGate',
              'role': 'teacher',
            },
            {
              'id': 'm-9',
              'schoolId': 's-1',
              'schoolName': 'BrightGate',
              'role': 'astronaut',
            },
          ],
        }),
      );
      tokens.tokens = const AuthTokens(access: 'a', refresh: 'r');
      final profile = await repo(server).refreshProfile();
      expect(profile.memberships.map((m) => m.id), ['m-1']);
    },
  );

  test('offline, the last known schools stay as they were', () async {
    session = SchoolSessionController(store: sessionStore);
    await session.setMemberships([teacher]);
    tokens.tokens = const AuthTokens(access: 'a', refresh: 'r');
    final server = FakeServer((r) async => throw const ApiOfflineException());
    await expectLater(
      repo(server).refreshProfile(),
      throwsA(isA<ApiOfflineException>()),
    );
    expect(session.memberships.map((m) => m.id), [teacher.id]);
  });

  test(
    'a school the person lost is no longer active after the list is refreshed',
    () async {
      await session.setMemberships([teacher]);
      await session.selectSchool(teacher);
      tokens.tokens = const AuthTokens(access: 'a', refresh: 'r');
      final server = FakeServer(
        (r) async => jsonResponse({..._me, 'memberships': []}),
      );
      await repo(server).refreshProfile();
      expect(session.activeMembership, isNull);
    },
  );

  test('signing out forgets the tokens and the school', () async {
    await session.setMemberships([teacher]);
    await session.selectSchool(teacher);
    tokens.tokens = const AuthTokens(access: 'a', refresh: 'r');
    final auth = repo(FakeServer((r) async => jsonResponse({})));
    expect(await auth.hasSession(), isTrue);
    await auth.signOut();
    expect(await auth.hasSession(), isFalse);
    expect(session.memberships, isEmpty);
    expect(session.activeMembership, isNull);
  });
}
