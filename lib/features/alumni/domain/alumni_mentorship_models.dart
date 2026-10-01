/// A real alumnus's opt-in to mentor other alumni (`apps/alumni/models.py: AlumniMentorProfile`) -
/// a separate decision from appearing in the Alumni Directory: never carries contact info.
class AlumniMentorProfile {
  const AlumniMentorProfile({
    required this.membershipId,
    required this.name,
    required this.expertise,
    required this.bio,
    required this.isActive,
  });

  final String membershipId;
  final String name;
  final String expertise;
  final String bio;
  final bool isActive;

  factory AlumniMentorProfile.fromJson(Map<String, dynamic> json) => AlumniMentorProfile(
        membershipId: json['membershipId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        expertise: json['expertise'] as String? ?? '',
        bio: json['bio'] as String? ?? '',
        isActive: json['isActive'] as bool? ?? true,
      );
}

enum AlumniMentorshipRequestStatus { pending, accepted, declined, withdrawn }

extension AlumniMentorshipRequestStatusLabel on AlumniMentorshipRequestStatus {
  String get label => switch (this) {
        AlumniMentorshipRequestStatus.pending => 'Pending',
        AlumniMentorshipRequestStatus.accepted => 'Accepted',
        AlumniMentorshipRequestStatus.declined => 'Declined',
        AlumniMentorshipRequestStatus.withdrawn => 'Withdrawn',
      };
}

/// A real mentee's request to a real mentor (`apps/alumni/models.py: AlumniMentorshipRequest`).
/// [mentorEmail]/[menteeEmail] are only ever present once [status] is really `accepted` - the
/// backend's own conditional reveal, never computed client-side.
class AlumniMentorshipRequest {
  const AlumniMentorshipRequest({
    required this.id,
    required this.mentorMembershipId,
    required this.mentorName,
    required this.mentorEmail,
    required this.menteeMembershipId,
    required this.menteeName,
    required this.menteeEmail,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String mentorMembershipId;
  final String mentorName;
  final String? mentorEmail;
  final String menteeMembershipId;
  final String menteeName;
  final String? menteeEmail;
  final String message;
  final AlumniMentorshipRequestStatus status;
  final String createdAt;

  factory AlumniMentorshipRequest.fromJson(Map<String, dynamic> json) => AlumniMentorshipRequest(
        id: json['id'] as String? ?? '',
        mentorMembershipId: json['mentorMembershipId'] as String? ?? '',
        mentorName: json['mentorName'] as String? ?? '',
        mentorEmail: json['mentorEmail'] as String?,
        menteeMembershipId: json['menteeMembershipId'] as String? ?? '',
        menteeName: json['menteeName'] as String? ?? '',
        menteeEmail: json['menteeEmail'] as String?,
        message: json['message'] as String? ?? '',
        status: AlumniMentorshipRequestStatus.values.firstWhere(
          (item) => item.name == json['status'],
          orElse: () => AlumniMentorshipRequestStatus.pending,
        ),
        createdAt: json['createdAt'] as String? ?? '',
      );
}
