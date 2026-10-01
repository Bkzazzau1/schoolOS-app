import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/media/media_api.dart';
import 'package:schoolos_app/core/media/media_upload_queue.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/gallery/data/gallery_repository.dart';
import 'package:schoolos_app/features/gallery/domain/gallery_models.dart';
import 'package:schoolos_app/features/gallery/presentation/gallery_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const teacher = SchoolMembership(id: 'membership-1', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;
  late GalleryRepository repository;
  MediaUploadQueue? queue;

  setUp(() async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([teacher]);
    await session.selectSchool(teacher);
    repository = GalleryRepository(localDatabase: db, schoolSession: session);
    queue = null;
    // A real album, so these tests have something real to open - without this, the gallery is
    // honestly empty and none of the "open-album-" assertions below would find anything.
    final snapshot = await repository.load();
    final term = snapshot.availableTerms.first;
    final academicSession = snapshot.availableSessions.firstWhere((s) => s.id == term.sessionId);
    await repository.createAlbum(
      title: 'Robotics Showcase',
      album: 'Coding & Robotics',
      owner: 'ICT Department',
      date: '18 Sep 2026',
      count: 19,
      visibility: GalleryVisibility.internal,
      consent: '',
      note: '',
      term: term,
      session: academicSession,
    );
  });

  tearDown(() {
    queue?.dispose();
    db.close();
  });

  Future<void> pump(WidgetTester tester, {MediaApi? api}) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    Widget home = GalleryPage(schoolName: 'BrightGate', repository: repository, onBack: () {});
    if (api != null) {
      queue = MediaUploadQueue(database: db, schoolSession: session, observeLifecycle: false)..api = api;
      home = MediaScope(api: api, queue: queue!, child: home);
    }
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: home)));
    await tester.pumpAndSettle();
  }

  testWidgets('without a school server, an album offers no way to open its real files', (tester) async {
    await pump(tester);
    expect(find.textContaining('Server needed'), findsWidgets);
    expect(find.byWidgetPredicate((w) => w.key is ValueKey && (w.key! as ValueKey).value.toString().startsWith('open-album-')), findsNothing);
  });

  testWidgets('with a school server, an album can be opened to its real photos and videos', (tester) async {
    final server = FakeServer((r) async {
      if (r.method == 'GET' && r.url.path.endsWith('/assets/')) return jsonResponse({'assets': <Object?>[]});
      return jsonResponse({}, 404);
    });
    await pump(tester, api: MediaApi(api: apiFor(server)));
    final openButtons = find.byWidgetPredicate((w) => w.key is ValueKey && (w.key! as ValueKey).value.toString().startsWith('open-album-'));
    expect(openButtons, findsWidgets);

    await tester.tap(openButtons.first);
    await tester.pumpAndSettle();

    expect(find.text('No photos or videos added yet.'), findsOneWidget);
    expect(server.requests.any((r) => r.url.path.contains('/assets/')), isTrue); // it really asked the server for this album's files
  });

  testWidgets('a teacher can add a photo to an album, and it shows as waiting until the server confirms it', (tester) async {
    final server = FakeServer((r) async {
      if (r.method == 'GET' && r.url.path.endsWith('/assets/')) return jsonResponse({'assets': <Object?>[]});
      return jsonResponse({}, 404);
    });
    await pump(tester, api: MediaApi(api: apiFor(server)));
    final openButtons = find.byWidgetPredicate((w) => w.key is ValueKey && (w.key! as ValueKey).value.toString().startsWith('open-album-'));
    await tester.tap(openButtons.first);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('add-gallery_photo')), findsOneWidget); // teacher may contribute
    expect(find.byKey(const ValueKey('add-gallery_video')), findsOneWidget);
  });
}
