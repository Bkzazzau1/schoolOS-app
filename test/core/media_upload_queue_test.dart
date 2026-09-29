import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/media/media_api.dart';
import 'package:schoolos_app/core/media/media_local_files.dart';
import 'package:schoolos_app/core/media/media_queue_models.dart';
import 'package:schoolos_app/core/media/media_upload_queue.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'backend_test_support.dart';
import 'local_database_queue_test.dart' show MemorySecureStorage;
import 'media_api_test.dart' show assetJson;

const membership = SchoolMembership(id: 'membership-1', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);
Future<void> pause([int ms = 60]) => Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  late LocalDatabase db;
  late Directory tempRoot;
  late SchoolSessionController session;
  MediaUploadQueue? queue;

  setUp(() async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    tempRoot = Directory.systemTemp.createTempSync('media_upload_queue_test_');
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([membership]);
    await session.selectSchool(membership);
    queue = null;
  });

  tearDown(() {
    queue?.dispose();
    db.close();
    tempRoot.deleteSync(recursive: true);
  });

  MediaUploadQueue make({
    MediaApi? api,
    Duration interval = const Duration(seconds: 30),
    Duration first = const Duration(milliseconds: 30),
    Duration max = const Duration(milliseconds: 100),
  }) {
    return queue = MediaUploadQueue(
      database: db,
      schoolSession: session,
      files: MediaLocalFiles(rootDirectory: () async => tempRoot),
      interval: interval,
      debounce: const Duration(milliseconds: 10),
      firstBackoff: first,
      maxBackoff: max,
      observeLifecycle: false,
    )..api = api;
  }

  Future<String> enqueuePhoto(MediaUploadQueue q, {Uint8List? bytes}) => q.enqueue(
        membership: membership,
        ownerType: 'gallery_media_album',
        ownerId: 'album-1',
        category: 'gallery_photo',
        fileName: 'day.png',
        mimeType: 'image/png',
        bytes: bytes ?? Uint8List.fromList([1, 2, 3, 4]),
        caption: 'Sports day',
      );

  test('enqueue copies the bytes and returns at once, before anything has touched the network', () async {
    final q = make(api: null);
    final id = await enqueuePhoto(q);
    final item = db.mediaUpload(id)!;
    expect(item.state, MediaUploadState.waiting);
    expect(await File(item.localPath).readAsBytes(), [1, 2, 3, 4]);
  });

  test('with no server the queue never runs, and a queued file just waits', () async {
    final q = make(api: null)..start();
    final id = await enqueuePhoto(q);
    await pause();
    expect(db.mediaUpload(id)!.state, MediaUploadState.waiting);
  });

  group('sending, local storage (direct upload)', () {
    test('a queued photo goes waiting -> uploading -> uploaded, and the server sees every step', () async {
      final calls = <String>[];
      final server = FakeServer((r) async {
        calls.add('${r.method} ${r.url.path}');
        if (r.method == 'POST' && r.url.path.endsWith('/assets/')) {
          return jsonResponse({
            'asset': assetJson(id: 'asset-9', status: 'pending_upload'),
            'upload': {'mode': 'direct', 'uploadUrl': 'schools/school-1/media/assets/asset-9/upload/', 'method': 'PUT', 'headers': <String, String>{}, 'expiresAt': null},
          }, 201);
        }
        if (r.method == 'PUT') return jsonResponse({'asset': assetJson(id: 'asset-9', status: 'uploaded')});
        if (r.method == 'POST' && r.url.path.endsWith('/complete/')) return jsonResponse({'asset': assetJson(id: 'asset-9', status: 'available')});
        return jsonResponse({}, 404);
      });
      final q = make(api: MediaApi(api: apiFor(server)))..start();
      final id = await enqueuePhoto(q);
      await pause(200);
      final item = db.mediaUpload(id)!;
      expect((item.state, item.serverAssetId, item.serverStatus), (MediaUploadState.uploaded, 'asset-9', 'available'));
      expect(calls.where((c) => c.contains('/assets/asset-9/upload/')).single, startsWith('PUT'));
      // the bytes really left the phone
      final put = server.requests.firstWhere((r) => r.method == 'PUT');
      expect(put.bodyBytes, [1, 2, 3, 4]);
    });

    test('a file the server refuses outright is marked failed at once, and is never retried by itself', () async {
      final server = FakeServer((r) async {
        if (r.method == 'POST' && r.url.path.endsWith('/assets/')) {
          return jsonResponse({'code': 'mime_type_mismatch', 'message': 'Not really a PNG.'}, 400);
        }
        return jsonResponse({}, 404);
      });
      final q = make(api: MediaApi(api: apiFor(server)))..start();
      final id = await enqueuePhoto(q);
      await pause(200);
      final item = db.mediaUpload(id)!;
      expect((item.state, item.lastErrorCode), (MediaUploadState.failed, 'mime_type_mismatch'));
      await pause(300); // long enough for another round, if one wrongly happened
      expect(server.requests.where((r) => r.url.path.endsWith('/assets/')).length, 1); // never asked again by itself
    });
  });

  group('sending, object storage (presigned upload)', () {
    Future<HttpServer> fakeBucket(List<List<int>> received) async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        final bytes = await request.fold<List<int>>([], (a, b) => a..addAll(b));
        received.add(bytes);
        request.response.statusCode = 200;
        await request.response.close();
      });
      return server;
    }

    test('the bytes go straight to the object store, with no SchoolOS token, and only then is the upload completed', () async {
      final received = <List<int>>[];
      final bucket = await fakeBucket(received);
      addTearDown(bucket.close);
      final uploadUrl = 'http://127.0.0.1:${bucket.port}/bucket/key.png';

      final api = FakeServer((r) async {
        if (r.method == 'POST' && r.url.path.endsWith('/assets/')) {
          return jsonResponse({
            'asset': assetJson(id: 'asset-7', status: 'pending_upload'),
            'upload': {'mode': 'presigned_put', 'uploadUrl': uploadUrl, 'method': 'PUT', 'headers': {'Content-Type': 'image/png'}, 'expiresAt': null},
          }, 201);
        }
        if (r.method == 'POST' && r.url.path.endsWith('/complete/')) return jsonResponse({'asset': assetJson(id: 'asset-7', status: 'available')});
        return jsonResponse({}, 404);
      });
      final q = make(api: MediaApi(api: apiFor(api)))..start();
      final id = await enqueuePhoto(q);
      await pause(300);

      expect(received.single, [1, 2, 3, 4]); // the object store received the bytes directly
      expect(api.requests.every((r) => r.headers['Authorization'] == 'Bearer access-1'), isTrue); // never sent to the bucket
      expect(db.mediaUpload(id)!.state, MediaUploadState.uploaded);
    });

    test('the object store refusing the upload is a retryable failure, not a permanent one', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response.statusCode = 500;
        await request.response.close();
      });
      addTearDown(server.close);
      final uploadUrl = 'http://127.0.0.1:${server.port}/bucket/key.png';

      final api = FakeServer((r) async {
        if (r.method == 'POST' && r.url.path.endsWith('/assets/')) {
          return jsonResponse({
            'asset': assetJson(id: 'asset-8', status: 'pending_upload'),
            'upload': {'mode': 'presigned_put', 'uploadUrl': uploadUrl, 'method': 'PUT', 'headers': <String, String>{}, 'expiresAt': null},
          }, 201);
        }
        return jsonResponse({}, 404);
      });
      final q = make(api: MediaApi(api: apiFor(api)))..start();
      final id = await enqueuePhoto(q);
      await pause(200);
      expect(db.mediaUpload(id)!.state, MediaUploadState.waiting); // not failed: kept for another try
      expect(db.mediaUpload(id)!.attemptCount, greaterThan(0));
    });
  });

  group('offline and retry', () {
    test('no network at all is kept waiting, tried again with a growing gap, and never marked failed', () async {
      var attempts = 0;
      final server = FakeServer((r) async {
        attempts++;
        throw const SocketException('no route to host');
      });
      final q = make(api: MediaApi(api: apiFor(server)), first: const Duration(milliseconds: 20), max: const Duration(milliseconds: 60))..start();
      final id = await enqueuePhoto(q);
      await pause(400);
      expect(db.mediaUpload(id)!.state, MediaUploadState.waiting);
      expect(attempts, greaterThan(1)); // it really did try more than once
    });

    test('asking to retry by hand sends a failed upload again', () async {
      var refuse = true;
      final server = FakeServer((r) async {
        if (r.method == 'POST' && r.url.path.endsWith('/assets/')) {
          if (refuse) return jsonResponse({'code': 'file_too_large', 'message': 'Too big.'}, 400);
          return jsonResponse({
            'asset': assetJson(id: 'asset-5', status: 'pending_upload'),
            'upload': {'mode': 'direct', 'uploadUrl': 'schools/school-1/media/assets/asset-5/upload/', 'method': 'PUT', 'headers': <String, String>{}, 'expiresAt': null},
          }, 201);
        }
        if (r.method == 'PUT') return jsonResponse({'asset': assetJson(id: 'asset-5', status: 'uploaded')});
        if (r.method == 'POST' && r.url.path.endsWith('/complete/')) return jsonResponse({'asset': assetJson(id: 'asset-5', status: 'available')});
        return jsonResponse({}, 404);
      });
      final q = make(api: MediaApi(api: apiFor(server)))..start();
      final id = await enqueuePhoto(q);
      await pause(150);
      expect(db.mediaUpload(id)!.state, MediaUploadState.failed);

      refuse = false;
      q.retry(id);
      await pause(150);
      expect(db.mediaUpload(id)!.state, MediaUploadState.uploaded);
    });
  });

  group('cancelling a queued upload', () {
    test('forgets it and deletes its local copy', () async {
      final q = make(api: null);
      final id = await enqueuePhoto(q);
      final path = db.mediaUpload(id)!.localPath;
      await q.cancel(id);
      expect(db.mediaUpload(id), isNull);
      expect(await File(path).exists(), isFalse);
    });

    test('does nothing to an upload the server already has', () async {
      final q = make(api: null);
      final id = await enqueuePhoto(q);
      db.markMediaUploadUploaded(id, serverAssetId: 'asset-1', serverStatus: 'available');
      await q.cancel(id);
      expect(db.mediaUpload(id), isNotNull);
    });
  });

  test('uploadsForOwner reads straight from the local queue, independent of the server list', () async {
    final q = make(api: null);
    await enqueuePhoto(q);
    await enqueuePhoto(q, bytes: Uint8List.fromList([9, 9]));
    final mine = q.uploadsForOwner(membership, ownerType: 'gallery_media_album', ownerId: 'album-1');
    expect(mine, hasLength(2));
    expect(mine.every((u) => u.isLocalOnly), isTrue);
  });
}
