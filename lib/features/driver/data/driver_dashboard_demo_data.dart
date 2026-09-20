import '../domain/driver_dashboard_models.dart';

const defaultDriverAssignment = DriverTransportAssignment(
  membershipId: 'membership-driver-001',
  routeId: 'BUS-02',
  driverDisplayName: 'Mr. Daniel Peter',
);

const driverPrivacyBoundary =
    'Driver access is limited to assigned transport duties. Academic results, fees, unrelated students, family financial records and confidential school records are never part of the driver workspace.';

const driverSafetyBoundary =
    'Transport events record operational facts only. A queued offline event is not a server-confirmed event, and a student is never treated as dropped off until the driver records the actual handover or approved drop completion.';
