import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/auth/token_store.dart';
import 'package:schoolos_app/core/network/api_client.dart';
import 'package:schoolos_app/core/network/api_config.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/alumni/data/alumni_directory_repository.dart';
import 'package:schoolos_app/features/alumni/data/alumni_server_api.dart';
import 'package:schoolos_app/features/alumni/domain/alumni_directory_models.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';

const alumnus = SchoolMembership(id: 'm-alumnus', schoolId: 's', schoolName: 'School', role: SchoolRole.alumni);

const _entry = AlumniDirectoryEntry(
  membershipId: 'm-1',
  name: 'Jane Doe',
  graduationYear: 2015,
  graduationSet: 'Class of 2015',
  profession: 'Engineer',
  organisation: 'Acme Co',
  locationText: 'Lagos',
  bio: 'Hello.',
);

/// A real `AlumniServerApi`, with `loadDirectory` swapped for a fake answer instead of an actual
/// network call - `AlumniServerApi` is a concrete class, not an interface, so this is the same
/// "subclass and override the one method under test" shape used elsewhere in this app's tests.
class _FakeAlumniServerApi extends AlumniServerApi {
  _FakeAlumniServerApi({this.entries, this.error})
      : super(
          api: ApiClient(config: const ApiConfig('http://test'), tokens: MemoryTokenStore()),
          schoolSession: SchoolSessionController(store: FakeSessionStore()),
        );

  final List<AlumniDirectoryEntry>? entries;
  final Object? error;

  @override
  Future<List<AlumniDirectoryEntry>> loadDirectory(
    SchoolMembership membership, {
    String query = '',
    int? graduationYear,
  }) async {
    final thrown = error;
    if (thrown != null) throw thrown;
    return entries ?? const [];
  }
}

void main() {
  test('with no server, load() is an honest empty list, never fabricated', () async {
    final repository = AlumniDirectoryRepository(membership: alumnus, remote: null);
    expect(repository.hasServer, isFalse);
    expect(await repository.load(), isEmpty);
  });

  test('with a server, a real entry is returned as-is', () async {
    final repository = AlumniDirectoryRepository(
      membership: alumnus,
      remote: _FakeAlumniServerApi(entries: const [_entry]),
    );
    expect(repository.hasServer, isTrue);
    final result = await repository.load();
    expect(result.single.name, 'Jane Doe');
  });

  test('a load failure propagates so the page can show a retry, never a silent empty list', () async {
    final repository = AlumniDirectoryRepository(
      membership: alumnus,
      remote: _FakeAlumniServerApi(error: StateError('offline')),
    );
    expect(repository.load(), throwsStateError);
  });

  group('AlumniDirectoryEntry.matches', () {
    test('matches by name, profession or organisation, case-insensitively', () {
      expect(_entry.matches(''), isTrue);
      expect(_entry.matches('jane'), isTrue);
      expect(_entry.matches('ENGINEER'), isTrue);
      expect(_entry.matches('acme'), isTrue);
      expect(_entry.matches('doctor'), isFalse);
    });
  });
}
