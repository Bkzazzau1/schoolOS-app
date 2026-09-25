import '../domain/excursion_models.dart';

// These ids match the current-session/first-term/JSS-2A rows seeded by
// AdministratorAcademicsRepository, so a trip logged here links to the same
// real academic-structure records any role would see, not a lookalike.
const _currentSessionName = '2026/2027';
const _firstTermId = '41111111-1111-4111-8111-111111111111';
const _firstTermName = 'First Term';
const _jss2Id = '32222222-2222-4222-8222-222222222222';
const _jss2Name = 'JSS 2A';

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
    termId: _firstTermId,
    termName: _firstTermName,
    sessionName: _currentSessionName,
    classId: _jss2Id,
    className: _jss2Name,
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
    termId: _firstTermId,
    termName: _firstTermName,
    sessionName: _currentSessionName,
    // No Primary 6 class exists in the seeded academic structure yet, so this
    // stays without a single class link rather than pointing at a wrong one.
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
    termId: _firstTermId,
    termName: _firstTermName,
    sessionName: _currentSessionName,
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
    termId: _firstTermId,
    termName: _firstTermName,
    sessionName: _currentSessionName,
    // A club, not one class, so it has no single class link either.
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
