import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../teacher/data/teacher_assessment_repository.dart'
    show teacherAssessmentEntityType;
import '../../teacher/domain/teacher_assessment_models.dart';
import '../domain/parent_learning_progress_models.dart';
import 'parent_children_repository.dart';

const _notRecorded = 'Not recorded yet';

class ParentLearningProgressRepository {
  ParentLearningProgressRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required ParentChildrenRepository children,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _children = children;

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final ParentChildrenRepository _children;

  /// Every child's average, evidence and timeline are computed live from the same real canonical
  /// assessment records ([teacherAssessmentEntityType]) a Teacher enters and Principal's Academics
  /// screen aggregates class-wide, filtered down to this one real student's own score entry — so a
  /// family can never see a number the register or a teacher's own assessment would disagree with.
  ///
  /// Only RELEASED assessments are shown here: a Student/Parent never sees a mark before the school
  /// has released it, even if it happens to already be sitting in this device's local cache (demo
  /// mode shares one local database across every signed-in role; a connected server also never sends
  /// an unreleased mark to this membership in the first place, but this filter is a defensive second
  /// gate, not a replacement for that server-side authority).
  ///
  /// No real assessment records a subject-wide topic, a day-by-day history or a narrative "insight"
  /// (Principal Academics already established the same "no subject label exists yet" fact school-wide),
  /// so those stay honestly empty instead of inventing them.
  Future<ParentLearningProgressSnapshot> load() async {
    final membership = _requireParentMembership();
    final linked = (await _children.load()).children;

    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: teacherAssessmentEntityType,
    );
    final released = records
        .map((record) => TeacherAssessment.fromJson(record.payload))
        .where((item) => item.state == TeacherAssessmentState.released)
        .toList(growable: false);

    final children = <ParentLearningChild>[];
    for (final child in linked) {
      final evidence = <ParentLearningEvidenceItem>[];
      final timeline = <ParentLearningTimelineEvent>[];
      var totalPercent = 0.0;
      var scoredCount = 0;

      for (final item in released) {
        if (item.className != child.className) continue;

        TeacherAssessmentEntry? entry;
        for (final e in item.entries) {
          if (e.studentId == child.id) {
            entry = e;
            break;
          }
        }
        if (entry == null || entry.score == null) continue;

        final percent = entry.percent ??
            (item.maximumScore <= 0 ? 0 : (entry.score! / item.maximumScore) * 100);
        totalPercent += percent;
        scoredCount += 1;

        evidence.add(ParentLearningEvidenceItem(
          label: item.title,
          value: '${entry.score!.toStringAsFixed(0)}/${item.maximumScore} (${percent.round()}%)',
          note: '${item.className} · ${teacherAssessmentTypeLabel(item.type)}',
        ));

        final dateLabel = item.releasedAt?.split('T').first;
        timeline.add(ParentLearningTimelineEvent(
          dateLabel: dateLabel ?? _notRecorded,
          title: item.title,
          detail: 'Score released: ${entry.score!.toStringAsFixed(0)}/${item.maximumScore}',
        ));
      }

      timeline.sort((a, b) => b.dateLabel.compareTo(a.dateLabel));

      final averagePercent = scoredCount == 0 ? 0 : (totalPercent / scoredCount).round();
      final status = scoredCount == 0
          ? ParentLearningStatus.stable
          : averagePercent >= 75
              ? ParentLearningStatus.strong
              : averagePercent >= 60
                  ? ParentLearningStatus.stable
                  : averagePercent >= 40
                      ? ParentLearningStatus.watch
                      : ParentLearningStatus.needsSupport;

      children.add(ParentLearningChild(
        id: child.id,
        name: child.name,
        className: child.className,
        section: child.section,
        averagePercent: averagePercent,
        // The real gate-scan record only ever keeps today's attendance (see Parent Attendance);
        // there is no real second attendance source to compute this from.
        attendancePercent: child.presentToday ? 100 : 0,
        // No real longitudinal series exists to compute a trend from; a single current snapshot
        // cannot honestly claim to be rising or falling, so this stays at zero rather than guessing.
        trendPercent: 0,
        status: status,
        history: const [],
        subjects: const [],
        topics: const [],
        evidence: evidence,
        timeline: timeline,
        insight: scoredCount == 0
            ? _notRecorded
            : 'Based on $scoredCount recorded assessment${scoredCount == 1 ? '' : 's'} so far this term.',
        actions: const [],
      ));
    }

    return ParentLearningProgressSnapshot(
      familyAccountId: membership.id,
      children: children,
    );
  }

  Future<ParentLearningChild> childById(String childId) async {
    final normalized = childId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(childId, 'childId', 'Child id is required.');
    }

    final snapshot = await load();
    final child = snapshot.childById(normalized);
    if (child == null) {
      throw StateError(
        'Learning progress is unavailable because this child is not linked to the active guardian membership.',
      );
    }
    return child;
  }

  SchoolMembership _requireParentMembership() {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.parent) {
      throw StateError(
        'Family learning progress requires an active Parent membership.',
      );
    }
    return membership;
  }
}
