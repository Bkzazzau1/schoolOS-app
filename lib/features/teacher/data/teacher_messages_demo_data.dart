// Every channel type Teacher Messages shows is real now, built in teacher_messages_repository.dart:
// guardian-group broadcasts from the teacher's own real assigned classes, a real leadership thread
// per real teacher, and a real, shared thread per real subject a teacher currently teaches. Only
// the constants below - which never described a channel or a message - remain.

const teacherMessageAiDraft = 'Dear guardian, I am sharing a short academic progress update for your child. Please review the latest assignment and revision guidance in SchoolOS.';

const teacherMessageDeliveryBoundary = 'A locally queued message is not sent, delivered or read. Only authoritative server or messaging-provider acknowledgements may advance delivery state.';
const teacherMessagePrivacyBoundary = 'Teachers communicate only through approved SchoolOS channels linked to their assigned classes or school role. Private guardian phone numbers and email addresses remain hidden.';
const teacherMessageAiBoundary = 'Teacher AI may draft concise school communication, but the teacher must review and explicitly queue the message. AI cannot send autonomously.';
