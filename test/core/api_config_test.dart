import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/network/api_config.dart';

void main() {
  group('a release build must never silently ship on demo data', () {
    test('no API_BASE_URL in a release build throws', () {
      expect(
        () => assertApiConfiguredForRelease(const ApiConfig(''), isRelease: true),
        throwsA(isA<MissingApiBaseUrlError>()),
      );
    });

    test('a blank or whitespace-only API_BASE_URL in a release build still throws', () {
      expect(
        () => assertApiConfiguredForRelease(const ApiConfig('   '), isRelease: true),
        throwsA(isA<MissingApiBaseUrlError>()),
      );
    });

    test('a real API_BASE_URL in a release build is fine', () {
      expect(
        () => assertApiConfiguredForRelease(
          const ApiConfig('https://api.schoolos.ng/api/v1'),
          isRelease: true,
        ),
        returnsNormally,
      );
    });

    test('no API_BASE_URL outside a release build is fine: that is demo mode, on purpose', () {
      expect(
        () => assertApiConfiguredForRelease(const ApiConfig(''), isRelease: false),
        returnsNormally,
      );
    });
  });
}
