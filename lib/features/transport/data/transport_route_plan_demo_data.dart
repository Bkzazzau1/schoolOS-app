import '../domain/transport_route_management_models.dart';

const transportRoutePlanSeed = <TransportRoutePlan>[
  TransportRoutePlan(
    routeId: 'BUS-01',
    stops: [
      TransportStopDefinition(id: 'BUS-01-STOP-01', sequence: 1, name: 'Zaria Road Stop 1', morningTime: '06:25', afternoonTime: '15:55'),
      TransportStopDefinition(id: 'BUS-01-STOP-02', sequence: 2, name: 'Zaria Road Stop 2', morningTime: '06:35', afternoonTime: '15:45'),
      TransportStopDefinition(id: 'BUS-01-STOP-03', sequence: 3, name: 'Zaria Road Stop 3', morningTime: '06:45', afternoonTime: '15:35'),
      TransportStopDefinition(id: 'BUS-01-STOP-04', sequence: 4, name: 'Zaria Road Stop 4', morningTime: '06:55', afternoonTime: '15:25'),
      TransportStopDefinition(id: 'BUS-01-STOP-05', sequence: 5, name: 'Zaria Road Stop 5', morningTime: '07:05', afternoonTime: '15:15'),
      TransportStopDefinition(id: 'BUS-01-STOP-06', sequence: 6, name: 'Zaria Road Stop 6', morningTime: '07:15', afternoonTime: '15:05'),
      TransportStopDefinition(id: 'BUS-01-STOP-07', sequence: 7, name: 'Zaria Road Stop 7', morningTime: '07:25', afternoonTime: '14:55'),
      TransportStopDefinition(id: 'BUS-01-STOP-08', sequence: 8, name: 'Zaria Road Stop 8', morningTime: '07:35', afternoonTime: '14:45'),
    ],
  ),
  TransportRoutePlan(
    routeId: 'BUS-02',
    stops: [
      TransportStopDefinition(id: 'BUS-02-STOP-01', sequence: 1, name: 'Barnawa Market Junction', morningTime: '06:35', afternoonTime: '15:45'),
      TransportStopDefinition(id: 'BUS-02-STOP-02', sequence: 2, name: 'Barnawa Complex', morningTime: '06:45', afternoonTime: '15:35'),
      TransportStopDefinition(id: 'BUS-02-STOP-03', sequence: 3, name: 'Kakuri Roundabout', morningTime: '06:55', afternoonTime: '15:25'),
      TransportStopDefinition(id: 'BUS-02-STOP-04', sequence: 4, name: 'Kakuri Bus Stop', morningTime: '07:05', afternoonTime: '15:15'),
      TransportStopDefinition(id: 'BUS-02-STOP-05', sequence: 5, name: 'Television Garage', morningTime: '07:15', afternoonTime: '15:05'),
      TransportStopDefinition(id: 'BUS-02-STOP-06', sequence: 6, name: 'Nasarawa Junction', morningTime: '07:25', afternoonTime: '14:55'),
      TransportStopDefinition(id: 'BUS-02-STOP-07', sequence: 7, name: 'Command Junction', morningTime: '07:35', afternoonTime: '14:45'),
    ],
  ),
  TransportRoutePlan(
    routeId: 'BUS-03',
    stops: [
      TransportStopDefinition(id: 'BUS-03-STOP-01', sequence: 1, name: 'Kawo / Ungwan Rimi Stop 1', morningTime: '06:15', afternoonTime: '16:05'),
      TransportStopDefinition(id: 'BUS-03-STOP-02', sequence: 2, name: 'Kawo / Ungwan Rimi Stop 2', morningTime: '06:25', afternoonTime: '15:55'),
      TransportStopDefinition(id: 'BUS-03-STOP-03', sequence: 3, name: 'Kawo / Ungwan Rimi Stop 3', morningTime: '06:35', afternoonTime: '15:45'),
      TransportStopDefinition(id: 'BUS-03-STOP-04', sequence: 4, name: 'Kawo / Ungwan Rimi Stop 4', morningTime: '06:45', afternoonTime: '15:35'),
      TransportStopDefinition(id: 'BUS-03-STOP-05', sequence: 5, name: 'Kawo / Ungwan Rimi Stop 5', morningTime: '06:55', afternoonTime: '15:25'),
      TransportStopDefinition(id: 'BUS-03-STOP-06', sequence: 6, name: 'Kawo / Ungwan Rimi Stop 6', morningTime: '07:05', afternoonTime: '15:15'),
      TransportStopDefinition(id: 'BUS-03-STOP-07', sequence: 7, name: 'Kawo / Ungwan Rimi Stop 7', morningTime: '07:15', afternoonTime: '15:05'),
      TransportStopDefinition(id: 'BUS-03-STOP-08', sequence: 8, name: 'Kawo / Ungwan Rimi Stop 8', morningTime: '07:25', afternoonTime: '14:55'),
      TransportStopDefinition(id: 'BUS-03-STOP-09', sequence: 9, name: 'Kawo / Ungwan Rimi Stop 9', morningTime: '07:35', afternoonTime: '14:45'),
    ],
  ),
  TransportRoutePlan(routeId: 'BUS-04', stops: []),
];

TransportRoutePlan? seededTransportRoutePlan(String routeId) {
  for (final plan in transportRoutePlanSeed) {
    if (plan.routeId == routeId) return plan;
  }
  return null;
}
