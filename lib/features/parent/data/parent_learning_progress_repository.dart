import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../teacher/data/teacher_assessment_repository.dart'
    show teacherAssessmentRegisterEntityType, teacherAssessmentScoreSheetEntityType;
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

  /// Every child's average, evidence and timeline are computed live from the same real assessment
  /// records a Teacher enters and Principal's Academics screen aggregates class-wide
  /// ([teacherAssessmentRegisterEntityType] / [teacherAssessmentScoreSheetEntityType]), filtered down to
  /// this one real student's own score entries — so a family can never see a number Finance, the
  /// register or a teacher's own score sheet would disagree with.
  ///
  /// No real assessment records a subject, a topic, a day-by-day history or a narrative "insight"
  /// (Principal Academics already established the same "no subject label exists yet" fact school-wide),
  /// so those stay honestly empty instead of inventing them.
  Future<ParentLearningProgressSnapshot> load() async {
    final membership = _requireParentMembership();
    final linked = (await _children.load()).children;

    final registerRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: teacherAssessmentRegisterEntityType,
    );
    final register = registerRecords
        .map((record) => TeacherAssessmentRegisterItem.fromJson(record.payload))
        .toList(growable: false);

    final sheetRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: teacherAssessmentScoreSheetEntityType,
    );
    final sheetsById = <String, TeacherAssessmentScoreSheet>{
      for (final record in sheetRecords)
        record.entityId: TeacherAssessmentScoreSheet.fromJson(record.payload),
    };

    final children = <ParentLearningChild>[];
    for (final child in linked) {
      final evidence = <ParentLearningEvidenceItem>[];
      final timeline = <ParentLearningTimelineEvent>[];
      var totalPercent = 0;
      var scoredCount = 0;

      for (final item in register) {
        if (item.className != child.className) continue;
        final sheet = sheetsById[item.id];
        if (sheet == null) continue;

        TeacherAssessmentScoreEntry? entry;
        for (final e in sheet.entries) {
          if (e.studentId == child.id) {
            entry = e;
            break;
          }
        }
        // A score of exactly 0 cannot be told apart from "not entered yet" with the current score
        // model, so this follows the same honest convention the register itself uses.
        if (entry == null || entry.score <= 0) continue;

        final percent = sheet.maximumScore <= 0
            ? 0
            : ((entry.score / sheet.maximumScore) * 100).round();
        totalPercent += percent;
        scoredCount += 1;

        evidence.add(ParentLearningEvidenceItem(
          label: item.title,
          value: '${entry.score}/${sheet.maximumScore} ($percent%)',
          note: item.className,
        ));

        final dateLabel = (sheet.submittedAt ?? sheet.updatedAt)?.split('T').first;
        timeline.add(ParentLearningTimelineEvent(
          dateLabel: dateLabel ?? _notRecorded,
          title: item.title,
          detail: 'Score recorded: ${entry.score}/${sheet.maximumScore}',
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
