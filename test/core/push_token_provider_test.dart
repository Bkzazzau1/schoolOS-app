import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/notifications/push_token_provider.dart';

void main() {
  // In a plain `flutter test` run there is no Firebase plugin implementation
  // registered at all (the same reason a real device with no
  // google-services.json/GoogleService-Info.plist sees this too) - so every
  // one of these proves the honest, disabled-by-default outcome, never a
  // fabricated token.

  test('a provider with no real Firebase app available stays disabled', () async {
    final provider = PushTokenProvider();
    expect(await provider.currentToken(), isNull);
    expect(provider.enabled, isFalse);
  });

  test('ensureReady never throws when Firebase is unavailable', () async {
    final provider = PushTokenProvider();
    await provider.ensureReady();
    expect(provider.enabled, isFalse);
    expect(provider.platform, isNull);
  });

  test('onRefresh is an empty stream when disabled, not an error', () async {
    final provider = PushTokenProvider();
    await provider.currentToken();
    await expectLater(provider.onRefresh, emitsDone);
  });

  test('registering the background handler never throws when push is unavailable', () async {
    await registerPushBackgroundHandlerIfAvailable();
  });
}
