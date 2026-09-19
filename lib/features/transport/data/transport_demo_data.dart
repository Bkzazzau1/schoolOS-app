import '../domain/transport_models.dart';

const transportWebsiteSeed = <SchoolTransportRoute>[
  SchoolTransportRoute(
    id: 'BUS-01',
    name: 'Zaria Road Route',
    vehicle: 'Toyota Coaster · BGA-01',
    driver: 'Mr. Musa Lawal',
    assistant: 'Mrs. Esther John',
    riders: 34,
    stops: 8,
    morning: '34 / 34 checked',
    afternoon: 'Pending dismissal',
    status: TransportRouteStatus.arrived,
    note: 'Morning run completed; vehicle parked on campus.',
  ),
  SchoolTransportRoute(
    id: 'BUS-02',
    name: 'Barnawa / Kakuri Route',
    vehicle: 'Toyota Hiace · BGA-02',
    driver: 'Mr. Daniel Peter',
    assistant: 'Mr. Kabiru Ali',
    riders: 26,
    stops: 7,
    morning: '25 / 26 checked',
    afternoon: 'Pending dismissal',
    status: TransportRouteStatus.arrived,
    note: 'One registered rider recorded as absent from school today.',
  ),
  SchoolTransportRoute(
    id: 'BUS-03',
    name: 'Kawo / Ungwan Rimi Route',
    vehicle: 'Toyota Coaster · BGA-03',
    driver: 'Mr. Samuel Audu',
    assistant: 'Mrs. Ruth James',
    riders: 31,
    stops: 9,
    morning: '31 / 31 checked',
    afternoon: 'Pending dismissal',
    status: TransportRouteStatus.arrived,
    note: 'Normal morning service.',
  ),
  SchoolTransportRoute(
    id: 'BUS-04',
    name: 'Backup Vehicle',
    vehicle: 'Hiace · BGA-04',
    driver: 'Relief pool',
    assistant: 'Assigned as needed',
    riders: 0,
    stops: 0,
    morning: 'Not dispatched',
    afternoon: 'Standby',
    status: TransportRouteStatus.maintenance,
    note: 'Routine brake inspection; unavailable until cleared.',
  ),
];

int get transportRegisteredRiders => transportWebsiteSeed.fold(
      0,
      (sum, route) => sum + route.riders,
    );

const transportSafetyRules = <String, String>{
  'Daily rider check': 'Boarding and school-arrival status should be reconciled.',
  'Vehicle readiness': 'Maintenance clearance should override scheduling.',
  'Authorized staff only': 'Detailed rider lists and pickup points should not be public.',
};

const transportParentExperience =
    'Parents can later receive their own child\'s route, boarding/drop status and approved transport alerts without seeing other children\'s addresses or stops.';

const transportGpsBoundary =
    'Live GPS and transport notifications are not implemented in this UI phase.';

List<TransportStat> transportStats(List<SchoolTransportRoute> routes) => [
      TransportStat(
        'Configured routes',
        '${routes.where((route) => route.riders > 0).length}',
        'Plus 1 backup vehicle',
      ),
      TransportStat(
        'Registered riders',
        '${routes.fold<int>(0, (sum, route) => sum + route.riders)}',
        'Across active routes',
      ),
      TransportStat(
        'Vehicles available',
        '${routes.where((route) => route.isAvailable).length} / ${routes.length}',
        '1 under maintenance',
      ),
      const TransportStat('Morning exceptions', '1', 'Absent registered rider'),
      const TransportStat('GPS tracking', 'Later', 'No live location in UI phase'),
    ];
