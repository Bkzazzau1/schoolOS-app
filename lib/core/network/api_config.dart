/// Where the SchoolOS backend is.
///
/// Set it when running or building the app:
///
///     flutter run --dart-define=API_BASE_URL=https://api.schoolos.ng/api/v1
///
/// With no value the app runs on its built-in demo data exactly as before, so
/// nothing changes until a backend is chosen.
class ApiConfig {
  const ApiConfig(this.baseUrl);

  static const fromEnvironment = ApiConfig(
    String.fromEnvironment('API_BASE_URL'),
  );

  final String baseUrl;

  bool get enabled => baseUrl.trim().isNotEmpty;

  Uri uri(String path, [Map<String, String>? query]) {
    final base = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final tail = path.startsWith('/') ? path : '/$path';
    final parsed = Uri.parse('$base$tail');
    return query == null || query.isEmpty
        ? parsed
        : parsed.replace(queryParameters: {...parsed.queryParameters, ...query});
  }
}

/// Thrown at startup when a release build has no real backend wired in. A
/// release build must never silently fall back to running on demo data: that
/// would ship indistinguishably from a real release until someone noticed the
/// data was fake.
class MissingApiBaseUrlError extends StateError {
  MissingApiBaseUrlError()
      : super(
          'This release build has no API_BASE_URL, so it would silently run on '
          'demo data. Build with --dart-define=API_BASE_URL=<the real backend '
          'URL>.',
        );
}

/// Call once at startup, before anything else. [isRelease] is `kReleaseMode`
/// in `main()`, passed in rather than read here so this can be tested without
/// actually producing a release build.
void assertApiConfiguredForRelease(ApiConfig config, {required bool isRelease}) {
  if (isRelease && !config.enabled) {
    throw MissingApiBaseUrlError();
  }
}
