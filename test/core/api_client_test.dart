import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:schoolos_app/core/auth/token_store.dart';
import 'package:schoolos_app/core/network/api_client.dart';
import 'package:schoolos_app/core/network/api_config.dart';
import 'package:schoolos_app/core/network/api_exceptions.dart';

import 'backend_test_support.dart';

void main() {
  group('ApiConfig', () {
    test(
      'builds addresses whatever slashes are used, and is off without a base',
      () {
        expect(
          const ApiConfig('https://x.ng/api/v1').uri('me/').toString(),
          'https://x.ng/api/v1/me/',
        );
        expect(
          const ApiConfig('https://x.ng/api/v1/').uri('/me/').toString(),
          'https://x.ng/api/v1/me/',
        );
        expect(
          const ApiConfig(
            'https://x.ng/api/v1',
          ).uri('sync/pull/', {'since': '3'}).toString(),
          'https://x.ng/api/v1/sync/pull/?since=3',
        );
        expect(const ApiConfig('').enabled, isFalse);
        expect(const ApiConfig('  ').enabled, isFalse);
        expect(testConfig.enabled, isTrue);
      },
    );
  });

  group('ApiClient', () {
    test('sends the token and reads JSON', () async {
      final server = FakeServer((r) async => jsonResponse({'ok': true}));
      final data = await apiFor(server).get('me/');
      expect(data, {'ok': true});
      expect(
        server.requests.single.headers['Authorization'],
        'Bearer access-1',
      );
    });

    test('posts a JSON body', () async {
      final server = FakeServer((r) async => jsonResponse({}));
      await apiFor(server).post('sync/push/', body: {'a': 1});
      expect(body(server.requests.single), {'a': 1});
      expect(
        server.requests.single.headers['Content-Type'],
        contains('application/json'),
      );
    });

    test('renews an expired token once and repeats the request', () async {
      final tokens = MemoryTokenStore()
        ..tokens = const AuthTokens(access: 'old', refresh: 'r-1');
      final server = FakeServer((r) async {
        if (r.url.path.endsWith('auth/token/refresh/')) {
          return jsonResponse({'access': 'new'});
        }
        return r.headers['Authorization'] == 'Bearer new'
            ? jsonResponse({'ok': 1})
            : jsonResponse({}, 401);
      });
      expect(await apiFor(server, tokens: tokens).get('me/'), {'ok': 1});
      expect(tokens.tokens!.access, 'new');
      expect(tokens.tokens!.refresh, 'r-1');
      expect(server.to('me/').length, 2);
    });

    test('keeps a rotated refresh token', () async {
      final tokens = MemoryTokenStore()
        ..tokens = const AuthTokens(access: 'old', refresh: 'r-1');
      final server = FakeServer((r) async {
        if (r.url.path.endsWith('auth/token/refresh/')) {
          return jsonResponse({'access': 'new', 'refresh': 'r-2'});
        }
        return r.headers['Authorization'] == 'Bearer new'
            ? jsonResponse({})
            : jsonResponse({}, 401);
      });
      await apiFor(server, tokens: tokens).get('me/');
      expect(tokens.tokens!.refresh, 'r-2');
    });

    test(
      'two requests that both find the token expired share one renewal',
      () async {
        final tokens = MemoryTokenStore()
          ..tokens = const AuthTokens(access: 'old', refresh: 'r-1');
        final server = FakeServer((r) async {
          if (r.url.path.endsWith('auth/token/refresh/')) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return jsonResponse({'access': 'new'});
          }
          return r.headers['Authorization'] == 'Bearer new'
              ? jsonResponse({})
              : jsonResponse({}, 401);
        });
        final api = apiFor(server, tokens: tokens);
        await Future.wait([api.get('a/'), api.get('b/')]);
        expect(server.to('auth/token/refresh/').length, 1);
      },
    );

    test('when the token cannot be renewed the sign-in is dropped', () async {
      final tokens = MemoryTokenStore()
        ..tokens = const AuthTokens(access: 'old', refresh: 'dead');
      final server = FakeServer(
        (r) async => jsonResponse({'detail': 'no'}, 401),
      );
      await expectLater(
        apiFor(server, tokens: tokens).get('me/'),
        throwsA(isA<SessionExpiredException>()),
      );
      expect(tokens.tokens, isNull);
    });

    test('with no sign-in it does not even ask the server', () async {
      final server = FakeServer((r) async => jsonResponse({}));
      final api = apiFor(server, tokens: MemoryTokenStore());
      await expectLater(
        api.get('me/'),
        throwsA(isA<SessionExpiredException>()),
      );
      expect(server.requests, isEmpty);
    });

    test('a sign-in request does not send or renew a token', () async {
      final server = FakeServer(
        (r) async => jsonResponse({'detail': 'No active account found'}, 401),
      );
      await expectLater(
        apiFor(server).post('auth/token/', body: {}, authenticated: false),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'No active account found',
          ),
        ),
      );
      expect(
        server.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
      expect(server.requests.length, 1);
    });

    test(
      'no signal, a timeout and a broken server all mean try again later',
      () async {
        for (final failing in <Future<http.Response> Function(http.Request)>[
          (r) async => throw const SocketException('no route'),
          (r) async => throw http.ClientException('reset'),
          (r) async => jsonResponse({}, 503),
          (r) async => jsonResponse({}, 500),
        ]) {
          await expectLater(
            apiFor(FakeServer(failing)).get('me/'),
            throwsA(isA<ApiOfflineException>()),
          );
        }
      },
    );

    test(
      'a server that answers slowly past the timeout is treated as offline',
      () async {
        final slow = FakeServer((r) async {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          return jsonResponse({});
        });
        final api = ApiClient(
          config: testConfig,
          tokens: MemoryTokenStore()
            ..tokens = const AuthTokens(access: 'a', refresh: 'r'),
          httpClient: slow.client,
          timeout: const Duration(milliseconds: 50),
        );
        await expectLater(api.get('me/'), throwsA(isA<ApiOfflineException>()));
      },
    );

    test('errors carry the servers own words and code', () async {
      final cases = <(Object, int, String, String?)>[
        (
          {'code': 'membership_required', 'message': 'Say which role.'},
          400,
          'Say which role.',
          'membership_required',
        ),
        (
          {'detail': 'You do not have permission.'},
          403,
          'You do not have permission.',
          null,
        ),
        (
          {
            'password': ['Too short.', 'Too common.'],
          },
          400,
          'Too short. Too common.',
          null,
        ),
        (<String, Object>{}, 404, 'That was not found.', null),
        (
          <String, Object>{},
          429,
          'Too many attempts. Please wait a moment and try again.',
          null,
        ),
      ];
      for (final (data, status, message, code) in cases) {
        final error = await apiFor(
          FakeServer((r) async => jsonResponse(data, status)),
        ).get('x/').then<Object?>((_) => null, onError: (e) => e);
        expect(error, isA<ApiException>(), reason: '$status');
        expect((error as ApiException).message, message);
        expect(error.code, code);
        expect(error.statusCode, status);
      }
    });

    test('a page that is not JSON does not crash', () async {
      final server = FakeServer(
        (r) async => http.Response('<html>oops</html>', 404),
      );
      await expectLater(apiFor(server).get('x/'), throwsA(isA<ApiException>()));
    });
  });
}
