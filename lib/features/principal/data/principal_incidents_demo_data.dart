import '../domain/principal_incidents_models.dart';

const principalIncidentCases = <PrincipalIncident>[
  PrincipalIncident(
    id: 'INC-2401',
    title: 'Repeated classroom disruption',
    category: PrincipalIncidentCategory.behaviour,
    severity: PrincipalIncidentSeverity.medium,
    status: PrincipalIncidentStatus.monitoring,
    person: 'Student Beta',
    context: 'JSS 2A',
    reportedBy: 'Mrs. Amina Yusuf',
    owner: 'Vice Principal Academics',
    reportedAt: 'Today · 10:18 AM',
    location: 'Block B · Room 12',
    guardianContact: PrincipalGuardianContact.contacted,
    evidenceCount: 1,
    summary: 'Repeated disruption was documented across two lessons. A restorative conversation has been completed and classroom behaviour is being monitored.',
    nextAction: 'Review behaviour after the next three school days.',
  ),
  PrincipalIncident(
    id: 'INC-2402',
    title: 'Student welfare concern',
    category: PrincipalIncidentCategory.safeguarding,
    severity: PrincipalIncidentSeverity.high,
    status: PrincipalIncidentStatus.investigating,
    person: 'Student Gamma',
    context: 'JSS 2B',
    reportedBy: 'Mrs. Fatima Bello',
    owner: 'Principal',
    reportedAt: 'Today · 8:42 AM',
    location: 'Counselling Office',
    guardianContact: PrincipalGuardianContact.pending,
    evidenceCount: 2,
    summary: 'A welfare concern was escalated for restricted leadership review. Detailed sensitive notes are intentionally not shown in the general incident list.',
    nextAction: 'Complete restricted safeguarding review and document authorized follow-up.',
  ),
  PrincipalIncident(
    id: 'INC-2403',
    title: 'Repeated late arrival',
    category: PrincipalIncidentCategory.attendance,
    severity: PrincipalIncidentSeverity.low,
    status: PrincipalIncidentStatus.open,
    person: 'Student Epsilon',
    context: 'SS 1A',
    reportedBy: 'Attendance Office',
    owner: 'Year Coordinator',
    reportedAt: 'Yesterday · 1:10 PM',
    location: 'Main Gate',
    guardianContact: PrincipalGuardianContact.pending,
    evidenceCount: 0,
    summary: 'Three late arrivals were recorded within the current week and require a routine attendance follow-up.',
    nextAction: 'Contact guardian and agree an arrival-time improvement plan.',
  ),
  PrincipalIncident(
    id: 'INC-2399',
    title: 'Damaged laboratory equipment',
    category: PrincipalIncidentCategory.property,
    severity: PrincipalIncidentSeverity.medium,
    status: PrincipalIncidentStatus.resolved,
    person: 'Science Lab Group',
    context: 'SS 2A',
    reportedBy: 'Mr. Peter James',
    owner: 'Principal',
    reportedAt: '11 Sep · 12:25 PM',
    location: 'Science Laboratory 2',
    guardianContact: PrincipalGuardianContact.notRequired,
    evidenceCount: 3,
    summary: 'Equipment damage was documented, replacement was approved, and the laboratory safety reminder was completed.',
    nextAction: 'No further action unless the issue repeats.',
  ),
  PrincipalIncident(
    id: 'INC-2398',
    title: 'Wet corridor slip hazard',
    category: PrincipalIncidentCategory.healthSafety,
    severity: PrincipalIncidentSeverity.high,
    status: PrincipalIncidentStatus.resolved,
    person: 'Facilities',
    context: 'Administration Block',
    reportedBy: 'Front Office',
    owner: 'Operations Lead',
    reportedAt: '10 Sep · 9:02 AM',
    location: 'Administration Block',
    guardianContact: PrincipalGuardianContact.notRequired,
    evidenceCount: 2,
    summary: 'A temporary slip hazard was isolated immediately, cleaned, marked and closed after facilities verification.',
    nextAction: 'Include the location in the next facilities inspection.',
  ),
];

const principalIncidentActivity = <({String time, String text})>[
  (time: '10:32 AM', text: 'Principal restricted access applied to INC-2402.'),
  (time: '10:20 AM', text: 'Behaviour follow-up note added to INC-2401.'),
  (time: '9:05 AM', text: 'Guardian-contact task created for INC-2403.'),
  (time: 'Yesterday', text: 'INC-2399 marked resolved after replacement approval.'),
];

const principalIncidentCategories = <String>[
  'All categories',
  'Behaviour',
  'Safeguarding',
  'Attendance',
  'Health & Safety',
  'Property',
];

const principalIncidentStatuses = <String>[
  'All statuses',
  'Open',
  'Investigating',
  'Monitoring',
  'Resolved',
];

const principalIncidentSeverities = <String>[
  'All severities',
  'Low',
  'Medium',
  'High',
  'Critical',
];

const principalIncidentResolvedThisTerm = 18;

const principalIncidentRestrictedBoundary =
    'Restricted safeguarding case: only authorized safeguarding/leadership users should see sensitive case details. General staff views receive the minimum necessary information.';

const principalIncidentAuditBoundary =
    'Case changes, internal notes, evidence references and decisions must remain attributable and append-only; resolving a case never erases its history.';

const principalIncidentAiBoundary =
    'AI may surface patterns for human review, but cannot determine safeguarding or disciplinary outcomes.';

const principalIncidentAuthorityBoundary =
    'Principal incident authority is limited to the Secondary section. Primary and Early Years cases require their authorized leadership roles.';

const principalIncidentAiInsight =
    'Prototype pattern: JSS 2B currently carries both attendance and welfare signals. Treat these as potentially connected indicators for human review, not as an automated conclusion. Sensitive safeguarding decisions must remain with authorized people.';
