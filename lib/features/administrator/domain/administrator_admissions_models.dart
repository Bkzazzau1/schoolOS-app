enum AdmissionStage {
  newApplication('New'),
  documents('Documents'),
  screening('Screening'),
  offer('Offer'),
  accepted('Accepted'),
  registered('Registered');

  const AdmissionStage(this.label);

  final String label;
}

enum AdmissionDocumentStatus {
  received('Received'),
  pending('Pending');

  const AdmissionDocumentStatus(this.label);

  final String label;
}

class AdmissionKpi {
  const AdmissionKpi({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;
}

class AdmissionApplicant {
  const AdmissionApplicant({
    required this.reference,
    required this.name,
    required this.section,
    required this.className,
    required this.guardian,
    required this.phone,
    required this.stage,
    required this.submitted,
    this.source = 'School website',
    this.birthCertificate = AdmissionDocumentStatus.received,
    this.previousSchoolReport = AdmissionDocumentStatus.received,
    this.guardianId = AdmissionDocumentStatus.received,
    this.documentRequestQueued = false,
    this.closedReason = '',
  });

  final String reference;
  final String name;
  final String section;
  final String className;
  final String guardian;
  final String phone;
  final AdmissionStage stage;
  final String submitted;
  final String source;
  final AdmissionDocumentStatus birthCertificate;
  final AdmissionDocumentStatus previousSchoolReport;
  final AdmissionDocumentStatus guardianId;
  final bool documentRequestQueued;

  /// Set when the application will not go ahead (declined, withdrawn). The record is kept.
  final String closedReason;

  bool get isClosed => closedReason.isNotEmpty;

  AdmissionApplicant copyWith({
    AdmissionStage? stage,
    AdmissionDocumentStatus? birthCertificate,
    AdmissionDocumentStatus? previousSchoolReport,
    AdmissionDocumentStatus? guardianId,
    bool? documentRequestQueued,
    String? closedReason,
  }) {
    return AdmissionApplicant(
      reference: reference,
      name: name,
      section: section,
      className: className,
      guardian: guardian,
      phone: phone,
      stage: stage ?? this.stage,
      submitted: submitted,
      source: source,
      birthCertificate: birthCertificate ?? this.birthCertificate,
      previousSchoolReport: previousSchoolReport ?? this.previousSchoolReport,
      guardianId: guardianId ?? this.guardianId,
      documentRequestQueued:
          documentRequestQueued ?? this.documentRequestQueued,
      closedReason: closedReason ?? this.closedReason,
    );
  }

  bool matchesStage(AdmissionStage? filter) => filter == null || stage == filter;

  Map<String, Object?> toJson() {
    return {
      'reference': reference,
      'name': name,
      'section': section,
      'className': className,
      'guardian': guardian,
      'phone': phone,
      'stage': stage.name,
      'submitted': submitted,
      'source': source,
      'birthCertificate': birthCertificate.name,
      'previousSchoolReport': previousSchoolReport.name,
      'guardianId': guardianId.name,
      'documentRequestQueued': documentRequestQueued,
      'closedReason': closedReason,
    };
  }

  factory AdmissionApplicant.fromJson(Map<String, dynamic> json) {
    return AdmissionApplicant(
      reference: json['reference'] as String,
      name: json['name'] as String,
      section: json['section'] as String,
      className: json['className'] as String,
      guardian: json['guardian'] as String,
      phone: json['phone'] as String,
      stage: AdmissionStage.values.byName(json['stage'] as String),
      submitted: json['submitted'] as String,
      source: json['source'] as String? ?? 'School website',
      birthCertificate: AdmissionDocumentStatus.values.byName(
        json['birthCertificate'] as String? ?? AdmissionDocumentStatus.received.name,
      ),
      previousSchoolReport: AdmissionDocumentStatus.values.byName(
        json['previousSchoolReport'] as String? ?? AdmissionDocumentStatus.received.name,
      ),
      guardianId: AdmissionDocumentStatus.values.byName(
        json['guardianId'] as String? ?? AdmissionDocumentStatus.received.name,
      ),
      documentRequestQueued: json['documentRequestQueued'] as bool? ?? false,
      closedReason: json['closedReason'] as String? ?? '',
    );
  }
}

class AdmissionPermissions {
  const AdmissionPermissions({required this.canManagePipeline});

  final bool canManagePipeline;
}
