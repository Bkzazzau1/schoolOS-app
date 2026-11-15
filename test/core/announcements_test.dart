import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/announcements/announcements_controller.dart';
import 'package:schoolos_app/core/network/api_exceptions.dart';

import 'backend_test_support.dart';

Map<String, Object?> announcement(String id, {String title = 'Title', String body = 'Body'}) => {
      'id': id, 'title': title, 'body': body, 'startsAt': '2026-09-21T08:00:00Z',
    };

void main() {
  late MemorySyncStore store;
  setUp(() => store = MemorySyncStore());

  AnnouncementsController controller(FakeServer server) => AnnouncementsController(api: apiFor(server), store: store);

  test('reads what is currently active', () async {
    final server = FakeServer(
      (r) async => jsonResponse({'announcements': [announcement('a1', title: 'Sale')]}),
    );
    final c = controller(server);
    await c.refresh(teacher);
    expect(server.requests.single.url.path, endsWith('/schools/${teacher.schoolId}/announcements/active/'));
    expect(c.toShow.length, 1);
    expect(c.toShow.single.title, 'Sale');
  });

  test('is kept on the device, so it is there offline and after a restart', () async {
    await controller(FakeServer((r) async => jsonResponse({'announcements': [announcement('a1')]}))).refresh(teacher);
    final restarted = controller(FakeServer((r) async => throw const ApiOfflineException()));
    await restarted.restore(teacher);
    expect(restarted.toShow.length, 1);
  });

  test('dismissing one removes it from toShow and that is remembered after a restart', () async {
    final c = controller(FakeServer((r) async => jsonResponse({'announcements': [announcement('a1')]})));
    await c.refresh(teacher);
    await c.dismiss(teacher, 'a1');
    expect(c.toShow, isEmpty);

    final restarted = controller(FakeServer((r) async => throw const ApiOfflineException()));
    await restarted.restore(teacher);
    expect(restarted.toShow, isEmpty);
  });

  test('dismissing twice does nothing the second time', () async {
    final c = controller(FakeServer((r) async => jsonResponse({'announcements': [announcement('a1')]})));
    await c.refresh(teacher);
    await c.dismiss(teacher, 'a1');
    await c.dismiss(teacher, 'a1');
    expect(c.toShow, isEmpty);
  });

  test('a dismissed id for an announcement that has since ended is forgotten, not kept forever', () async {
    final c = controller(FakeServer((r) async => jsonResponse({'announcements': [announcement('a1')]})));
    await c.refresh(teacher);
    await c.dismiss(teacher, 'a1');

    // The next refresh finds a1 has ended (no longer in the active list) and a brand
    // new a2 has started.
    final again = AnnouncementsController(api: apiFor(FakeServer((r) async => jsonResponse({'announcements': [announcement('a2')]}))), store: store);
    await again.restore(teacher);
    await again.refresh(teacher);
    expect(again.toShow.map((a) => a.id), ['a2']); // a1's dismissal never blocks a2
  });

  test('a platform-wide announcement with no title/body still parses safely', () async {
    final c = controller(FakeServer((r) async => jsonResponse({'announcements': [{'id': 'a1', 'startsAt': '2026-09-21T08:00:00Z'}]})));
    await c.refresh(teacher);
    expect(c.toShow.single.title, '');
    expect(c.toShow.single.body, '');
  });

  test('signing out empties it', () async {
    final c = controller(FakeServer((r) async => jsonResponse({'announcements': [announcement('a1')]})));
    await c.refresh(teacher);
    c.clear();
    expect(c.toShow, isEmpty);
  });

  test('offline leaves the last known list alone', () async {
    final c = controller(FakeServer((r) async => jsonResponse({'announcements': [announcement('a1')]})));
    await c.refresh(teacher);
    final failing = AnnouncementsController(api: apiFor(FakeServer((r) async => throw const ApiOfflineException())), store: store);
    await failing.restore(teacher);
    await expectLater(failing.refresh(teacher), throwsA(isA<ApiOfflineException>()));
    expect(failing.toShow.length, 1);
  });
}
