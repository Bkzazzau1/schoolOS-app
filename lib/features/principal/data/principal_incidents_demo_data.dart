// Reference filters only; no fabricated cases or activity.
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

const principalIncidentRestrictedBoundary =
    'Restricted safeguarding case: only authorized safeguarding/leadership users should see sensitive case details. General staff views receive the minimum necessary information.';

const principalIncidentAuditBoundary =
    'Case changes, internal notes, evidence references and decisions must remain attributable and append-only; resolving a case never erases its history.';

const principalIncidentAiBoundary =
    'AI may surface patterns for human review, but cannot determine safeguarding or disciplinary outcomes.';

const principalIncidentAuthorityBoundary =
    'Principal incident authority is limited to the Secondary section. Primary and Early Years cases require their authorized leadership roles.';

const principalIncidentAiInsight =
    'No automated case evaluation is available. Review recorded evidence with authorized staff.';
