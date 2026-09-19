import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../shared/models/school_membership.dart';

class SchoolSessionStore {
  SchoolSessionStore({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _activeMembershipKey = 'schoolos.active_membership.v1';
  static const _membershipsKey = 'schoolos.memberships.v1';

  final FlutterSecureStorage _secureStorage;

  Future<void> saveMemberships(List<SchoolMembership> memberships) async {
    await _secureStorage.write(
      key: _membershipsKey,
      value: jsonEncode(
        memberships.map((membership) => membership.toJson()).toList(),
      ),
    );
  }

  Future<List<SchoolMembership>> readMemberships() async {
    final value = await _secureStorage.read(key: _membershipsKey);
    if (value == null || value.isEmpty) return const [];

    final decoded = jsonDecode(value);
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map>()
        .map(
          (item) => SchoolMembership.fromJson(
            item.cast<String, dynamic>(),
          ),
        )
        .toList(growable: false);
  }

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

  Future<void> clear() async {
    await _secureStorage.delete(key: _activeMembershipKey);
    await _secureStorage.delete(key: _membershipsKey);
  }
}
