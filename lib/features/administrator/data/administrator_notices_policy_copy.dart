import '../domain/administrator_notices_models.dart';

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
    'Native offline Save notice creates a Draft only. It must not silently publish or schedule authoritative communication before the governed approval workflow completes.';
