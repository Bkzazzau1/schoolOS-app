import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/network/api_exceptions.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/sync/sync_puller.dart';
import 'package:schoolos_app/core/sync/sync_transport.dart';

import 'backend_test_support.dart';

Map<String, Object?> rec(String type, String id, {int version = 1, Map<String, Object?>? payload, bool deleted = false}) => {
      'entityType': type,
      'entityId': id,
      'version': version,
      'deleted': deleted,
      'payload': deleted ? <String, Object?>{} : payload ?? {'id': id},
    };

void main() {
  late MemorySyncStore store;
  setUp(() => store = MemorySyncStore());

  SyncPuller puller(FakeServer server, {int pageSize = 200}) => SyncPuller(api: apiFor(server), store: store, pageSize: pageSize);

  Future<LocalRecord?> local(String type, String id) => store.getLocalRecord(tenantId: teacher.schoolId, entityType: type, entityId: id);

  test('downloads records from the start and remembers where it got to', () async {
    final server = FakeServer((r) async => jsonResponse({
          'records': [rec('school_event', 'E-1', version: 3, payload: {'title': 'Sports day'}), rec('school_house', 'H-1')],
          'cursor': 12,
          'hasMore': false,
        }));
    final summary = await puller(server).pull(teacher);
    final query = server.requests.single.url.queryParameters;
    expect(query, {'school': teacher.schoolId, 'membership': teacher.id, 'since': '0', 'limit': '200'});
    expect(summary.applied, 2);
    final event = (await local('school_event', 'E-1'))!;
    expect((event.payload['title'], event.serverVersion, event.isDirty), ('Sports day', 3, false));
    expect(store.cursors['${teacher.schoolId}|${teacher.id}'], 12);
  });

  test('next time it asks only for what is new', () async {
    var call = 0;
    final server = FakeServer((r) async => jsonResponse(
        call++ == 0 ? {'records': [rec('school_event', 'E-1')], 'cursor': 5, 'hasMore': false} : {'records': [], 'cursor': 5, 'hasMore': false}));
    await puller(server).pull(teacher);
    await puller(server).pull(teacher);
    expect(server.requests.map((r) => r.url.queryParameters['since']), ['0', '5']);
  });

  test('pages are followed until there are no more, saving the cursor as it goes', () async {
    final pages = [
      {'records': [rec('a', '1')], 'cursor': 3, 'hasMore': true},
      {'records': [rec('a', '2')], 'cursor': 7, 'hasMore': true},
      {'records': [rec('a', '3')], 'cursor': 9, 'hasMore': false},
    ];
    var i = 0;
    final server = FakeServer((r) async => jsonResponse(pages[i++]));
    final summary = await puller(server, pageSize: 1).pull(teacher);
    expect(summary.applied, 3);
    expect(server.requests.map((r) => r.url.queryParameters['since']), ['0', '3', '7']);
    expect(store.cursors['${teacher.schoolId}|${teacher.id}'], 9);
  });

  test('an interrupted download carries on from the last saved page', () async {
    var call = 0;
    final server = FakeServer((r) async {
      call++;
      if (call == 1) return jsonResponse({'records': [rec('a', '1')], 'cursor': 4, 'hasMore': true});
      throw const ApiOfflineException();
    });
    await expectLater(puller(server).pull(teacher), throwsA(isA<SyncRetryLater>()));
    expect(await local('a', '1'), isNotNull);
    expect(store.cursors['${teacher.schoolId}|${teacher.id}'], 4);

    final again = FakeServer((r) async => jsonResponse({'records': [], 'cursor': 4, 'hasMore': false}));
    await puller(again).pull(teacher);
    expect(again.requests.single.url.queryParameters['since'], '4');
  });

  test('a changed record replaces the old copy, with its new version', () async {
    await store.upsertLocalRecord(tenantId: teacher.schoolId, entityType: 'a', entityId: '1', payload: {'v': 1}, serverVersion: 1);
    final server = FakeServer((r) async => jsonResponse({'records': [rec('a', '1', version: 2, payload: {'v': 2})], 'cursor': 2, 'hasMore': false}));
    await puller(server).pull(teacher);
    final record = (await local('a', '1'))!;
    expect((record.payload['v'], record.serverVersion), (2, 2));
  });

  test('a record with an unsent edit on this device is left alone', () async {
    await store.upsertLocalRecord(tenantId: teacher.schoolId, entityType: 'a', entityId: '1', payload: {'v': 'mine'}, serverVersion: 1, isDirty: true);
    final server = FakeServer((r) async => jsonResponse({'records': [rec('a', '1', version: 2, payload: {'v': 'theirs'})], 'cursor': 2, 'hasMore': false}));
    final summary = await puller(server).pull(teacher);
    expect(summary.skippedUnsent, 1);
    final record = (await local('a', '1'))!;
    expect((record.payload['v'], record.serverVersion, record.isDirty), ('mine', 1, true));
  });

  test('a record deleted on the server is removed here', () async {
    await store.upsertLocalRecord(tenantId: teacher.schoolId, entityType: 'a', entityId: '1', payload: {'v': 1}, serverVersion: 1);
    final server = FakeServer((r) async => jsonResponse({'records': [rec('a', '1', version: 2, deleted: true), rec('a', 'never-here', deleted: true)], 'cursor': 3, 'hasMore': false}));
    final summary = await puller(server).pull(teacher);
    expect(await local('a', '1'), isNull);
    expect(summary.removed, 2);
  });

  test('cursors are kept apart for each membership and school', () async {
    final server = FakeServer((r) async => jsonResponse({'records': [], 'cursor': 8, 'hasMore': false}));
    await puller(server).pull(teacher);
    expect(await store.readSyncCursor(tenantId: teacher.schoolId, membershipId: 'someone-else'), 0);
    expect(await store.readSyncCursor(tenantId: 'other-school', membershipId: teacher.id), 0);
  });

  test('offline and an expired sign-in mean try later, and the cursor does not move', () async {
    await expectLater(puller(FakeServer((r) async => throw const ApiOfflineException())).pull(teacher),
        throwsA(isA<SyncRetryLater>().having((e) => e.needsSignIn, 'needsSignIn', isFalse)));
    await expectLater(puller(FakeServer((r) async => jsonResponse({}, 401))).pull(teacher), throwsA(isA<SyncRetryLater>().having((e) => e.needsSignIn, 'needsSignIn', isTrue)));
    expect(store.cursors, isEmpty);
  });

  test('a school the person no longer belongs to is an error to show, not silence', () async {
    await expectLater(puller(FakeServer((r) async => jsonResponse({'detail': 'You do not have access to this school.'}, 403))).pull(teacher),
        throwsA(isA<ApiException>().having((e) => e.isForbidden, 'isForbidden', isTrue)));
  });

  test('a strange answer does not corrupt anything', () async {
    await expectLater(puller(FakeServer((r) async => jsonResponse({'nope': 1}))).pull(teacher), throwsA(isA<ApiException>()));
    expect(store.records, isEmpty);
    expect(store.cursors, isEmpty);
  });
}
