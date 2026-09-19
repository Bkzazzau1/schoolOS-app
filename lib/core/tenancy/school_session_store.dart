import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../shared/models/school_membership.dart';

class SchoolSessionStore {
  SchoolSessionStore({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _activeMembershipKey = 'schoolos.active_membership.v1';

  final FlutterSecureStorage _secureStorage;

  Future<void> saveActiveMembership(SchoolMembership membership) async {
    await _secureStorage.write(
      key: _activeMembershipKey,
      value: jsonEncode(membership.toJson()),
    );
  }

  Future<SchoolMembership?> readActiveMembership() async {
    final value = await _secureStorage.read(key: _activeMembershipKey);
    if (value == null || value.isEmpty) return null;

    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic>) return null;

    return SchoolMembership.fromJson(decoded);
  }

  Future<void> clearActiveMembership() async {
    await _secureStorage.delete(key: _activeMembershipKey);
  }
}
