import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/transport/data/transport_demo_data.dart';
import 'package:schoolos_app/features/transport/domain/transport_models.dart';

void main() {
  test('website transport seed has three active routes plus backup', () {
    expect(transportWebsiteSeed, hasLength(4));
    expect(
      transportWebsiteSeed.where((route) => route.riders > 0),
      hasLength(3),
    );
    // BUS-02's rider count matches the one real student actually registered on it (see
    // driver_morning_run_demo_data.dart); the other routes are a separate, not-yet-audited concern.
    expect(transportRegisteredRiders, 66);
  });

  test('vehicle availability matches website snapshot', () {
    expect(
      transportWebsiteSeed.where((route) => route.isAvailable),
      hasLength(3),
    );
    expect(
      transportWebsiteSeed.where((route) => route.status == TransportRouteStatus.maintenance).single.id,
      'BUS-04',
    );
  });

  test('Barnawa route (BUS-02) starts honest: no run recorded, no invented driver identity', () {
    final route = transportWebsiteSeed.firstWhere((item) => item.id == 'BUS-02');
    expect(route.morning, 'Not started');
    expect(route.status, TransportRouteStatus.preparing);
    expect(route.driver, 'Driver');
    expect(route.assistant, 'Not recorded yet');
    // Only one real student is actually registered on this route.
    expect(route.riders, 1);
  });

  test('search and status filtering match website behavior', () {
    expect(
      transportWebsiteSeed.where((route) => route.matches('Musa Lawal', null)),
      hasLength(1),
    );
    // BUS-02 now honestly starts as "preparing" (no run recorded yet) rather than a fabricated
    // "arrived", so only the two other, not-yet-audited routes still match "arrived".
    expect(
      transportWebsiteSeed.where((route) => route.matches('', TransportRouteStatus.arrived)),
      hasLength(2),
    );
    expect(
      transportWebsiteSeed.where((route) => route.matches('Backup', TransportRouteStatus.arrived)),
      isEmpty,
    );
  });

  test('route review state serializes without adding rider addresses', () {
    final reviewed = transportWebsiteSeed.first.copyWith(reviewed: true);
    final json = reviewed.toJson();
    final restored = SchoolTransportRoute.fromJson(json);
    expect(restored.reviewed, isTrue);
    expect(json.keys, isNot(contains('address')));
    expect(json.keys, isNot(contains('pickupPoint')));
  });

  test('transport safety and future parent boundary remain explicit', () {
    expect(transportSafetyRules['Vehicle readiness'], contains('override scheduling'));
    expect(transportSafetyRules['Authorized staff only'], contains('should not be public'));
    expect(transportParentExperience, contains('without seeing other children'));
    expect(transportGpsBoundary, contains('not implemented'));
  });
}
