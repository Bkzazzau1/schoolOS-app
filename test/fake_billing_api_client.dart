import 'dart:async';

import 'package:schoolos_app/core/auth/token_store.dart';
import 'package:schoolos_app/core/network/api_client.dart';
import 'package:schoolos_app/core/network/api_config.dart';

class _UnusedTokenStore implements TokenStore {
  // Never actually read: FakeApiClient overrides get()/post() directly, so the base
  // ApiClient's own token-refresh machinery that would call these is never reached.
  @override
  Future<AuthTokens?> read() async => null;
  @override
  Future<void> write(AuthTokens tokens) async {}
  @override
  Future<void> clear() async {}
}

/// One recorded call a test can assert against - which path was hit, how many times, and
/// with what body - so a widget test can prove "never create another charge" or "refetches
/// exactly once," not just that *some* request happened.
class FakeApiCall {
  const FakeApiCall(this.method, this.path, {this.body});

  final String method;
  final String path;
  final Object? body;

  @override
  String toString() => '$method $path';
}

/// A deterministic stand-in for the real network client, for Flutter widget tests (Phase D
/// Stage 1.5, Task 6): returns canned JSON per exact path, records every call made, and never
/// performs a real HTTP request or talks to a real payment provider.
///
/// Register a response with [respond] (always the same answer) or [respondWith] (computed
/// per call, so a test can change its answer after the Nth call - e.g. "pending" on the first
/// verify, "succeeded" on the second). Register a thrown exception with [fail].
class FakeApiClient extends ApiClient {
  FakeApiClient() : super(config: const ApiConfig(''), tokens: _UnusedTokenStore());

  final List<FakeApiCall> calls = [];
  final Map<String, Object? Function(FakeApiCall call)> _handlers = {};
  final Map<String, Object> _errors = {};

  void respond(String path, Object? json) => _handlers[path] = (_) => json;

  void respondWith(String path, Object? Function(FakeApiCall call) handler) =>
      _handlers[path] = handler;

  /// Registers a response that stays pending until the test completes the returned
  /// [Completer] - lets a test drive a real await-ordering race (e.g. "the selected school
  /// changes while this call is still in flight") instead of one that always resolves
  /// before the test gets a chance to act in between.
  Completer<Object?> respondLater(String path) {
    final completer = Completer<Object?>();
    _handlers[path] = (_) => completer.future;
    return completer;
  }

  void fail(String path, Object error) => _errors[path] = error;

  int callCount(String path) => calls.where((call) => call.path == path).length;

  @override
  Future<Object?> get(String path, {Map<String, String>? query, bool authenticated = true}) async {
    return _respond(FakeApiCall('GET', path));
  }

  @override
  Future<Object?> post(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    return _respond(FakeApiCall('POST', path, body: body));
  }

  Object? _respond(FakeApiCall call) {
    calls.add(call);
    final error = _errors[call.path];
    if (error != null) throw error;
    final handler = _handlers[call.path];
    if (handler == null) {
      throw StateError('FakeApiClient: no response registered for ${call.method} ${call.path}');
    }
    return handler(call);
  }
}
