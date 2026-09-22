import '../domain/principal_communication_models.dart';

const principalCommunicationAudiences = <PrincipalCommunicationAudience>[
  PrincipalCommunicationAudience.staff,
  PrincipalCommunicationAudience.guardians,
];

const principalCommunicationChannels = <PrincipalCommunicationChannel>[
  PrincipalCommunicationChannel.portal,
  PrincipalCommunicationChannel.sms,
  PrincipalCommunicationChannel.email,
  PrincipalCommunicationChannel.whatsApp,
];

const principalCommunicationPermissions = PrincipalCommunicationPermissions(
  canViewSecondaryCommunication: true,
  canQueueMessages: true,
  canMessagePrimaryOrEarlyYears: false,
  canCrossSchoolMessage: false,
);

const principalQuickReply =
    'Thank you for your response. We will coordinate the next step and keep you informed.';
const principalAttendanceTemplateSubject = 'Attendance follow-up';
const principalAttendanceTemplateMessage =
    'Dear Parent/Guardian, please review the attendance records available in SchoolOS and contact the school with any questions. Thank you.';

const principalCommunicationPrivacyBoundary =
    'Only authorized school users and linked guardians receive student-specific information. Cross-school messaging is not permitted.';
const principalCommunicationOfflineBoundary =
    'Replies and announcements may be queued fully offline. SMS, Email and WhatsApp delivery is never claimed until the external channel adapter confirms delivery after connectivity returns.';
const principalCommunicationScopeBoundary =
    'The Principal communication audience is constrained to the authorized Secondary leadership scope; Primary and Early Years recipients require their own authorized leadership role.';
