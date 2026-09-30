import '../../parent/domain/parent_messages_models.dart';

/// A real family conversation, from the class teacher's own side. Reuses [ParentMessageThread] and
/// [ParentMessageItem] as-is rather than duplicating them — both sides read and write the exact same
/// server-side `parent_message` row (`apps/schoollife/messaging/parent_messages.py`), just from the
/// other real participant's point of view. This is a separate, teacher-scoped surface, not a merge
/// into `TeacherMessagesRepository`'s own class-wide broadcast channels, which stay exactly as they
/// are.
class TeacherFamilyMessagesSnapshot {
  const TeacherFamilyMessagesSnapshot({
    required this.teacherMembershipId,
    required this.threads,
  });

  final String teacherMembershipId;
  final List<ParentMessageThread> threads;

  ParentMessageThread? threadById(String id) {
    for (final thread in threads) {
      if (thread.id == id) return thread;
    }
    return null;
  }

  TeacherFamilyMessagesSnapshot replaceThread(ParentMessageThread replacement) =>
      TeacherFamilyMessagesSnapshot(
        teacherMembershipId: teacherMembershipId,
        threads: [
          for (final thread in threads)
            if (thread.id == replacement.id) replacement else thread,
        ],
      );
}
