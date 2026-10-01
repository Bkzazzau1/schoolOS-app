import '../domain/transport_models.dart';

const transportSafetyRules = <String, String>{
  'Daily rider check':
      'Boarding and school-arrival status should be reconciled.',
  'Vehicle readiness': 'Maintenance clearance should override scheduling.',
  'Authorized staff only':
      'Detailed rider lists and pickup points should not be public.',
};

const transportParentExperience =
    'Parents can later receive their own child\'s route, boarding/drop status and approved transport alerts without seeing other children\'s addresses or stops.';

const transportGpsBoundary =
    'Live GPS and transport notifications are not implemented in this UI phase.';

List<TransportStat> transportStats(
  List<SchoolTransportRoute> routes,
  int morningExceptionsToday,
) {
  final configuredRoutes = routes.where((route) => route.riders > 0).length;
  final spareVehicles = routes.length - configuredRoutes;
  final underMaintenance = routes.where((route) => !route.isAvailable).length;
  return [
    TransportStat(
      'Configured routes',
      '$configuredRoutes',
      spareVehicles > 0
          ? 'Plus $spareVehicles spare vehicle${spareVehicles == 1 ? '' : 's'}'
          : 'No spare vehicles',
    ),
    TransportStat(
      'Registered riders',
      '${routes.fold<int>(0, (sum, route) => sum + route.riders)}',
      'Across active routes',
    ),
    TransportStat(
      'Vehicles available',
      '${routes.where((route) => route.isAvailable).length} / ${routes.length}',
      underMaintenance > 0
          ? '$underMaintenance under maintenance'
          : 'None under maintenance',
    ),
    TransportStat(
      'Morning exceptions',
      '$morningExceptionsToday',
      morningExceptionsToday > 0
          ? 'Riders marked exception today'
          : 'No exceptions recorded today',
    ),
    const TransportStat(
      'GPS tracking',
      'Later',
      'No live location in UI phase',
    ),
  ];
}
