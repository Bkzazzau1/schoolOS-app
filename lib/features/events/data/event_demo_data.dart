import '../domain/event_models.dart';

const eventWebsiteSeed = <SchoolEvent>[
  SchoolEvent(
    id: 'EV-001',
    title: 'Parent–Teacher Conference',
    type: SchoolEventType.parents,
    audience: 'Primary + Secondary families',
    date: '18 Sep 2026',
    time: '9:00 AM–2:00 PM',
    venue: 'Classrooms',
    owner: 'Academic Leadership',
    status: SchoolEventStatus.scheduled,
    note:
        'Appointment windows by class; families can see only their allocated child/class meetings.',
  ),
  SchoolEvent(
    id: 'EV-002',
    title: 'Inter-House Sports Day',
    type: SchoolEventType.sports,
    audience: 'Whole school',
    date: '24 Sep 2026',
    time: '8:00 AM–4:00 PM',
    venue: 'Main field',
    owner: 'Sports Committee',
    status: SchoolEventStatus.registrationOpen,
    note:
        'Athletics, relays and field events with house points and parent viewing areas.',
  ),
  SchoolEvent(
    id: 'EV-003',
    title: 'Early Years Family Morning',
    type: SchoolEventType.schoolWide,
    audience: 'Nursery / Early Years',
    date: '26 Sep 2026',
    time: '9:00 AM–11:30 AM',
    venue: 'Early Years courtyard',
    owner: 'Mrs. Mary Daniel',
    status: SchoolEventStatus.scheduled,
    note:
        'Play-based family activities, classroom showcase and routine guidance.',
  ),
  SchoolEvent(
    id: 'EV-004',
    title: 'JSS 3 Mock Examination',
    type: SchoolEventType.academic,
    audience: 'JSS 3',
    date: '5 Oct 2026',
    time: '8:00 AM',
    venue: 'Secondary blocks',
    owner: 'Principal Office',
    status: SchoolEventStatus.scheduled,
    note:
        'Multi-day examination window; timetable details remain in the academic module.',
  ),
  SchoolEvent(
    id: 'EV-005',
    title: 'Coding & Robotics Showcase',
    type: SchoolEventType.club,
    audience: 'Whole school',
    date: '10 Oct 2026',
    time: '11:00 AM–1:00 PM',
    venue: 'ICT Lab',
    owner: 'ICT Department',
    status: SchoolEventStatus.scheduled,
    note: 'Student projects, demonstrations and club recruitment.',
  ),
];

const eventThisMonthCount = 3;
const eventParentFacingCount = 3;
const eventRegistrationOpenCount = 1;
const eventCalendarConflicts = 0;

const eventAuthorityRule =
    'A section leader may create events for their section; whole-school events require school-wide authority. Parents and students see only events targeted to them.';

const eventAcademicBoundary =
    'Academic timetable periods remain separate from the shared school calendar.';

const eventFutureIntegrations = <String, String>{
  'Noticeboard': 'Turn an event into an official announcement.',
  'Activities & Clubs': 'Link fixtures, club sessions and showcases.',
  'Excursions': 'Attach consent and transport requirements.',
};
