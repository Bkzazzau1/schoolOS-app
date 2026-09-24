import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../teacher/data/teacher_assessment_repository.dart'
    show teacherAssessmentEntityType;
import '../../teacher/domain/teacher_assessment_models.dart';

/// One released assessment result, from the Student's own point of view.
class StudentResult {
  const StudentResult({
    required this.title,
    required this.className,
    required this.subject,
    required this.type,
    required this.score,
    required this.maximumScore,
    required this.percent,
    required this.grade,
    required this.releasedAt,
  });

  final String title;
  final String className;
  final String subject;
  final TeacherAssessmentType type;
  final double score;
  final int maximumScore;
  final double percent;
  final String grade;
  final String? releasedAt;
}

class StudentResultsSnapshot {
  const StudentResultsSnapshot({required this.results, required this.averagePercent});

  final List<StudentResult> results;
  final double? averagePercent;
}

/// A Student never sees a mark before the school has released it, and only
/// ever their own - never a classmate's. Only RELEASED assessments are read
/// here, and only the one entry matching this Student's own canonical
/// student code (from [StudentRepository.canonicalProfileEntityType],
/// synced from the server; the same record Study/CBT already trust for
/// class identity). A connected server never sends an unreleased mark or a
/// classmate's entry to this membership in the first place - this filter is
/// a defensive second gate, not a substitute for that server-side authority,
/// and matters most in standalone demo mode, which shares one local database
/// across every signed-in role.
class StudentResultsRepository {
  StudentResultsRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _classLinkEntityType = 'student_class_link';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  Future<StudentResultsSnapshot> load() async {
    final membership = _requireStudentMembership();
    final myStudentCode = await _myStudentCode(membership);
    if (myStudentCode == null) {
      return const StudentResultsSnapshot(results: [], averagePercent: null);
    }

    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: teacherAssessmentEntityType,
    );
    final results = <StudentResult>[];
    var totalPercent = 0.0;
    for (final record in records) {
      final item = TeacherAssessment.fromJson(record.payload);
      if (item.state != TeacherAssessmentState.released) continue;
      TeacherAssessmentEntry? mine;
      for (final entry in item.entries) {
        if (entry.studentId == myStudentCode) {
          mine = entry;
          break;
        }
      }
      if (mine == null || mine.score == null) continue;
      final percent = mine.percent ??
          (item.maximumScore <= 0 ? 0 : (mine.score! / item.maximumScore) * 100);
      totalPercent += percent;
      results.add(
        StudentResult(
          title: item.title,
          className: item.className,
          subject: item.subject,
          type: item.type,
          score: mine.score!,
          maximumScore: item.maximumScore,
          percent: percent,
          grade: mine.grade,
          releasedAt: item.releasedAt,
        ),
      );
    }
    results.sort((a, b) => (b.releasedAt ?? '').compareTo(a.releasedAt ?? ''));

    return StudentResultsSnapshot(
      results: results,
      averagePercent: results.isEmpty ? null : totalPercent / results.length,
    );
  }

  Future<String?> _myStudentCode(SchoolMembership membership) async {
    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _classLinkEntityType,
      entityId: membership.id,
    );
    final code = (record?.payload['studentId'] as String? ?? '').trim();
    return code.isEmpty ? null : code;
  }

  SchoolMembership _requireStudentMembership() {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.student) {
      throw StateError('Term results require an active Student membership.');
    }
    return membership;
  }
}
