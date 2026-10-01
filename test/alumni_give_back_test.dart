import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/auth/token_store.dart';
import 'package:schoolos_app/core/network/api_client.dart';
import 'package:schoolos_app/core/network/api_config.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/alumni/data/alumni_give_back_repository.dart';
import 'package:schoolos_app/features/alumni/data/alumni_server_api.dart';
import 'package:schoolos_app/features/alumni/domain/alumni_pledge_models.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';

const alumnus = SchoolMembership(id: 'm-alumnus', schoolId: 's', schoolName: 'School', role: SchoolRole.alumni);

const _pledge = AlumniPledge(
  id: 'pl-1',
  alumniMembershipId: 'm-alumnus',
  alumniName: 'Jane Doe',
  category: AlumniPledgeCategory.volunteering,
  description: 'I can help run the careers fair.',
  status: AlumniPledgeStatus.offered,
  schoolNote: '',
  createdAt: '2026-01-01T00:00:00Z',
);

/// A real `AlumniServerApi`, with the Give Back methods swapped for a fake answer instead of an
/// actual network call - the same "subclass and override the methods under test" shape
/// `alumni_events_test.dart` already uses.
class _FakeAlumniServerApi extends AlumniServerApi {
  _FakeAlumniServerApi({this.pledges, this.loadError, this.createError, this.withdrawError})
      : super(
          api: ApiClient(config: const ApiConfig('http://test'), tokens: MemoryTokenStore()),
          schoolSession: SchoolSessionController(store: FakeSessionStore()),
        );

  final List<AlumniPledge>? pledges;
  final Object? loadError;
  final Object? createError;
  final Object? withdrawError;
  AlumniPledgeCategory? lastCategory;
  String? lastDescription;
  String? lastWithdrawnId;

  @override
  Future<List<AlumniPledge>> loadMyPledges(SchoolMembership membership) async {
    final thrown = loadError;
    if (thrown != null) throw thrown;
    return pledges ?? const [];
  }

  @override
  Future<AlumniPledge> createPledge(
    SchoolMembership membership, {
    required AlumniPledgeCategory category,
    required String description,
  }) async {
    final thrown = createError;
    if (thrown != null) throw thrown;
    lastCategory = category;
    lastDescription = description;
    return AlumniPledge(
      id: 'pl-new',
      alumniMembershipId: membership.id,
      alumniName: 'Jane Doe',
      category: category,
      description: description,
      status: AlumniPledgeStatus.offered,
      schoolNote: '',
      createdAt: '2026-01-02T00:00:00Z',
    );
  }

  @override
  Future<AlumniPledge> withdrawPledge(SchoolMembership membership, String pledgeId) async {
    final thrown = withdrawError;
    if (thrown != null) throw thrown;
    lastWithdrawnId = pledgeId;
    return AlumniPledge(
      id: pledgeId,
      alumniMembershipId: membership.id,
      alumniName: 'Jane Doe',
      category: _pledge.category,
      description: _pledge.description,
      status: AlumniPledgeStatus.withdrawn,
      schoolNote: '',
      createdAt: _pledge.createdAt,
    );
  }
}

void main() {
  test('with no server, load() is an honest empty list, never fabricated', () async {
    final repository = AlumniGiveBackRepository(membership: alumnus, remote: null);
    expect(repository.hasServer, isFalse);
    expect(await repository.load(), isEmpty);
  });

  test('with a server, a real pledge round-trips', () async {
    final repository = AlumniGiveBackRepository(
      membership: alumnus,
      remote: _FakeAlumniServerApi(pledges: const [_pledge]),
    );
    final result = await repository.load();
    expect(result.single.alumniName, 'Jane Doe');
    expect(result.single.status, AlumniPledgeStatus.offered);
  });

  test('a load failure propagates so the page can show a retry, never a silent empty list', () async {
    final repository = AlumniGiveBackRepository(
      membership: alumnus,
      remote: _FakeAlumniServerApi(loadError: StateError('offline')),
    );
    expect(repository.load(), throwsStateError);
  });

  test('create() with no server throws rather than pretending to record a pledge', () async {
    final repository = AlumniGiveBackRepository(membership: alumnus, remote: null);
    expect(
      repository.create(category: AlumniPledgeCategory.mentoring, description: 'I can mentor Form 5 students.'),
      throwsStateError,
    );
  });

  test('create() really sends this membership\'s own category and description', () async {
    final api = _FakeAlumniServerApi();
    final repository = AlumniGiveBackRepository(membership: alumnus, remote: api);
    final created = await repository.create(
      category: AlumniPledgeCategory.supplies,
      description: 'I can donate textbooks.',
    );
    expect(api.lastCategory, AlumniPledgeCategory.supplies);
    expect(api.lastDescription, 'I can donate textbooks.');
    expect(created.status, AlumniPledgeStatus.offered);
  });

  test('create() refuses a description that is too short to mean anything', () async {
    final repository = AlumniGiveBackRepository(membership: alumnus, remote: _FakeAlumniServerApi());
    expect(
      repository.create(category: AlumniPledgeCategory.other, description: 'hi'),
      throwsArgumentError,
    );
  });

  test('a real create failure propagates rather than silently appearing to succeed', () async {
    final repository = AlumniGiveBackRepository(
      membership: alumnus,
      remote: _FakeAlumniServerApi(createError: StateError('rejected')),
    );
    expect(
      repository.create(category: AlumniPledgeCategory.other, description: 'A real description.'),
      throwsStateError,
    );
  });

  test('a real withdraw failure propagates rather than silently appearing to succeed', () async {
    final repository = AlumniGiveBackRepository(
      membership: alumnus,
      remote: _FakeAlumniServerApi(withdrawError: StateError('not found')),
    );
    expect(repository.withdraw('ghost'), throwsStateError);
  });

  test('withdraw() with no server throws rather than pretending to withdraw', () async {
    final repository = AlumniGiveBackRepository(membership: alumnus, remote: null);
    expect(repository.withdraw('pl-1'), throwsStateError);
  });

  test('withdraw() really withdraws this exact pledge', () async {
    final api = _FakeAlumniServerApi();
    final repository = AlumniGiveBackRepository(membership: alumnus, remote: api);
    final updated = await repository.withdraw('pl-1');
    expect(api.lastWithdrawnId, 'pl-1');
    expect(updated.status, AlumniPledgeStatus.withdrawn);
  });

  group('AlumniPledge.canWithdraw', () {
    test('true while offered or acknowledged, false once fulfilled or withdrawn', () {
      for (final status in [AlumniPledgeStatus.offered, AlumniPledgeStatus.acknowledged]) {
        expect(
          AlumniPledge.fromJson({..._jsonFor(_pledge), 'status': status.name}).canWithdraw,
          isTrue,
          reason: status.name,
        );
      }
      for (final status in [AlumniPledgeStatus.fulfilled, AlumniPledgeStatus.withdrawn]) {
        expect(
          AlumniPledge.fromJson({..._jsonFor(_pledge), 'status': status.name}).canWithdraw,
          isFalse,
          reason: status.name,
        );
      }
    });
  });
}

Map<String, Object?> _jsonFor(AlumniPledge pledge) => {
      'id': pledge.id,
      'alumniMembershipId': pledge.alumniMembershipId,
      'alumniName': pledge.alumniName,
      'category': pledge.category.name,
      'description': pledge.description,
      'status': pledge.status.name,
      'schoolNote': pledge.schoolNote,
      'createdAt': pledge.createdAt,
    };
