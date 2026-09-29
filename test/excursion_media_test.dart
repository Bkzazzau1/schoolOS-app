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
import 'package:schoolos_app/features/excursions/data/excursion_repository.dart';
import 'package:schoolos_app/features/excursions/presentation/excursions_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;
import 'core/media_api_test.dart' show assetJson;

const manager = SchoolMembership(id: 'm-owner', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.proprietor);
const otherSchoolManager = SchoolMembership(id: 'm-owner-2', schoolId: 'school-2', schoolName: 'Riverside', role: SchoolRole.proprietor);
const teacherContributor = SchoolMembership(id: 'm-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);
const parent = SchoolMembership(id: 'm-parent', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.parent);

/// "Science Discovery Trip" - the demo school's own seeded TRIP-001, real enough to attach evidence to.
const _tripId = 'TRIP-001';

void main() {
  late LocalDatabase db;
  late Directory tempRoot;
  late SchoolSessionController session;
  late ExcursionRepository repository;
  MediaUploadQueue? queue;

  Future<void> setUpSchool([SchoolMembership who = manager]) async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    tempRoot = Directory.systemTemp.createTempSync('excursion_media_test_');
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([manager, otherSchoolManager, teacherContributor, parent]);
    await session.selectSchool(who);
    repository = ExcursionRepository(localDatabase: db, schoolSession: session);
    queue = null;
  }

  tearDown(() {
    queue?.dispose();
    db.close();
    tempRoot.deleteSync(recursive: true);
  });

  /// Several rounds of a real pump plus a real delay - the same shape community_media_test.dart's own helper
  /// uses - real async work (loading the repository, and here also a real file write) needs tester.runAsync()
  /// to actually run at all inside a testWidgets test.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
  }

  Future<void> pump(WidgetTester tester, {MediaApi? api, SchoolMembership who = manager}) async {
    tester.view.physicalSize = const Size(1600, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => setUpSchool(who));

    Widget home = ExcursionsPage(schoolName: 'BrightGate', repository: repository, onBack: () {});
    if (api != null) {
      final q = MediaUploadQueue(database: db, schoolSession: session, files: MediaLocalFiles(rootDirectory: () async => tempRoot), observeLifecycle: false)..api = api;
      queue = q;
      home = MediaScope(api: api, queue: q, child: home);
    }
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: home)));
    await settle(tester);
  }

  /// Every trip's own attachments panel uses the same category-based "add" key (options are keyed by category,
  /// not by owner - see media_attachments_panel.dart), and every seeded trip renders its own panel on the one
  /// scrolling register at once, so a bare find.byKey would be ambiguous. Scoping to one trip's own Container
  /// (keyed `trip-<id>`) finds exactly the one control that trip's own card renders.
  Finder tripCard(String id) => find.byKey(ValueKey('trip-$id'));
  Finder within(String id, Key key) => find.descendant(of: tripCard(id), matching: find.byKey(key));

  /// A real (if tiny) PNG - an asset with hasThumbnail:true (assetJson's own default) makes MediaThumbnailView
  /// actually fetch and decode one, and handing it real JSON instead of image bytes throws deep inside Flutter's
  /// image codec. See the same tinyPng()/mediaServer() pattern already proven in core/media_attachments_panel_test.dart,
  /// administrator_records_media_test.dart and community_media_test.dart.
  Future<Uint8List> tinyPng() async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(const ui.Rect.fromLTWH(0, 0, 2, 2), ui.Paint()..color = const Color(0xFF2255AA));
    final image = await recorder.endRecording().toImage(2, 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  /// [assetsByTrip] maps a trip id to the assets that trip's own attachments panel should list; any trip not
  /// named there (every other seeded trip also renders its own panel on the same register) sees an empty list.
  FakeServer serverWithAssets(Map<String, List<Map<String, Object?>>> assetsByTrip) => FakeServer((r) async {
        if (r.method == 'GET' && r.url.path.contains('/download/')) {
          final id = r.url.pathSegments[r.url.pathSegments.indexOf('assets') + 1];
          return jsonResponse({'mode': 'stream', 'url': 'assets/$id/raw/', 'mimeType': 'image/png', 'expiresAt': null});
        }
        if (r.method == 'GET' && r.url.path.endsWith('/raw/')) return http.Response.bytes(await tinyPng(), 200);
        if (r.method == 'GET' && r.url.path.endsWith('/assets/')) {
          final ownerId = r.url.queryParameters['ownerId'];
          return jsonResponse({'assets': assetsByTrip[ownerId] ?? const []});
        }
        if (r.method == 'POST' && r.url.path.endsWith('/retire/')) {
          final id = r.url.pathSegments[r.url.pathSegments.indexOf('assets') + 1];
          return jsonResponse({'asset': assetJson(id: id, status: 'retired')});
        }
        return jsonResponse({}, 404);
      });

  group('a trip with no evidence', () {
    testWidgets('without a school server, attaching evidence is not offered at all', (tester) async {
      await pump(tester);
      expect(within(_tripId, const ValueKey('add-excursion_evidence')), findsNothing);
    });

    testWidgets('with a school server and nothing attached yet, it says so honestly', (tester) async {
      await pump(tester, api: MediaApi(api: apiFor(serverWithAssets(const {}))));
      expect(within(_tripId, const ValueKey('attachments-empty')), findsOneWidget);
      expect(within(_tripId, const ValueKey('add-excursion_evidence')), findsOneWidget);
    });
  });

  testWidgets('existing evidence the server already has is shown as available', (tester) async {
    await pump(tester, api: MediaApi(api: apiFor(serverWithAssets({
      _tripId: [assetJson(id: 'a1', status: 'available')],
    }))));
    expect(within(_tripId, const ValueKey('asset-a1')), findsOneWidget);
    expect(within(_tripId, const ValueKey('asset-status-a1')), findsNothing); // available: no "not ready" word shown
  });

  group('attaching evidence', () {
    testWidgets('a rejected file type never reaches the queue', (tester) async {
      await setUpSchool();
      final api = MediaApi(api: apiFor(serverWithAssets(const {})));
      final q = MediaUploadQueue(database: db, schoolSession: session, files: MediaLocalFiles(rootDirectory: () async => tempRoot), observeLifecycle: false)..api = api;
      addTearDown(q.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaAttachmentsPanel(
              api: api,
              queue: q,
              membership: teacherContributor,
              ownerType: 'school_excursion',
              ownerId: _tripId,
              canContribute: true,
              canManage: true,
              options: const [
                MediaAttachmentOption(label: 'Attach evidence', category: 'excursion_evidence', mediaType: 'image'),
              ],
              pickFile: (option) async => PickedMediaFile(name: 'virus.exe', extension: 'exe', bytes: Uint8List.fromList([1])),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-excursion_evidence')));
      await tester.pumpAndSettle();
      expect(find.textContaining('does not accept'), findsOneWidget);
      expect(q.pendingCount(teacherContributor), 0);
    });

    testWidgets('supported evidence (JPG, PNG, WEBP or GIF) queues successfully', (tester) async {
      await setUpSchool();
      final api = MediaApi(api: apiFor(serverWithAssets(const {})));
      final q = MediaUploadQueue(database: db, schoolSession: session, files: MediaLocalFiles(rootDirectory: () async => tempRoot), observeLifecycle: false)..api = api;
      addTearDown(q.dispose);
      for (final (name, ext) in const [('a.jpg', 'jpg'), ('a.png', 'png'), ('a.webp', 'webp'), ('a.gif', 'gif')]) {
        await tester.pumpWidget(const SizedBox()); // fully unmount between rounds
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MediaAttachmentsPanel(
                api: api,
                queue: q,
                membership: teacherContributor,
                ownerType: 'school_excursion',
                ownerId: _tripId,
                canContribute: true,
                canManage: true,
                options: const [
                  MediaAttachmentOption(label: 'Attach evidence', category: 'excursion_evidence', mediaType: 'image'),
                ],
                pickFile: (option) async => PickedMediaFile(name: name, extension: ext, bytes: Uint8List.fromList([1, 2, 3])),
              ),
            ),
          ),
        );
        // Not pumpAndSettle(): from the second round on, an earlier round's own queued item still shows an
        // indeterminate "waiting" spinner (the queue is never started here), which would spin forever - a
        // handful of ordinary pumps is enough to let this round's own initial server list load finish.
        await tester.pump();
        await tester.pump();
        final before = q.pendingCount(teacherContributor);
        // Picking copies real bytes to real disk (MediaLocalFiles) - genuine dart:io I/O, which the widget-test
        // clock never drives on its own; tester.runAsync() lets it actually run against the real event loop.
        await tester.runAsync(() => tester.tap(find.byKey(const ValueKey('add-excursion_evidence'))));
        await tester.runAsync(() async {
          while (q.pendingCount(teacherContributor) == before) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        await tester.pump();
        expect(q.pendingCount(teacherContributor), before + 1, reason: ext);
      }
    });
  });

  // A plain test(), not testWidgets(): nothing here ever pumps a widget, so there is no FakeAsync clock to fight -
  // q.start()'s own Timer and the delay below are real, exactly like media_upload_queue_test.dart's own tests.
  test('offline (no network), a queued attachment stays local and is never shown as uploaded', () async {
    await setUpSchool();
    final server = FakeServer((r) async => throw Exception('offline'));
    final api = MediaApi(api: apiFor(server));
    final q = MediaUploadQueue(database: db, schoolSession: session, files: MediaLocalFiles(rootDirectory: () async => tempRoot), observeLifecycle: false, firstBackoff: const Duration(milliseconds: 30))..api = api;
    addTearDown(q.dispose);
    final id = await q.enqueue(membership: teacherContributor, ownerType: 'school_excursion', ownerId: _tripId, category: 'excursion_evidence', fileName: 'a.jpg', mimeType: 'image/jpeg', bytes: Uint8List.fromList([1]));
    q.start();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final item = db.mediaUpload(id)!;
    expect(item.state.name, isNot('uploaded'));
    expect(item.serverAssetId, isNull);
  });

  testWidgets('a failed attachment offers a retry, and the trip itself is never touched by any of this', (tester) async {
    await setUpSchool();
    final api = MediaApi(api: apiFor(serverWithAssets(const {})));
    final q = MediaUploadQueue(database: db, schoolSession: session, files: MediaLocalFiles(rootDirectory: () async => tempRoot), observeLifecycle: false)..api = api;
    addTearDown(q.dispose);
    // Queuing copies real bytes to real disk - see the note on the "supported evidence" test above.
    final id = (await tester.runAsync(
      () => q.enqueue(membership: teacherContributor, ownerType: 'school_excursion', ownerId: _tripId, category: 'excursion_evidence', fileName: 'a.jpg', mimeType: 'image/jpeg', bytes: Uint8List.fromList([1])),
    ))!;
    db.markMediaUploadFailed(id, errorCode: 'file_too_large', errorMessage: 'Too big');

    final before = await repository.load();
    final beforeTrip = before.trips.firstWhere((t) => t.id == _tripId);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaAttachmentsPanel(api: api, queue: q, membership: teacherContributor, ownerType: 'school_excursion', ownerId: _tripId, canContribute: true, canManage: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Failed'), findsOneWidget);
    expect(find.byKey(ValueKey('retry-$id')), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('retry-$id')));
    await tester.pump();
    await tester.pump();
    expect(db.mediaUpload(id)!.state.name, 'waiting');

    final after = await repository.load();
    final afterTrip = after.trips.firstWhere((t) => t.id == _tripId);
    // Attaching (or failing to attach, or retrying) a file never moves the trip's own status or readiness sign-off.
    expect(afterTrip.status, beforeTrip.status);
    expect(afterTrip.readinessReviewed, beforeTrip.readinessReviewed);
    expect(afterTrip.consentReceived, beforeTrip.consentReceived);
  });

  group('removing evidence', () {
    testWidgets('a manager may retire anyone\'s evidence, with a reason, posted to the server', (tester) async {
      var retired = false;
      final server = FakeServer((r) async {
        if (r.method == 'GET' && r.url.path.contains('/download/')) {
          final id = r.url.pathSegments[r.url.pathSegments.indexOf('assets') + 1];
          return jsonResponse({'mode': 'stream', 'url': 'assets/$id/raw/', 'mimeType': 'image/png', 'expiresAt': null});
        }
        if (r.method == 'GET' && r.url.path.endsWith('/raw/')) return http.Response.bytes(await tinyPng(), 200);
        if (r.method == 'POST' && r.url.path.endsWith('/retire/')) {
          retired = true;
          return jsonResponse({'asset': assetJson(id: 'a1', status: 'retired')});
        }
        return jsonResponse({'assets': retired ? <Object?>[] : [assetJson(id: 'a1')]});
      });
      await pump(tester, api: MediaApi(api: apiFor(server)), who: manager);
      expect(within(_tripId, const ValueKey('retire-a1')), findsOneWidget);
      await tester.tap(within(_tripId, const ValueKey('retire-a1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('remove-reason')), 'wrong photo attached');
      await tester.tap(find.byKey(const ValueKey('remove-confirm')));
      await tester.pumpAndSettle();
      expect(retired, isTrue);
    });

    testWidgets('a contributor who did not upload it, and is not a manager, has no remove control at all', (tester) async {
      // assetJson's own default uploadedByMembershipId belongs to neither membership below.
      await pump(tester, api: MediaApi(api: apiFor(serverWithAssets({
        _tripId: [assetJson(id: 'a1')],
      }))), who: teacherContributor);
      expect(within(_tripId, const ValueKey('asset-a1')), findsOneWidget);
      expect(within(_tripId, const ValueKey('retire-a1')), findsNothing);
    });
  });

  testWidgets('a parent cannot create or edit a trip, so there is no attach control on any trip either', (tester) async {
    await pump(tester, api: MediaApi(api: apiFor(serverWithAssets(const {}))), who: parent);
    expect(within(_tripId, const ValueKey('add-excursion_evidence')), findsNothing);
  });

  testWidgets('a teacher, an ordinary contributor, can still attach evidence to any visible trip', (tester) async {
    await pump(tester, api: MediaApi(api: apiFor(serverWithAssets(const {}))), who: teacherContributor);
    expect(within(_tripId, const ValueKey('add-excursion_evidence')), findsOneWidget);
  });

  // A plain test(): no widget is ever pumped, so a real MediaUploadQueue.enqueue() (real disk I/O) just works.
  test('switching the active school changes which schools queued evidence this device shows', () async {
    await setUpSchool(manager);
    final api = MediaApi(api: apiFor(serverWithAssets(const {})));
    final q = MediaUploadQueue(database: db, schoolSession: session, files: MediaLocalFiles(rootDirectory: () async => tempRoot), observeLifecycle: false)..api = api;
    addTearDown(q.dispose);

    await q.enqueue(membership: manager, ownerType: 'school_excursion', ownerId: _tripId, category: 'excursion_evidence', fileName: 'brightgate.jpg', mimeType: 'image/jpeg', bytes: Uint8List.fromList([1]));
    expect(q.uploadsForOwner(manager, ownerType: 'school_excursion', ownerId: _tripId), hasLength(1));

    // A trip id can never mean the same trip in a different school; what matters is that a device holding
    // queued evidence for one school never shows it for another, whatever a screen's own ids happen to be.
    expect(q.uploadsForOwner(otherSchoolManager, ownerType: 'school_excursion', ownerId: _tripId), isEmpty);
    expect(q.pendingCount(otherSchoolManager), 0);
    expect(q.pendingCount(manager), 1);

    await session.selectSchool(otherSchoolManager);
    await q.enqueue(membership: otherSchoolManager, ownerType: 'school_excursion', ownerId: _tripId, category: 'excursion_evidence', fileName: 'riverside.jpg', mimeType: 'image/jpeg', bytes: Uint8List.fromList([2]));
    expect(q.uploadsForOwner(otherSchoolManager, ownerType: 'school_excursion', ownerId: _tripId).single.fileName, 'riverside.jpg');
    expect(q.uploadsForOwner(manager, ownerType: 'school_excursion', ownerId: _tripId).single.fileName, 'brightgate.jpg');
  });
}
