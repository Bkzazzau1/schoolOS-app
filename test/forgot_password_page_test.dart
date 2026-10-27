import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/auth/auth_repository.dart';
import 'package:schoolos_app/core/auth/token_store.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/authentication/presentation/forgot_password_page.dart';

import 'core/backend_test_support.dart';

void main() {
  late MemoryTokenStore tokens;
  late SchoolSessionController session;

  setUp(() {
    tokens = MemoryTokenStore();
    session = SchoolSessionController(store: FakeSessionStore());
  });

  AuthRepository repo(FakeServer server) => AuthRepository(
    api: apiFor(server, tokens: tokens),
    tokens: tokens,
    schoolSession: session,
  );

  Future<void> pump(WidgetTester tester, AuthRepository auth) async {
    await tester.pumpWidget(
      MaterialApp(home: ForgotPasswordPage(auth: auth)),
    );
  }

  group('the chooser', () {
    testWidgets('offers both audiences and nothing is sent until one is chosen', (tester) async {
      final server = FakeServer((r) async => jsonResponse({}));
      await pump(tester, repo(server));
      expect(find.text('Student admission ID, or Parent phone number'), findsOneWidget);
      expect(find.text('Staff or proprietor email'), findsOneWidget);
      expect(server.requests, isEmpty);
    });
  });

  group('Student or Parent', () {
    testWidgets('submitting a blank login ID is refused locally, nothing is sent', (tester) async {
      final server = FakeServer((r) async => jsonResponse({}));
      await pump(tester, repo(server));
      await tester.tap(find.text('Student admission ID, or Parent phone number'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Request recovery'));
      await tester.pump();
      expect(find.text('Enter your login ID'), findsOneWidget);
      expect(server.requests, isEmpty);
    });

    testWidgets('a real submission shows the servers accepted message', (tester) async {
      final server = FakeServer(
        (r) async => jsonResponse({'accepted': true, 'message': 'The school office will review this.'}),
      );
      await pump(tester, repo(server));
      await tester.tap(find.text('Student admission ID, or Parent phone number'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'ADM-001');
      await tester.tap(find.text('Request recovery'));
      await tester.pumpAndSettle();

      expect(body(server.to('credentials/recovery/request/').single), {'identifier': 'ADM-001'});
      expect(find.text('The school office will review this.'), findsOneWidget);
    });
  });

  group('Staff or Proprietor', () {
    testWidgets('an invalid email is refused locally, nothing is sent', (tester) async {
      final server = FakeServer((r) async => jsonResponse({}));
      await pump(tester, repo(server));
      await tester.tap(find.text('Staff or proprietor email'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'not-an-email');
      await tester.tap(find.text('Send reset code'));
      await tester.pump();
      expect(find.text('Enter a real email address'), findsOneWidget);
      expect(server.requests, isEmpty);
    });

    testWidgets('requesting a code, then a password mismatch is refused locally', (tester) async {
      final server = FakeServer((r) async => jsonResponse({'accepted': true}));
      await pump(tester, repo(server));
      await tester.tap(find.text('Staff or proprietor email'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'owner@school.ng');
      await tester.tap(find.text('Send reset code'));
      await tester.pumpAndSettle();

      expect(body(server.to('credentials/password-reset/request/').single), {'email': 'owner@school.ng'});
      expect(find.textContaining('a code is on its way to owner@school.ng'), findsOneWidget);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '123456');
      await tester.enterText(fields.at(1), 'a-new-long-password-1');
      await tester.enterText(fields.at(2), 'does-not-match');
      await tester.tap(find.text('Set new password'));
      await tester.pump();

      expect(find.text('The two passwords do not match'), findsOneWidget);
      expect(server.to('credentials/password-reset/confirm/'), isEmpty);
    });

    testWidgets('the full flow: request, confirm, done', (tester) async {
      final server = FakeServer((r) async {
        if (r.url.path.endsWith('password-reset/request/')) {
          return jsonResponse({'accepted': true});
        }
        return jsonResponse({'reset': true, 'resetAt': 'now'});
      });
      await pump(tester, repo(server));
      await tester.tap(find.text('Staff or proprietor email'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'owner@school.ng');
      await tester.tap(find.text('Send reset code'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '123456');
      await tester.enterText(fields.at(1), 'a-new-long-password-1');
      await tester.enterText(fields.at(2), 'a-new-long-password-1');
      await tester.tap(find.text('Set new password'));
      await tester.pumpAndSettle();

      expect(body(server.to('credentials/password-reset/confirm/').single), {
        'email': 'owner@school.ng',
        'code': '123456',
        'newPassword': 'a-new-long-password-1',
      });
      expect(find.text('Password changed. Sign in with your new password.'), findsOneWidget);
    });

    testWidgets('a wrong code shows the servers own message and stays on the code step', (tester) async {
      final server = FakeServer((r) async {
        if (r.url.path.endsWith('password-reset/request/')) {
          return jsonResponse({'accepted': true});
        }
        return jsonResponse({'message': 'That reset code is not correct or has expired.'}, 400);
      });
      await pump(tester, repo(server));
      await tester.tap(find.text('Staff or proprietor email'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'owner@school.ng');
      await tester.tap(find.text('Send reset code'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '000000');
      await tester.enterText(fields.at(1), 'a-new-long-password-1');
      await tester.enterText(fields.at(2), 'a-new-long-password-1');
      await tester.tap(find.text('Set new password'));
      await tester.pumpAndSettle();

      expect(find.text('That reset code is not correct or has expired.'), findsOneWidget);
      expect(find.text('Set new password'), findsOneWidget);
    });
  });
}
