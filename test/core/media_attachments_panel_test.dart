import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/media/media_api.dart';
import 'package:schoolos_app/core/media/media_local_files.dart';
import 'package:schoolos_app/core/media/media_upload_queue.dart';
import 'package:schoolos_app/core/media/presentation/media_attachments_panel.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'backend_test_support.dart';
import 'local_database_queue_test.dart' show MemorySecureStorage;
import 'media_api_test.dart' show assetJson;

const membership = SchoolMembership(id: 'membership-1', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

const photoOption = MediaAttachmentOption(label: 'Add photo', category: 'gallery_photo', mediaType: 'image', icon: Icons.add_photo_alternate_outlined);

Future<Uint8List> tinyPng() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(const ui.Rect.fromLTWH(0, 0, 4, 4), ui.Paint()..color = const Color(0xFF2255AA));
  final image = await recorder.endRecording().toImage(4, 4);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

/// A FakeServer that answers the media API's own endpoints properly (list, download-info, the raw stream), the
/// same way the real school server would - so a thumbnail fetch inside a widget test is real image bytes, never
/// the wrong endpoint's JSON handed to an image decoder, and never a real network request.
FakeServer mediaServer({required List<Map<String, Object?>> assets, Uint8List? thumbnailBytes}) {
  late FakeServer server;
  server = FakeServer((r) async {
    if (r.method == 'GET' && r.url.path.endsWith('/assets/')) return jsonResponse({'assets': assets});
    if (r.method == 'GET' && r.url.path.contains('/download/')) {
      final id = r.url.pathSegments[r.url.pathSegments.indexOf('assets') + 1];
      return jsonResponse({'mode': 'stream', 'url': 'assets/$id/raw/', 'mimeType': 'image/png', 'expiresAt': null});
    }
    if (r.method == 'GET' && r.url.path.endsWith('/raw/')) {
      return http.Response.bytes(thumbnailBytes ?? await tinyPng(), 200);
    }
    if (r.method == 'POST' && r.url.path.endsWith('/retire/')) {
      final id = r.url.pathSegments[r.url.pathSegments.indexOf('assets') + 1];
      return jsonResponse({'asset': assetJson(id: id, status: 'retired')});
    }
    return jsonResponse({}, 404);
  });
  return server;
}

void main() {
  late LocalDatabase db;
  late Directory tempRoot;
  late SchoolSessionController session;
  late FakeServer server;
  late MediaApi api;
  MediaUploadQueue? queue;

  setUp(() async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    tempRoot = Directory.systemTemp.createTempSync('media_attachments_panel_test_');
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([membership]);
    await session.selectSchool(membership);
    server = FakeServer((r) async => jsonResponse({'assets': <Object?>[]}));
    api = MediaApi(api: apiFor(server));
    queue = null;
  });

  tearDown(() {
    queue?.dispose();
    db.close();
    tempRoot.deleteSync(recursive: true);
  });

  MediaUploadQueue makeQueue({MediaApi? apiForQueue}) => queue = MediaUploadQueue(
        database: db,
        schoolSession: session,
        files: MediaLocalFiles(rootDirectory: () async => tempRoot),
        observeLifecycle: false,
      )..api = apiForQueue;

  Future<void> pump(WidgetTester tester, Widget panel) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: panel)));
    await tester.pumpAndSettle();
  }

  testWidgets('with nothing attached it says so, and offers no add button without contribute rights', (tester) async {
    final q = makeQueue();
    await pump(
      tester,
      MediaAttachmentsPanel(api: api, queue: q, membership: membership, ownerType: 'gallery_media_album', ownerId: 'album-1', canContribute: false, canManage: false, emptyLabel: 'No photos yet.'),
    );
    expect(find.byKey(const ValueKey('attachments-empty')), findsOneWidget);
    expect(find.text('No photos yet.'), findsOneWidget);
    expect(find.byKey(const ValueKey('add-gallery_photo')), findsNothing);
  });

  testWidgets('the servers own confirmed files are shown, each with its caption', (tester) async {
    server = mediaServer(assets: [assetJson(id: 'a1'), assetJson(id: 'a2', status: 'pending_upload', hasThumbnail: false)]);
    api = MediaApi(api: apiFor(server));
    final q = makeQueue();
    await pump(tester, MediaAttachmentsPanel(api: api, queue: q, membership: membership, ownerType: 'gallery_media_album', ownerId: 'album-1', canContribute: false, canManage: false));
    expect(find.byKey(const ValueKey('asset-a1')), findsOneWidget);
    expect(find.byKey(const ValueKey('asset-a2')), findsOneWidget);
    expect(find.text('The final'), findsWidgets); // the caption from assetJson
    expect(find.byKey(const ValueKey('asset-status-a2')), findsOneWidget); // not available yet: says so
    expect(find.byKey(const ValueKey('asset-status-a1')), findsNothing); // available: no status word shown
  });

  testWidgets('picking a photo queues it at once, showing it as waiting - never as uploaded', (tester) async {
    final q = makeQueue(); // no api: it will never actually send during this test
    final bytes = Uint8List.fromList([1, 2, 3]);
    await pump(
      tester,
      MediaAttachmentsPanel(
        api: api, queue: q, membership: membership, ownerType: 'gallery_media_album', ownerId: 'album-1', canContribute: true, canManage: false,
        options: const [photoOption],
        pickFile: (option) async => PickedMediaFile(name: 'day.png', extension: 'png', bytes: bytes),
      ),
    );
    expect(find.byKey(const ValueKey('add-gallery_photo')), findsOneWidget);
    // Picking copies real bytes to real disk (MediaLocalFiles) - genuine dart:io I/O, which the widget-test
    // clock never drives on its own; tester.runAsync() lets it actually run against the real event loop.
    await tester.runAsync(() => tester.tap(find.byKey(const ValueKey('add-gallery_photo'))));
    await tester.runAsync(() async {
      while (q.pendingCount(membership) == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();
    final tile = find.byWidgetPredicate((w) => w.key is ValueKey && (w.key! as ValueKey).value.toString().startsWith('queued-'));
    expect(tile, findsWidgets);
    expect(find.textContaining('Waiting to send'), findsOneWidget);
    expect(find.textContaining('Sent'), findsNothing);
    expect(q.pendingCount(membership), 1);
  });

  testWidgets('a file type SchoolOS does not accept here is refused on the phone, and nothing is queued', (tester) async {
    final q = makeQueue();
    await pump(
      tester,
      MediaAttachmentsPanel(
        api: api, queue: q, membership: membership, ownerType: 'gallery_media_album', ownerId: 'album-1', canContribute: true, canManage: false,
        options: const [photoOption],
        pickFile: (option) async => PickedMediaFile(name: 'notes.exe', extension: 'exe', bytes: Uint8List.fromList([1])),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('add-gallery_photo')));
    await tester.pumpAndSettle();
    expect(find.textContaining('does not accept'), findsOneWidget);
    expect(q.pendingCount(membership), 0);
  });

  testWidgets('cancelling the picker (nothing chosen) queues nothing', (tester) async {
    final q = makeQueue();
    await pump(
      tester,
      MediaAttachmentsPanel(
        api: api, queue: q, membership: membership, ownerType: 'gallery_media_album', ownerId: 'album-1', canContribute: true, canManage: false,
        options: const [photoOption],
        pickFile: (option) async => null,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('add-gallery_photo')));
    await tester.pumpAndSettle();
    expect(q.pendingCount(membership), 0);
    expect(find.byKey(const ValueKey('attachments-empty')), findsOneWidget);
  });

  testWidgets('a failed local upload offers a retry, and retrying asks the queue to try again', (tester) async {
    final q = makeQueue();
    // Queuing copies real bytes to real disk - see the note on the "picking a photo" test above.
    final id = await tester.runAsync(
      () => q.enqueue(membership: membership, ownerType: 'gallery_media_album', ownerId: 'album-1', category: 'gallery_photo', fileName: 'x.png', mimeType: 'image/png', bytes: Uint8List.fromList([1])),
    );
    db.markMediaUploadFailed(id!, errorCode: 'file_too_large', errorMessage: 'Too big');
    await pump(tester, MediaAttachmentsPanel(api: api, queue: q, membership: membership, ownerType: 'gallery_media_album', ownerId: 'album-1', canContribute: true, canManage: false));
    expect(find.textContaining('Failed'), findsOneWidget);
    expect(find.byKey(ValueKey('retry-$id')), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('retry-$id')));
    // Not pumpAndSettle(): a 'waiting' tile shows an indeterminate CircularProgressIndicator, which schedules a
    // frame forever and would never let pumpAndSettle() finish - a handful of ordinary pumps is enough to see
    // the state the tap already produced synchronously (queue.retry() itself does no I/O).
    await tester.pump();
    await tester.pump();
    expect(db.mediaUpload(id)!.state.name, 'waiting');
  });

  testWidgets('only someone who manages the owner, or the file\'s own uploader, may remove it', (tester) async {
    server = mediaServer(assets: [assetJson(id: 'a1', hasThumbnail: false)..['uploadedByMembershipId'] = 'someone-else']);
    api = MediaApi(api: apiFor(server));
    final q = makeQueue();
    await pump(tester, MediaAttachmentsPanel(api: api, queue: q, membership: membership, ownerType: 'gallery_media_album', ownerId: 'album-1', canContribute: false, canManage: false));
    expect(find.byKey(const ValueKey('retire-a1')), findsNothing); // not the uploader, and cannot manage

    server = mediaServer(assets: [assetJson(id: 'a2', hasThumbnail: false)..['uploadedByMembershipId'] = membership.id]);
    api = MediaApi(api: apiFor(server));
    await tester.pumpWidget(const SizedBox()); // unmount fully: a new api instance is not a reason this State reloads on its own
    await pump(tester, MediaAttachmentsPanel(api: api, queue: q, membership: membership, ownerType: 'gallery_media_album', ownerId: 'album-1', canContribute: false, canManage: false));
    expect(find.byKey(const ValueKey('retire-a2')), findsOneWidget); // their own upload
  });

  testWidgets('removing a file asks for a reason and posts it to the server', (tester) async {
    var retired = false;
    server = FakeServer((r) async {
      if (r.method == 'POST' && r.url.path.endsWith('/retire/')) {
        retired = true;
        return jsonResponse({'asset': assetJson(id: 'a1', status: 'retired')});
      }
      return jsonResponse({
        'assets': retired ? <Object?>[] : [assetJson(id: 'a1', hasThumbnail: false)],
      });
    });
    api = MediaApi(api: apiFor(server));
    final q = makeQueue();
    await pump(tester, MediaAttachmentsPanel(api: api, queue: q, membership: membership, ownerType: 'gallery_media_album', ownerId: 'album-1', canContribute: false, canManage: true));
    await tester.tap(find.byKey(const ValueKey('retire-a1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('remove-reason')), 'wrong album');
    await tester.tap(find.byKey(const ValueKey('remove-confirm')));
    await tester.pumpAndSettle();
    expect(retired, isTrue);
  });
}
