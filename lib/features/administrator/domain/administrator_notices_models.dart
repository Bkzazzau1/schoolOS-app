enum AdministratorNoticeAudience {
  parents('Parents'),
  staff('Staff'),
  wholeSchool('Whole school'),
  primary('Primary'),
  secondary('Secondary');

  const AdministratorNoticeAudience(this.label);
  final String label;

  static AdministratorNoticeAudience fromLabel(String value) {
    return AdministratorNoticeAudience.values.firstWhere(
      (item) => item.label == value,
      orElse: () => AdministratorNoticeAudience.parents,
    );
  }
}

enum AdministratorNoticeType {
  generalAdministration('General administration'),
  documentRequest('Document request'),
  feeReminder('Fee reminder'),
  serviceUpdate('Service update');

  const AdministratorNoticeType(this.label);
  final String label;

  static AdministratorNoticeType fromLabel(String value) {
    return AdministratorNoticeType.values.firstWhere(
      (item) => item.label == value,
      orElse: () => AdministratorNoticeType.generalAdministration,
    );
  }
}

enum AdministratorNoticeStatus {
  scheduled('Scheduled'),
  published('Published'),
  draft('Draft');

  const AdministratorNoticeStatus(this.label);
  final String label;

  static AdministratorNoticeStatus fromLabel(String value) {
    return AdministratorNoticeStatus.values.firstWhere(
      (item) => item.label == value,
      orElse: () => AdministratorNoticeStatus.draft,
    );
  }
}

class AdministratorNotice {
  const AdministratorNotice({
    required this.id,
    required this.title,
    required this.audience,
    required this.type,
    required this.message,
    required this.status,
    required this.createdLabel,
  });

  final String id;
  final String title;
  final AdministratorNoticeAudience audience;
  final AdministratorNoticeType type;
  final String message;
  final AdministratorNoticeStatus status;
  final String createdLabel;

  bool get isDraft => status == AdministratorNoticeStatus.draft;
  bool get isPublished => status == AdministratorNoticeStatus.published;
  bool get isScheduled => status == AdministratorNoticeStatus.scheduled;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'audience': audience.label,
        'type': type.label,
        'message': message,
        'status': status.label,
        'createdLabel': createdLabel,
      };

  factory AdministratorNotice.fromJson(Map<String, dynamic> json) {
    return AdministratorNotice(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      audience: AdministratorNoticeAudience.fromLabel(
        json['audience'] as String? ?? 'Parents',
      ),
      type: AdministratorNoticeType.fromLabel(
        json['type'] as String? ?? 'General administration',
      ),
      message: json['message'] as String? ?? '',
      status: AdministratorNoticeStatus.fromLabel(
        json['status'] as String? ?? 'Draft',
      ),
      createdLabel: json['createdLabel'] as String? ?? '',
    );
  }
}

class AdministratorNoticePermissions {
  const AdministratorNoticePermissions({required this.canCreateDrafts});
  final bool canCreateDrafts;
}
