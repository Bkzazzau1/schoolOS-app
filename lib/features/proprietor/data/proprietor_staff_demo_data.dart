import '../domain/proprietor_staff_models.dart';

const proprietorStaffKpis = <OwnerStaffKpi>[
  OwnerStaffKpi(
    label: 'Teaching staff',
    value: '64',
    note: 'Across three sections',
  ),
  OwnerStaffKpi(
    label: 'Staff attendance',
    value: '96%',
    note: 'Current prototype average',
  ),
  OwnerStaffKpi(
    label: 'Heavy workload',
    value: '5',
    note: 'Review before new assignments',
  ),
  OwnerStaffKpi(
    label: 'Open vacancies',
    value: '2',
    note: 'Primary class teacher + lab support',
  ),
  OwnerStaffKpi(
    label: 'Contracts due',
    value: '7',
    note: 'Within next 60 days',
  ),
];

const proprietorLeadershipRows = <OwnerLeaderRow>[
  OwnerLeaderRow(
    name: 'Mrs. Maryam Abdullahi',
    role: 'Head Teacher',
    scope: 'Nursery / Early Years',
    team: '12 staff',
    signal: 'On track',
  ),
  OwnerLeaderRow(
    name: 'Mrs. Hauwa Sule',
    role: 'Headmistress',
    scope: 'Primary School',
    team: '28 staff',
    signal: 'On track',
  ),
  OwnerLeaderRow(
    name: 'Mr. Ibrahim Danladi',
    role: 'Principal',
    scope: 'Secondary School',
    team: '24 staff',
    signal: 'Review',
  ),
  OwnerLeaderRow(
    name: 'Mrs. Zainab Musa',
    role: 'Vice Principal Academics',
    scope: 'Secondary School',
    team: 'Academic leadership',
    signal: 'On track',
  ),
];

const proprietorPeopleAttention = <OwnerPeopleAttentionItem>[
  OwnerPeopleAttentionItem(
    title: 'Primary 6 class-teacher gap',
    detail: 'Assign a confirmed class teacher before the next planning cycle.',
    owner: 'Headmistress',
  ),
  OwnerPeopleAttentionItem(
    title: 'Five staff with heavy workload',
    detail: 'Review assignments before adding periods or administrative duties.',
    owner: 'Section leaders',
  ),
  OwnerPeopleAttentionItem(
    title: 'Seven contracts approaching renewal',
    detail: 'HR review should consider role need, documented performance context and policy—not an automatic score.',
    owner: 'HR / Proprietor',
  ),
];

const proprietorStaffMix = <OwnerStaffMixItem>[
  OwnerStaffMixItem(
    section: 'Early Years',
    count: 12,
    note: 'Educators + assistants',
  ),
  OwnerStaffMixItem(
    section: 'Primary',
    count: 28,
    note: 'Class + specialists',
  ),
  OwnerStaffMixItem(
    section: 'Secondary',
    count: 24,
    note: 'Subject teachers',
  ),
];

int get proprietorTeachingStaffTotal =>
    proprietorStaffMix.fold(0, (sum, item) => sum + item.count);
