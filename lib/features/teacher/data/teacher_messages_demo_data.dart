import '../domain/teacher_messages_models.dart';

const teacherMessageThreads = <TeacherMessageThread>[
  TeacherMessageThread(id: 'thread-1', name: 'JSS 2A Guardians', type: TeacherMessageChannelType.parentGroup, preview: 'Reminder: assignment closes tomorrow.', timeLabel: '9:42 AM', unread: 3, className: 'JSS 2A'),
  TeacherMessageThread(id: 'thread-2', name: 'Academic Office', type: TeacherMessageChannelType.schoolLeadership, preview: 'Week 6 lesson-plan review completed.', timeLabel: 'Yesterday', unread: 0),
  TeacherMessageThread(id: 'thread-3', name: 'JSS 2B Guardians', type: TeacherMessageChannelType.parentGroup, preview: 'Revision support notice has been shared.', timeLabel: 'Yesterday', unread: 1, className: 'JSS 2B'),
  TeacherMessageThread(id: 'thread-4', name: 'Mathematics Department', type: TeacherMessageChannelType.staffChannel, preview: 'Department meeting moved to Thursday.', timeLabel: 'Mon', unread: 0),
];

const teacherMessageSeedMessages = <TeacherMessage>[
  TeacherMessage(id: 'msg-seed-1', threadId: 'thread-1', direction: TeacherMessageDirection.outgoing, body: 'Good morning. This is a reminder that the JSS 2A linear-equations assignment closes tomorrow at 6:00 PM.', timeLabel: '9:18 AM', deliveryState: TeacherMessageDeliveryState.read, serverMessageId: 'server-msg-1'),
  TeacherMessage(id: 'msg-seed-2', threadId: 'thread-1', direction: TeacherMessageDirection.incoming, body: 'Thank you. Is the revision sheet available inside SchoolOS?', timeLabel: '9:31 AM', deliveryState: TeacherMessageDeliveryState.received, serverMessageId: 'server-msg-2'),
  TeacherMessage(id: 'msg-seed-3', threadId: 'thread-1', direction: TeacherMessageDirection.outgoing, body: 'Yes. It is attached to the assignment page and students can access it from their portal.', timeLabel: '9:42 AM', deliveryState: TeacherMessageDeliveryState.read, serverMessageId: 'server-msg-3'),
];

const teacherMessageAiDraft = 'Dear guardian, I am sharing a short academic progress update for your child. Please review the latest assignment and revision guidance in SchoolOS.';

const teacherMessageDeliveryBoundary = 'A locally queued message is not sent, delivered or read. Only authoritative server or messaging-provider acknowledgements may advance delivery state.';
const teacherMessagePrivacyBoundary = 'Teachers communicate only through approved SchoolOS channels linked to their assigned classes or school role. Private guardian phone numbers and email addresses remain hidden.';
const teacherMessageAiBoundary = 'Teacher AI may draft concise school communication, but the teacher must review and explicitly queue the message. AI cannot send autonomously.';
