import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/transport/data/transport_policy_copy.dart';
import 'package:schoolos_app/features/transport/domain/transport_models.dart';

const _route1 = SchoolTransportRoute(
  id: 'BUS-01',
  name: 'Zaria Road Route',
  vehicle: 'Toyota Coaster · BGA-01',
  driver: 'Driver',
  assistant: 'Not recorded yet',
  riders: 2,
  stops: 3,
  morning: 'Not started',
  afternoon: 'Not started',
  status: TransportRouteStatus.preparing,
  note: 'No transport run recorded yet today.',
);

const _route2 = SchoolTransportRoute(
  id: 'BUS-02',
  name: 'Barnawa / Kakuri Route',
  vehicle: 'Toyota Hiace · BGA-02',
  driver: 'Mr. Musa Lawal',
  assistant: 'Mrs. Esther John',
  riders: 1,
  stops: 7,
  morning: '1 / 1 checked',
  afternoon: 'Pending dismissal',
  status: TransportRouteStatus.arrived,
  note: '',
);

const _route3 = SchoolTransportRoute(
  id: 'BUS-03',
  name: 'Backup Vehicle',
  vehicle: 'Hiace · BGA-03',
  driver: 'Relief pool',
  assistant: 'Assigned as needed',
  riders: 0,
  stops: 0,
  morning: 'Not dispatched',
  afternoon: 'Standby',
  status: TransportRouteStatus.maintenance,
  note: 'Routine brake inspection; unavailable until cleared.',
);

void main() {
  test('search and status filtering work against real route fields', () {
    final routes = [_route1, _route2, _route3];
    expect(routes.where((route) => route.matches('Musa Lawal', null)), hasLength(1));
    expect(routes.where((route) => route.matches('', TransportRouteStatus.arrived)), hasLength(1));
    expect(routes.where((route) => route.matches('Backup', TransportRouteStatus.arrived)), isEmpty);
  });

  test('vehicle availability reflects status, not a fixed assumption', () {
    expect(_route1.isAvailable, isTrue);
    expect(_route2.isAvailable, isTrue);
    expect(_route3.isAvailable, isFalse, reason: 'maintenance routes are never available');
  });

  test('route review state serializes without adding rider addresses', () {
    final reviewed = _route1.copyWith(reviewed: true);
    final json = reviewed.toJson();
    final restored = SchoolTransportRoute.fromJson(json);
    expect(restored.reviewed, isTrue);
    expect(json.keys, isNot(contains('address')));
    expect(json.keys, isNot(contains('pickupPoint')));
  });

  group('transportStats is honestly computed from real routes, never fixed placeholders', () {
    test('an empty route list is all honest zeros', () {
      final stats = transportStats(const [], 0);
      expect(stats.firstWhere((s) => s.label == 'Configured routes').value, '0');
      expect(stats.firstWhere((s) => s.label == 'Registered riders').value, '0');
      expect(stats.firstWhere((s) => s.label == 'Vehicles available').value, '0 / 0');
      expect(stats.firstWhere((s) => s.label == 'Morning exceptions').value, '0');
      expect(
        stats.firstWhere((s) => s.label == 'Morning exceptions').detail,
        'No exceptions recorded today',
      );
    });

    test('real routes and a real exception count are reflected exactly', () {
      final stats = transportStats([_route1, _route2, _route3], 2);
      expect(stats.firstWhere((s) => s.label == 'Configured routes').value, '2');
      expect(
        stats.firstWhere((s) => s.label == 'Configured routes').detail,
        'Plus 1 spare vehicle',
      );
      expect(stats.firstWhere((s) => s.label == 'Registered riders').value, '3');
      expect(stats.firstWhere((s) => s.label == 'Vehicles available').value, '2 / 3');
      expect(
        stats.firstWhere((s) => s.label == 'Vehicles available').detail,
        '1 under maintenance',
      );
      expect(stats.firstWhere((s) => s.label == 'Morning exceptions').value, '2');
      expect(
        stats.firstWhere((s) => s.label == 'Morning exceptions').detail,
        'Riders marked exception today',
      );
    });
  });

  test('transport safety and future parent boundary remain explicit', () {
    expect(transportSafetyRules['Vehicle readiness'], contains('override scheduling'));
    expect(transportSafetyRules['Authorized staff only'], contains('should not be public'));
    expect(transportParentExperience, contains('without seeing other children'));
    expect(transportGpsBoundary, contains('not implemented'));
  });
}
