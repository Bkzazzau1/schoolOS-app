import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/auth/token_store.dart';
import 'package:schoolos_app/core/network/api_client.dart';
import 'package:schoolos_app/core/network/api_config.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/alumni/data/alumni_mentorship_repository.dart';
import 'package:schoolos_app/features/alumni/data/alumni_server_api.dart';
import 'package:schoolos_app/features/alumni/domain/alumni_mentorship_models.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';

const alumnus = SchoolMembership(id: 'm-alumnus', schoolId: 's', schoolName: 'School', role: SchoolRole.alumni);

const _mentor = AlumniMentorProfile(
  membershipId: 'm-mentor',
  name: 'Jane Doe',
  expertise: 'Software Engineering',
  bio: 'Happy to help with career advice.',
  isActive: true,
);

const _pendingRequest = AlumniMentorshipRequest(
  id: 'req-1',
  mentorMembershipId: 'm-mentor',
  mentorName: 'Jane Doe',
  mentorEmail: null,
  menteeMembershipId: 'm-alumnus',
  menteeName: 'John Smith',
  menteeEmail: null,
  message: 'Could you help me?',
  status: AlumniMentorshipRequestStatus.pending,
  createdAt: '2026-01-01T00:00:00Z',
);

/// A real `AlumniServerApi`, with the Mentorship methods swapped for a fake answer instead of an
/// actual network call - the same "subclass and override the methods under test" shape
/// `alumni_opportunities_test.dart` already uses.
class _FakeAlumniServerApi extends AlumniServerApi {
  _FakeAlumniServerApi({
    this.mentors,
    this.myMentorProfile,
    this.requests,
    this.loadError,
    this.saveError,
    this.requestError,
    this.respondError,
    this.withdrawError,
  }) : super(
          api: ApiClient(config: const ApiConfig('http://test'), tokens: MemoryTokenStore()),
          schoolSession: SchoolSessionController(store: FakeSessionStore()),
        );

  final List<AlumniMentorProfile>? mentors;
  final AlumniMentorProfile? myMentorProfile;
  final List<AlumniMentorshipRequest>? requests;
  final Object? loadError;
  final Object? saveError;
  final Object? requestError;
  final Object? respondError;
  final Object? withdrawError;
  String? lastExpertise;
  String? lastMentorRequested;
  bool? lastAccept;
  String? lastWithdrawnId;

  @override
  Future<List<AlumniMentorProfile>> loadMentors(SchoolMembership membership) async {
    final thrown = loadError;
    if (thrown != null) throw thrown;
    return mentors ?? const [];
  }

  @override
  Future<AlumniMentorProfile?> loadMyMentorProfile(SchoolMembership membership) async {
    final thrown = loadError;
    if (thrown != null) throw thrown;
    return myMentorProfile;
  }

  @override
  Future<List<AlumniMentorshipRequest>> loadMyMentorshipRequests(SchoolMembership membership) async {
    final thrown = loadError;
    if (thrown != null) throw thrown;
    return requests ?? const [];
  }

  @override
  Future<AlumniMentorProfile> saveMyMentorProfile(
    SchoolMembership membership, {
    required String expertise,
    required String bio,
    bool isActive = true,
  }) async {
    final thrown = saveError;
    if (thrown != null) throw thrown;
    lastExpertise = expertise;
    return AlumniMentorProfile(membershipId: membership.id, name: 'Jane Doe', expertise: expertise, bio: bio, isActive: isActive);
  }

  @override
  Future<AlumniMentorshipRequest> requestMentor(
    SchoolMembership membership, {
    required String mentorMembershipId,
    String message = '',
  }) async {
    final thrown = requestError;
    if (thrown != null) throw thrown;
    lastMentorRequested = mentorMembershipId;
    return AlumniMentorshipRequest(
      id: 'req-new',
      mentorMembershipId: mentorMembershipId,
      mentorName: 'Jane Doe',
      mentorEmail: null,
      menteeMembershipId: membership.id,
      menteeName: 'John Smith',
      menteeEmail: null,
      message: message,
      status: AlumniMentorshipRequestStatus.pending,
      createdAt: '2026-01-02T00:00:00Z',
    );
  }

  @override
  Future<AlumniMentorshipRequest> respondToMentorshipRequest(
    SchoolMembership membership,
    String requestId, {
    required bool accept,
  }) async {
    final thrown = respondError;
    if (thrown != null) throw thrown;
    lastAccept = accept;
    return AlumniMentorshipRequest(
      id: requestId,
      mentorMembershipId: _pendingRequest.mentorMembershipId,
      mentorName: _pendingRequest.mentorName,
      mentorEmail: accept ? 'jane@example.com' : null,
      menteeMembershipId: _pendingRequest.menteeMembershipId,
      menteeName: _pendingRequest.menteeName,
      menteeEmail: accept ? 'john@example.com' : null,
      message: _pendingRequest.message,
      status: accept ? AlumniMentorshipRequestStatus.accepted : AlumniMentorshipRequestStatus.declined,
      createdAt: _pendingRequest.createdAt,
    );
  }

  @override
  Future<AlumniMentorshipRequest> withdrawMentorshipRequest(SchoolMembership membership, String requestId) async {
    final thrown = withdrawError;
    if (thrown != null) throw thrown;
    lastWithdrawnId = requestId;
    return AlumniMentorshipRequest(
      id: requestId,
      mentorMembershipId: _pendingRequest.mentorMembershipId,
      mentorName: _pendingRequest.mentorName,
      mentorEmail: null,
      menteeMembershipId: _pendingRequest.menteeMembershipId,
      menteeName: _pendingRequest.menteeName,
      menteeEmail: null,
      message: _pendingRequest.message,
      status: AlumniMentorshipRequestStatus.withdrawn,
      createdAt: _pendingRequest.createdAt,
    );
  }
}

void main() {
  test('with no server, load() is an honest empty snapshot, never fabricated', () async {
    final repository = AlumniMentorshipRepository(membership: alumnus, remote: null);
    expect(repository.hasServer, isFalse);
    final snapshot = await repository.load();
    expect(snapshot.mentors, isEmpty);
    expect(snapshot.myMentorProfile, isNull);
    expect(snapshot.requests, isEmpty);
  });

  test('with a server, a real mentor and own profile round-trip', () async {
    final repository = AlumniMentorshipRepository(
      membership: alumnus,
      remote: _FakeAlumniServerApi(mentors: const [_mentor], myMentorProfile: _mentor),
    );
    final snapshot = await repository.load();
    expect(snapshot.mentors.single.name, 'Jane Doe');
    expect(snapshot.myMentorProfile?.expertise, 'Software Engineering');
  });

  test('a load failure propagates so the page can show a retry, never a silent empty snapshot', () async {
    final repository = AlumniMentorshipRepository(
      membership: alumnus,
      remote: _FakeAlumniServerApi(loadError: StateError('offline')),
    );
    expect(repository.load(), throwsStateError);
  });

  group('requestsAsMentee / requestsAsMentor', () {
    test('splits real requests by this membership\'s real relationship to each one', () async {
      const asMentee = _pendingRequest;
      const asMentor = AlumniMentorshipRequest(
        id: 'req-2',
        mentorMembershipId: 'm-alumnus',
        mentorName: 'John Smith',
        mentorEmail: null,
        menteeMembershipId: 'm-other',
        menteeName: 'Someone Else',
        menteeEmail: null,
        message: '',
        status: AlumniMentorshipRequestStatus.pending,
        createdAt: '2026-01-03T00:00:00Z',
      );
      final repository = AlumniMentorshipRepository(
        membership: alumnus,
        remote: _FakeAlumniServerApi(requests: const [asMentee, asMentor]),
      );
      final snapshot = await repository.load();
      expect(snapshot.requestsAsMentee.single.id, 'req-1');
      expect(snapshot.requestsAsMentor.single.id, 'req-2');
    });
  });

  test('saveMyMentorProfile() with no server throws rather than pretending to opt in', () async {
    final repository = AlumniMentorshipRepository(membership: alumnus, remote: null);
    expect(
      repository.saveMyMentorProfile(expertise: 'Finance', bio: 'A real bio.', isActive: true),
      throwsStateError,
    );
  });

  test('saveMyMentorProfile() refuses a bio that is too short to mean anything', () async {
    final repository = AlumniMentorshipRepository(membership: alumnus, remote: _FakeAlumniServerApi());
    expect(
      repository.saveMyMentorProfile(expertise: 'Finance', bio: 'hi', isActive: true),
      throwsArgumentError,
    );
  });

  test('saveMyMentorProfile() really sends this membership\'s own expertise', () async {
    final api = _FakeAlumniServerApi();
    final repository = AlumniMentorshipRepository(membership: alumnus, remote: api);
    await repository.saveMyMentorProfile(expertise: 'Finance', bio: 'A real, long-enough bio.', isActive: true);
    expect(api.lastExpertise, 'Finance');
  });

  test('a real save failure propagates rather than silently appearing to succeed', () async {
    final repository = AlumniMentorshipRepository(
      membership: alumnus,
      remote: _FakeAlumniServerApi(saveError: StateError('rejected')),
    );
    expect(
      repository.saveMyMentorProfile(expertise: 'Finance', bio: 'A real, long-enough bio.', isActive: true),
      throwsStateError,
    );
  });

  test('requestMentor() with no server throws rather than pretending to request', () async {
    final repository = AlumniMentorshipRepository(membership: alumnus, remote: null);
    expect(repository.requestMentor(mentorMembershipId: 'm-mentor'), throwsStateError);
  });

  test('requestMentor() really sends this membership\'s own chosen mentor', () async {
    final api = _FakeAlumniServerApi();
    final repository = AlumniMentorshipRepository(membership: alumnus, remote: api);
    final result = await repository.requestMentor(mentorMembershipId: 'm-mentor', message: 'Hi');
    expect(api.lastMentorRequested, 'm-mentor');
    expect(result.status, AlumniMentorshipRequestStatus.pending);
  });

  test('a real request failure propagates rather than silently appearing to succeed', () async {
    final repository = AlumniMentorshipRepository(
      membership: alumnus,
      remote: _FakeAlumniServerApi(requestError: StateError('rejected')),
    );
    expect(repository.requestMentor(mentorMembershipId: 'm-mentor'), throwsStateError);
  });

  test('respond() with no server throws rather than pretending to respond', () async {
    final repository = AlumniMentorshipRepository(membership: alumnus, remote: null);
    expect(repository.respond('req-1', accept: true), throwsStateError);
  });

  test('accepting really reveals contact email; declining never does', () async {
    final api = _FakeAlumniServerApi();
    final repository = AlumniMentorshipRepository(membership: alumnus, remote: api);

    final accepted = await repository.respond('req-1', accept: true);
    expect(api.lastAccept, isTrue);
    expect(accepted.mentorEmail, isNotNull);
    expect(accepted.menteeEmail, isNotNull);

    final declined = await repository.respond('req-1', accept: false);
    expect(declined.mentorEmail, isNull);
    expect(declined.menteeEmail, isNull);
  });

  test('a real respond failure propagates rather than silently appearing to succeed', () async {
    final repository = AlumniMentorshipRepository(
      membership: alumnus,
      remote: _FakeAlumniServerApi(respondError: StateError('forbidden')),
    );
    expect(repository.respond('req-1', accept: true), throwsStateError);
  });

  test('withdraw() with no server throws rather than pretending to withdraw', () async {
    final repository = AlumniMentorshipRepository(membership: alumnus, remote: null);
    expect(repository.withdraw('req-1'), throwsStateError);
  });

  test('withdraw() really withdraws this exact request', () async {
    final api = _FakeAlumniServerApi();
    final repository = AlumniMentorshipRepository(membership: alumnus, remote: api);
    final result = await repository.withdraw('req-1');
    expect(api.lastWithdrawnId, 'req-1');
    expect(result.status, AlumniMentorshipRequestStatus.withdrawn);
  });

  test('a real withdraw failure propagates rather than silently appearing to succeed', () async {
    final repository = AlumniMentorshipRepository(
      membership: alumnus,
      remote: _FakeAlumniServerApi(withdrawError: StateError('forbidden')),
    );
    expect(repository.withdraw('req-1'), throwsStateError);
  });
}
