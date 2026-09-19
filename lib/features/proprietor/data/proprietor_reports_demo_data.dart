import '../domain/proprietor_reports_models.dart';

const proprietorReportKpis = <OwnerReportKpi>[
  OwnerReportKpi(
    label: 'Report packs',
    value: '12',
    note: 'Current session',
  ),
  OwnerReportKpi(
    label: 'Scheduled',
    value: '4',
    note: 'Weekly / monthly / term',
  ),
  OwnerReportKpi(
    label: 'Owner KPIs',
    value: '18',
    note: 'Across major functions',
  ),
  OwnerReportKpi(
    label: 'Open exceptions',
    value: '4',
    note: 'Need context before closure',
  ),
  OwnerReportKpi(
    label: 'Last executive pack',
    value: '12 Sep',
    note: 'Current prototype date',
  ),
];

const proprietorExecutiveReports = <OwnerExecutiveReport>[
  OwnerExecutiveReport(
    title: 'Executive Term Review',
    coverage: 'Finance · enrollment · attendance · academic · operations',
    updated: 'Updated today',
    status: 'Ready',
  ),
  OwnerExecutiveReport(
    title: 'Finance Collection Report',
    coverage: 'Billing · collections · outstanding · financing',
    updated: 'Updated 17:20',
    status: 'Ready',
  ),
  OwnerExecutiveReport(
    title: 'Enrollment & Retention Report',
    coverage: 'Applications · conversion · active enrollment · retention',
    updated: 'Updated today',
    status: 'Ready',
  ),
  OwnerExecutiveReport(
    title: 'Staff & Leadership Report',
    coverage: 'Staffing · attendance · workload · leadership context',
    updated: 'Updated today',
    status: 'Ready',
  ),
  OwnerExecutiveReport(
    title: 'School Life & Operations Report',
    coverage: 'Activities · transport · events · incidents · visitors',
    updated: 'Updated today',
    status: 'Ready',
  ),
];

const proprietorReportPackSections = <OwnerReportPackSection>[
  OwnerReportPackSection(
    number: 1,
    title: 'Executive summary',
    description: 'Top changes, risks, decisions and follow-up owners.',
  ),
  OwnerReportPackSection(
    number: 2,
    title: 'Finance & enrollment',
    description: 'Collections, arrears, enrollment movement and retention.',
  ),
  OwnerReportPackSection(
    number: 3,
    title: 'Academic & attendance',
    description: 'Section trends with context, not a single opaque score.',
  ),
  OwnerReportPackSection(
    number: 4,
    title: 'People & operations',
    description: 'Staffing, workload, transport, School Life and major incidents.',
  ),
];

const proprietorReportCadence = <OwnerReportCadence>[
  OwnerReportCadence(
    frequency: 'Weekly',
    reportType: 'Operations',
    purpose: 'Exceptions + owner queue',
  ),
  OwnerReportCadence(
    frequency: 'Monthly',
    reportType: 'Executive',
    purpose: 'Finance + people + enrollment',
  ),
  OwnerReportCadence(
    frequency: 'Termly',
    reportType: 'Board',
    purpose: 'Full-school review',
  ),
];

const proprietorReportingPrinciple =
    'Reports should preserve the source context behind indicators, distinguish missing data from poor performance, and clearly label mock/estimated values. AI may summarize evidence, but should not fabricate causes or silently turn operational metrics into employment or student judgments.';
