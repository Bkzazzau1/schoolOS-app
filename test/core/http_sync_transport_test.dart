import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/auth/token_store.dart';
import 'package:schoolos_app/core/network/api_exceptions.dart';
import 'package:schoolos_app/core/sync/http_sync_transport.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/sync/sync_transport.dart';

import 'backend_test_support.dart';

SyncMutation mutation({SyncOperation op = SyncOperation.update, int? base = 3}) => SyncMutation(
      id: 'mut-1',
      tenantId: teacher.schoolId,
      membershipId: teacher.id,
      entityType: 'school_event',
      entityId: 'E-1',
      operation: op,
      payload: {'title': 'Sports day'},
      baseVersion: base,
      createdAt: DateTime.utc(2026, 9, 21, 8),
      status: SyncMutationStatus.pending,
    );

HttpSyncTransport transport(FakeServer server, {TokenStore? tokens}) => HttpSyncTransport(apiFor(server, tokens: tokens));

void main() {
  test('sends the change in the shape the server expects', () async {
    final server = FakeServer((r) async => jsonResponse({'disposition': 'accepted', 'serverVersion': 4, 'message': ''}));
    await transport(server).pushMutation(mutation());
    final sent = body(server.to('sync/push/').single);
    expect(sent, {
      'id': 'mut-1',
      'tenantId': teacher.schoolId,
      'membershipId': teacher.id,
      'entityType': 'school_event',
      'entityId': 'E-1',
      'operation': 'update',
      'payload': {'title': 'Sports day'},
      'baseVersion': 3,
      'createdAt': '2026-09-21T08:00:00.000Z',
    });
  });

  test('a delete has no payload and a create has no base version', () async {
    final server = FakeServer((r) async => jsonResponse({'disposition': 'accepted', 'serverVersion': 2}));
    await transport(server).pushMutation(mutation(op: SyncOperation.delete));
    await transport(server).pushMutation(mutation(op: SyncOperation.create, base: null));
    final sent = server.to('sync/push/').map(body).toList();
    expect(sent[0].containsKey('payload'), isFalse);
    expect(sent[1].containsKey('baseVersion'), isFalse);
    expect(sent[1]['payload'], isNotNull);
  });

  test('accepted carries the new version', () async {
    final server = FakeServer((r) async => jsonResponse({'disposition': 'accepted', 'serverVersion': 4, 'message': ''}));
    final result = await transport(server).pushMutation(mutation());
    expect((result.disposition, result.serverVersion), (SyncPushDisposition.accepted, 4));
  });

  test('a conflict and a refusal are decisions, with the servers words', () async {
    final conflict = await transport(FakeServer((r) async =>
            jsonResponse({'disposition': 'conflict', 'serverVersion': 7, 'message': 'This record changed on the server first.'}, 409)))
        .pushMutation(mutation());
    expect((conflict.disposition, conflict.serverVersion, conflict.message),
        (SyncPushDisposition.conflict, 7, 'This record changed on the server first.'));

    final rejected = await transport(FakeServer((r) async =>
            jsonResponse({'disposition': 'rejected', 'serverVersion': null, 'message': 'Only the owner can decide.'}, 422)))
        .pushMutation(mutation());
    expect((rejected.disposition, rejected.message), (SyncPushDisposition.rejected, 'Only the owner can decide.'));
  });

  test('losing access to the school is a refusal with a plain message', () async {
    final result = await transport(FakeServer((r) async => jsonResponse({'detail': 'no'}, 403))).pushMutation(mutation());
    expect(result.disposition, SyncPushDisposition.rejected);
    expect(result.message, contains('no longer have access'));
  });

  test('a malformed change is refused, and will not be retried', () async {
    final result = await transport(FakeServer((r) async => jsonResponse({'entityId': ['Enter a valid value.']}, 400))).pushMutation(mutation());
    expect(result.disposition, SyncPushDisposition.rejected);
    expect(result.message, 'Enter a valid value.');
  });

  test('no signal, server trouble and an expired sign-in all mean try later, never rejected', () async {
    for (final server in [
      FakeServer((r) async => throw const ApiOfflineException()),
      FakeServer((r) async => jsonResponse({}, 503)),
    ]) {
      await expectLater(transport(server).pushMutation(mutation()),
          throwsA(isA<SyncRetryLater>().having((e) => e.needsSignIn, 'needsSignIn', isFalse)));
    }
    await expectLater(
      transport(FakeServer((r) async => jsonResponse({}, 401)), tokens: MemoryTokenStore()..tokens = const AuthTokens(access: 'a', refresh: 'r'))
          .pushMutation(mutation()),
      throwsA(isA<SyncRetryLater>().having((e) => e.needsSignIn, 'needsSignIn', isTrue)),
    );
  });
}
