import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypts sensitive local payloads before they are written to SQLite.
///
/// The database never stores the master key. The key lives in the platform's
/// secure storage and is generated independently for each installation.
class PayloadCipher {
  PayloadCipher({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _masterKeyName = 'schoolos.local.master_key.v1';

  final FlutterSecureStorage _secureStorage;
  final Cipher _algorithm = AesGcm.with256bits();

  SecretKey? _secretKey;

  Future<void> initialize() async {
    if (_secretKey != null) return;

    final storedKey = await _secureStorage.read(key: _masterKeyName);
    if (storedKey != null && storedKey.isNotEmpty) {
      _secretKey = SecretKey(base64Url.decode(storedKey));
      return;
    }

    final generatedKey = await _algorithm.newSecretKey();
    final generatedBytes = await generatedKey.extractBytes();
    await _secureStorage.write(
      key: _masterKeyName,
      value: base64UrlEncode(generatedBytes),
    );
    _secretKey = SecretKey(generatedBytes);
  }

  Future<String> encryptJson(Map<String, Object?> payload) async {
    await initialize();

    final nonce = _algorithm.newNonce();
    final box = await _algorithm.encrypt(
      utf8.encode(jsonEncode(payload)),
      secretKey: _secretKey!,
      nonce: nonce,
    );

    return jsonEncode({
      'v': 1,
      'n': base64UrlEncode(box.nonce),
      'c': base64UrlEncode(box.cipherText),
      'm': base64UrlEncode(box.mac.bytes),
    });
  }

  Future<Map<String, Object?>> decryptJson(String encodedPayload) async {
    await initialize();

    final envelope = jsonDecode(encodedPayload) as Map<String, dynamic>;
    if (envelope['v'] != 1) {
      throw const FormatException('Unsupported encrypted payload version.');
    }

    final box = SecretBox(
      base64Url.decode(envelope['c'] as String),
      nonce: base64Url.decode(envelope['n'] as String),
      mac: Mac(base64Url.decode(envelope['m'] as String)),
    );

    final clearBytes = await _algorithm.decrypt(
      box,
      secretKey: _secretKey!,
    );
    final decoded = jsonDecode(utf8.decode(clearBytes));

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Encrypted payload must decode to an object.');
    }

    return decoded.cast<String, Object?>();
  }
}
