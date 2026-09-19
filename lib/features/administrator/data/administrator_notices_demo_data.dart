import '../domain/administrator_notices_models.dart';

const administratorNoticesWebsiteSeed = <AdministratorNotice>[
  AdministratorNotice(
    id: 'NOTICE-001',
    title: 'Term fee reminder',
    audience: AdministratorNoticeAudience.parents,
    type: AdministratorNoticeType.feeReminder,
    message: '',
    status: AdministratorNoticeStatus.scheduled,
    createdLabel: 'Website seed',
  ),
  AdministratorNotice(
    id: 'NOTICE-002',
    title: 'Primary reading week',
    audience: AdministratorNoticeAudience.primary,
    type: AdministratorNoticeType.generalAdministration,
    message: '',
    status: AdministratorNoticeStatus.published,
    createdLabel: 'Website seed',
  ),
  AdministratorNotice(
    id: 'NOTICE-003',
    title: 'Staff document update',
    audience: AdministratorNoticeAudience.staff,
    type: AdministratorNoticeType.documentRequest,
    message: '',
    status: AdministratorNoticeStatus.draft,
    createdLabel: 'Website seed',
  ),
];

const administratorNoticeAudienceOptions = <AdministratorNoticeAudience>[
  AdministratorNoticeAudience.parents,
  AdministratorNoticeAudience.staff,
  AdministratorNoticeAudience.wholeSchool,
  AdministratorNoticeAudience.primary,
  AdministratorNoticeAudience.secondary,
];

const administratorNoticeTypeOptions = <AdministratorNoticeType>[
  AdministratorNoticeType.generalAdministration,
  AdministratorNoticeType.documentRequest,
  AdministratorNoticeType.feeReminder,
  AdministratorNoticeType.serviceUpdate,
];

const administratorNoticesAuthorityBoundary =
    'Community discussions are conversational; notices are authoritative school communication. Administrator publishing requires permission checks, approval rules and an audit trail.';

const administratorNoticesDraftBoundary =
    'Native offline Save notice creates a Draft only. It must not silently publish or schedule authoritative communication before the governed publishing workflow approves it.';
