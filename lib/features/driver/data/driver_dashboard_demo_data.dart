import '../domain/driver_dashboard_models.dart';

// No real membership-to-person display-name directory exists anywhere in the app (the same reason
// Parent's Dashboard shows "Guardian" and Student's shows "Student Portal" instead of inventing a
// name), so the one demo Driver's real assignment record honestly carries a role label rather than
// a fabricated person. This name is written into every real transport record the driver produces
// (morning/afternoon runs, route, history), so inventing one here would fabricate evidence, not just
// a greeting.
const defaultDriverAssignment = DriverTransportAssignment(
  membershipId: 'membership-driver-001',
  routeId: 'BUS-02',
  driverDisplayName: 'Driver',
);

const driverPrivacyBoundary =
    'Driver access is limited to assigned transport duties. Academic results, fees, unrelated students, family financial records and confidential school records are never part of the driver workspace.';

const driverSafetyBoundary =
    'Transport events record operational facts only. A queued offline event is not a server-confirmed event, and a student is never treated as dropped off until the driver records the actual handover or approved drop completion.';
