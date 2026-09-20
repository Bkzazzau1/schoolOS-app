enum DriverIncidentCategory {
  vehicleBreakdown('Vehicle breakdown'),
  accident('Accident'),
  trafficDelay('Traffic delay'),
  routeObstruction('Route obstruction'),
  studentNotAtStop('Student not at pickup point'),
  guardianUnavailable('Guardian unavailable'),
  studentUnwell('Student became unwell'),
  vehicleIssue('Vehicle issue'),
  safetyConcern('Safety concern'),
  other('Other');

  const DriverIncidentCategory(this.label);
  final String label;
}

enum DriverIncidentSeverity {
  low('Low'),
  medium('Medium'),
  high('High'),
  critical('Critical');

  const DriverIncidentSeverity(this.label);
  final String label;
}

enum DriverIncidentStatus {
  queued('Queued locally'),
  submitted('Submitted'),
  acknowledged('Acknowledged'),
  underReview('Under review'),
  resolved('Resolved');

  const DriverIncidentStatus(this.label);
  final String label;
}

enum DriverIncidentTripPhase {
  beforeMorningRun('Before morning run'),
  morningRoute('Morning route'),
  atSchool('At school'),
  beforeAfternoonRun('Before afternoon run'),
  afternoonRoute('Afternoon route'),
  afterService('After service');

  const DriverIncidentTripPhase(this.label);
  final String label;
}

class DriverTransportIncident {
  const DriverTransportIncident({
    required this.id,
    required this.membershipId,
    required this.routeId,
    required this.vehicle,
    required this.serviceDate,
    required this.category,
    required this.severity,
    required this.phase,
    required this.description,
    required this.reportedAt,
    this.locationNote = '',
    this.studentId = '',
    this.studentName = '',
    this.status = DriverIncidentStatus.queued,
    this.requiresImmediateEscalation = false,
    this.serverReference = '',
  });

  final String id;
  final String membershipId;
  final String routeId;
  final String vehicle;
  final String serviceDate;
  final DriverIncidentCategory category;
  final DriverIncidentSeverity severity;
  final DriverIncidentTripPhase phase;
  final String description;
  final String reportedAt;
  final String locationNote;
  final String studentId;
  final String studentName;
  final DriverIncidentStatus status;
  final bool requiresImmediateEscalation;
  final String serverReference;

  bool get hasStudent => studentId.trim().isNotEmpty;
  bool get isOpen => status != DriverIncidentStatus.resolved;

  Map<String, Object?> toJson() => {
        'id': id,
        'membershipId': membershipId,
        'routeId': routeId,
        'vehicle': vehicle,
        'serviceDate': serviceDate,
        'category': category.name,
        'severity': severity.name,
        'phase': phase.name,
        'description': description,
        'reportedAt': reportedAt,
        'locationNote': locationNote,
        'studentId': studentId,
        'studentName': studentName,
        'status': status.name,
        'requiresImmediateEscalation': requiresImmediateEscalation,
        'serverReference': serverReference,
      };

  factory DriverTransportIncident.fromJson(Map<String, Object?> json) =>
      DriverTransportIncident(
        id: json['id'] as String? ?? '',
        membershipId: json['membershipId'] as String? ?? '',
        routeId: json['routeId'] as String? ?? '',
        vehicle: json['vehicle'] as String? ?? '',
        serviceDate: json['serviceDate'] as String? ?? '',
        category: DriverIncidentCategory.values.firstWhere(
          (value) => value.name == json['category'],
          orElse: () => DriverIncidentCategory.other,
        ),
        severity: DriverIncidentSeverity.values.firstWhere(
          (value) => value.name == json['severity'],
          orElse: () => DriverIncidentSeverity.medium,
        ),
        phase: DriverIncidentTripPhase.values.firstWhere(
          (value) => value.name == json['phase'],
          orElse: () => DriverIncidentTripPhase.beforeMorningRun,
        ),
        description: json['description'] as String? ?? '',
        reportedAt: json['reportedAt'] as String? ?? '',
        locationNote: json['locationNote'] as String? ?? '',
        studentId: json['studentId'] as String? ?? '',
        studentName: json['studentName'] as String? ?? '',
        status: DriverIncidentStatus.values.firstWhere(
          (value) => value.name == json['status'],
          orElse: () => DriverIncidentStatus.queued,
        ),
        requiresImmediateEscalation:
            json['requiresImmediateEscalation'] as bool? ?? false,
        serverReference: json['serverReference'] as String? ?? '',
      );
}

class DriverIncidentContext {
  const DriverIncidentContext({
    required this.routeId,
    required this.vehicle,
    required this.serviceDate,
    required this.phase,
  });

  final String routeId;
  final String vehicle;
  final String serviceDate;
  final DriverIncidentTripPhase phase;
}

class DriverIncidentStudentOption {
  const DriverIncidentStudentOption({
    required this.studentId,
    required this.name,
    required this.className,
    required this.stopName,
  });

  final String studentId;
  final String name;
  final String className;
  final String stopName;
}

class DriverIncidentSnapshot {
  const DriverIncidentSnapshot({
    required this.context,
    required this.incidents,
    required this.assignedStudents,
  });

  final DriverIncidentContext context;
  final List<DriverTransportIncident> incidents;
  final List<DriverIncidentStudentOption> assignedStudents;

  int get openCount => incidents.where((incident) => incident.isOpen).length;
  int get criticalCount => incidents
      .where((incident) => incident.severity == DriverIncidentSeverity.critical)
      .length;
  int get escalationCount => incidents
      .where((incident) => incident.requiresImmediateEscalation && incident.isOpen)
      .length;
}
