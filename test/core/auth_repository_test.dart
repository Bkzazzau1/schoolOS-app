import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/auth/auth_repository.dart';
import 'package:schoolos_app/core/auth/token_store.dart';
import 'package:schoolos_app/core/network/api_exceptions.dart';
import 'package:schoolos_app/core/notifications/push_token_provider.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'backend_test_support.dart';

/// A stand-in for the real Firebase-backed [PushTokenProvider] (which stays
/// honestly disabled in any plain `flutter test` run - see
/// push_token_provider_test.dart) so these tests can prove what
/// AuthRepository does once a device token genuinely exists.
class _FakePushTokenProvider extends PushTokenProvider {
  _FakePushTokenProvider({this.fakeToken, String fakePlatform = 'android'}) : _fakePlatform = fakePlatform;

  final String? fakeToken;
  final String _fakePlatform;

  @override
  bool get enabled => fakeToken != null;

  @override
  String? get platform => fakeToken != null ? _fakePlatform : null;

  @override
  Future<void> ensureReady() async {}

  @override
  Future<String?> currentToken() async => fakeToken;

  @override
  Stream<String> get onRefresh => const Stream.empty();
}

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

  AuthRepository repo(FakeServer server, {PushTokenProvider? pushTokens}) => AuthRepository(
    api: apiFor(server, tokens: tokens),
    tokens: tokens,
    schoolSession: session,
    pushTokens: pushTokens,
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

  test('signing in registers this devices push token when one is available', () async {
    final server = FakeServer((r) async {
      if (r.url.path.endsWith('auth/token/')) return jsonResponse({'access': 'a-1', 'refresh': 'r-1'});
      return jsonResponse(_me);
    });
    await repo(server, pushTokens: _FakePushTokenProvider(fakeToken: 'fcm-tok-1')).signIn(
      'musa@school.ng',
      'a-good-password',
    );
    expect(body(server.to('auth/device-tokens/').single), {'token': 'fcm-tok-1', 'platform': 'android'});
  });

  test('signing in never calls device-tokens when no push token is available', () async {
    final server = FakeServer((r) async {
      if (r.url.path.endsWith('auth/token/')) return jsonResponse({'access': 'a-1', 'refresh': 'r-1'});
      return jsonResponse(_me);
    });
    await repo(server, pushTokens: _FakePushTokenProvider()).signIn('musa@school.ng', 'a-good-password');
    expect(server.to('auth/device-tokens/'), isEmpty);
  });

  test('signing in with no push token provider at all never calls device-tokens', () async {
    final server = FakeServer((r) async {
      if (r.url.path.endsWith('auth/token/')) return jsonResponse({'access': 'a-1', 'refresh': 'r-1'});
      return jsonResponse(_me);
    });
    await repo(server).signIn('musa@school.ng', 'a-good-password');
    expect(server.to('auth/device-tokens/'), isEmpty);
  });

  test('a failing device-token registration never blocks sign-in', () async {
    final server = FakeServer((r) async {
      if (r.url.path.endsWith('auth/token/')) return jsonResponse({'access': 'a-1', 'refresh': 'r-1'});
      if (r.url.path.endsWith('auth/device-tokens/')) return jsonResponse({'detail': 'nope'}, 500);
      return jsonResponse(_me);
    });
    final profile = await repo(server, pushTokens: _FakePushTokenProvider(fakeToken: 'fcm-tok-1')).signIn(
      'musa@school.ng',
      'a-good-password',
    );
    expect(profile.email, 'musa@school.ng');
  });

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

  test('signing out forgets the tokens and the school, and revokes the refresh token', () async {
    await session.setMemberships([teacher]);
    await session.selectSchool(teacher);
    tokens.tokens = const AuthTokens(access: 'a', refresh: 'r-to-revoke');
    final server = FakeServer((r) async => jsonResponse({'loggedOut': true}));
    final auth = repo(server);
    expect(await auth.hasSession(), isTrue);
    await auth.signOut();
    expect(await auth.hasSession(), isFalse);
    expect(session.memberships, isEmpty);
    expect(session.activeMembership, isNull);
    expect(body(server.to('auth/logout/').single), {'refresh': 'r-to-revoke'});
  });

  test('signing out still forgets the tokens even when the server cannot be reached', () async {
    tokens.tokens = const AuthTokens(access: 'a', refresh: 'r');
    final auth = repo(FakeServer((r) async => throw const ApiOfflineException()));
    await auth.signOut();
    expect(await auth.hasSession(), isFalse);
  });

  test('signing out with no session never calls the server', () async {
    final server = FakeServer((r) async => jsonResponse({}));
    await repo(server).signOut();
    expect(server.to('auth/logout/'), isEmpty);
  });

  test('signing out unregisters this devices push token when one is available', () async {
    tokens.tokens = const AuthTokens(access: 'a', refresh: 'r');
    final server = FakeServer((r) async => jsonResponse({'loggedOut': true, 'unregistered': true}));
    await repo(server, pushTokens: _FakePushTokenProvider(fakeToken: 'fcm-tok-1')).signOut();
    expect(body(server.to('auth/device-tokens/unregister/').single), {'token': 'fcm-tok-1'});
  });

  test('signing out never calls unregister when no push token is available', () async {
    tokens.tokens = const AuthTokens(access: 'a', refresh: 'r');
    final server = FakeServer((r) async => jsonResponse({'loggedOut': true}));
    await repo(server, pushTokens: _FakePushTokenProvider()).signOut();
    expect(server.to('auth/device-tokens/unregister/'), isEmpty);
  });

  test('a failing push-token unregister never blocks signing out', () async {
    tokens.tokens = const AuthTokens(access: 'a', refresh: 'r');
    final server = FakeServer((r) async {
      if (r.url.path.endsWith('auth/device-tokens/unregister/')) return jsonResponse({'detail': 'nope'}, 500);
      return jsonResponse({'loggedOut': true});
    });
    final auth = repo(server, pushTokens: _FakePushTokenProvider(fakeToken: 'fcm-tok-1'));
    await auth.signOut();
    expect(await auth.hasSession(), isFalse);
  });

  test('requesting an email password reset posts the email and returns the servers message', () async {
    final server = FakeServer(
      (r) async => jsonResponse({'accepted': true, 'message': 'A code is on its way.'}),
    );
    final message = await repo(server).requestEmailPasswordReset('  Owner@School.NG ');
    expect(body(server.to('credentials/password-reset/request/').single), {
      'email': 'Owner@School.NG',
    });
    expect(
      server.to('credentials/password-reset/request/').single.headers.containsKey('Authorization'),
      isFalse,
    );
    expect(message, 'A code is on its way.');
  });

  test('confirming an email password reset posts email, code and the new password', () async {
    final server = FakeServer((r) async => jsonResponse({'reset': true, 'resetAt': 'now'}));
    await repo(server).confirmEmailPasswordReset(
      email: 'owner@school.ng',
      code: '123456',
      newPassword: 'a-new-long-password-1',
    );
    expect(body(server.to('credentials/password-reset/confirm/').single), {
      'email': 'owner@school.ng',
      'code': '123456',
      'newPassword': 'a-new-long-password-1',
    });
  });

  test('a wrong reset code surfaces the servers own message', () async {
    final server = FakeServer(
      (r) async => jsonResponse({'message': 'That reset code is not correct or has expired.'}, 400),
    );
    await expectLater(
      repo(server).confirmEmailPasswordReset(
        email: 'owner@school.ng',
        code: '000000',
        newPassword: 'a-new-long-password-1',
      ),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('not correct or has expired'),
        ),
      ),
    );
  });
}
