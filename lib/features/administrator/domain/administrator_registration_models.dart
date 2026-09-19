enum StudentRegistrationStatus {
  inProgress('Admission in progress'),
  active('Active');

  const StudentRegistrationStatus(this.label);
  final String label;

  static StudentRegistrationStatus fromLabel(String? value) {
    return values.firstWhere(
      (item) => item.label == value,
      orElse: () => StudentRegistrationStatus.inProgress,
    );
  }
}

class StudentRegistrationRecord {
  const StudentRegistrationRecord({
    required this.registrationId,
    required this.firstName,
    required this.surname,
    required this.otherName,
    required this.dateOfBirth,
    required this.gender,
    required this.academicSection,
    required this.proposedClass,
    required this.previousSchool,
    required this.address,
    required this.admissionNumber,
    required this.studentId,
    required this.status,
    required this.primaryGuardian,
    required this.relationship,
    required this.guardianPhone,
    required this.guardianEmail,
    required this.familyAccount,
    required this.siblingLink,
    required this.birthCertificateStatus,
    required this.previousSchoolRecordStatus,
    required this.guardianIdentificationStatus,
    required this.financeSetupStatus,
    required this.transportMealStatus,
    this.sourceApplicantReference,
  });

  final String registrationId;
  final String firstName;
  final String surname;
  final String otherName;
  final String dateOfBirth;
  final String gender;
  final String academicSection;
  final String proposedClass;
  final String previousSchool;
  final String address;
  final String admissionNumber;
  final String studentId;
  final StudentRegistrationStatus status;
  final String primaryGuardian;
  final String relationship;
  final String guardianPhone;
  final String guardianEmail;
  final String familyAccount;
  final String siblingLink;
  final String birthCertificateStatus;
  final String previousSchoolRecordStatus;
  final String guardianIdentificationStatus;
  final String financeSetupStatus;
  final String transportMealStatus;
  final String? sourceApplicantReference;

  String get fullName => [firstName, otherName, surname]
      .where((part) => part.trim().isNotEmpty)
      .join(' ');

  bool get isActive => status == StudentRegistrationStatus.active;

  StudentRegistrationRecord copyWith({
    String? registrationId,
    String? firstName,
    String? surname,
    String? otherName,
    String? dateOfBirth,
    String? gender,
    String? academicSection,
    String? proposedClass,
    String? previousSchool,
    String? address,
    String? admissionNumber,
    String? studentId,
    StudentRegistrationStatus? status,
    String? primaryGuardian,
    String? relationship,
    String? guardianPhone,
    String? guardianEmail,
    String? familyAccount,
    String? siblingLink,
    String? birthCertificateStatus,
    String? previousSchoolRecordStatus,
    String? guardianIdentificationStatus,
    String? financeSetupStatus,
    String? transportMealStatus,
    String? sourceApplicantReference,
  }) {
    return StudentRegistrationRecord(
      registrationId: registrationId ?? this.registrationId,
      firstName: firstName ?? this.firstName,
      surname: surname ?? this.surname,
      otherName: otherName ?? this.otherName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      academicSection: academicSection ?? this.academicSection,
      proposedClass: proposedClass ?? this.proposedClass,
      previousSchool: previousSchool ?? this.previousSchool,
      address: address ?? this.address,
      admissionNumber: admissionNumber ?? this.admissionNumber,
      studentId: studentId ?? this.studentId,
      status: status ?? this.status,
      primaryGuardian: primaryGuardian ?? this.primaryGuardian,
      relationship: relationship ?? this.relationship,
      guardianPhone: guardianPhone ?? this.guardianPhone,
      guardianEmail: guardianEmail ?? this.guardianEmail,
      familyAccount: familyAccount ?? this.familyAccount,
      siblingLink: siblingLink ?? this.siblingLink,
      birthCertificateStatus:
          birthCertificateStatus ?? this.birthCertificateStatus,
      previousSchoolRecordStatus:
          previousSchoolRecordStatus ?? this.previousSchoolRecordStatus,
      guardianIdentificationStatus:
          guardianIdentificationStatus ?? this.guardianIdentificationStatus,
      financeSetupStatus: financeSetupStatus ?? this.financeSetupStatus,
      transportMealStatus: transportMealStatus ?? this.transportMealStatus,
      sourceApplicantReference:
          sourceApplicantReference ?? this.sourceApplicantReference,
    );
  }

  Map<String, Object?> toJson() => {
        'registrationId': registrationId,
        'firstName': firstName,
        'surname': surname,
        'otherName': otherName,
        'dateOfBirth': dateOfBirth,
        'gender': gender,
        'academicSection': academicSection,
        'proposedClass': proposedClass,
        'previousSchool': previousSchool,
        'address': address,
        'admissionNumber': admissionNumber,
        'studentId': studentId,
        'status': status.label,
        'primaryGuardian': primaryGuardian,
        'relationship': relationship,
        'guardianPhone': guardianPhone,
        'guardianEmail': guardianEmail,
        'familyAccount': familyAccount,
        'siblingLink': siblingLink,
        'birthCertificateStatus': birthCertificateStatus,
        'previousSchoolRecordStatus': previousSchoolRecordStatus,
        'guardianIdentificationStatus': guardianIdentificationStatus,
        'financeSetupStatus': financeSetupStatus,
        'transportMealStatus': transportMealStatus,
        'sourceApplicantReference': sourceApplicantReference,
      };

  factory StudentRegistrationRecord.fromJson(Map<String, Object?> json) {
    return StudentRegistrationRecord(
      registrationId: json['registrationId'] as String? ?? 'REG-DRAFT-014',
      firstName: json['firstName'] as String? ?? '',
      surname: json['surname'] as String? ?? '',
      otherName: json['otherName'] as String? ?? '',
      dateOfBirth: json['dateOfBirth'] as String? ?? '',
      gender: json['gender'] as String? ?? 'Female',
      academicSection: json['academicSection'] as String? ?? 'Primary',
      proposedClass: json['proposedClass'] as String? ?? 'Primary 2',
      previousSchool: json['previousSchool'] as String? ?? '',
      address: json['address'] as String? ?? '',
      admissionNumber: json['admissionNumber'] as String? ?? '',
      studentId: json['studentId'] as String? ?? '',
      status: StudentRegistrationStatus.fromLabel(json['status'] as String?),
      primaryGuardian: json['primaryGuardian'] as String? ?? '',
      relationship: json['relationship'] as String? ?? 'Father',
      guardianPhone: json['guardianPhone'] as String? ?? '',
      guardianEmail: json['guardianEmail'] as String? ?? '',
      familyAccount: json['familyAccount'] as String? ?? 'Create new family account',
      siblingLink: json['siblingLink'] as String? ?? 'No existing sibling',
      birthCertificateStatus:
          json['birthCertificateStatus'] as String? ?? 'Received · pending verification',
      previousSchoolRecordStatus:
          json['previousSchoolRecordStatus'] as String? ?? 'Received',
      guardianIdentificationStatus:
          json['guardianIdentificationStatus'] as String? ?? 'Received',
      financeSetupStatus:
          json['financeSetupStatus'] as String? ?? 'Prepare after student activation',
      transportMealStatus:
          json['transportMealStatus'] as String? ?? 'Optional service setup',
      sourceApplicantReference: json['sourceApplicantReference'] as String?,
    );
  }
}

class RegistrationPermissions {
  const RegistrationPermissions({required this.canRegisterStudent});
  final bool canRegisterStudent;
}

String admissionNumberForSection(String section) {
  final code = switch (section) {
    'Primary' => 'PRI',
    'Secondary' => 'SEC',
    _ => 'EYR',
  };
  final serial = section == 'Primary' ? '014' : '009';
  return 'BGA/KD/$code/26/$serial';
}

const registrationQrSafetyBoundary =
    'QR/barcode must use a safe opaque identifier only. Do not encode date of birth, guardian phone, health information or fee balance directly.';

const registrationActivationBoundary =
    'Registration remains Admission in progress until completion. Finance account setup is prepared after activation; optional transport and meal enrollment stay separate service workflows.';
