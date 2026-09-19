class AdministratorWebsiteSettings {
  const AdministratorWebsiteSettings({
    required this.heroHeadline,
    required this.heroSupportingText,
    required this.admissionsOpen,
    required this.admissionSession,
  });

  final String heroHeadline;
  final String heroSupportingText;
  final bool admissionsOpen;
  final String admissionSession;

  AdministratorWebsiteSettings copyWith({
    String? heroHeadline,
    String? heroSupportingText,
    bool? admissionsOpen,
    String? admissionSession,
  }) {
    return AdministratorWebsiteSettings(
      heroHeadline: heroHeadline ?? this.heroHeadline,
      heroSupportingText: heroSupportingText ?? this.heroSupportingText,
      admissionsOpen: admissionsOpen ?? this.admissionsOpen,
      admissionSession: admissionSession ?? this.admissionSession,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'heroHeadline': heroHeadline,
      'heroSupportingText': heroSupportingText,
      'admissionsOpen': admissionsOpen,
      'admissionSession': admissionSession,
    };
  }

  factory AdministratorWebsiteSettings.fromJson(Map<String, dynamic> json) {
    return AdministratorWebsiteSettings(
      heroHeadline: json['heroHeadline'] as String,
      heroSupportingText: json['heroSupportingText'] as String,
      admissionsOpen: json['admissionsOpen'] as bool,
      admissionSession: json['admissionSession'] as String,
    );
  }
}

class AdministratorWebsiteKpi {
  const AdministratorWebsiteKpi({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;
}

class PublicWebsiteSection {
  const PublicWebsiteSection({
    required this.title,
    required this.description,
    required this.status,
  });

  final String title;
  final String description;
  final String status;
}

class AdmissionFormRequirement {
  const AdmissionFormRequirement({
    required this.title,
    required this.description,
    required this.status,
  });

  final String title;
  final String description;
  final String status;
}

class WebsiteBrandIdentity {
  const WebsiteBrandIdentity({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class AdministratorWebsitePermissions {
  const AdministratorWebsitePermissions({required this.canManageWebsite});

  final bool canManageWebsite;
}
