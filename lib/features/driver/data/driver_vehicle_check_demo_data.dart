import '../domain/driver_vehicle_check_models.dart';

const driverVehicleCheckSafetyBoundary =
    'This is an operational pre-trip safety check. The Driver records what is physically observed; the app does not infer mechanical condition.';

const driverVehicleCheckOfflineBoundary =
    'Checks and defect reports save locally first. A queued check or defect is not server-confirmed until synchronization succeeds.';

List<DriverVehicleCheckItem> defaultDriverVehicleCheckItems() => const [
      DriverVehicleCheckItem(
        id: 'fuel_charge',
        label: 'Fuel / charge level',
        description: 'Enough fuel or battery charge for the assigned route and safe return.',
        severity: DriverVehicleCheckSeverity.critical,
      ),
      DriverVehicleCheckItem(
        id: 'tyres',
        label: 'Tyres',
        description: 'Tyres appear properly inflated, undamaged and roadworthy.',
        severity: DriverVehicleCheckSeverity.critical,
      ),
      DriverVehicleCheckItem(
        id: 'brakes',
        label: 'Brakes',
        description: 'Brake pedal and braking response show no known defect.',
        severity: DriverVehicleCheckSeverity.critical,
      ),
      DriverVehicleCheckItem(
        id: 'steering',
        label: 'Steering',
        description: 'Steering response is normal with no unusual looseness or warning.',
        severity: DriverVehicleCheckSeverity.critical,
      ),
      DriverVehicleCheckItem(
        id: 'lights_horn',
        label: 'Lights & horn',
        description: 'Headlights, brake/indicator lights and horn are working.',
        severity: DriverVehicleCheckSeverity.critical,
      ),
      DriverVehicleCheckItem(
        id: 'doors',
        label: 'Doors & access',
        description: 'Passenger doors open, close and secure correctly.',
        severity: DriverVehicleCheckSeverity.critical,
      ),
      DriverVehicleCheckItem(
        id: 'seat_belts',
        label: 'Seat belts / restraints',
        description: 'Required passenger restraints are present and usable.',
        severity: DriverVehicleCheckSeverity.critical,
      ),
      DriverVehicleCheckItem(
        id: 'warning_lights',
        label: 'Dashboard warnings',
        description: 'No unresolved critical engine, brake, battery or safety warning is showing.',
        severity: DriverVehicleCheckSeverity.critical,
      ),
      DriverVehicleCheckItem(
        id: 'fire_extinguisher',
        label: 'Fire extinguisher',
        description: 'Required extinguisher is present, accessible and appears serviceable.',
        severity: DriverVehicleCheckSeverity.critical,
      ),
      DriverVehicleCheckItem(
        id: 'first_aid',
        label: 'First-aid kit',
        description: 'First-aid kit is present and accessible.',
        severity: DriverVehicleCheckSeverity.critical,
      ),
      DriverVehicleCheckItem(
        id: 'interior',
        label: 'Passenger area',
        description: 'No loose object, spill or interior obstruction creates an obvious trip hazard.',
        severity: DriverVehicleCheckSeverity.advisory,
      ),
    ];
