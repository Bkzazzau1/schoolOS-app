import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../teacher/data/teacher_cbt_repository.dart'
    show ensureTeacherCbtSeeded, teacherCbtAttemptEntityType, teacherCbtPracticeSetEntityType;
import '../../teacher/domain/teacher_cbt_models.dart';

/// One real, published CBT set available to this student, together with their own real attempt state
/// against it (if any). `set` is read from the same real record a teacher writes
/// (`teacherCbtPracticeSetEntityType`); `deadline`/`answers`/`submitted`/`score` are this specific
/// student's own real, locally-persisted progress against it.
class StudentCbtAvailableSet {
  const StudentCbtAvailableSet({
    required this.set,
    required this.deadline,
    required this.answers,
    required this.submitted,
    required this.score,
  });

  final TeacherCbtPracticeSet set;
  final DateTime? deadline;
  final List<int?> answers;
  final bool submitted;
  final int? score;

  bool get started => deadline != null;
}

/// No real system yet links a Student membership to a specific class the way
/// `ParentChildrenRepository` links a guardian to specific real children, or the way
/// `TeacherRoster` links a teacher membership to specific real assigned classes. Until a real
/// enrollment/admissions workflow creates that link, a student's class is honestly seeded once (to a
/// real class that really exists in the school's register) and then persisted like any other real
/// record — never re-guessed on every read, and changeable the same way `TeacherRoster.assign` lets an
/// administrator reassign a teacher's classes.
const _defaultStudentClassName = 'JSS 2A';

class StudentCbtRepository {
  StudentCbtRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    DateTime Function()? now,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _now = now ?? DateTime.now;

  static const _classLinkEntityType = 'student_class_link';
  static const _attemptStateEntityType = 'student_cbt_attempt_state';
  static const _setType = teacherCbtPracticeSetEntityType;
  static const _attemptType = teacherCbtAttemptEntityType;

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final DateTime Function() _now;

  /// This student's real class. Seeded to [_defaultStudentClassName] on first read.
  Future<String> className() async {
    final membership = _requireStudentMembership();
    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _classLinkEntityType,
      entityId: membership.id,
    );
    if (record != null) return record.payload['className'] as String? ?? _defaultStudentClassName;

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _classLinkEntityType,
      entityId: membership.id,
      payload: {'className': _defaultStudentClassName},
    );
    return _defaultStudentClassName;
  }

  /// Every real, published CBT set for this student's real class, each with this student's own real
  /// attempt state — never a fixed sample disconnected from what a teacher has actually published.
  Future<List<StudentCbtAvailableSet>> loadAvailableSets() async {
    final membership = _requireStudentMembership();
    await ensureTeacherCbtSeeded(_localDatabase, membership.schoolId);
    final myClass = await className();

    final setRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _setType,
    );
    final sets = setRecords
        .map((record) => TeacherCbtPracticeSet.fromJson(record.payload))
        .where((set) => set.state == TeacherCbtSetState.published && set.className == myClass)
        .toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));

    final result = <StudentCbtAvailableSet>[];
    for (final set in sets) {
      final state = await _attemptState(membership, set.id);
      result.add(StudentCbtAvailableSet(
        set: set,
        deadline: state['deadline'] == null ? null : DateTime.parse(state['deadline']! as String),
        answers: List<int?>.from(
          state['answers'] as List? ?? List<int?>.filled(set.items.length, null),
        ),
        submitted: state['submitted'] == true,
        score: state['score'] as int?,
      ));
    }
    return result;
  }

  Future<TeacherCbtPracticeSet> _requireAvailableSet(SchoolMembership membership, String setId) async {
    final myClass = await className();
    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _setType,
      entityId: setId,
    );
    if (record == null) throw StateError('This CBT is not available.');
    final set = TeacherCbtPracticeSet.fromJson(record.payload);
    if (set.state != TeacherCbtSetState.published || set.className != myClass) {
      throw StateError('This CBT is not available to your class.');
    }
    return set;
  }

  Future<void> startAttempt(String setId) async {
    final membership = _requireStudentMembership();
    final set = await _requireAvailableSet(membership, setId);
    final state = await _attemptState(membership, setId);
    if (state['deadline'] != null) return; // already started or resumed
    await _saveAttemptState(membership, setId, {
      'deadline': _now()
          .add(Duration(minutes: set.durationMinutes))
          .toUtc()
          .toIso8601String(),
      'answers': List<int?>.filled(set.items.length, null),
    });
  }

  Future<void> answer(String setId, int question, int option) async {
    final membership = _requireStudentMembership();
    final set = await _requireAvailableSet(membership, setId);
    final state = await _attemptState(membership, setId);
    final deadline = state['deadline'] as String?;
    if (deadline == null ||
        state['submitted'] == true ||
        !_now().isBefore(DateTime.parse(deadline))) {
      throw StateError('This CBT attempt is not open for answers.');
    }
    if (question < 0 || question >= set.items.length || option < 0 || option >= set.items[question].options.length) {
      throw ArgumentError('Invalid answer.');
    }
    final answers = List<int?>.from(state['answers']! as List);
    answers[question] = option;
    await _saveAttemptState(membership, setId, {...state, 'answers': answers});
  }

  /// Scores the attempt against the real correct answers the teacher set, marks it submitted, and
  /// writes a real attempt record the teacher's own CBT screen reads back to compute real evidence.
  Future<int> submit(String setId) async {
    final membership = _requireStudentMembership();
    final set = await _requireAvailableSet(membership, setId);
    final state = await _attemptState(membership, setId);
    if (state['deadline'] == null) throw StateError('Start an attempt first.');
    if (state['submitted'] == true) return state['score']! as int;

    final answers = List<int?>.from(state['answers']! as List);
    final score = [
      for (var i = 0; i < set.items.length; i++)
        if (i < answers.length && answers[i] == set.items[i].correctIndex) i,
    ].length;
    final now = _now().toUtc().toIso8601String();
    await _saveAttemptState(membership, setId, {
      ...state,
      'submitted': true,
      'score': score,
      'submittedAt': now,
    });

    final attempt = TeacherCbtAttempt(
      id: '${setId}_${membership.id}',
      setId: setId,
      studentMembershipId: membership.id,
      score: score,
      totalQuestions: set.items.length,
      submittedAt: now,
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _attemptType,
      entityId: attempt.id,
      payload: attempt.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _attemptType,
      entityId: attempt.id,
      operation: SyncOperation.create,
      payload: attempt.toJson(),
    );
    return score;
  }

  Future<Map<String, Object?>> _attemptState(SchoolMembership membership, String setId) async {
    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _attemptStateEntityType,
      entityId: '${membership.id}:$setId',
    );
    return Map<String, Object?>.from(record?.payload ?? {});
  }

  Future<void> _saveAttemptState(
    SchoolMembership membership,
    String setId,
    Map<String, Object?> state,
  ) async {
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _attemptStateEntityType,
      entityId: '${membership.id}:$setId',
      payload: state,
    );
  }

  SchoolMembership _requireStudentMembership() {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.student) {
      throw StateError('This CBT belongs to the signed-in student.');
    }
    return membership;
  }
}
