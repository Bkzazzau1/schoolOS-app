import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/excursions/data/excursion_demo_data.dart';
import 'package:schoolos_app/features/excursions/domain/excursion_models.dart';

void main() {
  test('website excursion seed has four trips and 23 outstanding consents', () {
    expect(excursionWebsiteSeed, hasLength(4));
    expect(excursionConsentOutstanding, 23);
    expect(excursionStats(excursionWebsiteSeed).first.value, '4');
    expect(excursionStats(excursionWebsiteSeed)[1].value, '23');
  });

  test('two website trips are ready to go', () {
    final ready = excursionWebsiteSeed
        .where((trip) => trip.status == TripStatus.ready)
        .map((trip) => trip.id)
        .toList();
    expect(ready, ['TRIP-002', 'TRIP-004']);
    expect(excursionStats(excursionWebsiteSeed)[2].value, '2');
  });

  test('consent percentages match website trip data', () {
    expect(excursionWebsiteSeed[0].consentPercent, 79);
    expect(excursionWebsiteSeed[1].consentPercent, 100);
    expect(excursionWebsiteSeed[2].consentPercent, 81);
    expect(excursionWebsiteSeed[3].consentPercent, 100);
  });

  test('search and status filters match trip, destination and audience', () {
    expect(excursionWebsiteSeed.where((trip) => trip.matches('Science Centre', null)), hasLength(1));
    expect(excursionWebsiteSeed.where((trip) => trip.matches('JSS 2', TripStatus.consentOpen)), hasLength(1));
    expect(excursionWebsiteSeed.where((trip) => trip.matches('museum', TripStatus.consentOpen)), isEmpty);
  });

  test('readiness review and serialization preserve safe trip fields', () {
    final reviewed = excursionWebsiteSeed.first.copyWith(readinessReviewed: true);
    final restored = SchoolTrip.fromJson(reviewed.toJson());
    expect(restored.readinessReviewed, isTrue);
    expect(restored.transport, '2 school buses');
    expect(restored.emergency, contains('pending final review'));
    expect(restored.toJson().keys, isNot(contains('medicalDetails')));
    expect(restored.toJson().keys, isNot(contains('familyInformation')));
  });

  test('departure and privacy rules remain explicit', () {
    expect(excursionDepartureChecks.keys, containsAll([
      'Guardian consent',
      'Transport manifest',
      'Emergency contacts',
      'Medical/access needs',
    ]));
    expect(excursionPrivacyRule, contains('should not expose sensitive medical or family information'));
    expect(excursionPrivacyRule, contains('minimum necessary safety information'));
  });
}
