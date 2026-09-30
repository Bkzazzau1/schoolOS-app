import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/appearance/school_appearance_controller.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/media/media_api.dart';
import 'package:schoolos_app/core/media/media_local_files.dart';
import 'package:schoolos_app/core/media/media_queue_models.dart';
import 'package:schoolos_app/core/media/media_upload_queue.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/proprietor/presentation/proprietor_appearance_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const owner = SchoolMembership(id: 'm-owner', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.proprietor);

/// A real picture: a coloured rectangle, as PNG bytes - the same shape test/school_appearance_test.dart's own
/// picture() helper uses.
Future<Uint8List> picture(int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), ui.Paint()..color = const Color(0xFF2255AA));
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  late LocalDatabase db;
  late Directory tempRoot;
  late SchoolSessionController session;
  late SchoolAppearanceController controller;
  MediaUploadQueue? queue;

  Future<void> setUpSchool() async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    tempRoot = Directory.systemTemp.createTempSync('school_logo_media_test_');
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([owner]);
    await session.selectSchool(owner);
    controller = SchoolAppearanceController(localDatabase: db, schoolSession: session);
    await controller.initialize();
    queue = null;
  }

  tearDown(() {
    queue?.dispose();
    controller.dispose();
    db.close();
    tempRoot.deleteSync(recursive: true);
  });

  Widget pageFor({MediaApi? api}) {
    Widget home = MaterialApp(
      home: Scaffold(
        body: ProprietorAppearancePage(
          schoolName: 'BrightGate',
          controller: controller,
          onDashboard: () {},
          onAppearanceChanged: () {},
          pickLogo: () async => picture(64, 64),
        ),
      ),
    );
    if (api != null) {
      final q = MediaUploadQueue(database: db, schoolSession: session, files: MediaLocalFiles(rootDirectory: () async => tempRoot), observeLifecycle: false)..api = api;
      queue = q;
      home = MediaScope(api: api, queue: q, child: home);
    }
    return home;
  }

  /// Lets real work (the picture codec, the database, and here also a real file write) finish while the widgets
  /// keep being redrawn - the same shape test/school_appearance_test.dart's own settle() helper uses.
  Future<void> settle(WidgetTester tester, [int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  FakeServer serverWithAssets() => FakeServer((r) async {
        if (r.method == 'GET' && r.url.path.endsWith('/assets/')) return jsonResponse({'assets': const []});
        return jsonResponse({}, 404);
      });

  /// Choosing a logo now chains a second real write (the durable copy) after the page's own already-real
  /// pick/shrink/apply chain - settle()'s fixed rounds, proven enough for that chain alone, are not always
  /// enough once this is stacked on top. Polling for the queue to actually gain the entry is exact instead of
  /// a guess at how many extra rounds would be enough.
  Future<void> waitForQueued(WidgetTester tester) async {
    await tester.runAsync(() async {
      while (queue!.uploadsForOwner(owner, ownerType: 'school_appearance', ownerId: 'theme').isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();
  }

  testWidgets('without a school server, choosing a logo still saves locally exactly as before', (tester) async {
    await tester.runAsync(setUpSchool);
    await tester.pumpWidget(pageFor()); // no MediaScope: demo mode, same as every other real attachment
    await settle(tester);
    // Picking and shrinking a logo does real dart:ui image encoding - genuine async work the widget-test clock
    // never drives on its own; tester.runAsync() lets it actually run against the real event loop, the same
    // idiom core/media_attachments_panel_test.dart already uses for Gallery's own picker.
    await tester.runAsync(() => tester.tap(find.byKey(const ValueKey('choose-logo'))));
    await settle(tester);
    expect(controller.logo, isNotNull); // the base64 path is untouched by any of this
    expect(tester.takeException(), isNull);
  });

  testWidgets('with a school server, choosing a logo also keeps a real durable copy in the media queue', (tester) async {
    await tester.runAsync(setUpSchool);
    await tester.pumpWidget(pageFor(api: MediaApi(api: apiFor(serverWithAssets()))));
    await settle(tester);
    await tester.runAsync(() => tester.tap(find.byKey(const ValueKey('choose-logo'))));
    await waitForQueued(tester);

    expect(controller.logo, isNotNull); // still saved locally, exactly as before
    final queued = queue!.uploadsForOwner(owner, ownerType: 'school_appearance', ownerId: 'theme');
    expect(queued, hasLength(1));
    expect(queued.single.category, 'school_logo');
    expect(queued.single.mimeType, 'image/png');
  });

  testWidgets('removing a logo does not touch the real media queue', (tester) async {
    await tester.runAsync(setUpSchool);
    await tester.pumpWidget(pageFor(api: MediaApi(api: apiFor(serverWithAssets()))));
    await settle(tester);
    await tester.runAsync(() => tester.tap(find.byKey(const ValueKey('choose-logo'))));
    await waitForQueued(tester);
    expect(queue!.uploadsForOwner(owner, ownerType: 'school_appearance', ownerId: 'theme'), hasLength(1));

    await tester.tap(find.byKey(const ValueKey('remove-logo'))); // removing does no real I/O - a bare tap is fine
    await settle(tester);
    expect(controller.logo, isNull); // removed locally
    // Removing is a base64-only action today - the durable copy from the earlier choice is left exactly as it
    // was (nothing is retired automatically on the phone's behalf).
    expect(queue!.uploadsForOwner(owner, ownerType: 'school_appearance', ownerId: 'theme'), hasLength(1));
  });

  testWidgets('offline (no network), the logo still saves locally and the queued copy stays honestly local', (tester) async {
    await tester.runAsync(setUpSchool);
    final server = FakeServer((r) async => throw Exception('offline'));
    await tester.pumpWidget(pageFor(api: MediaApi(api: apiFor(server))));
    await settle(tester);
    await tester.runAsync(() => tester.tap(find.byKey(const ValueKey('choose-logo'))));
    await waitForQueued(tester);

    expect(controller.logo, isNotNull); // never blocked by the network
    final queued = queue!.uploadsForOwner(owner, ownerType: 'school_appearance', ownerId: 'theme');
    expect(queued, hasLength(1));
    expect(queued.single.state, isNot(MediaUploadState.uploaded)); // never shown as uploaded before the server says so
  });
}
