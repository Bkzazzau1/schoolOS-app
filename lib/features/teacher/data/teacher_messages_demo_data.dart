import '../domain/teacher_messages_models.dart';

// Guardian-group (parentGroup) channels are no longer demo furniture - they are real, built from
// the teacher's own real assigned classes in teacher_messages_repository.dart, and a real send
// fans out into the same real parent_message channel ParentMessagesRepository/
// TeacherFamilyMessagesRepository already use. Only the two channel types with no real backend
// yet (staff/leadership) stay demo content, unchanged.
const teacherMessageThreads = <TeacherMessageThread>[
  TeacherMessageThread(id: 'thread-2', name: 'Academic Office', type: TeacherMessageChannelType.schoolLeadership, preview: 'Week 6 lesson-plan review completed.', timeLabel: 'Yesterday', unread: 0),
  TeacherMessageThread(id: 'thread-4', name: 'Mathematics Department', type: TeacherMessageChannelType.staffChannel, preview: 'Department meeting moved to Thursday.', timeLabel: 'Mon', unread: 0),
];

const teacherMessageSeedMessages = <TeacherMessage>[];

const teacherMessageAiDraft = 'Dear guardian, I am sharing a short academic progress update for your child. Please review the latest assignment and revision guidance in SchoolOS.';

const teacherMessageDeliveryBoundary = 'A locally queued message is not sent, delivered or read. Only authoritative server or messaging-provider acknowledgements may advance delivery state.';
const teacherMessagePrivacyBoundary = 'Teachers communicate only through approved SchoolOS channels linked to their assigned classes or school role. Private guardian phone numbers and email addresses remain hidden.';
const teacherMessageAiBoundary = 'Teacher AI may draft concise school communication, but the teacher must review and explicitly queue the message. AI cannot send autonomously.';
