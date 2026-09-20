/// Study levels, lowest to highest. Highest level of study is derived from
/// the recorded academic records so it can never disagree with them.
const studyLevels = <String>[
  'Secondary school certificate',
  'OND / NCE',
  'HND',
  'Bachelor degree',
  'Postgraduate diploma',
  'Master degree',
  'Doctorate (PhD)',
];

int studyLevelRank(String level) => studyLevels.indexOf(level);

/// The access role a new staff member is appointed to. It is chosen when they
/// are proposed and approved by the owner; the staff member never picks it.
/// The owner, parent and student roles can never be assigned this way.
const staffSystemRoles = <String, String>{
  'teacher': 'Teacher',
  'staff': 'Support / other staff',
  'accountant': 'Finance officer',
  'administrator': 'Administrator',
  'principal': 'Principal',
};

/// Roles someone the owner has assigned to approve staff may approve. The
/// others reach money and student records, so only the owner approves them.
const delegateApprovableRoles = <String>{'teacher', 'staff'};

String staffSystemRoleLabel(String role) => staffSystemRoles[role] ?? 'Not chosen';

class StaffPersonalInfo {
  const StaffPersonalInfo({
    this.phone = '',
    this.nin = '',
    this.email = '',
    this.address = '',
    this.dateOfBirth = '',
    this.gender = '',
    this.stateOfOrigin = '',
    this.nextOfKinName = '',
    this.nextOfKinPhone = '',
    this.employmentDate = '',
    this.employmentType = '',
  });

  /// Phone and NIN are each unique to one staff member. They are stored
  /// normalized (11 digits) so duplicates can be found reliably.
  final String phone;
  final String nin;
  final String email;
  final String address;
  final String dateOfBirth;
  final String gender;
  final String stateOfOrigin;
  final String nextOfKinName;
  final String nextOfKinPhone;
  final String employmentDate;
  final String employmentType;

  StaffPersonalInfo copyWith({String? phone, String? nin}) => StaffPersonalInfo(
    phone: phone ?? this.phone,
    nin: nin ?? this.nin,
    email: email,
    address: address,
    dateOfBirth: dateOfBirth,
    gender: gender,
    stateOfOrigin: stateOfOrigin,
    nextOfKinName: nextOfKinName,
    nextOfKinPhone: nextOfKinPhone,
    employmentDate: employmentDate,
    employmentType: employmentType,
  );

  Map<String, Object?> toJson() => {
    'phone': phone,
    'nin': nin,
    'email': email,
    'address': address,
    'dateOfBirth': dateOfBirth,
    'gender': gender,
    'stateOfOrigin': stateOfOrigin,
    'nextOfKinName': nextOfKinName,
    'nextOfKinPhone': nextOfKinPhone,
    'employmentDate': employmentDate,
    'employmentType': employmentType,
  };

  factory StaffPersonalInfo.fromJson(Map<String, Object?> json) =>
      StaffPersonalInfo(
        phone: json['phone'] as String? ?? '',
        nin: json['nin'] as String? ?? '',
        email: json['email'] as String? ?? '',
        address: json['address'] as String? ?? '',
        dateOfBirth: json['dateOfBirth'] as String? ?? '',
        gender: json['gender'] as String? ?? '',
        stateOfOrigin: json['stateOfOrigin'] as String? ?? '',
        nextOfKinName: json['nextOfKinName'] as String? ?? '',
        nextOfKinPhone: json['nextOfKinPhone'] as String? ?? '',
        employmentDate: json['employmentDate'] as String? ?? '',
        employmentType: json['employmentType'] as String? ?? '',
      );
}

class StaffAcademicRecord {
  const StaffAcademicRecord({
    required this.level,
    required this.institution,
    required this.course,
    required this.year,
    this.grade = '',
  });

  final String level;
  final String institution;
  final String course;
  final int year;
  final String grade;

  Map<String, Object?> toJson() => {
    'level': level,
    'institution': institution,
    'course': course,
    'year': year,
    'grade': grade,
  };

  factory StaffAcademicRecord.fromJson(Map<String, Object?> json) =>
      StaffAcademicRecord(
        level: json['level'] as String? ?? '',
        institution: json['institution'] as String? ?? '',
        course: json['course'] as String? ?? '',
        year: json['year'] as int? ?? 0,
        grade: json['grade'] as String? ?? '',
      );
}

/// A professional credential or identity document. Only its details are
/// stored; the scanned file itself is not stored by the app yet.
class StaffCredential {
  const StaffCredential({
    required this.title,
    required this.issuer,
    this.number = '',
    this.expiry = '',
    this.verified = false,
    this.documentRef = '',
  });

  final String title;
  final String issuer;
  final String number;

  /// ISO date (yyyy-MM-dd) or empty when it does not expire.
  final String expiry;
  final bool verified;

  /// Where the original is kept, e.g. "Filing cabinet 2, folder 14".
  final String documentRef;

  DateTime? get expiryDate => DateTime.tryParse(expiry);
  bool isExpired(DateTime now) => (expiryDate?.isBefore(now)) ?? false;

  StaffCredential copyWith({bool? verified}) => StaffCredential(
    title: title,
    issuer: issuer,
    number: number,
    expiry: expiry,
    verified: verified ?? this.verified,
    documentRef: documentRef,
  );

  Map<String, Object?> toJson() => {
    'title': title,
    'issuer': issuer,
    'number': number,
    'expiry': expiry,
    'verified': verified,
    'documentRef': documentRef,
  };

  factory StaffCredential.fromJson(Map<String, Object?> json) =>
      StaffCredential(
        title: json['title'] as String? ?? '',
        issuer: json['issuer'] as String? ?? '',
        number: json['number'] as String? ?? '',
        expiry: json['expiry'] as String? ?? '',
        verified: json['verified'] as bool? ?? false,
        documentRef: json['documentRef'] as String? ?? '',
      );
}

class StaffPerformanceReview {
  const StaffPerformanceReview({
    required this.period,
    required this.rating,
    required this.notes,
    required this.at,
    this.reviewerRole = '',
    this.reviewerMembershipId = '',
  });

  final String period;

  /// 1 (needs improvement) to 5 (outstanding).
  final int rating;
  final String notes;
  final String at;

  /// Who wrote the review, so past reviews stay attributable.
  final String reviewerRole;
  final String reviewerMembershipId;

  Map<String, Object?> toJson() => {
    'period': period,
    'rating': rating,
    'notes': notes,
    'at': at,
    'reviewerRole': reviewerRole,
    'reviewerMembershipId': reviewerMembershipId,
  };

  factory StaffPerformanceReview.fromJson(Map<String, Object?> json) =>
      StaffPerformanceReview(
        period: json['period'] as String? ?? '',
        rating: json['rating'] as int? ?? 0,
        notes: json['notes'] as String? ?? '',
        at: json['at'] as String? ?? '',
        reviewerRole: json['reviewerRole'] as String? ?? '',
        reviewerMembershipId: json['reviewerMembershipId'] as String? ?? '',
      );
}

class StaffPaymentDetails {
  const StaffPaymentDetails({
    this.bankName = '',
    this.accountName = '',
    this.accountNumber = '',
  });

  final String bankName;
  final String accountName;

  /// Nigerian NUBAN: exactly ten digits.
  final String accountNumber;

  bool get isEmpty =>
      bankName.isEmpty && accountName.isEmpty && accountNumber.isEmpty;

  /// Account number with all but the last four digits hidden.
  String get maskedAccountNumber => accountNumber.length < 4
      ? accountNumber
      : '******${accountNumber.substring(accountNumber.length - 4)}';

  Map<String, Object?> toJson() => {
    'bankName': bankName,
    'accountName': accountName,
    'accountNumber': accountNumber,
  };

  factory StaffPaymentDetails.fromJson(Map<String, Object?> json) =>
      StaffPaymentDetails(
        bankName: json['bankName'] as String? ?? '',
        accountName: json['accountName'] as String? ?? '',
        accountNumber: json['accountNumber'] as String? ?? '',
      );
}

enum StaffDocumentStatus { requested, received, verified }

/// A document the school asks a new staff member to provide.
/// Only its status and where the original is kept are stored; the file itself
/// is not stored by the app yet.
class StaffRequiredDocument {
  const StaffRequiredDocument({
    required this.name,
    this.status = StaffDocumentStatus.requested,
    this.reference = '',
  });

  final String name;
  final StaffDocumentStatus status;
  final String reference;

  StaffRequiredDocument copyWith({
    StaffDocumentStatus? status,
    String? reference,
  }) => StaffRequiredDocument(
    name: name,
    status: status ?? this.status,
    reference: reference ?? this.reference,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'status': status.name,
    'reference': reference,
  };

  factory StaffRequiredDocument.fromJson(Map<String, Object?> json) =>
      StaffRequiredDocument(
        name: json['name'] as String? ?? '',
        status: StaffDocumentStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => StaffDocumentStatus.requested,
        ),
        reference: json['reference'] as String? ?? '',
      );
}

const defaultRequiredDocuments = <String>[
  'Passport photograph',
  'Government ID (NIN slip or passport)',
  'Highest academic certificate',
  'Professional licence or certificate',
  'Curriculum vitae',
  'Guarantor form',
];

/// Onboarding request state. The request is queued for sync; sending the
/// email is done by the school backend, not by this app.
enum StaffOnboardingStatus { none, invitePending, submitted, reviewed }

class StaffProfile {
  const StaffProfile({
    required this.staffId,
    this.personal = const StaffPersonalInfo(),
    this.academics = const [],
    this.credentials = const [],
    this.reviews = const [],
    this.payment = const StaffPaymentDetails(),
    this.documents = const [],
    this.onboardingStatus = StaffOnboardingStatus.none,
    this.onboardingEmail = '',
    this.linkedMembershipId = '',
    this.systemRole = '',
  });

  /// The role the person was appointed to (a key of [staffSystemRoles]).
  final String systemRole;

  /// The login of the staff member this record belongs to. It is set when
  /// their account is activated and is the only login allowed to change their
  /// bank details.
  final String linkedMembershipId;

  final StaffPaymentDetails payment;
  final List<StaffRequiredDocument> documents;
  final StaffOnboardingStatus onboardingStatus;
  final String onboardingEmail;

  final String staffId;
  final StaffPersonalInfo personal;
  final List<StaffAcademicRecord> academics;
  final List<StaffCredential> credentials;
  final List<StaffPerformanceReview> reviews;

  StaffProfile copyWith({
    StaffPersonalInfo? personal,
    List<StaffAcademicRecord>? academics,
    List<StaffCredential>? credentials,
    List<StaffPerformanceReview>? reviews,
    StaffPaymentDetails? payment,
    List<StaffRequiredDocument>? documents,
    StaffOnboardingStatus? onboardingStatus,
    String? onboardingEmail,
  }) => StaffProfile(
    staffId: staffId,
    personal: personal ?? this.personal,
    academics: academics ?? this.academics,
    credentials: credentials ?? this.credentials,
    reviews: reviews ?? this.reviews,
    payment: payment ?? this.payment,
    documents: documents ?? this.documents,
    onboardingStatus: onboardingStatus ?? this.onboardingStatus,
    onboardingEmail: onboardingEmail ?? this.onboardingEmail,
    linkedMembershipId: linkedMembershipId,
    systemRole: systemRole,
  );

  String? get highestLevel {
    String? best;
    for (final record in academics) {
      if (best == null || studyLevelRank(record.level) > studyLevelRank(best)) {
        best = record.level;
      }
    }
    return best;
  }

  double? get averageRating => reviews.isEmpty
      ? null
      : reviews.fold<int>(0, (sum, r) => sum + r.rating) / reviews.length;

  StaffPerformanceReview? get latestReview =>
      reviews.isEmpty ? null : reviews.last;

  Map<String, Object?> toJson() => {
    'staffId': staffId,
    'personal': personal.toJson(),
    'academics': [for (final a in academics) a.toJson()],
    'credentials': [for (final c in credentials) c.toJson()],
    'reviews': [for (final r in reviews) r.toJson()],
    'payment': payment.toJson(),
    'documents': [for (final d in documents) d.toJson()],
    'onboardingStatus': onboardingStatus.name,
    'onboardingEmail': onboardingEmail,
    'linkedMembershipId': linkedMembershipId,
    'systemRole': systemRole,
  };

  static List<T> _list<T>(
    Object? raw,
    T Function(Map<String, Object?>) parse,
  ) => [
    for (final item in (raw as List? ?? const []))
      parse(Map<String, Object?>.from(item as Map)),
  ];

  factory StaffProfile.fromJson(Map<String, Object?> json) => StaffProfile(
    staffId: json['staffId'] as String? ?? '',
    personal: StaffPersonalInfo.fromJson(
      Map<String, Object?>.from(json['personal'] as Map? ?? const {}),
    ),
    academics: _list(json['academics'], StaffAcademicRecord.fromJson),
    credentials: _list(json['credentials'], StaffCredential.fromJson),
    reviews: _list(json['reviews'], StaffPerformanceReview.fromJson),
    payment: StaffPaymentDetails.fromJson(
      Map<String, Object?>.from(json['payment'] as Map? ?? const {}),
    ),
    documents: _list(json['documents'], StaffRequiredDocument.fromJson),
    onboardingStatus: StaffOnboardingStatus.values.firstWhere(
      (s) => s.name == json['onboardingStatus'],
      orElse: () => StaffOnboardingStatus.none,
    ),
    onboardingEmail: json['onboardingEmail'] as String? ?? '',
    linkedMembershipId: json['linkedMembershipId'] as String? ?? '',
    systemRole: json['systemRole'] as String? ?? '',
  );
}
