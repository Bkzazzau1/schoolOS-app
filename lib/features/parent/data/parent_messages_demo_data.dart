import '../domain/parent_messages_models.dart';

const parentDefaultMessages = ParentMessagesSnapshot(
  familyAccountId: 'FAM-BGA-0042',
  threads: [
    ParentMessageThread(
      id: 'M1',
      participantName: 'Mrs. Amina Yusuf',
      participantRole: 'Class Teacher · JSS 2A',
      childLabel: 'Maryam Abdullahi',
      preview: 'Maryam completed the Mathematics assessment well today.',
      timeLabel: '16:20',
      unread: true,
      approvedParticipant: true,
      messages: [
        ParentMessageItem(
          id: 'M1-S1',
          direction: ParentMessageDirection.schoolToGuardian,
          authorLabel: 'Mrs. Amina Yusuf',
          body: 'Maryam completed the Mathematics assessment well today.',
          timeLabel: '16:20',
          state: ParentMessageState.received,
        ),
        ParentMessageItem(
          id: 'M1-G1',
          direction: ParentMessageDirection.guardianToSchool,
          authorLabel: 'You',
          body: 'Thank you. I have seen this update and will follow up at home.',
          timeLabel: '16:34',
          state: ParentMessageState.delivered,
        ),
      ],
    ),
    ParentMessageThread(
      id: 'M2',
      participantName: 'Mrs. Khadija Musa',
      participantRole: 'Class Teacher · Primary 3',
      childLabel: 'Hafsa Abdullahi',
      preview: 'Please continue the short reading practice at home this week.',
      timeLabel: 'Yesterday',
      unread: false,
      approvedParticipant: true,
      messages: [
        ParentMessageItem(
          id: 'M2-S1',
          direction: ParentMessageDirection.schoolToGuardian,
          authorLabel: 'Mrs. Khadija Musa',
          body: 'Please continue the short reading practice at home this week.',
          timeLabel: 'Yesterday',
          state: ParentMessageState.received,
        ),
        ParentMessageItem(
          id: 'M2-G1',
          direction: ParentMessageDirection.guardianToSchool,
          authorLabel: 'You',
          body: 'Thank you. We will continue the short reading practice at home.',
          timeLabel: 'Yesterday',
          state: ParentMessageState.read,
        ),
      ],
    ),
    ParentMessageThread(
      id: 'M3',
      participantName: 'School Finance Office',
      participantRole: 'Finance',
      childLabel: 'Family account',
      preview: 'Your September payment receipt is available.',
      timeLabel: '12 Sep',
      unread: false,
      approvedParticipant: true,
      messages: [
        ParentMessageItem(
          id: 'M3-S1',
          direction: ParentMessageDirection.schoolToGuardian,
          authorLabel: 'School Finance Office',
          body: 'Your September payment receipt is available.',
          timeLabel: '12 Sep',
          state: ParentMessageState.received,
        ),
      ],
    ),
  ],
);

const parentMessagesPrivacyBoundary =
    'Guardians can message only approved school participants connected to their family account. Internal staff information and other families remain outside family access.';

const parentMessagesDeliveryBoundary =
    'Offline replies are stored as Queued. Queued does not mean Sent, Delivered or Read. Later states require synchronization acknowledgement.';
