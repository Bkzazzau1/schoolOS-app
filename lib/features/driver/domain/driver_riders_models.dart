import 'driver_afternoon_run_models.dart';
import 'driver_morning_run_models.dart';

enum DriverRiderViewFilter {
  all('All riders'),
  attention('Needs attention'),
  onboard('Currently onboard'),
  completed('Completed today');

  const DriverRiderViewFilter(this.label);
  final String label;
}

class DriverRiderOperationalView {
  const DriverRiderOperationalView({
    required this.studentId,
    required this.name,
    required this.className,
    required this.stopId,
    required this.stopSequence,
    required this.stopName,
    required this.morningScheduledTime,
    required this.afternoonScheduledTime,
    required this.morningStatus,
    required this.afternoonStatus,
    this.morningNote = '',
    this.afternoonNote = '',
  });

  final String studentId;
  final String name;
  final String className;
  final String stopId;
  final int stopSequence;
  final String stopName;
  final String morningScheduledTime;
  final String afternoonScheduledTime;
  final DriverMorningRiderStatus morningStatus;
  final DriverAfternoonRiderStatus afternoonStatus;
  final String morningNote;
  final String afternoonNote;

  bool get needsAttention =>
      morningStatus == DriverMorningRiderStatus.noShow ||
      morningStatus == DriverMorningRiderStatus.exception ||
      afternoonStatus == DriverAfternoonRiderStatus.boardingException ||
      afternoonStatus == DriverAfternoonRiderStatus.guardianUnavailable ||
      afternoonStatus == DriverAfternoonRiderStatus.dropException;

  bool get currentlyOnboard => afternoonStatus.stillOnBus;

  bool get completedToday =>
      morningStatus == DriverMorningRiderStatus.arrivedSchool &&
      (afternoonStatus.safelyReleased ||
          afternoonStatus == DriverAfternoonRiderStatus.guardianPickup ||
          afternoonStatus == DriverAfternoonRiderStatus.notRiding);

  bool matches(String query, DriverRiderViewFilter filter) {
    final normalized = query.trim().toLowerCase();
    final haystack = '$name $studentId $className $stopName'.toLowerCase();
    final queryMatches = normalized.isEmpty || haystack.contains(normalized);
    final filterMatches = switch (filter) {
      DriverRiderViewFilter.all => true,
      DriverRiderViewFilter.attention => needsAttention,
      DriverRiderViewFilter.onboard => currentlyOnboard,
      DriverRiderViewFilter.completed => completedToday,
    };
    return queryMatches && filterMatches;
  }
}

class DriverRidersSnapshot {
  const DriverRidersSnapshot({
    required this.routeId,
    required this.vehicle,
    required this.serviceDate,
    required this.riders,
  });

  final String routeId;
  final String vehicle;
  final String serviceDate;
  final List<DriverRiderOperationalView> riders;

  int get needsAttention => riders.where((rider) => rider.needsAttention).length;
  int get onboard => riders.where((rider) => rider.currentlyOnboard).length;
  int get completed => riders.where((rider) => rider.completedToday).length;
}
