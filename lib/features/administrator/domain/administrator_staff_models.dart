enum AdministratorStaffFileStatus {
  complete('Complete'),
  missingDocument('Missing document');

  const AdministratorStaffFileStatus(this.label);
  final String label;

  static AdministratorStaffFileStatus fromLabel(String? value) {
    return values.firstWhere(
      (item) => item.label == value,
      orElse: () => AdministratorStaffFileStatus.complete,
    );
  }
}

class AdministratorStaffRecord {
  const AdministratorStaffRecord({
    required this.id,
    required this.name,
    required this.role,
    required this.section,
    required this.fileStatus,
  });

  final String id;
  final String name;
  final String role;
  final String section;
  final AdministratorStaffFileStatus fileStatus;

  bool get needsAttention =>
      fileStatus == AdministratorStaffFileStatus.missingDocument;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'section': section,
        'fileStatus': fileStatus.label,
      };

  factory AdministratorStaffRecord.fromJson(Map<String, Object?> json) {
    return AdministratorStaffRecord(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? '',
      section: json['section'] as String? ?? '',
      fileStatus: AdministratorStaffFileStatus.fromLabel(
        json['fileStatus'] as String?,
      ),
    );
  }
}

class AdministratorStaffChecklistItem {
  const AdministratorStaffChecklistItem({
    required this.title,
    required this.detail,
  });

  final String title;
  final String detail;
}

class AdministratorStaffPermissions {
  const AdministratorStaffPermissions({
    required this.canViewDirectory,
    required this.canReviewOperationalFile,
  });

  final bool canViewDirectory;
  final bool canReviewOperationalFile;
}

const administratorStaffRestrictedBoundary =
    'Administrator may maintain staff records, but salary, bank details, deductions, loans, private medical information and employment decisions remain restricted to authorized HR, Finance or leadership roles.';

const administratorStaffReviewBoundary =
    'Review on this page is an operational file check only. The website does not expose an inline edit, payroll or employment-decision workflow here, so native review must not invent one.';
