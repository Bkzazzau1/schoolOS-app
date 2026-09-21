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
