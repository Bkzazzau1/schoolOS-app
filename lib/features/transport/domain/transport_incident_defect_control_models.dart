import '../../driver/domain/driver_incident_models.dart';

const transportIncidentDefectBoundary =
    'Transport Control can acknowledge, review and close operational reports. Closing a case is saved locally and queued for synchronization; it is not server-confirmed until sync succeeds. Drivers cannot close their own reports.';

class TransportIncidentControlEntry {
  const TransportIncidentControlEntry({
    required this.id,
    required this.routeId,
    required this.routeName,
    required this.vehicle,
    required this.serviceDate,
    required this.category,
    required this.severity,
    required this.phase,
    required this.description,
    required this.reportedAt,
    required this.status,
    required this.requiresImmediateEscalation,
    required this.driverMembershipId,
    required this.driverName,
    this.locationNote = '',
    this.studentId = '',
    this.studentName = '',
    this.managementNote = '',
    this.updatedAt = '',
    this.updatedByMembershipId = '',
  });

  final String id;
  final String routeId;
  final String routeName;
  final String vehicle;
  final String serviceDate;
  final DriverIncidentCategory category;
  final DriverIncidentSeverity severity;
  final DriverIncidentTripPhase phase;
  final String description;
  final String reportedAt;
  final DriverIncidentStatus status;
  final bool requiresImmediateEscalation;
  final String driverMembershipId;
  final String driverName;
  final String locationNote;
  final String studentId;
  final String studentName;
  final String managementNote;
  final String updatedAt;
  final String updatedByMembershipId;

  bool get isOpen => status != DriverIncidentStatus.resolved;
  bool get urgent => requiresImmediateEscalation && isOpen;
}

class TransportVehicleDefectControlEntry {
  const TransportVehicleDefectControlEntry({
    required this.id,
    required this.routeId,
    required this.routeName,
    required this.vehicle,
    required this.serviceDate,
    required this.period,
    required this.itemLabel,
    required this.severity,
    required this.blocksTrip,
    required this.note,
    required this.status,
    required this.reportedAt,
    required this.reportedByMembershipId,
    required this.driverName,
    this.managementNote = '',
    this.updatedAt = '',
    this.updatedByMembershipId = '',
  });

  final String id;
  final String routeId;
  final String routeName;
  final String vehicle;
  final String serviceDate;
  final String period;
  final String itemLabel;
  final String severity;
  final bool blocksTrip;
  final String note;
  final String status;
  final String reportedAt;
  final String reportedByMembershipId;
  final String driverName;
  final String managementNote;
  final String updatedAt;
  final String updatedByMembershipId;

  bool get isClosed {
    final normalized = status.toLowerCase();
    return normalized == 'cleared' ||
        normalized == 'resolved' ||
        normalized == 'closed';
  }

  bool get isOpen => !isClosed;
  bool get blocksService => isOpen && blocksTrip;

  String get statusLabel => switch (status.toLowerCase()) {
        'acknowledged' => 'Acknowledged',
        'under_review' || 'underreview' => 'Under review',
        'cleared' => 'Cleared',
        'resolved' => 'Resolved',
        'closed' => 'Closed',
        _ => 'Reported',
      };
}

class TransportIncidentDefectSnapshot {
  const TransportIncidentDefectSnapshot({
    required this.incidents,
    required this.defects,
    required this.canManage,
  });

  final List<TransportIncidentControlEntry> incidents;
  final List<TransportVehicleDefectControlEntry> defects;
  final bool canManage;

  int get openIncidents => incidents.where((item) => item.isOpen).length;
  int get urgentIncidents => incidents.where((item) => item.urgent).length;
  int get openDefects => defects.where((item) => item.isOpen).length;
  int get blockingDefects => defects.where((item) => item.blocksService).length;
}
