import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthTokens {
  const AuthTokens({required this.access, required this.refresh});

  final String access;
  final String refresh;

  AuthTokens withAccess(String newAccess, {String? newRefresh}) =>
      AuthTokens(access: newAccess, refresh: newRefresh ?? refresh);
}

/// Where the sign-in tokens live. Real devices use the secure store; tests use
/// memory.
abstract interface class TokenStore {
  Future<AuthTokens?> read();
  Future<void> write(AuthTokens tokens);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? secureStorage})
      : _storage = secureStorage ?? const FlutterSecureStorage();

  static const _accessKey = 'schoolos.auth.access.v1';
  static const _refreshKey = 'schoolos.auth.refresh.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthTokens?> read() async {
    final access = await _storage.read(key: _accessKey);
    final refresh = await _storage.read(key: _refreshKey);
    if (access == null || refresh == null) return null;
    return AuthTokens(access: access, refresh: refresh);
  }

  @override
  Future<void> write(AuthTokens tokens) async {
    await _storage.write(key: _accessKey, value: tokens.access);
    await _storage.write(key: _refreshKey, value: tokens.refresh);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}

class MemoryTokenStore implements TokenStore {
  AuthTokens? tokens;

  @override
  Future<AuthTokens?> read() async => tokens;

  @override
  Future<void> write(AuthTokens value) async => tokens = value;

  @override
  Future<void> clear() async => tokens = null;
}
