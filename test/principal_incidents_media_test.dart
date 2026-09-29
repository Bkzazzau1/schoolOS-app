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
import 'package:schoolos_app/features/principal/data/principal_incidents_repository.dart';
import 'package:schoolos_app/features/principal/domain/principal_incidents_models.dart';
import 'package:schoolos_app/features/principal/presentation/principal_incidents_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;
import 'core/media_api_test.dart' show assetJson;

const principal = SchoolMembership(id: 'm-principal', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.principal);
const otherSchoolPrincipal = SchoolMembership(id: 'm-principal-2', schoolId: 'school-2', schoolName: 'Riverside', role: SchoolRole.principal);
const teacher = SchoolMembership(id: 'm-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

/// A case real enough to attach evidence to. Principal Incidents has no seed/demo data at all ("Reference
/// filters only; no fabricated cases or activity" - principal_incidents_demo_data.dart), so every test inserts
/// this one directly, the same way test/principal_incidents_feature_test.dart's own record() helper does.
const _caseId = 'case-1';

void main() {
  late LocalDatabase db;
  late Directory tempRoot;
  late SchoolSessionController session;
  late PrincipalIncidentsRepository repository;
  MediaUploadQueue? queue;

  Future<void> setUpSchool([SchoolMembership who = principal]) async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    tempRoot = Directory.systemTemp.createTempSync('principal_incidents_media_test_');
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([principal, otherSchoolPrincipal, teacher]);
    await session.selectSchool(who);
    repository = PrincipalIncidentsRepository(localDatabase: db, schoolSession: session);
    queue = null;
  }

  tearDown(() {
    queue?.dispose();
    db.close();
    tempRoot.deleteSync(recursive: true);
  });

  /// The smallest real case, seeded directly into the local database - there is no "create a case" flow in the
  /// app yet (only notes and status changes), so every case a Principal ever sees today started this way.
  Future<void> seedCase({String tenant = 'school-1'}) async {
    const item = PrincipalIncident(
      id: _caseId,
      title: 'Corridor incident',
      category: PrincipalIncidentCategory.behaviour,
      severity: PrincipalIncidentSeverity.medium,
      status: PrincipalIncidentStatus.investigating,
      person: 'Reported by staff',
      context: 'JSS 2A',
      reportedBy: 'Front desk',
      owner: 'Principal',
      reportedAt: '2026-09-22',
      location: 'Main corridor',
      guardianContact: PrincipalGuardianContact.notRequired,
      evidenceCount: 0,
      summary: 'A staff-entered report.',
      nextAction: 'Review evidence',
    );
    await db.upsertLocalRecord(
      tenantId: tenant,
      entityType: 'principal_recorded_incident_case',
      entityId: _caseId,
      payload: item.toJson(),
      isDirty: true,
    );
  }

  /// Several rounds of a real pump plus a real delay - the same shape the other *_media_test.dart files use -
  /// real async work (loading the repository, and here also a real file write) needs tester.runAsync() to
  /// actually run at all inside a testWidgets test.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
  }

  Future<void> pump(WidgetTester tester, {MediaApi? api, SchoolMembership who = principal}) async {
    tester.view.physicalSize = const Size(1600, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await setUpSchool(who);
      await seedCase();
    });

    Widget home = PrincipalIncidentsPage(repository: repository, onNavigate: (_) {});
    if (api != null) {
      final q = MediaUploadQueue(database: db, schoolSession: session, files: MediaLocalFiles(rootDirectory: () async => tempRoot), observeLifecycle: false)..api = api;
      queue = q;
      home = MediaScope(api: api, queue: q, child: home);
    }
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: home)));
    await settle(tester);
  }

  /// A real (if tiny) PNG - an asset with hasThumbnail:true (assetJson's own default) makes MediaThumbnailView
  /// actually fetch and decode one, and handing it real JSON instead of image bytes throws deep inside Flutter's
  /// image codec. See the same tinyPng()/mediaServer() pattern already proven in the other *_media_test.dart files.
  Future<Uint8List> tinyPng() async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(const ui.Rect.fromLTWH(0, 0, 2, 2), ui.Paint()..color = const Color(0xFF2255AA));
    final image = await recorder.endRecording().toImage(2, 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  FakeServer serverWithAssets(List<Map<String, Object?>> assets) => FakeServer((r) async {
        if (r.method == 'GET' && r.url.path.contains('/download/')) {
          final id = r.url.pathSegments[r.url.pathSegments.indexOf('assets') + 1];
          return jsonResponse({'mode': 'stream', 'url': 'assets/$id/raw/', 'mimeType': 'image/png', 'expiresAt': null});
        }
        if (r.method == 'GET' && r.url.path.endsWith('/raw/')) return http.Response.bytes(await tinyPng(), 200);
        if (r.method == 'GET' && r.url.path.endsWith('/assets/')) return jsonResponse({'assets': assets});
        if (r.method == 'POST' && r.url.path.endsWith('/retire/')) {
          final id = r.url.pathSegments[r.url.pathSegments.indexOf('assets') + 1];
          return jsonResponse({'asset': assetJson(id: id, status: 'retired')});
        }
        return jsonResponse({}, 404);
      });

  group('a case with no evidence', () {
    testWidgets('without a school server, attaching evidence is not offered at all', (tester) async {
      await pump(tester);
      expect(find.byKey(const ValueKey('add-incident_evidence')), findsNothing);
    });

    testWidgets('with a school server and nothing attached yet, it says so honestly', (tester) async {
      await pump(tester, api: MediaApi(api: apiFor(serverWithAssets(const []))));
      expect(find.byKey(const ValueKey('attachments-empty')), findsOneWidget);
      expect(find.byKey(const ValueKey('add-incident_evidence')), findsOneWidget);
    });
  });

  testWidgets('existing evidence the server already has is shown as available', (tester) async {
    await pump(tester, api: MediaApi(api: apiFor(serverWithAssets([assetJson(id: 'a1', status: 'available')]))));
    expect(find.byKey(const ValueKey('asset-a1')), findsOneWidget);
    expect(find.byKey(const ValueKey('asset-status-a1')), findsNothing); // available: no "not ready" word shown
  });

  group('attaching evidence', () {
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
              membership: principal,
              ownerType: 'principal_recorded_incident_case',
              ownerId: _caseId,
              canContribute: true,
              canManage: true,
              options: const [
                MediaAttachmentOption(label: 'Attach evidence', category: 'incident_evidence', mediaType: 'image'),
              ],
              pickFile: (option) async => PickedMediaFile(name: 'virus.exe', extension: 'exe', bytes: Uint8List.fromList([1])),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-incident_evidence')));
      await tester.pumpAndSettle();
      expect(find.textContaining('does not accept'), findsOneWidget);
      expect(q.pendingCount(principal), 0);
    });

    testWidgets('supported evidence (JPG, PNG, WEBP or GIF) queues successfully', (tester) async {
      await setUpSchool();
      final api = MediaApi(api: apiFor(serverWithAssets(const [])));
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
                membership: principal,
                ownerType: 'principal_recorded_incident_case',
                ownerId: _caseId,
                canContribute: true,
                canManage: true,
                options: const [
                  MediaAttachmentOption(label: 'Attach evidence', category: 'incident_evidence', mediaType: 'image'),
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
        final before = q.pendingCount(principal);
        // Picking copies real bytes to real disk (MediaLocalFiles) - genuine dart:io I/O, which the widget-test
        // clock never drives on its own; tester.runAsync() lets it actually run against the real event loop.
        await tester.runAsync(() => tester.tap(find.byKey(const ValueKey('add-incident_evidence'))));
        await tester.runAsync(() async {
          while (q.pendingCount(principal) == before) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        await tester.pump();
        expect(q.pendingCount(principal), before + 1, reason: ext);
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
    final id = await q.enqueue(membership: principal, ownerType: 'principal_recorded_incident_case', ownerId: _caseId, category: 'incident_evidence', fileName: 'a.jpg', mimeType: 'image/jpeg', bytes: Uint8List.fromList([1]));
    q.start();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final item = db.mediaUpload(id)!;
    expect(item.state.name, isNot('uploaded'));
    expect(item.serverAssetId, isNull);
  });

  testWidgets('a failed attachment offers a retry, and the case itself is never touched by any of this', (tester) async {
    await setUpSchool();
    await seedCase();
    final api = MediaApi(api: apiFor(serverWithAssets(const [])));
    final q = MediaUploadQueue(database: db, schoolSession: session, files: MediaLocalFiles(rootDirectory: () async => tempRoot), observeLifecycle: false)..api = api;
    addTearDown(q.dispose);
    // Queuing copies real bytes to real disk - see the note on the "supported evidence" test above.
    final id = (await tester.runAsync(
      () => q.enqueue(membership: principal, ownerType: 'principal_recorded_incident_case', ownerId: _caseId, category: 'incident_evidence', fileName: 'a.jpg', mimeType: 'image/jpeg', bytes: Uint8List.fromList([1])),
    ))!;
    db.markMediaUploadFailed(id, errorCode: 'file_too_large', errorMessage: 'Too big');

    final before = await repository.load();
    final beforeCase = before.cases.firstWhere((c) => c.id == _caseId);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaAttachmentsPanel(api: api, queue: q, membership: principal, ownerType: 'principal_recorded_incident_case', ownerId: _caseId, canContribute: true, canManage: true),
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
    final afterCase = after.cases.firstWhere((c) => c.id == _caseId);
    // Attaching (or failing to attach, or retrying) a file never moves the case's own status or evidence count.
    expect(afterCase.status, beforeCase.status);
    expect(afterCase.evidenceCount, beforeCase.evidenceCount);
    expect((await repository.load()).audit, isEmpty); // no audit event was invented by any of this either
  });

  testWidgets('a principal may retire evidence, with a reason, posted to the server', (tester) async {
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
    expect(find.byKey(const ValueKey('retire-a1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('retire-a1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('remove-reason')), 'wrong photo attached');
    await tester.tap(find.byKey(const ValueKey('remove-confirm')));
    await tester.pumpAndSettle();
    expect(retired, isTrue);
  });

  testWidgets('a teacher cannot see the case at all, so there is no attachment control to find', (tester) async {
    await pump(tester, api: MediaApi(api: apiFor(serverWithAssets(const []))), who: teacher);
    expect(find.byKey(const ValueKey('add-incident_evidence')), findsNothing);
    expect(find.textContaining('No recorded Secondary incidents.'), findsOneWidget);
  });

  // A plain test(): no widget is ever pumped, so a real MediaUploadQueue.enqueue() (real disk I/O) just works.
  test('switching the active school changes which schools queued evidence this device shows', () async {
    await setUpSchool(principal);
    final api = MediaApi(api: apiFor(serverWithAssets(const [])));
    final q = MediaUploadQueue(database: db, schoolSession: session, files: MediaLocalFiles(rootDirectory: () async => tempRoot), observeLifecycle: false)..api = api;
    addTearDown(q.dispose);

    await q.enqueue(membership: principal, ownerType: 'principal_recorded_incident_case', ownerId: _caseId, category: 'incident_evidence', fileName: 'brightgate.jpg', mimeType: 'image/jpeg', bytes: Uint8List.fromList([1]));
    expect(q.uploadsForOwner(principal, ownerType: 'principal_recorded_incident_case', ownerId: _caseId), hasLength(1));

    // A case id can never mean the same case in a different school; what matters is that a device holding
    // queued evidence for one school never shows it for another, whatever a screen's own ids happen to be.
    expect(q.uploadsForOwner(otherSchoolPrincipal, ownerType: 'principal_recorded_incident_case', ownerId: _caseId), isEmpty);
    expect(q.pendingCount(otherSchoolPrincipal), 0);
    expect(q.pendingCount(principal), 1);

    await session.selectSchool(otherSchoolPrincipal);
    await q.enqueue(membership: otherSchoolPrincipal, ownerType: 'principal_recorded_incident_case', ownerId: _caseId, category: 'incident_evidence', fileName: 'riverside.jpg', mimeType: 'image/jpeg', bytes: Uint8List.fromList([2]));
    expect(q.uploadsForOwner(otherSchoolPrincipal, ownerType: 'principal_recorded_incident_case', ownerId: _caseId).single.fileName, 'riverside.jpg');
    expect(q.uploadsForOwner(principal, ownerType: 'principal_recorded_incident_case', ownerId: _caseId).single.fileName, 'brightgate.jpg');
  });
}
