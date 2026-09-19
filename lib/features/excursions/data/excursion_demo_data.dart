import '../domain/excursion_models.dart';

const excursionWebsiteSeed = <SchoolTrip>[
  SchoolTrip(
    id: 'TRIP-001',
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
  ),
  SchoolTrip(
    id: 'TRIP-002',
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
  ),
  SchoolTrip(
    id: 'TRIP-003',
    title: 'Early Years Nature Walk',
    audience: 'Reception A',
    date: '8 Oct 2026',
    destination: 'School botanical garden',
    coordinator: 'Mrs. Mary Daniel',
    students: 26,
    consentReceived: 21,
    transport: 'On-campus walking route',
    emergency: 'Group contact list ready',
    status: TripStatus.consentOpen,
    note: 'Short age-appropriate supervised nature activity within the school environment.',
  ),
  SchoolTrip(
    id: 'TRIP-004',
    title: 'Robotics Inter-School Showcase',
    audience: 'Coding & Robotics Club',
    date: '15 Oct 2026',
    destination: 'Innovation Hub',
    coordinator: 'Mr. Samuel Ter',
    students: 18,
    consentReceived: 18,
    transport: 'School minibus',
    emergency: 'Complete',
    status: TripStatus.ready,
    note: 'Club representation at an inter-school technology showcase.',
  ),
];

int get excursionConsentOutstanding => excursionWebsiteSeed.fold(
      0,
      (sum, trip) => sum + trip.consentOutstanding,
    );

const excursionDepartureChecks = <String, String>{
  'Guardian consent': 'Required where school policy says so.',
  'Transport manifest': 'Vehicle, adults and participant list.',
  'Emergency contacts': 'Accessible to authorized supervising staff.',
  'Medical/access needs': 'Handled privately and only where necessary for safe participation.',
};

const excursionPrivacyRule =
    'The general trip view should not expose sensitive medical or family information. Supervisors receive only the minimum necessary safety information through restricted workflows later.';

List<ExcursionStat> excursionStats(List<SchoolTrip> trips) => [
      ExcursionStat('Planned trips', '${trips.length}', 'Representative current term'),
      ExcursionStat(
        'Consent outstanding',
        '${trips.fold<int>(0, (sum, trip) => sum + trip.consentOutstanding)}',
        'Across current mock trips',
      ),
      ExcursionStat(
        'Ready to go',
        '${trips.where((trip) => trip.status == TripStatus.ready).length}',
        'Consent + readiness complete',
      ),
      const ExcursionStat('Transport plans', '4', 'Linked per trip'),
      ExcursionStat(
        'Unreviewed readiness',
        '${trips.where((trip) => !trip.readinessReviewed).length}',
        'Offline review state',
      ),
    ];
