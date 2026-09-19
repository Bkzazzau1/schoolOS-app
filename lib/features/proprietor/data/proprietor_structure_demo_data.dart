import '../domain/proprietor_structure_models.dart';

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

const initialAcademicSections = <AcademicSection>[
  AcademicSection(
    id: 'nursery',
    name: 'Nursery / Early Years',
    stage: 'Nursery',
    campus: 'Kaduna Campus',
    leaderTitle: 'Head Teacher',
    leaderName: 'Mrs. Mary Daniel',
    classes: 2,
  ),
  AcademicSection(
    id: 'primary',
    name: 'Primary School',
    stage: 'Primary',
    campus: 'Kaduna Campus',
    leaderTitle: 'Headmistress',
    leaderName: 'Mrs. Hauwa Sule',
    classes: 6,
  ),
  AcademicSection(
    id: 'secondary',
    name: 'Secondary School',
    stage: 'Secondary',
    campus: 'Kaduna Campus',
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

const proprietorAuthorityMatrix = <AuthorityMatrixRow>[
  AuthorityMatrixRow(
    role: 'Proprietor / Owner',
    students: 'All',
    teachers: 'All',
    assignments: 'Can override',
    results: 'All',
    schoolIdentity: 'Manage',
  ),
  AuthorityMatrixRow(
    role: 'Principal · Secondary',
    students: 'Secondary',
    teachers: 'Secondary',
    assignments: 'Secondary',
    results: 'Secondary',
    schoolIdentity: 'No',
  ),
  AuthorityMatrixRow(
    role: 'Headmaster / Headmistress · Primary',
    students: 'Primary',
    teachers: 'Primary',
    assignments: 'Primary',
    results: 'Primary',
    schoolIdentity: 'No',
  ),
  AuthorityMatrixRow(
    role: 'Head Teacher · Nursery',
    students: 'Nursery',
    teachers: 'Nursery',
    assignments: 'Nursery',
    results: 'Nursery',
    schoolIdentity: 'No',
  ),
  AuthorityMatrixRow(
    role: 'HOD / Coordinator',
    students: 'Delegated',
    teachers: 'Delegated',
    assignments: 'Only if permitted',
    results: 'Delegated',
    schoolIdentity: 'No',
  ),
];

const proprietorAccessResolution = <String>[
  'User',
  'School',
  'Campus',
  'Academic Section',
  'Role + Permissions',
  'Allowed records',
];
