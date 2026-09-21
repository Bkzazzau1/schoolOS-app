import '../../driver/domain/driver_vehicle_check_models.dart';

/// School-side release state for the vehicle currently attached to a route.
/// Driver pre-trip checks are separate evidence and never replace this state.
enum TransportVehicleClearanceStatus {
  released('Released for service'),
  held('Held by Transport Control'),
  maintenance('Maintenance — unavailable');

  const TransportVehicleClearanceStatus(this.label);
  final String label;
}

class TransportVehicleClearance {
  const TransportVehicleClearance({
    required this.routeId,
    required this.vehicle,
    required this.status,
    this.note = '',
    this.updatedAt = '',
    this.updatedByMembershipId = '',
  });

  final String routeId;
  final String vehicle;
  final TransportVehicleClearanceStatus status;
  final String note;
  final String updatedAt;
  final String updatedByMembershipId;

  bool get released => status == TransportVehicleClearanceStatus.released;

  TransportVehicleClearance copyWith({
    String? vehicle,
    TransportVehicleClearanceStatus? status,
    String? note,
    String? updatedAt,
    String? updatedByMembershipId,
  }) =>
      TransportVehicleClearance(
        routeId: routeId,
        vehicle: vehicle ?? this.vehicle,
        status: status ?? this.status,
        note: note ?? this.note,
        updatedAt: updatedAt ?? this.updatedAt,
        updatedByMembershipId:
            updatedByMembershipId ?? this.updatedByMembershipId,
      );

  Map<String, Object?> toJson() => {
        'routeId': routeId,
        'vehicle': vehicle,
        'status': status.name,
        'note': note,
        'updatedAt': updatedAt,
        'updatedByMembershipId': updatedByMembershipId,
      };

  factory TransportVehicleClearance.fromJson(Map<String, Object?> json) =>
      TransportVehicleClearance(
        routeId: json['routeId'] as String? ?? '',
        vehicle: json['vehicle'] as String? ?? '',
        status: TransportVehicleClearanceStatus.values.firstWhere(
          (value) => value.name == json['status'],
          orElse: () => TransportVehicleClearanceStatus.held,
        ),
        note: json['note'] as String? ?? '',
        updatedAt: json['updatedAt'] as String? ?? '',
        updatedByMembershipId:
            json['updatedByMembershipId'] as String? ?? '',
      );
}

class TransportVehicleReadinessEntry {
  const TransportVehicleReadinessEntry({
    required this.routeId,
    required this.routeName,
    required this.vehicle,
    required this.driverName,
    required this.clearance,
    required this.morningCheckStatus,
    required this.afternoonCheckStatus,
    required this.morningSubmittedAt,
    required this.afternoonSubmittedAt,
    required this.openDefectCount,
    required this.blockingDefectCount,
  });

  final String routeId;
  final String routeName;
  final String vehicle;
  final String driverName;
  final TransportVehicleClearance clearance;
  final DriverVehicleCheckStatus? morningCheckStatus;
  final DriverVehicleCheckStatus? afternoonCheckStatus;
  final String morningSubmittedAt;
  final String afternoonSubmittedAt;
  final int openDefectCount;
  final int blockingDefectCount;

  bool get effectivelyReleased =>
      clearance.released && blockingDefectCount == 0;

  String get readinessLabel {
    if (blockingDefectCount > 0) return 'Blocked by safety defect';
    return clearance.status.label;
  }
}

class TransportVehicleReadinessSnapshot {
  const TransportVehicleReadinessSnapshot({
    required this.serviceDate,
    required this.vehicles,
    required this.canManage,
  });

  final String serviceDate;
  final List<TransportVehicleReadinessEntry> vehicles;
  final bool canManage;

  int get releasedCount =>
      vehicles.where((vehicle) => vehicle.effectivelyReleased).length;
  int get blockedCount =>
      vehicles.where((vehicle) => !vehicle.effectivelyReleased).length;
  int get blockingDefectCount => vehicles.fold(
        0,
        (sum, vehicle) => sum + vehicle.blockingDefectCount,
      );
}

const transportVehicleReadinessBoundary =
    'A Driver pre-trip check is evidence from the vehicle inspection; it is not Transport Control clearance. Open blocking defects override any release state. Queued local changes are not server-confirmed until synchronization succeeds.';
