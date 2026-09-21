import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../auth/token_store.dart';
import 'api_config.dart';
import 'api_exceptions.dart';

/// Talks to the SchoolOS backend: JSON in, JSON out, the signed-in person's
/// token attached, and an expired token renewed once, quietly.
///
/// It only throws three things, so callers can react to what matters:
/// [ApiOfflineException] (try again later), [SessionExpiredException] (sign in
/// again) and [ApiException] (the server said no, with words to show).
class ApiClient {
  ApiClient({
    required ApiConfig config,
    required TokenStore tokens,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 20),
  })  : _config = config,
        _tokens = tokens,
        _http = httpClient ?? http.Client();

  final ApiConfig _config;
  final TokenStore _tokens;
  final http.Client _http;
  final Duration timeout;

  Future<bool>? _refreshing;

  Future<Object?> get(String path, {Map<String, String>? query, bool authenticated = true}) =>
      _send('GET', path, query: query, authenticated: authenticated);

  Future<Object?> post(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) => _send('POST', path, query: query, body: body, authenticated: authenticated);

  Future<Object?> put(String path, {Object? body, Map<String, String>? query}) =>
      _send('PUT', path, query: query, body: body);

  Future<Object?> delete(String path, {Map<String, String>? query}) =>
      _send('DELETE', path, query: query);

  Future<Object?> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool authenticated = true,
  }) async {
    var response = await _request(method, path, query, body, authenticated);
    if (response.statusCode == 401 && authenticated) {
      if (await _refreshOnce()) {
        response = await _request(method, path, query, body, authenticated);
      }
      if (response.statusCode == 401) {
        await _tokens.clear();
        throw const SessionExpiredException();
      }
    }
    return _decode(response);
  }

  Future<http.Response> _request(
    String method,
    String path,
    Map<String, String>? query,
    Object? body,
    bool authenticated,
  ) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
    };
    if (authenticated) {
      final tokens = await _tokens.read();
      if (tokens == null) throw const SessionExpiredException();
      headers['Authorization'] = 'Bearer ${tokens.access}';
    }
    final uri = _config.uri(path, query);
    try {
      final encoded = jsonEncode(body ?? const {});
      final future = switch (method) {
        'GET' => _http.get(uri, headers: headers),
        'DELETE' => _http.delete(uri, headers: headers),
        'PUT' => _http.put(uri, headers: headers, body: encoded),
        _ => _http.post(uri, headers: headers, body: encoded),
      };
      return await future.timeout(timeout);
    } on TimeoutException {
      throw const ApiOfflineException('The server took too long to answer.');
    } on SocketException {
      throw const ApiOfflineException();
    } on http.ClientException {
      throw const ApiOfflineException();
    }
  }

  /// One refresh at a time, however many requests found the token expired.
  Future<bool> _refreshOnce() => _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<bool> _refresh() async {
    final tokens = await _tokens.read();
    if (tokens == null) return false;
    try {
      final response = await _request('POST', 'auth/token/refresh/', null, {'refresh': tokens.refresh}, false);
      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body);
      if (data is! Map || data['access'] is! String) return false;
      // The server may rotate the refresh token; keep whichever is newest.
      await _tokens.write(tokens.withAccess(data['access'] as String, newRefresh: data['refresh'] as String?));
      return true;
    } on ApiOfflineException {
      rethrow;
    } on FormatException {
      return false;
    }
  }

  Object? _decode(http.Response response) {
    Object? data;
    if (response.body.isNotEmpty) {
      try {
        data = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        data = null;
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return data;
    if (response.statusCode >= 500) {
      throw const ApiOfflineException('The server had a problem. Please try again shortly.');
    }
    throw ApiException(response.statusCode, _messageFrom(data, response.statusCode), code: _codeFrom(data), details: data);
  }

  static String? _codeFrom(Object? data) => data is Map && data['code'] is String ? data['code'] as String : null;

  /// The server's own words where it gave them (they are written for people).
  static String _messageFrom(Object? data, int status) {
    if (data is Map) {
      for (final key in ['message', 'detail']) {
        if (data[key] is String && (data[key] as String).isNotEmpty) return data[key] as String;
      }
      // Validation errors: {"field": ["problem", ...]}
      final problems = <String>[];
      for (final value in data.values) {
        if (value is List) problems.addAll(value.whereType<String>());
        if (value is String) problems.add(value);
      }
      if (problems.isNotEmpty) return problems.join(' ');
    }
    return switch (status) {
      401 => 'Please sign in again.',
      403 => 'You do not have access to this.',
      404 => 'That was not found.',
      429 => 'Too many attempts. Please wait a moment and try again.',
      _ => 'Something went wrong (error $status).',
    };
  }
}
