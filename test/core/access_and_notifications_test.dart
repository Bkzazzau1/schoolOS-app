import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/access/access_controller.dart';
import 'package:schoolos_app/core/network/api_exceptions.dart';
import 'package:schoolos_app/core/notifications/notifications_controller.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'backend_test_support.dart';

Map<String, Object?> access(List<String> activities, {List<Map<String, Object?>> blocking = const []}) => {
      'membershipId': teacher.id,
      'role': 'teacher',
      'activities': activities,
      'blocking': blocking,
    };

Map<String, Object?> note(int id, {bool read = false, String kind = 'access_changed'}) => {
      'id': id,
      'kind': kind,
      'title': 'Title $id',
      'message': 'Message $id',
      'data': {'activities': ['teacher.cbt']},
      'createdAt': '2026-09-21T08:00:00Z',
      'read': read,
    };

// The same person's other role at the same school: it has its own access.
const sameSchoolOtherRole = SchoolMembership(
  id: '33333333-3333-3333-3333-333333333333',
  schoolId: '22222222-2222-2222-2222-222222222222',
  schoolName: 'BrightGate',
  role: SchoolRole.parent,
);

void main() {
  late MemorySyncStore store;
  setUp(() => store = MemorySyncStore());

  group('AccessController', () {
    AccessController controller(FakeServer server) => AccessController(api: apiFor(server), store: store);

    test('nothing is hidden until access is known', () {
      final c = controller(FakeServer((r) async => jsonResponse({})));
      expect(c.known, isFalse);
      expect(c.allows('owner.payroll'), isTrue);
    });

    test('asks for this membership and then allows only what the owner allows', () async {
      final server = FakeServer((r) async => jsonResponse(access(['teacher.dashboard', 'teacher.students'])));
      final c = controller(server);
      await c.refresh(teacher);
      final query = server.requests.single.url.queryParameters;
      expect(server.requests.single.url.path, endsWith('/schools/${teacher.schoolId}/access/me/'));
      expect(query, {'membership': teacher.id});
      expect(c.known, isTrue);
      expect(c.allows('teacher.students'), isTrue);
      expect(c.allows('teacher.cbt'), isFalse);
      expect(c.allows('owner.payroll'), isFalse);
    });

    test('is kept on the device, so the menus are right offline and after a restart', () async {
      await (controller(FakeServer((r) async => jsonResponse(access(['teacher.dashboard']))))).refresh(teacher);
      final restarted = controller(FakeServer((r) async => throw const ApiOfflineException()));
      expect(restarted.known, isFalse);
      await restarted.restore(teacher);
      expect(restarted.allows('teacher.dashboard'), isTrue);
      expect(restarted.allows('teacher.students'), isFalse);
    });

    test('another membership never sees this one\'s access', () async {
      await controller(FakeServer((r) async => jsonResponse(access(['teacher.dashboard'])))).refresh(teacher);
      final other = controller(FakeServer((r) async => jsonResponse({})));
      await other.restore(sameSchoolOtherRole);
      expect(other.known, isFalse);
    });

    test('a change is announced, an unchanged answer is not', () async {
      final answers = [
        access(['teacher.dashboard', 'teacher.cbt']),
        access(['teacher.dashboard', 'teacher.cbt']),
        access(['teacher.dashboard']),
      ];
      final c = controller(FakeServer((r) async => jsonResponse(answers.removeAt(0))));
      var heard = 0;
      c.addListener(() => heard++);
      await c.refresh(teacher);
      expect(heard, 1);
      await c.refresh(teacher);
      expect(heard, 1);                          // same access: nobody needs to redraw
      await c.refresh(teacher);
      expect(heard, 2);
      expect(c.allows('teacher.cbt'), isFalse);  // taken away
    });

    test('a waiting block is reported and the person keeps the screen until it is settled', () async {
      final deadline = DateTime.utc(2026, 9, 23);
      final c = controller(FakeServer((r) async => jsonResponse(access(['teacher.cbt'], blocking: [
            {'activity': 'teacher.cbt', 'finalizeAt': deadline.toIso8601String()},
          ]))));
      await c.refresh(teacher);
      expect(c.allows('teacher.cbt'), isTrue);
      expect(c.blocking.single.activity, 'teacher.cbt');
      expect(c.blocking.single.finalizeAt, deadline);
    });

    test('acknowledging tells the server which activities, and takes its answer', () async {
      final server = FakeServer((r) async {
        if (r.url.path.endsWith('/acknowledge/')) return jsonResponse(access(['teacher.dashboard']));
        return jsonResponse(access(['teacher.dashboard', 'teacher.cbt'], blocking: [
          {'activity': 'teacher.cbt', 'finalizeAt': '2026-09-23T00:00:00Z'},
        ]));
      });
      final c = controller(server);
      await c.refresh(teacher);
      await c.acknowledge(teacher, c.blocking.map((b) => b.activity));
      expect(body(server.to('/acknowledge/').single), {'activities': ['teacher.cbt']});
      expect(c.allows('teacher.cbt'), isFalse);
      expect(c.blocking, isEmpty);
    });

    test('acknowledging nothing sends nothing', () async {
      final server = FakeServer((r) async => jsonResponse({}));
      await controller(server).acknowledge(teacher, const []);
      expect(server.requests, isEmpty);
    });

    test('offline or refused leaves the last known access alone', () async {
      final c = controller(FakeServer((r) async => jsonResponse(access(['teacher.dashboard']))));
      await c.refresh(teacher);
      final failing = AccessController(api: apiFor(FakeServer((r) async => throw const ApiOfflineException())), store: store);
      await failing.restore(teacher);
      await expectLater(failing.refresh(teacher), throwsA(isA<ApiOfflineException>()));
      expect(failing.allows('teacher.dashboard'), isTrue);
      expect(failing.allows('teacher.students'), isFalse);
    });

    test('signing out forgets it', () async {
      final c = controller(FakeServer((r) async => jsonResponse(access(['teacher.dashboard']))));
      await c.refresh(teacher);
      c.clear();
      expect(c.known, isFalse);
      expect(c.allows('anything'), isTrue);
    });
  });

  group('NotificationsController', () {
    NotificationsController controller(FakeServer server) => NotificationsController(api: apiFor(server), store: store);

    Object inbox({int unread = 2, List<Map<String, Object?>>? notes}) =>
        {'unread': unread, 'notifications': notes ?? [note(2), note(1, read: true)]};

    test('reads the inbox and the unread count', () async {
      final server = FakeServer((r) async => jsonResponse(inbox()));
      final c = controller(server);
      await c.refresh(teacher);
      expect(server.requests.single.url.queryParameters, {'membership': teacher.id, 'limit': '100'});
      expect((c.unread, c.items.length), (2, 2));
      expect((c.items.first.title, c.items.first.kind, c.items.first.read), ('Title 2', 'access_changed', false));
      expect(c.items.first.data['activities'], ['teacher.cbt']);
    });

    test('the last inbox is there offline and after a restart', () async {
      await controller(FakeServer((r) async => jsonResponse(inbox()))).refresh(teacher);
      final restarted = controller(FakeServer((r) async => throw const ApiOfflineException()));
      await restarted.restore(teacher);
      expect((restarted.unread, restarted.items.length), (2, 2));
    });

    test('reading a message updates it at once and tells the server', () async {
      final server = FakeServer((r) async => r.method == 'GET' ? jsonResponse(inbox()) : jsonResponse({'ok': true}));
      final c = controller(server);
      await c.refresh(teacher);
      await c.markRead(teacher, 2);
      expect((c.unread, c.items.first.read), (1, true));
      expect(server.to('/notifications/2/read/').length, 1);
      await c.markRead(teacher, 2);                 // already read: nothing more to send
      expect(server.to('/notifications/2/read/').length, 1);
      await c.markRead(teacher, 99);                // not in the inbox: ignored
      expect(server.to('/notifications/99/read/'), isEmpty);
    });

    test('reading everything clears the count', () async {
      final server = FakeServer((r) async => r.method == 'GET' ? jsonResponse(inbox()) : jsonResponse({'marked': 2}));
      final c = controller(server);
      await c.refresh(teacher);
      await c.markAllRead(teacher);
      expect((c.unread, c.items.every((n) => n.read)), (0, true));
      expect(server.to('/read-all/').length, 1);
      await c.markAllRead(teacher);
      expect(server.to('/read-all/').length, 1);
    });

    test('a message read while offline is remembered and told to the server later', () async {
      var online = false;
      final server = FakeServer((r) async {
        if (r.method == 'GET') return jsonResponse(inbox());
        if (!online) throw const ApiOfflineException();
        return jsonResponse({'ok': true});
      });
      final c = controller(server);
      await c.refresh(teacher);
      await c.markRead(teacher, 2);
      expect(c.items.first.read, isTrue);            // the person sees it read straight away
      expect(server.to('/notifications/2/read/').length, 1);

      online = true;
      await c.refresh(teacher);
      expect(server.to('/notifications/2/read/').length, 2);   // told now
    });

    test('a message the server no longer knows does not block the inbox', () async {
      var reject = true;
      final server = FakeServer((r) async {
        if (r.method == 'GET') return jsonResponse(inbox());
        if (reject) return jsonResponse({'code': 'not_found', 'message': 'That message was not found.'}, 404);
        return jsonResponse({'ok': true});
      });
      final c = controller(server);
      await c.refresh(teacher);
      await c.markRead(teacher, 2);                  // 404: remembered as "to tell", but the server refuses it
      reject = true;
      await c.refresh(teacher);                      // must still complete
      expect(c.items.length, 2);
    });

    test('signing out empties it', () async {
      final c = controller(FakeServer((r) async => jsonResponse(inbox())));
      await c.refresh(teacher);
      c.clear();
      expect(c.unread, 0);
      expect(c.items, isEmpty);
    });
  });
}
