enum AdministratorStudentStatus {
  active('Active'),
  transferPending('Transfer pending'),
  transferredOut('Transferred out');

  const AdministratorStudentStatus(this.label);
  final String label;

  static AdministratorStudentStatus fromLabel(String? value) {
    return values.firstWhere(
      (item) => item.label == value,
      orElse: () => AdministratorStudentStatus.active,
    );
  }
}

class AdministratorStudentRecord {
  const AdministratorStudentRecord({
    required this.id,
    required this.name,
    required this.className,
    required this.primaryGuardian,
    required this.status,
  });

  final String id;
  final String name;
  final String className;
  final String primaryGuardian;
  final AdministratorStudentStatus status;

  AdministratorStudentRecord copyWith({String? className, AdministratorStudentStatus? status}) => AdministratorStudentRecord(
        id: id,
        name: name,
        className: className ?? this.className,
        primaryGuardian: primaryGuardian,
        status: status ?? this.status,
      );

  bool get isPrimary => id.startsWith('PRI');
  String get leadershipDestination =>
      isPrimary ? 'Primary leadership profile' : 'Secondary leadership profile';

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'className': className,
        'primaryGuardian': primaryGuardian,
        'status': status.label,
      };

  factory AdministratorStudentRecord.fromJson(Map<String, Object?> json) {
    return AdministratorStudentRecord(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      className: json['className'] as String? ?? '',
      primaryGuardian: json['primaryGuardian'] as String? ?? '',
      status: AdministratorStudentStatus.fromLabel(json['status'] as String?),
    );
  }
}

class AdministratorStudentTask {
  const AdministratorStudentTask({required this.title, required this.detail});

  final String title;
  final String detail;
}

class AdministratorStudentsPermissions {
  const AdministratorStudentsPermissions({
    required this.canViewDirectory,
    required this.canOpenOperationalSummary,
  });

  final bool canViewDirectory;
  final bool canOpenOperationalSummary;
}

const administratorStudentProfileBoundary =
    'The website hands Open to section leadership profiles. Administrator access must stay operational: do not expose leadership-only academic judgement, restricted health data, confidential finance, promotion decisions or private notes through this directory.';

const administratorFamilyBoundary =
    'Family accounts can link authorized guardians and siblings without merging each child’s separate academic, attendance, welfare or lifecycle record.';
