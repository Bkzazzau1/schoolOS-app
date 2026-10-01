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
import 'package:schoolos_app/features/administrator/data/administrator_records_repository.dart';
import 'package:schoolos_app/features/administrator/presentation/administrator_records_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;
import 'core/media_api_test.dart' show assetJson;

const admin = SchoolMembership(id: 'm-admin', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.administrator);
const otherSchoolAdmin = SchoolMembership(id: 'm-admin-2', schoolId: 'school-2', schoolName: 'Riverside', role: SchoolRole.administrator);
const teacher = SchoolMembership(id: 'm-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

void main() {
  late LocalDatabase db;
  late Directory tempRoot;
  late SchoolSessionController session;
  late AdministratorRecordsRepository repository;
  late String recordId;
  late String staffRecordId;
  MediaUploadQueue? queue;

  Future<void> setUpSchool([SchoolMembership who = admin]) async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    tempRoot = Directory.systemTemp.createTempSync('administrator_records_media_test_');
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([admin, otherSchoolAdmin, teacher]);
    await session.selectSchool(admin);
    repository = AdministratorRecordsRepository(localDatabase: db, schoolSession: session);
    queue = null;

    // A document record real enough to open a review dialog for: "Birth certificate" for Ahmed Yusuf,
    // Student kind, missing status - the same shape the app's own demo data used to fake.
    recordId = (await repository.add(owner: 'Ahmed Yusuf', document: 'Birth certificate', kind: 'Student')).record!.id;
    staffRecordId = (await repository.add(owner: 'Mrs. Grace Musa', document: 'Staff qualification', kind: 'Staff')).record!.id;

    await session.selectSchool(who);
  }

  tearDown(() {
    queue?.dispose();
    db.close();
    tempRoot.deleteSync(recursive: true);
  });

  /// Several rounds of a real pump plus a real delay, the same shape the existing
  /// administrator_records_actions_test.dart's own widget test already uses - real async work (loading the
  /// repository, and here also a real file write) needs tester.runAsync() to actually run at all inside a
  /// testWidgets test.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
  }

  Future<void> pump(WidgetTester tester, {MediaApi? api, SchoolMembership who = admin}) async {
    tester.view.physicalSize = const Size(1600, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => setUpSchool(who));

    Widget home = AdministratorRecordsPage(schoolName: 'BrightGate', repository: repository);
    if (api != null) {
      final q = MediaUploadQueue(database: db, schoolSession: session, files: MediaLocalFiles(rootDirectory: () async => tempRoot), observeLifecycle: false)..api = api;
      queue = q;
      home = MediaScope(api: api, queue: q, child: home);
    }
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: home)));
    await settle(tester);
  }

  Future<void> openReview(WidgetTester tester, {String? id}) async {
    await tester.tap(find.byKey(ValueKey('review-${id ?? recordId}')));
    await tester.pumpAndSettle();
  }

  /// A real (if tiny) PNG - an asset with hasThumbnail:true (assetJson's own default) makes MediaThumbnailView
  /// actually fetch and decode one, and handing it real JSON instead of image bytes throws deep inside Flutter's
  /// image codec, failing whichever test happens to be pumping when that rejected Future surfaces. See the same
  /// tinyPng()/mediaServer() pattern already proven in core/media_attachments_panel_test.dart.
  Future<Uint8List> tinyPng() async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(const ui.Rect.fromLTWH(0, 0, 2, 2), ui.Paint()..color = const Color(0xFF2255AA));
    final image = await recorder.endRecording().toImage(2, 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  FakeServer serverWithAssets(List<Map<String, Object?>> assets) => FakeServer((r) async {
        if (r.method == 'GET' && r.url.path.endsWith('/assets/')) return jsonResponse({'assets': assets});
        if (r.method == 'GET' && r.url.path.contains('/download/')) {
          final id = r.url.pathSegments[r.url.pathSegments.indexOf('assets') + 1];
          return jsonResponse({'mode': 'stream', 'url': 'assets/$id/raw/', 'mimeType': 'image/png', 'expiresAt': null});
        }
        if (r.method == 'GET' && r.url.path.endsWith('/raw/')) return http.Response.bytes(await tinyPng(), 200);
        if (r.method == 'POST' && r.url.path.endsWith('/retire/')) {
          final id = r.url.pathSegments[r.url.pathSegments.indexOf('assets') + 1];
          return jsonResponse({'asset': assetJson(id: id, status: 'retired')});
        }
        return jsonResponse({}, 404);
      });

  group('a document with no attachment', () {
    testWidgets('without a school server, attaching a file is not offered at all', (tester) async {
      await pump(tester);
      await openReview(tester);
      expect(find.textContaining('needs your school\'s server'), findsOneWidget);
      expect(find.byKey(const ValueKey('add-student_document')), findsNothing);
    });

    testWidgets('with a school server and nothing attached yet, it says so honestly', (tester) async {
      await pump(tester, api: MediaApi(api: apiFor(serverWithAssets(const []))));
      await openReview(tester);
      expect(find.byKey(const ValueKey('attachments-empty')), findsOneWidget);
      expect(find.byKey(const ValueKey('add-student_document')), findsOneWidget); // Student kind -> student_document
    });
  });

  testWidgets('an existing file the server already has is shown as available', (tester) async {
    await pump(tester, api: MediaApi(api: apiFor(serverWithAssets([assetJson(id: 'a1', status: 'available')]))));
    await openReview(tester);
    expect(find.byKey(const ValueKey('asset-a1')), findsOneWidget);
    expect(find.byKey(const ValueKey('asset-status-a1')), findsNothing); // available: no "not ready" word shown
  });

  group('attaching a file', () {
    testWidgets('a rejected file type never reaches the queue', (tester) async {
      await setUpSchool();
      final api = MediaApi(api: apiFor(serverWithAssets(const [])));
      final q = MediaUploadQueue(database: db, schoolSession: session, files: MediaLocalFiles(rootDirectory: () async => tempRoot), observeLifecycle: false)..api = api;
      addTearDown(q.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaAttachmentsPanel(
              api: api,
              queue: q,
              membership: admin,
              ownerType: 'administrator_document_record',
              ownerId: recordId,
              canContribute: true,
              canManage: true,
              options: const [
                MediaAttachmentOption(label: 'Attach a file', category: 'student_document', mediaType: 'document', allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png']),
              ],
              pickFile: (option) async => PickedMediaFile(name: 'virus.exe', extension: 'exe', bytes: Uint8List.fromList([1])),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-student_document')));
      await tester.pumpAndSettle();
      expect(find.textContaining('does not accept'), findsOneWidget);
      expect(q.pendingCount(admin), 0);
    });

    testWidgets('a supported document (PDF, JPEG, PNG, DOC or DOCX) queues successfully', (tester) async {
      await setUpSchool();
      final api = MediaApi(api: apiFor(serverWithAssets(const [])));
      final q = MediaUploadQueue(database: db, schoolSession: session, files: MediaLocalFiles(rootDirectory: () async => tempRoot), observeLifecycle: false)..api = api;
      addTearDown(q.dispose);
      for (final (name, ext) in const [('a.pdf', 'pdf'), ('a.jpg', 'jpg'), ('a.png', 'png'), ('a.doc', 'doc'), ('a.docx', 'docx')]) {
        await tester.pumpWidget(const SizedBox()); // fully unmount between rounds
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MediaAttachmentsPanel(
                api: api,
                queue: q,
                membership: admin,
                ownerType: 'administrator_document_record',
                ownerId: recordId,
                canContribute: true,
                canManage: true,
                options: const [
                  MediaAttachmentOption(label: 'Attach a file', category: 'student_document', mediaType: 'document', allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png']),
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
        final before = q.pendingCount(admin);
        // Picking copies real bytes to real disk (MediaLocalFiles) - genuine dart:io I/O, which the widget-test
        // clock never drives on its own; tester.runAsync() lets it actually run against the real event loop -
        // the same idiom core/media_attachments_panel_test.dart already uses for Gallery's own picker.
        await tester.runAsync(() => tester.tap(find.byKey(const ValueKey('add-student_document'))));
        await tester.runAsync(() async {
          while (q.pendingCount(admin) == before) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        await tester.pump();
        expect(q.pendingCount(admin), before + 1, reason: ext);
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
    final id = await q.enqueue(membership: admin, ownerType: 'administrator_document_record', ownerId: recordId, category: 'student_document', fileName: 'a.pdf', mimeType: 'application/pdf', bytes: Uint8List.fromList([1]));
    q.start();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final item = db.mediaUpload(id)!;
    expect(item.state.name, isNot('uploaded'));
    expect(item.serverAssetId, isNull);
  });

  testWidgets('a failed attachment offers a retry, and the document status is never touched by any of this', (tester) async {
    await setUpSchool();
    final api = MediaApi(api: apiFor(serverWithAssets(const [])));
    final q = MediaUploadQueue(database: db, schoolSession: session, files: MediaLocalFiles(rootDirectory: () async => tempRoot), observeLifecycle: false)..api = api;
    addTearDown(q.dispose);
    // Queuing copies real bytes to real disk - see the note on the "a supported document" test above.
    final id = (await tester.runAsync(
      () => q.enqueue(membership: admin, ownerType: 'administrator_document_record', ownerId: recordId, category: 'student_document', fileName: 'a.pdf', mimeType: 'application/pdf', bytes: Uint8List.fromList([1])),
    ))!;
    db.markMediaUploadFailed(id, errorCode: 'file_too_large', errorMessage: 'Too big');

    final before = await repository.load();
    final beforeStatus = before.records.firstWhere((r) => r.id == recordId).status;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaAttachmentsPanel(api: api, queue: q, membership: admin, ownerType: 'administrator_document_record', ownerId: recordId, canContribute: true, canManage: true),
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
    expect(after.records.firstWhere((r) => r.id == recordId).status, beforeStatus); // "received"/"verified" never moved by attaching anything
  });

  testWidgets('removing an attached file needs a reason and posts a retire to the server, only for someone who reviews records', (tester) async {
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
    await pump(tester, api: MediaApi(api: apiFor(server)));
    await openReview(tester);
    expect(find.byKey(const ValueKey('retire-a1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('retire-a1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('remove-reason')), 'wrong file attached');
    await tester.tap(find.byKey(const ValueKey('remove-confirm')));
    await tester.pumpAndSettle();
    expect(retired, isTrue);
  });

  testWidgets('a teacher cannot open the review dialog, so there is no attachment control to reach', (tester) async {
    await pump(tester, api: MediaApi(api: apiFor(serverWithAssets(const []))), who: teacher);
    // The register row itself still renders (existing, unchanged behaviour) - only its own "Review" control is
    // disabled for a role that cannot review restricted metadata, so a teacher can never reach the dialog this
    // attachments panel lives inside.
    final button = tester.widget<TextButton>(find.byKey(ValueKey('review-$recordId')));
    expect(button.onPressed, isNull);
  });

  // A plain test(): no widget is ever pumped, so a real MediaUploadQueue.enqueue() (real disk I/O) just works.
  test('switching the active school changes which schools queued files this device shows', () async {
    await setUpSchool(admin);
    final api = MediaApi(api: apiFor(serverWithAssets(const [])));
    final q = MediaUploadQueue(database: db, schoolSession: session, files: MediaLocalFiles(rootDirectory: () async => tempRoot), observeLifecycle: false)..api = api;
    addTearDown(q.dispose);

    await q.enqueue(membership: admin, ownerType: 'administrator_document_record', ownerId: recordId, category: 'student_document', fileName: 'brightgate.pdf', mimeType: 'application/pdf', bytes: Uint8List.fromList([1]));
    expect(q.uploadsForOwner(admin, ownerType: 'administrator_document_record', ownerId: recordId), hasLength(1));

    // The same record id can never mean the same record in a different school; what matters is that a device
    // holding queued files for one school never shows them for another, whatever a screen's own ids happen to be.
    expect(q.uploadsForOwner(otherSchoolAdmin, ownerType: 'administrator_document_record', ownerId: recordId), isEmpty);
    expect(q.pendingCount(otherSchoolAdmin), 0);
    expect(q.pendingCount(admin), 1);

    await session.selectSchool(otherSchoolAdmin);
    await q.enqueue(membership: otherSchoolAdmin, ownerType: 'administrator_document_record', ownerId: recordId, category: 'student_document', fileName: 'riverside.pdf', mimeType: 'application/pdf', bytes: Uint8List.fromList([2]));
    expect(q.uploadsForOwner(otherSchoolAdmin, ownerType: 'administrator_document_record', ownerId: recordId).single.fileName, 'riverside.pdf');
    expect(q.uploadsForOwner(admin, ownerType: 'administrator_document_record', ownerId: recordId).single.fileName, 'brightgate.pdf');
  });

  testWidgets('a staff kind document uses the staff_document category, matching staff onboarding documents', (tester) async {
    await pump(tester, api: MediaApi(api: apiFor(serverWithAssets(const []))));
    await openReview(tester, id: staffRecordId); // Staff qualification, kind: Staff
    expect(find.byKey(const ValueKey('add-staff_document')), findsOneWidget);
  });
}
