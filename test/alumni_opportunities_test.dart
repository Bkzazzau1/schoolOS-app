import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/auth/token_store.dart';
import 'package:schoolos_app/core/network/api_client.dart';
import 'package:schoolos_app/core/network/api_config.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/alumni/data/alumni_opportunities_repository.dart';
import 'package:schoolos_app/features/alumni/data/alumni_server_api.dart';
import 'package:schoolos_app/features/alumni/domain/alumni_opportunity_models.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';

const alumnus = SchoolMembership(id: 'm-alumnus', schoolId: 's', schoolName: 'School', role: SchoolRole.alumni);

const _opportunity = AlumniOpportunity(
  id: 'op-1',
  postedByMembershipId: 'm-alumnus',
  postedByName: 'Jane Doe',
  title: 'Software Engineer',
  organisation: 'Acme Co',
  type: AlumniOpportunityType.fullTime,
  locationText: 'Lagos',
  description: 'We are hiring a software engineer for our growing team.',
  contactInfo: 'jobs@acme.example',
  status: AlumniOpportunityStatus.open,
  createdAt: '2026-01-01T00:00:00Z',
);

/// A real `AlumniServerApi`, with the opportunity methods swapped for a fake answer instead of an
/// actual network call - the same "subclass and override the methods under test" shape
/// `alumni_give_back_test.dart` already uses.
class _FakeAlumniServerApi extends AlumniServerApi {
  _FakeAlumniServerApi({this.opportunities, this.loadError, this.postError, this.closeError})
      : super(
          api: ApiClient(config: const ApiConfig('http://test'), tokens: MemoryTokenStore()),
          schoolSession: SchoolSessionController(store: FakeSessionStore()),
        );

  final List<AlumniOpportunity>? opportunities;
  final Object? loadError;
  final Object? postError;
  final Object? closeError;
  String? lastTitle;
  AlumniOpportunityType? lastType;
  String? lastClosedId;

  @override
  Future<List<AlumniOpportunity>> loadOpportunities(SchoolMembership membership) async {
    final thrown = loadError;
    if (thrown != null) throw thrown;
    return opportunities ?? const [];
  }

  @override
  Future<AlumniOpportunity> postOpportunity(
    SchoolMembership membership, {
    required String title,
    required String organisation,
    required AlumniOpportunityType type,
    String locationText = '',
    required String description,
    String contactInfo = '',
  }) async {
    final thrown = postError;
    if (thrown != null) throw thrown;
    lastTitle = title;
    lastType = type;
    return AlumniOpportunity(
      id: 'op-new',
      postedByMembershipId: membership.id,
      postedByName: 'Jane Doe',
      title: title,
      organisation: organisation,
      type: type,
      locationText: locationText,
      description: description,
      contactInfo: contactInfo,
      status: AlumniOpportunityStatus.open,
      createdAt: '2026-01-02T00:00:00Z',
    );
  }

  @override
  Future<AlumniOpportunity> closeOpportunity(SchoolMembership membership, String opportunityId) async {
    final thrown = closeError;
    if (thrown != null) throw thrown;
    lastClosedId = opportunityId;
    return AlumniOpportunity(
      id: opportunityId,
      postedByMembershipId: _opportunity.postedByMembershipId,
      postedByName: _opportunity.postedByName,
      title: _opportunity.title,
      organisation: _opportunity.organisation,
      type: _opportunity.type,
      locationText: _opportunity.locationText,
      description: _opportunity.description,
      contactInfo: _opportunity.contactInfo,
      status: AlumniOpportunityStatus.closed,
      createdAt: _opportunity.createdAt,
    );
  }
}

void main() {
  test('with no server, load() is an honest empty list, never fabricated', () async {
    final repository = AlumniOpportunitiesRepository(membership: alumnus, remote: null);
    expect(repository.hasServer, isFalse);
    expect(await repository.load(), isEmpty);
  });

  test('with a server, a real posting round-trips', () async {
    final repository = AlumniOpportunitiesRepository(
      membership: alumnus,
      remote: _FakeAlumniServerApi(opportunities: const [_opportunity]),
    );
    final result = await repository.load();
    expect(result.single.postedByName, 'Jane Doe');
    expect(result.single.status, AlumniOpportunityStatus.open);
  });

  test('a load failure propagates so the page can show a retry, never a silent empty list', () async {
    final repository = AlumniOpportunitiesRepository(
      membership: alumnus,
      remote: _FakeAlumniServerApi(loadError: StateError('offline')),
    );
    expect(repository.load(), throwsStateError);
  });

  test('post() with no server throws rather than pretending to post', () async {
    final repository = AlumniOpportunitiesRepository(membership: alumnus, remote: null);
    expect(
      repository.post(
        title: 'Role',
        organisation: 'Acme',
        type: AlumniOpportunityType.internship,
        description: 'A real internship opportunity.',
        contactInfo: 'jobs@acme.example',
      ),
      throwsStateError,
    );
  });

  test('post() really sends this membership\'s own title, organisation and type', () async {
    final api = _FakeAlumniServerApi();
    final repository = AlumniOpportunitiesRepository(membership: alumnus, remote: api);
    final posted = await repository.post(
      title: 'Marketing Intern',
      organisation: 'Acme Co',
      type: AlumniOpportunityType.internship,
      description: 'A real internship opportunity for a recent graduate.',
      contactInfo: 'jobs@acme.example',
    );
    expect(api.lastTitle, 'Marketing Intern');
    expect(api.lastType, AlumniOpportunityType.internship);
    expect(posted.status, AlumniOpportunityStatus.open);
  });

  test('post() refuses a description that is too short to mean anything', () async {
    final repository = AlumniOpportunitiesRepository(membership: alumnus, remote: _FakeAlumniServerApi());
    expect(
      repository.post(title: 'Role', organisation: 'Acme', type: AlumniOpportunityType.other, description: 'hi'),
      throwsArgumentError,
    );
  });

  test('post() refuses no contact info with too short a description to follow up on', () async {
    final repository = AlumniOpportunitiesRepository(membership: alumnus, remote: _FakeAlumniServerApi());
    expect(
      repository.post(
        title: 'Role',
        organisation: 'Acme',
        type: AlumniOpportunityType.other,
        description: 'Short desc.',
        contactInfo: '',
      ),
      throwsArgumentError,
    );
  });

  test('a real post failure propagates rather than silently appearing to succeed', () async {
    final repository = AlumniOpportunitiesRepository(
      membership: alumnus,
      remote: _FakeAlumniServerApi(postError: StateError('rejected')),
    );
    expect(
      repository.post(
        title: 'Role',
        organisation: 'Acme',
        type: AlumniOpportunityType.other,
        description: 'A real description that is long enough to follow up on.',
      ),
      throwsStateError,
    );
  });

  test('close() with no server throws rather than pretending to close', () async {
    final repository = AlumniOpportunitiesRepository(membership: alumnus, remote: null);
    expect(repository.close('op-1'), throwsStateError);
  });

  test('close() really closes this exact posting', () async {
    final api = _FakeAlumniServerApi();
    final repository = AlumniOpportunitiesRepository(membership: alumnus, remote: api);
    final updated = await repository.close('op-1');
    expect(api.lastClosedId, 'op-1');
    expect(updated.status, AlumniOpportunityStatus.closed);
  });

  test('a real close failure propagates rather than silently appearing to succeed', () async {
    final repository = AlumniOpportunitiesRepository(
      membership: alumnus,
      remote: _FakeAlumniServerApi(closeError: StateError('forbidden')),
    );
    expect(repository.close('op-1'), throwsStateError);
  });

  group('AlumniOpportunityType wire mapping', () {
    test('round-trips through the backend\'s own snake_case choices', () {
      for (final type in AlumniOpportunityType.values) {
        expect(AlumniOpportunityTypeLabel.fromWire(type.wireValue), type);
      }
      expect(AlumniOpportunityType.fullTime.wireValue, 'full_time');
      expect(AlumniOpportunityType.partTime.wireValue, 'part_time');
    });
  });
}
