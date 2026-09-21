import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:schoolos_app/core/auth/token_store.dart';
import 'package:schoolos_app/core/network/api_client.dart';
import 'package:schoolos_app/core/network/api_config.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/sync/sync_store.dart';
import 'package:schoolos_app/core/tenancy/school_session_store.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

const testConfig = ApiConfig('https://api.test/api/v1/');

http.Response jsonResponse(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

/// A client whose server is [handler]; every request it receives is kept.
class FakeServer {
  FakeServer(this.handler) {
    client = MockClient((request) async {
      requests.add(request);
      return handler(request);
    });
  }

  final Future<http.Response> Function(http.Request request) handler;
  late final MockClient client;
  final requests = <http.Request>[];

  List<http.Request> to(String path) =>
      requests.where((r) => r.url.path.endsWith(path)).toList();
}

ApiClient apiFor(FakeServer server, {TokenStore? tokens}) => ApiClient(
  config: testConfig,
  tokens:
      tokens ??
      (MemoryTokenStore()
        ..tokens = const AuthTokens(access: 'access-1', refresh: 'refresh-1')),
  httpClient: server.client,
);

class FakeSessionStore implements SchoolSessionStore {
  List<SchoolMembership> memberships = const [];
  SchoolMembership? active;

  @override
  Future<void> saveMemberships(List<SchoolMembership> value) async =>
      memberships = value;

  @override
  Future<List<SchoolMembership>> readMemberships() async => memberships;

  @override
  Future<void> saveActiveMembership(SchoolMembership value) async =>
      active = value;

  @override
  Future<SchoolMembership?> readActiveMembership() async => active;

  @override
  Future<void> clear() async {
    memberships = const [];
    active = null;
  }
}

class MemorySyncStore implements SyncStore {
  final records = <String, LocalRecord>{};
  final cursors = <String, int>{};

  static String key(String tenant, String type, String id) =>
      '$tenant|$type|$id';

  @override
  Future<int> readSyncCursor({
    required String tenantId,
    required String membershipId,
  }) async => cursors['$tenantId|$membershipId'] ?? 0;

  @override
  Future<void> writeSyncCursor({
    required String tenantId,
    required String membershipId,
    required int cursor,
  }) async => cursors['$tenantId|$membershipId'] = cursor;

  @override
  Future<LocalRecord?> getLocalRecord({
    required String tenantId,
    required String entityType,
    required String entityId,
  }) async => records[key(tenantId, entityType, entityId)];

  @override
  Future<void> upsertLocalRecord({
    required String tenantId,
    required String entityType,
    required String entityId,
    required Map<String, Object?> payload,
    int? serverVersion,
    bool isDirty = false,
  }) async {
    records[key(tenantId, entityType, entityId)] = LocalRecord(
      tenantId: tenantId,
      entityType: entityType,
      entityId: entityId,
      payload: payload,
      serverVersion: serverVersion,
      updatedAt: DateTime.now(),
      isDirty: isDirty,
    );
  }

  @override
  Future<void> deleteLocalRecord({
    required String tenantId,
    required String entityType,
    required String entityId,
  }) async => records.remove(key(tenantId, entityType, entityId));
}

const teacher = SchoolMembership(
  id: '11111111-1111-1111-1111-111111111111',
  schoolId: '22222222-2222-2222-2222-222222222222',
  schoolName: 'BrightGate',
  role: SchoolRole.teacher,
);

Map<String, Object?> body(http.Request request) =>
    Map<String, Object?>.from(jsonDecode(request.body) as Map);
