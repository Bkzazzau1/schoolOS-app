enum AlumniVerificationState { pending, verified, rejected }

extension AlumniVerificationStateLabel on AlumniVerificationState {
  String get label => switch (this) {
        AlumniVerificationState.pending => 'Pending verification',
        AlumniVerificationState.verified => 'Verified',
        AlumniVerificationState.rejected => 'Needs correction',
      };
}

class AlumniProfileRecord {
  const AlumniProfileRecord({
    required this.membershipId,
    required this.schoolId,
    required this.email,
    required this.name,
    required this.originalStudentReference,
    required this.admissionNumber,
    required this.graduationYear,
    required this.graduationSet,
    required this.verificationState,
    required this.profession,
    required this.organisation,
    required this.locationText,
    required this.bio,
    required this.directoryVisible,
    required this.submittedAt,
    required this.reviewedAt,
    required this.verificationNote,
    required this.verifiedAt,
    required this.verifiedByMembershipId,
    required this.updatedAt,
  });

  final String membershipId;
  final String schoolId;
  final String email;
  final String name;
  final String originalStudentReference;
  final String admissionNumber;
  final int? graduationYear;
  final String graduationSet;
  final AlumniVerificationState verificationState;
  final String profession;
  final String organisation;
  final String locationText;
  final String bio;
  final bool directoryVisible;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String verificationNote;
  final DateTime? verifiedAt;
  final String verifiedByMembershipId;
  final DateTime? updatedAt;

  bool get hasIdentityEvidence =>
      graduationYear != null &&
      (admissionNumber.trim().isNotEmpty || originalStudentReference.trim().isNotEmpty);

  bool get isVerified => verificationState == AlumniVerificationState.verified;

  factory AlumniProfileRecord.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? value) =>
        value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;

    final status = (json['verification_status'] as String? ?? 'pending').trim();
    return AlumniProfileRecord(
      membershipId: json['membershipId'] as String? ?? '',
      schoolId: json['schoolId'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      originalStudentReference:
          json['original_student_reference'] as String? ?? '',
      admissionNumber: json['admission_number'] as String? ?? '',
      graduationYear: (json['graduation_year'] as num?)?.toInt(),
      graduationSet: json['graduation_set'] as String? ?? '',
      verificationState: AlumniVerificationState.values.firstWhere(
        (value) => value.name == status,
        orElse: () => AlumniVerificationState.pending,
      ),
      profession: json['profession'] as String? ?? '',
      organisation: json['organisation'] as String? ?? '',
      locationText: json['location_text'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      directoryVisible: json['directory_visible'] as bool? ?? false,
      submittedAt: parseDate(json['submitted_at']),
      reviewedAt: parseDate(json['reviewed_at']),
      verificationNote: json['verification_note'] as String? ?? '',
      verifiedAt: parseDate(json['verified_at']),
      verifiedByMembershipId:
          json['verifiedByMembershipId'] as String? ?? '',
      updatedAt: parseDate(json['updated_at']),
    );
  }

  Map<String, Object?> toJson() => {
        'membershipId': membershipId,
        'schoolId': schoolId,
        'email': email,
        'name': name,
        'original_student_reference': originalStudentReference,
        'admission_number': admissionNumber,
        'graduation_year': graduationYear,
        'graduation_set': graduationSet,
        'verification_status': verificationState.name,
        'profession': profession,
        'organisation': organisation,
        'location_text': locationText,
        'bio': bio,
        'directory_visible': directoryVisible,
        'submitted_at': submittedAt?.toUtc().toIso8601String(),
        'reviewed_at': reviewedAt?.toUtc().toIso8601String(),
        'verification_note': verificationNote,
        'verified_at': verifiedAt?.toUtc().toIso8601String(),
        'verifiedByMembershipId': verifiedByMembershipId,
        'updated_at': updatedAt?.toUtc().toIso8601String(),
      };
}

class AlumniTransitionCandidate {
  const AlumniTransitionCandidate({
    required this.membershipId,
    required this.name,
    required this.email,
  });

  final String membershipId;
  final String name;
  final String email;

  factory AlumniTransitionCandidate.fromJson(Map<String, dynamic> json) =>
      AlumniTransitionCandidate(
        membershipId: json['membershipId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
      );
}

class AlumniManagementSnapshot {
  const AlumniManagementSnapshot({
    required this.profiles,
    required this.transitionCandidates,
  });

  final List<AlumniProfileRecord> profiles;
  final List<AlumniTransitionCandidate> transitionCandidates;

  int get pendingCount => profiles
      .where((profile) =>
          profile.verificationState == AlumniVerificationState.pending)
      .length;
  int get verifiedCount => profiles
      .where((profile) =>
          profile.verificationState == AlumniVerificationState.verified)
      .length;
  int get correctionCount => profiles
      .where((profile) =>
          profile.verificationState == AlumniVerificationState.rejected)
      .length;
}
