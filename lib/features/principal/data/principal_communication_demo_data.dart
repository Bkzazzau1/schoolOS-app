import '../domain/principal_communication_models.dart';

const principalCommunicationThreads = <PrincipalCommunicationThread>[
  PrincipalCommunicationThread(
    id: 'MSG-201',
    title: 'JSS 2B attendance follow-up',
    person: 'Guardian C',
    context: 'Student Gamma · JSS 2B',
    time: '10:42 AM',
    unread: true,
    priority: PrincipalCommunicationPriority.urgent,
    preview: 'Thank you for reaching out. We are available to discuss the repeated absences and the support plan.',
  ),
  PrincipalCommunicationThread(
    id: 'MSG-202',
    title: 'Lesson-plan review',
    person: 'Mrs. Amina Yusuf',
    context: 'Teacher · Mathematics',
    time: '9:18 AM',
    unread: true,
    priority: PrincipalCommunicationPriority.important,
    preview: 'I have revised the Week 6 lesson plan based on the comments and sent it back for review.',
  ),
  PrincipalCommunicationThread(
    id: 'MSG-203',
    title: 'SS 1A Physics support',
    person: 'Mr. Peter James',
    context: 'Teacher · Science',
    time: 'Yesterday',
    unread: false,
    priority: PrincipalCommunicationPriority.normal,
    preview: 'I propose a targeted revision class before the next topic test.',
  ),
  PrincipalCommunicationThread(
    id: 'MSG-204',
    title: 'Report card release',
    person: 'Vice Principal Academics',
    context: 'Academic office',
    time: 'Yesterday',
    unread: false,
    priority: PrincipalCommunicationPriority.important,
    preview: 'JSS 1A and JSS 3A report batches are ready for your final release confirmation.',
  ),
];

const principalRecentAnnouncements = <PrincipalRecentAnnouncement>[
  PrincipalRecentAnnouncement(
    id: 'ANN-61',
    title: 'First Term Mid-Term Review',
    audience: 'Whole School',
    channel: 'Portal + SMS',
    sent: '12 Sep 2026',
    delivered: '97%',
    read: '82%',
  ),
  PrincipalRecentAnnouncement(
    id: 'ANN-60',
    title: 'Staff Academic Review Meeting',
    audience: 'Staff',
    channel: 'Portal',
    sent: '11 Sep 2026',
    delivered: '100%',
    read: '94%',
  ),
  PrincipalRecentAnnouncement(
    id: 'ANN-59',
    title: 'JSS 2B Attendance Notice',
    audience: 'Class Guardians',
    channel: 'SMS + Portal',
    sent: '10 Sep 2026',
    delivered: '96%',
    read: '79%',
  ),
];

const principalCommunicationFollowUps = <PrincipalCommunicationFollowUp>[
  PrincipalCommunicationFollowUp(
    id: 'FU-1',
    title: 'Student Gamma',
    context: 'JSS 2B · 4 absences in 10 days',
    action: 'Guardian contact',
    status: 'Due today',
    targetKey: 'students',
  ),
  PrincipalCommunicationFollowUp(
    id: 'FU-2',
    title: 'Mr. Peter James',
    context: 'Science · second absence this month',
    action: 'Staff check-in',
    status: 'Due today',
    targetKey: 'teachers',
  ),
  PrincipalCommunicationFollowUp(
    id: 'FU-3',
    title: 'JSS 2B',
    context: 'Academic + attendance decline',
    action: 'Class guardian notice',
    status: 'This week',
    targetKey: 'academics',
  ),
];

const principalCommunicationAudiences = <PrincipalCommunicationAudience>[
  PrincipalCommunicationAudience.staff,
  PrincipalCommunicationAudience.guardians,
  PrincipalCommunicationAudience.classGuardians,
  PrincipalCommunicationAudience.individual,
  PrincipalCommunicationAudience.wholeSchool,
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

const principalCommunicationTermAnnouncementCount = 12;
const principalCommunicationDeliveryRate = 97;
const principalGuardianResponseRate = 84;

const principalQuickReply = 'Thank you for your response. We will coordinate the next step and keep you informed.';
const principalAttendanceTemplateSubject = 'Attendance follow-up';
const principalAttendanceTemplateMessage =
    'Dear Parent/Guardian, we are contacting you regarding recent attendance concerns. Please contact the school so we can work together on a suitable support plan. Thank you.';

const principalCommunicationPrivacyBoundary =
    'Only authorized school users and linked guardians receive student-specific information. Cross-school messaging is not permitted.';
const principalCommunicationOfflineBoundary =
    'Replies and announcements may be queued fully offline. SMS, Email and WhatsApp delivery is never claimed until the external channel adapter confirms delivery after connectivity returns.';
const principalCommunicationScopeBoundary =
    'The Principal communication audience is constrained to the authorized Secondary leadership scope; Primary and Early Years recipients require their own authorized leadership role.';
