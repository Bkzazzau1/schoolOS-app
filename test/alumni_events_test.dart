import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/auth/token_store.dart';
import 'package:schoolos_app/core/network/api_client.dart';
import 'package:schoolos_app/core/network/api_config.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/alumni/data/alumni_events_repository.dart';
import 'package:schoolos_app/features/alumni/data/alumni_server_api.dart';
import 'package:schoolos_app/features/alumni/domain/alumni_event_models.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';

const alumnus = SchoolMembership(id: 'm-alumnus', schoolId: 's', schoolName: 'School', role: SchoolRole.alumni);

const _event = AlumniEvent(
  id: 'ev-1',
  title: 'Class of 2015 Reunion',
  date: '2026-12-12',
  timeText: '4:00 PM',
  venue: 'School Hall',
  note: 'Bring your family.',
  attendingCount: 3,
  myRsvp: null,
);

/// A real `AlumniServerApi`, with `loadEvents`/`rsvp` swapped for a fake answer instead of an
/// actual network call - the same "subclass and override the methods under test" shape
/// `alumni_directory_test.dart` already uses.
class _FakeAlumniServerApi extends AlumniServerApi {
  _FakeAlumniServerApi({this.events, this.loadError, this.rsvpError})
      : super(
          api: ApiClient(config: const ApiConfig('http://test'), tokens: MemoryTokenStore()),
          schoolSession: SchoolSessionController(store: FakeSessionStore()),
        );

  final List<AlumniEvent>? events;
  final Object? loadError;
  final Object? rsvpError;
  String? lastRsvpEventId;
  bool? lastRsvpAttending;

  @override
  Future<List<AlumniEvent>> loadEvents(SchoolMembership membership) async {
    final thrown = loadError;
    if (thrown != null) throw thrown;
    return events ?? const [];
  }

  @override
  Future<AlumniEvent> rsvp(SchoolMembership membership, String eventId, {required bool attending}) async {
    final thrown = rsvpError;
    if (thrown != null) throw thrown;
    lastRsvpEventId = eventId;
    lastRsvpAttending = attending;
    return AlumniEvent(
      id: _event.id,
      title: _event.title,
      date: _event.date,
      timeText: _event.timeText,
      venue: _event.venue,
      note: _event.note,
      attendingCount: attending ? _event.attendingCount + 1 : _event.attendingCount - 1,
      myRsvp: attending,
    );
  }
}

void main() {
  test('with no server, load() is an honest empty list, never fabricated', () async {
    final repository = AlumniEventsRepository(membership: alumnus, remote: null);
    expect(repository.hasServer, isFalse);
    expect(await repository.load(), isEmpty);
  });

  test('with a server, a real event with its real RSVP state round-trips', () async {
    final repository = AlumniEventsRepository(
      membership: alumnus,
      remote: _FakeAlumniServerApi(events: const [_event]),
    );
    final result = await repository.load();
    expect(result.single.title, 'Class of 2015 Reunion');
    expect(result.single.attendingCount, 3);
    expect(result.single.myRsvp, isNull);
  });

  test('a load failure propagates so the page can show a retry, never a silent empty list', () async {
    final repository = AlumniEventsRepository(
      membership: alumnus,
      remote: _FakeAlumniServerApi(loadError: StateError('offline')),
    );
    expect(repository.load(), throwsStateError);
  });

  test('rsvp() with no server throws rather than pretending to record a response', () async {
    final repository = AlumniEventsRepository(membership: alumnus, remote: null);
    expect(repository.rsvp('ev-1', attending: true), throwsStateError);
  });

  test('rsvp() really sends this membership\'s own answer and returns the real updated event', () async {
    final api = _FakeAlumniServerApi(events: const [_event]);
    final repository = AlumniEventsRepository(membership: alumnus, remote: api);
    final updated = await repository.rsvp('ev-1', attending: true);
    expect(api.lastRsvpEventId, 'ev-1');
    expect(api.lastRsvpAttending, isTrue);
    expect(updated.myRsvp, isTrue);
    expect(updated.attendingCount, 4);
  });

  test('a real rsvp failure propagates rather than silently appearing to succeed', () async {
    final repository = AlumniEventsRepository(
      membership: alumnus,
      remote: _FakeAlumniServerApi(rsvpError: StateError('not found')),
    );
    expect(repository.rsvp('ghost', attending: true), throwsStateError);
  });
}
