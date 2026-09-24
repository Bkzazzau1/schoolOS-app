import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../teacher/data/teacher_weekly_learning_repository.dart'
    show teacherWeeklyLearningUpdateEntityType;
import '../../teacher/domain/teacher_weekly_learning_models.dart';
import '../domain/parent_weekly_learning_models.dart';
import 'parent_children_repository.dart';

const _notRecorded = 'Not recorded yet';

class ParentWeeklyLearningRepository {
  ParentWeeklyLearningRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required ParentChildrenRepository children,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _children = children;

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final ParentChildrenRepository _children;

  /// Families receive only canonical server-published weekly subject reports.
  /// Queued Teacher mutations remain private/pending even if the same device can
  /// switch between Teacher and Parent memberships.
  Future<ParentWeeklyLearningSnapshot> load() async {
    final membership = _requireParentMembership();
    final linked = (await _children.load()).children;
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: teacherWeeklyLearningUpdateEntityType,
    );

    final groups = <String, _WeeklyGroup>{};
    for (final record in records) {
      final update = TeacherWeeklyLearningUpdate.fromJson(record.payload);
      if (update.state != TeacherWeeklyPublicationState.published) continue;

      for (final child in linked) {
        if (update.className != child.className) continue;
        final weekKey = update.weekStart.isNotEmpty ? update.weekStart : update.week;
        final key = '${child.id}|${update.className}|$weekKey';
        final group = groups.putIfAbsent(
          key,
          () => _WeeklyGroup(
            id: 'weekly-$key',
            childId: child.id,
            childName: child.name,
            className: update.className,
            weekLabel: update.week,
            dateLabel: (update.publishedAt ?? update.updatedAt)?.split('T').first ??
                _notRecorded,
            sortKey: weekKey,
          ),
        );

        final author = (record.payload['author'] as String? ?? '').trim();
        if (author.isNotEmpty) group.teachers.add(author);

        for (final subject in update.subjects) {
          group.subjects.add(
            ParentWeeklySubjectUpdate(
              subject: subject.subject,
              thisWeek:
                  subject.covered.trim().isEmpty ? _notRecorded : subject.covered,
              learningEvidence:
                  subject.evidence.trim().isEmpty ? _notRecorded : subject.evidence,
              nextTopic: subject.next.trim().isEmpty ? _notRecorded : subject.next,
              practiceNote:
                  subject.support.trim().isEmpty ? _notRecorded : subject.support,
            ),
          );
          if (update.note.trim().isNotEmpty) {
            final prefix = subject.subject.trim().isEmpty
                ? update.className
                : subject.subject.trim();
            group.notes.add('$prefix: ${update.note.trim()}');
          }
        }
      }
    }

    final ordered = groups.values.toList()
      ..sort((a, b) => b.sortKey.compareTo(a.sortKey));
    return ParentWeeklyLearningSnapshot(
      familyAccountId: membership.id,
      updates: [for (final group in ordered) group.toParentUpdate()],
    );
  }

  SchoolMembership _requireParentMembership() {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.parent) {
      throw StateError(
        'Weekly learning requires an active Parent membership.',
      );
    }
    return membership;
  }
}

class _WeeklyGroup {
  _WeeklyGroup({
    required this.id,
    required this.childId,
    required this.childName,
    required this.className,
    required this.weekLabel,
    required this.dateLabel,
    required this.sortKey,
  });

  final String id;
  final String childId;
  final String childName;
  final String className;
  final String weekLabel;
  final String dateLabel;
  final String sortKey;
  final Set<String> teachers = {};
  final Set<String> notes = {};
  final List<ParentWeeklySubjectUpdate> subjects = [];

  ParentWeeklyLearningUpdate toParentUpdate() {
    subjects.sort((a, b) => a.subject.compareTo(b.subject));
    return ParentWeeklyLearningUpdate(
      id: id,
      weekLabel: weekLabel,
      dateLabel: dateLabel,
      childId: childId,
      childName: childName,
      className: className,
      teacher: teachers.isEmpty ? _notRecorded : teachers.join(' · '),
      teacherNote: notes.isEmpty ? _notRecorded : notes.join('\n'),
      subjects: List.unmodifiable(subjects),
      published: true,
    );
  }
}
