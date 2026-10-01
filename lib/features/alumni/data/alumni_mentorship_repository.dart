import '../../../shared/models/school_membership.dart';
import '../domain/alumni_mentorship_models.dart';
import 'alumni_server_api.dart';

class AlumniMentorshipSnapshot {
  const AlumniMentorshipSnapshot({
    required this.mentors,
    required this.myMentorProfile,
    required this.requests,
    required this.membershipId,
  });

  final List<AlumniMentorProfile> mentors;
  final AlumniMentorProfile? myMentorProfile;
  final List<AlumniMentorshipRequest> requests;
  final String membershipId;

  List<AlumniMentorshipRequest> get requestsAsMentee =>
      requests.where((item) => item.menteeMembershipId == membershipId).toList(growable: false);

  List<AlumniMentorshipRequest> get requestsAsMentor =>
      requests.where((item) => item.mentorMembershipId == membershipId).toList(growable: false);
}

/// Online-only, the same shape `AlumniOpportunitiesRepository` already uses: with no school server
/// connected there is nothing real to show, so this stays an honest empty state rather than a
/// fabricated one.
class AlumniMentorshipRepository {
  AlumniMentorshipRepository({
    required SchoolMembership membership,
    required AlumniServerApi? remote,
  })  : _membership = membership,
        _remote = remote;

  final SchoolMembership _membership;
  final AlumniServerApi? _remote;

  bool get hasServer => _remote != null;

  Future<AlumniMentorshipSnapshot> load() async {
    final remote = _remote;
    if (remote == null) {
      return AlumniMentorshipSnapshot(
        mentors: const [],
        myMentorProfile: null,
        requests: const [],
        membershipId: _membership.id,
      );
    }
    final mentors = await remote.loadMentors(_membership);
    final myMentorProfile = await remote.loadMyMentorProfile(_membership);
    final requests = await remote.loadMyMentorshipRequests(_membership);
    return AlumniMentorshipSnapshot(
      mentors: mentors,
      myMentorProfile: myMentorProfile,
      requests: requests,
      membershipId: _membership.id,
    );
  }

  Future<AlumniMentorProfile> saveMyMentorProfile({
    required String expertise,
    required String bio,
    required bool isActive,
  }) async {
    final remote = _remote;
    if (remote == null) {
      throw StateError('Becoming a mentor requires the SchoolOS server.');
    }
    final cleanBio = bio.trim();
    if (cleanBio.length < 5) {
      throw ArgumentError.value(bio, 'bio', 'Say a little about what you can offer first.');
    }
    return remote.saveMyMentorProfile(_membership, expertise: expertise, bio: cleanBio, isActive: isActive);
  }

  Future<AlumniMentorshipRequest> requestMentor({
    required String mentorMembershipId,
    String message = '',
  }) async {
    final remote = _remote;
    if (remote == null) {
      throw StateError('Requesting a mentor requires the SchoolOS server.');
    }
    return remote.requestMentor(_membership, mentorMembershipId: mentorMembershipId, message: message);
  }

  Future<AlumniMentorshipRequest> respond(String requestId, {required bool accept}) async {
    final remote = _remote;
    if (remote == null) {
      throw StateError('Responding to a mentorship request requires the SchoolOS server.');
    }
    return remote.respondToMentorshipRequest(_membership, requestId, accept: accept);
  }

  Future<AlumniMentorshipRequest> withdraw(String requestId) async {
    final remote = _remote;
    if (remote == null) {
      throw StateError('Withdrawing a mentorship request requires the SchoolOS server.');
    }
    return remote.withdrawMentorshipRequest(_membership, requestId);
  }
}
