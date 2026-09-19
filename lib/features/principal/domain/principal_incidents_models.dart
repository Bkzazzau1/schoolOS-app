enum PrincipalIncidentSeverity { low, medium, high, critical }

enum PrincipalIncidentStatus { open, investigating, monitoring, resolved }

enum PrincipalIncidentCategory { behaviour, safeguarding, attendance, healthSafety, property }

enum PrincipalGuardianContact { notRequired, pending, contacted }

extension PrincipalIncidentSeverityLabel on PrincipalIncidentSeverity {
  String get label => switch (this) {
        PrincipalIncidentSeverity.low => 'Low',
        PrincipalIncidentSeverity.medium => 'Medium',
        PrincipalIncidentSeverity.high => 'High',
        PrincipalIncidentSeverity.critical => 'Critical',
      };
}

extension PrincipalIncidentStatusLabel on PrincipalIncidentStatus {
  String get label => switch (this) {
        PrincipalIncidentStatus.open => 'Open',
        PrincipalIncidentStatus.investigating => 'Investigating',
        PrincipalIncidentStatus.monitoring => 'Monitoring',
        PrincipalIncidentStatus.resolved => 'Resolved',
      };
}

extension PrincipalIncidentCategoryLabel on PrincipalIncidentCategory {
  String get label => switch (this) {
        PrincipalIncidentCategory.behaviour => 'Behaviour',
        PrincipalIncidentCategory.safeguarding => 'Safeguarding',
        PrincipalIncidentCategory.attendance => 'Attendance',
        PrincipalIncidentCategory.healthSafety => 'Health & Safety',
        PrincipalIncidentCategory.property => 'Property',
      };
}

extension PrincipalGuardianContactLabel on PrincipalGuardianContact {
  String get label => switch (this) {
        PrincipalGuardianContact.notRequired => 'Not required',
        PrincipalGuardianContact.pending => 'Pending',
        PrincipalGuardianContact.contacted => 'Contacted',
      };
}

class PrincipalIncident {
  const PrincipalIncident({
    required this.id,
    required this.title,
    required this.category,
    required this.severity,
    required this.status,
    required this.person,
    required this.context,
    required this.reportedBy,
    required this.owner,
    required this.reportedAt,
    required this.location,
    required this.guardianContact,
    required this.evidenceCount,
    required this.summary,
    required this.nextAction,
    this.lastUpdatedByMembershipId,
    this.lastUpdatedAt,
  });

  final String id;
  final String title;
  final PrincipalIncidentCategory category;
  final PrincipalIncidentSeverity severity;
  final PrincipalIncidentStatus status;
  final String person;
  final String context;
  final String reportedBy;
  final String owner;
  final String reportedAt;
  final String location;
  final PrincipalGuardianContact guardianContact;
  final int evidenceCount;
  final String summary;
  final String nextAction;
  final String? lastUpdatedByMembershipId;
  final String? lastUpdatedAt;

  bool get isRestricted => category == PrincipalIncidentCategory.safeguarding;

  PrincipalIncident copyWith({
    PrincipalIncidentStatus? status,
    String? lastUpdatedByMembershipId,
    String? lastUpdatedAt,
  }) =>
      PrincipalIncident(
        id: id,
        title: title,
        category: category,
        severity: severity,
        status: status ?? this.status,
        person: person,
        context: context,
        reportedBy: reportedBy,
        owner: owner,
        reportedAt: reportedAt,
        location: location,
        guardianContact: guardianContact,
        evidenceCount: evidenceCount,
        summary: summary,
        nextAction: nextAction,
        lastUpdatedByMembershipId: lastUpdatedByMembershipId ?? this.lastUpdatedByMembershipId,
        lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category.name,
        'severity': severity.name,
        'status': status.name,
        'person': person,
        'context': context,
        'reportedBy': reportedBy,
        'owner': owner,
        'reportedAt': reportedAt,
        'location': location,
        'guardianContact': guardianContact.name,
        'evidenceCount': evidenceCount,
        'summary': summary,
        'nextAction': nextAction,
        'lastUpdatedByMembershipId': lastUpdatedByMembershipId,
        'lastUpdatedAt': lastUpdatedAt,
      };

  factory PrincipalIncident.fromJson(Map<String, dynamic> json) => PrincipalIncident(
        id: json['id'] as String,
        title: json['title'] as String,
        category: PrincipalIncidentCategory.values.byName(json['category'] as String),
        severity: PrincipalIncidentSeverity.values.byName(json['severity'] as String),
        status: PrincipalIncidentStatus.values.byName(json['status'] as String),
        person: json['person'] as String,
        context: json['context'] as String,
        reportedBy: json['reportedBy'] as String,
        owner: json['owner'] as String,
        reportedAt: json['reportedAt'] as String,
        location: json['location'] as String,
        guardianContact: PrincipalGuardianContact.values.byName(json['guardianContact'] as String),
        evidenceCount: json['evidenceCount'] as int,
        summary: json['summary'] as String,
        nextAction: json['nextAction'] as String,
        lastUpdatedByMembershipId: json['lastUpdatedByMembershipId'] as String?,
        lastUpdatedAt: json['lastUpdatedAt'] as String?,
      );
}

class PrincipalIncidentAuditEvent {
  const PrincipalIncidentAuditEvent({
    required this.id,
    required this.incidentId,
    required this.action,
    required this.actorMembershipId,
    required this.createdAt,
    this.previousStatus,
    this.newStatus,
    this.note,
  });

  final String id;
  final String incidentId;
  final String action;
  final String actorMembershipId;
  final String createdAt;
  final PrincipalIncidentStatus? previousStatus;
  final PrincipalIncidentStatus? newStatus;
  final String? note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'incidentId': incidentId,
        'action': action,
        'actorMembershipId': actorMembershipId,
        'createdAt': createdAt,
        'previousStatus': previousStatus?.name,
        'newStatus': newStatus?.name,
        'note': note,
      };

  factory PrincipalIncidentAuditEvent.fromJson(Map<String, dynamic> json) => PrincipalIncidentAuditEvent(
        id: json['id'] as String,
        incidentId: json['incidentId'] as String,
        action: json['action'] as String,
        actorMembershipId: json['actorMembershipId'] as String,
        createdAt: json['createdAt'] as String,
        previousStatus: json['previousStatus'] == null
            ? null
            : PrincipalIncidentStatus.values.byName(json['previousStatus'] as String),
        newStatus: json['newStatus'] == null
            ? null
            : PrincipalIncidentStatus.values.byName(json['newStatus'] as String),
        note: json['note'] as String?,
      );
}

class PrincipalIncidentPermissions {
  const PrincipalIncidentPermissions({
    required this.canViewSecondaryIncidents,
    required this.canViewRestrictedSafeguardingSummary,
    required this.canAddInternalNote,
    required this.canChangeCaseStatus,
    required this.canManagePrimaryOrEarlyYears,
  });

  final bool canViewSecondaryIncidents;
  final bool canViewRestrictedSafeguardingSummary;
  final bool canAddInternalNote;
  final bool canChangeCaseStatus;
  final bool canManagePrimaryOrEarlyYears;
}
