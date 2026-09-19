import '../domain/proprietor_enrollment_models.dart';

const proprietorEnrollmentKpis = <OwnerEnrollmentKpi>[
  OwnerEnrollmentKpi(
    label: 'Active students',
    value: '648',
    note: '+29 net this session',
  ),
  OwnerEnrollmentKpi(
    label: 'New applications',
    value: '131',
    note: 'Current admission cycle',
  ),
  OwnerEnrollmentKpi(
    label: 'Offers issued',
    value: '100',
    note: '76% of applications',
  ),
  OwnerEnrollmentKpi(
    label: 'Accepted',
    value: '79',
    note: '79% offer conversion',
  ),
  OwnerEnrollmentKpi(
    label: 'Retention',
    value: '96%',
    note: 'Whole-school current estimate',
  ),
];

const proprietorEnrollmentPipeline = <OwnerEnrollmentPipelineRow>[
  OwnerEnrollmentPipelineRow(
    section: 'Nursery / Early Years',
    applications: 31,
    offers: 24,
    accepted: 18,
    activeStudents: 84,
    retentionPercent: 96,
  ),
  OwnerEnrollmentPipelineRow(
    section: 'Primary School',
    applications: 46,
    offers: 35,
    accepted: 29,
    activeStudents: 286,
    retentionPercent: 97,
  ),
  OwnerEnrollmentPipelineRow(
    section: 'Secondary School',
    applications: 54,
    offers: 41,
    accepted: 32,
    activeStudents: 278,
    retentionPercent: 95,
  ),
];

const proprietorCapacityWatch = <OwnerCapacityWatchItem>[
  OwnerCapacityWatchItem(
    title: 'Primary is nearing configured capacity',
    detail: '286 active pupils against a mock planning capacity of 320.',
    action: 'Consider classroom and staffing readiness before expansion',
  ),
  OwnerCapacityWatchItem(
    title: 'Secondary demand is strongest',
    detail: '54 applications in the current mock intake cycle.',
    action: 'Review science-lab and teacher capacity before accepting additional places',
  ),
  OwnerCapacityWatchItem(
    title: 'Early Years retention remains healthy',
    detail: '96% retention with 84 active children.',
    action: 'Family engagement remains a major retention driver',
  ),
];

const proprietorEnrollmentTrend = <int>[598, 612, 621, 630, 638, 644, 648];

const proprietorEnrollmentSnapshot = OwnerEnrollmentSnapshot(
  kpis: proprietorEnrollmentKpis,
  pipeline: proprietorEnrollmentPipeline,
  capacityWatch: proprietorCapacityWatch,
  trend: proprietorEnrollmentTrend,
);
