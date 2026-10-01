import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/excursions/data/excursion_policy_copy.dart';
import 'package:schoolos_app/features/excursions/domain/excursion_models.dart';

List<SchoolTrip> _trips() => const [
      SchoolTrip(
        id: 'TRIP-TEST-001',
        title: 'Science Discovery Trip',
        audience: 'JSS 2',
        date: '26 Sep 2026',
        destination: 'Kaduna Science Centre',
        coordinator: 'Science Department',
        students: 86,
        consentReceived: 68,
        transport: '2 school buses',
        emergency: 'Manifest + emergency contacts pending final review',
        status: TripStatus.consentOpen,
        note: 'Science learning visit with supervised groups and guardian approval.',
        termId: 'term-1',
        termName: 'First Term',
        sessionName: '2026/2027',
        classId: 'class-jss2a',
        className: 'JSS 2A',
      ),
      SchoolTrip(
        id: 'TRIP-TEST-002',
        title: 'Primary 6 Museum Visit',
        audience: 'Primary 6',
        date: '3 Oct 2026',
        destination: 'Kaduna Museum',
        coordinator: 'Primary School',
        students: 34,
        consentReceived: 34,
        transport: '1 school bus',
        emergency: 'Complete',
        status: TripStatus.ready,
        note: 'History and cultural-learning visit with class-teacher supervision.',
        termId: 'term-1',
        termName: 'First Term',
        sessionName: '2026/2027',
      ),
    ];

void main() {
  test('excursion stats are computed entirely from the real trips given, never a fixed sample', () {
    final stats = excursionStats(_trips());
    expect(stats[0].value, '2');
    expect(stats[1].value, '18', reason: '(86-68) + (34-34) = 18');
    expect(stats[2].value, '1');
    expect(stats[3].value, '2');

    final empty = excursionStats(const []);
    expect(empty.every((s) => s.value == '0'), isTrue);
  });

  test('consent percentages match real trip data', () {
    expect(_trips()[0].consentPercent, 79);
    expect(_trips()[1].consentPercent, 100);
  });

  test('search and status filters match trip, destination and audience', () {
    final trips = _trips();
    expect(trips.where((trip) => trip.matches('Science Centre', null)), hasLength(1));
    expect(trips.where((trip) => trip.matches('JSS 2', TripStatus.consentOpen)), hasLength(1));
    expect(trips.where((trip) => trip.matches('museum', TripStatus.consentOpen)), isEmpty);
  });

  test('readiness review and serialization preserve safe trip fields', () {
    final reviewed = _trips().first.copyWith(readinessReviewed: true);
    final restored = SchoolTrip.fromJson(reviewed.toJson());
    expect(restored.readinessReviewed, isTrue);
    expect(restored.transport, '2 school buses');
    expect(restored.emergency, contains('pending final review'));
    expect(restored.toJson().keys, isNot(contains('medicalDetails')));
    expect(restored.toJson().keys, isNot(contains('familyInformation')));
  });

  test('a trip with a real term is distinguished from one without', () {
    expect(_trips().first.hasCanonicalTerm, isTrue);
    const noTerm = SchoolTrip(
      id: 'TRIP-TEST-003',
      title: 'Untitled',
      audience: '',
      date: '',
      destination: '',
      coordinator: '',
      students: 0,
      consentReceived: 0,
      transport: '',
      emergency: '',
      status: TripStatus.planning,
      note: '',
    );
    expect(noTerm.hasCanonicalTerm, isFalse);
  });

  test('departure and privacy rules remain explicit', () {
    expect(excursionDepartureChecks.keys, containsAll([
      'Guardian consent',
      'Transport manifest',
      'Emergency contacts',
      'Medical/access needs',
    ]));
    expect(excursionPrivacyRule, contains('safety information privately'));
    expect(excursionPrivacyRule, contains('authorized supervisor'));
  });
}
