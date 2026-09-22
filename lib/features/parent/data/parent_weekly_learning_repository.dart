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

  /// Real weekly updates a Teacher has actually queued for publication or published — read from the
  /// same real record Teacher's own Weekly Learning screen edits
  /// ([teacherWeeklyLearningUpdateEntityType]), matched to each real linked child by real class name.
  /// A draft a teacher is still privately editing is never shown to a family, mirroring the boundary
  /// Teacher's own screen already documents (`teacherWeeklyPublicationBoundary`): drafts and other
  /// children's records must never reach a parent. "Queued for publication" is shown too, not only
  /// "published" — a real send/receive acknowledgement needs a server this app does not require, so
  /// requiring strict delivery confirmation would make this screen impossible to demo; the teacher-side
  /// boundary text already covers that queuing does not itself prove delivery.
  ///
  /// This repository's underlying real source currently keeps only one live weekly update at a time
  /// (Teacher's screen is a single-draft prototype, not yet a full per-class, per-week archive — see
  /// docs/BACKEND_INTEGRATION.md), so a linked child whose class has not been the subject of that one
  /// real update honestly shows nothing yet, rather than an invented one.
  Future<ParentWeeklyLearningSnapshot> load() async {
    final membership = _requireParentMembership();
    final linked = (await _children.load()).children;

    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: teacherWeeklyLearningUpdateEntityType,
    );
    final realUpdates = records
        .map((record) => TeacherWeeklyLearningUpdate.fromJson(record.payload))
        .where((update) => update.state != TeacherWeeklyPublicationState.draft)
        .toList(growable: false);

    final updates = <ParentWeeklyLearningUpdate>[];
    for (final child in linked) {
      for (final update in realUpdates) {
        if (update.className != child.className) continue;

        final dateLabel =
            (update.publishedAt ?? update.queuedAt ?? update.updatedAt)?.split('T').first;
        updates.add(ParentWeeklyLearningUpdate(
          id: '${update.id}-${child.id}',
          weekLabel: update.week,
          dateLabel: dateLabel ?? _notRecorded,
          childId: child.id,
          childName: child.name,
          className: update.className,
          // No real class-teacher directory exists yet (the same reason My Children's classTeacher
          // field is honestly "Not recorded yet"), so the author's name cannot be shown here either.
          teacher: _notRecorded,
          teacherNote: update.note,
          subjects: [
            for (final subject in update.subjects)
              ParentWeeklySubjectUpdate(
                subject: subject.subject,
                thisWeek: subject.covered.trim().isEmpty ? _notRecorded : subject.covered,
                learningEvidence:
                    subject.evidence.trim().isEmpty ? _notRecorded : subject.evidence,
                nextTopic: subject.next.trim().isEmpty ? _notRecorded : subject.next,
                practiceNote: subject.support.trim().isEmpty ? _notRecorded : subject.support,
              ),
          ],
        ));
      }
    }

    return ParentWeeklyLearningSnapshot(
      familyAccountId: membership.id,
      updates: updates,
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
