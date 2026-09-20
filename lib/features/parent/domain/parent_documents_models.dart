enum ParentDocumentStatus {
  ready('Ready'),
  actionNeeded('Action needed');

  const ParentDocumentStatus(this.label);
  final String label;

  static ParentDocumentStatus fromJson(String value) =>
      ParentDocumentStatus.values.firstWhere(
        (item) => item.name == value,
        orElse: () => ParentDocumentStatus.ready,
      );
}

enum ParentConsentDecision {
  approved('Approved'),
  declined('Declined'),
  confirmed('Confirmed'),
  queued('Queued');

  const ParentConsentDecision(this.label);
  final String label;

  static ParentConsentDecision fromJson(String value) =>
      ParentConsentDecision.values.firstWhere(
        (item) => item.name == value,
        orElse: () => ParentConsentDecision.confirmed,
      );
}

class ParentFamilyDocument {
  const ParentFamilyDocument({
    required this.id,
    required this.ownerLabel,
    required this.title,
    required this.typeLabel,
    required this.status,
    this.approvedForGuardianVisibility = true,
  });

  final String id;
  final String ownerLabel;
  final String title;
  final String typeLabel;
  final ParentDocumentStatus status;
  final bool approvedForGuardianVisibility;

  Map<String, Object?> toJson() => {
        'id': id,
        'ownerLabel': ownerLabel,
        'title': title,
        'typeLabel': typeLabel,
        'status': status.name,
        'approvedForGuardianVisibility': approvedForGuardianVisibility,
      };

  factory ParentFamilyDocument.fromJson(Map<String, dynamic> json) =>
      ParentFamilyDocument(
        id: json['id'] as String? ?? '',
        ownerLabel: json['ownerLabel'] as String? ?? '',
        title: json['title'] as String? ?? '',
        typeLabel: json['typeLabel'] as String? ?? '',
        status: ParentDocumentStatus.fromJson(json['status'] as String? ?? ''),
        approvedForGuardianVisibility:
            json['approvedForGuardianVisibility'] as bool? ?? false,
      );
}

class ParentConsentRequest {
  const ParentConsentRequest({
    required this.id,
    required this.childName,
    required this.contextLabel,
    required this.title,
    required this.dateLabel,
    required this.schoolSection,
    required this.description,
    required this.actionNeeded,
    this.localDecisionQueued = false,
    this.queuedAt,
  });

  final String id;
  final String childName;
  final String contextLabel;
  final String title;
  final String dateLabel;
  final String schoolSection;
  final String description;
  final bool actionNeeded;
  final bool localDecisionQueued;
  final DateTime? queuedAt;

  ParentConsentRequest copyWith({
    bool? actionNeeded,
    bool? localDecisionQueued,
    DateTime? queuedAt,
  }) =>
      ParentConsentRequest(
        id: id,
        childName: childName,
        contextLabel: contextLabel,
        title: title,
        dateLabel: dateLabel,
        schoolSection: schoolSection,
        description: description,
        actionNeeded: actionNeeded ?? this.actionNeeded,
        localDecisionQueued:
            localDecisionQueued ?? this.localDecisionQueued,
        queuedAt: queuedAt ?? this.queuedAt,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'childName': childName,
        'contextLabel': contextLabel,
        'title': title,
        'dateLabel': dateLabel,
        'schoolSection': schoolSection,
        'description': description,
        'actionNeeded': actionNeeded,
        'localDecisionQueued': localDecisionQueued,
        'queuedAt': queuedAt?.toUtc().toIso8601String(),
      };

  factory ParentConsentRequest.fromJson(Map<String, dynamic> json) =>
      ParentConsentRequest(
        id: json['id'] as String? ?? '',
        childName: json['childName'] as String? ?? '',
        contextLabel: json['contextLabel'] as String? ?? '',
        title: json['title'] as String? ?? '',
        dateLabel: json['dateLabel'] as String? ?? '',
        schoolSection: json['schoolSection'] as String? ?? '',
        description: json['description'] as String? ?? '',
        actionNeeded: json['actionNeeded'] as bool? ?? false,
        localDecisionQueued: json['localDecisionQueued'] as bool? ?? false,
        queuedAt: _date(json['queuedAt']),
      );
}

class ParentConsentHistoryItem {
  const ParentConsentHistoryItem({
    required this.id,
    required this.title,
    required this.decision,
    required this.dateLabel,
    required this.subjectLabel,
  });

  final String id;
  final String title;
  final ParentConsentDecision decision;
  final String dateLabel;
  final String subjectLabel;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'decision': decision.name,
        'dateLabel': dateLabel,
        'subjectLabel': subjectLabel,
      };

  factory ParentConsentHistoryItem.fromJson(Map<String, dynamic> json) =>
      ParentConsentHistoryItem(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        decision:
            ParentConsentDecision.fromJson(json['decision'] as String? ?? ''),
        dateLabel: json['dateLabel'] as String? ?? '',
        subjectLabel: json['subjectLabel'] as String? ?? '',
      );
}

class ParentDocumentsSnapshot {
  const ParentDocumentsSnapshot({
    required this.familyAccountId,
    required this.documents,
    required this.consentRequests,
    required this.consentHistory,
  });

  final String familyAccountId;
  final List<ParentFamilyDocument> documents;
  final List<ParentConsentRequest> consentRequests;
  final List<ParentConsentHistoryItem> consentHistory;

  ParentConsentRequest? consentById(String id) {
    for (final item in consentRequests) {
      if (item.id == id) return item;
    }
    return null;
  }

  ParentDocumentsSnapshot replaceConsent(ParentConsentRequest replacement) =>
      ParentDocumentsSnapshot(
        familyAccountId: familyAccountId,
        documents: documents,
        consentRequests: [
          for (final item in consentRequests)
            if (item.id == replacement.id) replacement else item,
        ],
        consentHistory: consentHistory,
      );

  Map<String, Object?> toJson() => {
        'familyAccountId': familyAccountId,
        'documents': documents.map((item) => item.toJson()).toList(),
        'consentRequests': consentRequests.map((item) => item.toJson()).toList(),
        'consentHistory': consentHistory.map((item) => item.toJson()).toList(),
      };

  factory ParentDocumentsSnapshot.fromJson(Map<String, dynamic> json) =>
      ParentDocumentsSnapshot(
        familyAccountId: json['familyAccountId'] as String? ?? '',
        documents: _maps(json['documents'])
            .map(ParentFamilyDocument.fromJson)
            .toList(growable: false),
        consentRequests: _maps(json['consentRequests'])
            .map(ParentConsentRequest.fromJson)
            .toList(growable: false),
        consentHistory: _maps(json['consentHistory'])
            .map(ParentConsentHistoryItem.fromJson)
            .toList(growable: false),
      );
}

List<Map<String, dynamic>> _maps(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

DateTime? _date(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}
