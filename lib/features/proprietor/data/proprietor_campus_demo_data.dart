import '../domain/proprietor_campus_models.dart';

const proprietorCampusKpis = <OwnerCampusKpi>[
  OwnerCampusKpi(
    label: 'Active campuses',
    value: '1',
    note: 'Kaduna operational',
  ),
  OwnerCampusKpi(
    label: 'Planned campuses',
    value: '1',
    note: 'Zaria concept',
  ),
  OwnerCampusKpi(
    label: 'Total enrollment',
    value: '648',
    note: 'Active-campus total',
  ),
  OwnerCampusKpi(
    label: 'Staff',
    value: '64',
    note: 'Teaching staff sample',
  ),
  OwnerCampusKpi(
    label: 'Expansion readiness',
    value: 'Planning',
    note: 'Not yet approved',
  ),
];

const proprietorCampuses = <OwnerCampusSummary>[
  OwnerCampusSummary(
    name: 'Kaduna Campus',
    status: CampusStatus.active,
    students: 648,
    staff: 64,
    attendancePercent: 92,
    feeCollectionPercent: 94,
    academicPercent: 81,
    leader: 'Whole-school leadership team',
    description:
        'Current full school operation with Nursery, Primary and Secondary.',
    readinessNote:
        'Leadership: Whole-school leadership team. Academic indicator 81%.',
  ),
  OwnerCampusSummary(
    name: 'Zaria Campus',
    status: CampusStatus.planned,
    students: 0,
    staff: 0,
    attendancePercent: 0,
    feeCollectionPercent: 0,
    academicPercent: 0,
    leader: 'Not appointed',
    description:
        'Future branch placeholder. No students, staff or finance should be counted until formally activated.',
    readinessNote:
        'Before activation: define campus leadership, sections, fee policy, staffing, transport, safety and operating calendar.',
  ),
];

const proprietorCampusExpansionChecklist = <OwnerCampusChecklistItem>[
  OwnerCampusChecklistItem(
    title: 'Governance & leadership',
    detail: 'Campus head, section leaders and delegated authority defined.',
  ),
  OwnerCampusChecklistItem(
    title: 'Capacity & staffing',
    detail:
        'Classrooms, teachers, support staff and timetable readiness reviewed.',
  ),
  OwnerCampusChecklistItem(
    title: 'Finance configuration',
    detail:
        'Fee structure, accounts, collection channels and reporting scope configured.',
  ),
  OwnerCampusChecklistItem(
    title: 'Safety & operations',
    detail:
        'Transport, visitor controls, health, safeguarding and emergency procedures configured.',
  ),
];

const proprietorCampusIsolationPrinciple =
    'A staff member appointed to Kaduna Campus should not automatically see or manage Zaria Campus. In production, campus scope must be enforced before records reach the user or AI context.';

int get activeCampusEnrollment => proprietorCampuses
    .where((campus) => campus.isActive)
    .fold(0, (total, campus) => total + campus.students);

int get activeCampusStaff => proprietorCampuses
    .where((campus) => campus.isActive)
    .fold(0, (total, campus) => total + campus.staff);
