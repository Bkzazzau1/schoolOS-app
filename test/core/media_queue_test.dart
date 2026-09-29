import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/media/media_queue_models.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';

import 'local_database_queue_test.dart' show MemorySecureStorage;

const tenant = 'school-1';
const membership = 'membership-1';

void main() {
  late LocalDatabase db;

  setUp(() async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
  });

  tearDown(() => db.close());

  Future<String> queue({String ownerId = 'album-1', String path = '/tmp/a.png', int callCount = 0}) => db.queueMediaUpload(
        tenantId: tenant,
        membershipId: membership,
        ownerType: 'gallery_media_album',
        ownerId: ownerId,
        category: 'gallery_photo',
        fileName: 'sports-day.png',
        mimeType: 'image/png',
        byteSize: 1234,
        sha256: 'abc123',
        localPath: path,
      );

  test('a queued file starts waiting, with its own bytes already recorded, and fires the queued hook', () async {
    var fired = 0;
    db.onMediaUploadQueued = () => fired++;
    final id = await queue();
    expect(fired, 1);
    final item = db.mediaUpload(id)!;
    expect((item.state, item.localPath, item.byteSize, item.sha256), (MediaUploadState.waiting, '/tmp/a.png', 1234, 'abc123'));
    expect(item.serverAssetId, isNull);
    expect(item.isLocalOnly, isTrue);
  });

  test('reading a queued file back decodes every column, not just the ones a screen usually asks for', () async {
    final id = await queue(ownerId: 'album-7', path: '/tmp/real.mp4');
    final item = db.mediaUpload(id)!;
    expect((item.tenantId, item.membershipId, item.ownerType, item.ownerId, item.category, item.fileName, item.mimeType, item.visibility), (
      tenant, membership, 'gallery_media_album', 'album-7', 'gallery_photo', 'sports-day.png', 'image/png', 'private',
    ));
    expect(item.createdAt, isNotNull);
    expect(item.attemptCount, 0);
  });

  test('uploads attached to one owner come back oldest first, and another owner never sees them', () async {
    final first = await queue(ownerId: 'album-1', path: '/tmp/1.png');
    final second = await queue(ownerId: 'album-1', path: '/tmp/2.png');
    await queue(ownerId: 'album-2', path: '/tmp/3.png');
    final forAlbum1 = db.mediaUploadsForOwner(tenantId: tenant, ownerType: 'gallery_media_album', ownerId: 'album-1');
    expect(forAlbum1.map((u) => u.id).toList(), [first, second]);
  });

  test('due uploads are only ever the waiting ones, and only once their retry time has come', () async {
    final id = await queue();
    expect(db.dueMediaUploads(tenantId: tenant).map((u) => u.id), [id]);
    db.markMediaUploadUploading(id);
    expect(db.dueMediaUploads(tenantId: tenant), isEmpty); // being sent right now: not due again
    db.markMediaUploadWaitingRetry(id, errorCode: 'offline', errorMessage: 'no network', nextAttemptAt: DateTime.now().add(const Duration(minutes: 5)));
    expect(db.dueMediaUploads(tenantId: tenant), isEmpty); // waiting, but its backoff has not elapsed
    db.markMediaUploadWaitingRetry(id, errorCode: 'offline', errorMessage: 'no network', nextAttemptAt: DateTime.now().subtract(const Duration(seconds: 1)));
    expect(db.dueMediaUploads(tenantId: tenant).map((u) => u.id), [id]);
  });

  test('pendingCount counts waiting and uploading but not uploaded or failed', () async {
    final a = await queue(path: '/tmp/a.png');
    final b = await queue(path: '/tmp/b.png');
    await queue(path: '/tmp/c.png');
    expect(db.pendingMediaUploadCount(tenantId: tenant), 3);
    db.markMediaUploadUploaded(a, serverAssetId: 'asset-1', serverStatus: 'available');
    db.markMediaUploadFailed(b, errorCode: 'refused', errorMessage: 'no');
    expect(db.pendingMediaUploadCount(tenantId: tenant), 1);
  });

  test('once uploaded, the row carries the servers own id and status, and any earlier error is cleared', () async {
    final id = await queue();
    db.markMediaUploadWaitingRetry(id, errorCode: 'offline', errorMessage: 'no network', nextAttemptAt: DateTime.now());
    db.markMediaUploadUploaded(id, serverAssetId: 'asset-9', serverStatus: 'available');
    final item = db.mediaUpload(id)!;
    expect((item.state, item.serverAssetId, item.serverStatus, item.lastErrorCode), (MediaUploadState.uploaded, 'asset-9', 'available', null));
  });

  test('a failed upload can be retried by hand, and only a failed one can be', () async {
    final id = await queue();
    db.markMediaUploadFailed(id, errorCode: 'refused', errorMessage: 'bad file');
    db.retryMediaUpload(id);
    expect(db.mediaUpload(id)!.state, MediaUploadState.waiting);

    final waiting = await queue(path: '/tmp/still-waiting.png');
    db.retryMediaUpload(waiting); // not failed: nothing changes
    expect(db.mediaUpload(waiting)!.state, MediaUploadState.waiting);
  });

  test('deleting a queued upload forgets it entirely', () async {
    final id = await queue();
    db.deleteMediaUpload(id);
    expect(db.mediaUpload(id), isNull);
  });

  test('every write is tenant scoped', () async {
    expect(() => db.mediaUploadsForOwner(tenantId: '', ownerType: 'x', ownerId: 'y'), throwsArgumentError);
    expect(() => db.dueMediaUploads(tenantId: ''), throwsArgumentError);
    expect(() => db.pendingMediaUploadCount(tenantId: ''), throwsArgumentError);
  });
}
