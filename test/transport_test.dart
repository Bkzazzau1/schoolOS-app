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
    expect(transportRegisteredRiders, 91);
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

  test('Barnawa route carries the single morning exception', () {
    final route = transportWebsiteSeed.firstWhere((item) => item.id == 'BUS-02');
    expect(route.morning, '25 / 26 checked');
    expect(route.note, contains('absent from school today'));
  });

  test('search and status filtering match website behavior', () {
    expect(
      transportWebsiteSeed.where((route) => route.matches('Musa Lawal', null)),
      hasLength(1),
    );
    expect(
      transportWebsiteSeed.where((route) => route.matches('', TransportRouteStatus.arrived)),
      hasLength(3),
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
