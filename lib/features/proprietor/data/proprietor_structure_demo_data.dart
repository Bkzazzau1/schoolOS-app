import '../domain/proprietor_structure_models.dart';

/// A real school's starting structure: the standard sections, with no leader
/// assigned yet and no made-up campus name. Used by
/// [ProprietorStructureRepository.setUpStandardStructure] for a real,
/// backend-connected school - never these invented names, which exist only for
/// the offline demo below.
const standardCampuses = <Campus>[
  Campus(id: 'main', name: 'Main Campus'),
];

const standardAcademicSections = <AcademicSection>[
  AcademicSection(
    id: 'nursery', name: 'Nursery / Early Years', stage: 'Nursery', campusId: 'main',
    leaderTitle: 'Head Teacher', leaderName: '', classes: 0,
  ),
  AcademicSection(
    id: 'primary', name: 'Primary School', stage: 'Primary', campusId: 'main',
    leaderTitle: 'Headmistress', leaderName: '', classes: 0,
  ),
  AcademicSection(
    id: 'secondary', name: 'Secondary School', stage: 'Secondary', campusId: 'main',
    leaderTitle: 'Principal', leaderName: '', classes: 0,
  ),
];

/// A brand-new real school has nobody appointed yet - the proprietor appoints
/// their own real staff from here (see [_HeadControl] and "Appoint leader").
const standardLeadershipAppointments = <LeadershipAppointment>[];

/// Illustrative names for the OFFLINE DEMO ONLY (no backend configured at
/// all - see LocalDatabase.blockDemoSeeds). Never shown or synced for a real,
/// backend-connected school.
const proprietorStructurePeople = <String>[
  'Mrs. Mary Daniel',
  'Mrs. Hauwa Sule',
  'Mr. Ibrahim Danladi',
  'Mrs. Grace Musa',
  'Mr. Daniel John',
  'Mrs. Amina Yusuf',
  'Mr. Peter James',
  'Mrs. Fatima Bello',
];

const initialCampuses = <Campus>[
  Campus(id: 'kaduna', name: 'Kaduna Campus'),
];

const initialAcademicSections = <AcademicSection>[
  AcademicSection(
    id: 'nursery',
    name: 'Nursery / Early Years',
    stage: 'Nursery',
    campusId: 'kaduna',
    leaderTitle: 'Head Teacher',
    leaderName: 'Mrs. Mary Daniel',
    classes: 2,
  ),
  AcademicSection(
    id: 'primary',
    name: 'Primary School',
    stage: 'Primary',
    campusId: 'kaduna',
    leaderTitle: 'Headmistress',
    leaderName: 'Mrs. Hauwa Sule',
    classes: 6,
  ),
  AcademicSection(
    id: 'secondary',
    name: 'Secondary School',
    stage: 'Secondary',
    campusId: 'kaduna',
    leaderTitle: 'Principal',
    leaderName: 'Mr. Ibrahim Danladi',
    classes: 6,
  ),
];

const initialLeadershipAppointments = <LeadershipAppointment>[
  LeadershipAppointment(
    id: 'L-001',
    person: 'Mrs. Mary Daniel',
    title: 'Head Teacher',
    level: LeadershipLevel.sectionHead,
    sectionId: 'nursery',
  ),
  LeadershipAppointment(
    id: 'L-002',
    person: 'Mrs. Hauwa Sule',
    title: 'Headmistress',
    level: LeadershipLevel.sectionHead,
    sectionId: 'primary',
  ),
  LeadershipAppointment(
    id: 'L-003',
    person: 'Mr. Ibrahim Danladi',
    title: 'Principal',
    level: LeadershipLevel.sectionHead,
    sectionId: 'secondary',
  ),
  LeadershipAppointment(
    id: 'L-004',
    person: 'Mrs. Grace Musa',
    title: 'Vice Principal Academics',
    level: LeadershipLevel.deputy,
    sectionId: 'secondary',
    reportsTo: 'L-003',
  ),
  LeadershipAppointment(
    id: 'L-005',
    person: 'Mr. Daniel John',
    title: 'HOD Mathematics',
    level: LeadershipLevel.hod,
    sectionId: 'secondary',
    department: 'Mathematics',
    reportsTo: 'L-004',
  ),
];

