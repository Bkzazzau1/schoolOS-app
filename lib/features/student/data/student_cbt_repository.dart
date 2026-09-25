import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/data/administrator_students_repository.dart';
import '../../teacher/data/teacher_cbt_repository.dart'
    show teacherCbtAttemptEntityType, teacherCbtTestEntityType;
import '../../teacher/domain/teacher_cbt_models.dart';

/// One CBT test available to the signed-in Student, paired with their own
/// attempt. The attempt always exists once a test appears here - the school
/// creates it the moment the test is published (see
/// TeacherCbtRepository.publish), and a Student only ever starts, answers or
/// submits it, never creates their own.
class StudentCbtItem {
  const StudentCbtItem({required this.test, required this.attempt});

  final TeacherCbtTest test;
  final TeacherCbtAttempt attempt;

  bool get started => attempt.started;
  bool get submitted => attempt.submitted;
  DateTime? get deadline => attempt.deadline;
  List<int?> get answers => attempt.answers;
  int? get score => attempt.score;
}

class StudentCbtActionResult {
  const StudentCbtActionResult({required this.success, required this.message});
  final bool success;
  final String message;
}

/// A CBT score can only be trusted from whoever holds the answer key, never
/// from the device answering the questions. In canonical (server-backed)
/// mode this Student's own local copy of a test never carries
/// correctIndex/explanation until the school's server redacts-then-reveals
/// them after this Student's own attempt is submitted (see the backend's
/// apps.cbt.visibility) - so submit() never computes a score itself there,
/// it only queues the submit action and waits for the server's own answer
/// to arrive on the next sync. Standalone demo mode has no real server and
/// shares one local database across every seeded role, so there is no
/// separate device for an answer key to leak from; there, and only there,
/// submission also plays the part of the backend and computes the score
/// locally - mirroring how TeacherCbtRepository's own demo publish step
/// already plays the part of the backend that freezes recipients and births
/// attempts.
class StudentCbtRepository {
  StudentCbtRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required AdministratorStudentsRepository students,
    DateTime Function()? now,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _students = students,
        _now = now ?? DateTime.now;

  static const _classLinkEntityType = 'student_class_link';
  static const _demoIdentityEntityType = '_student_cbt_identity';
  static const _testType = teacherCbtTestEntityType;
  static const _attemptType = teacherCbtAttemptEntityType;

  /// The class StudentRepository's own demo profile names as home to the
  /// standalone demo Student - used only to pick a believable classmate
  /// identity below, never to filter anything server-authoritative.
  static const _demoClassName = 'JSS 2A';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final AdministratorStudentsRepository _students;
  final DateTime Function() _now;

  Future<List<StudentCbtItem>> loadAvailable() async {
    final membership = _requireStudentMembership();
    final myCode = await _myStudentCode(membership);
    if (myCode == null) return const [];

    final attemptRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _attemptType,
    );
    final testRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _testType,
    );
    final testsById = {
      for (final record in testRecords) record.entityId: TeacherCbtTest.fromJson(record.payload),
    };

    final items = <StudentCbtItem>[];
    for (final record in attemptRecords) {
      final attempt = TeacherCbtAttempt.fromJson(record.payload);
      // A connected server only ever sends this membership its own attempt
      // in the first place; this equality check is a defensive second gate
      // that matters most in standalone demo mode, which shares one local
      // database across every signed-in role.
      if (attempt.studentId != myCode) continue;
      final test = testsById[attempt.testId];
      if (test == null) continue;
      items.add(StudentCbtItem(test: test, attempt: attempt));
    }
    items.sort((a, b) {
      final byPublished = (b.test.publishedAt ?? '').compareTo(a.test.publishedAt ?? '');
      return byPublished != 0 ? byPublished : a.test.title.compareTo(b.test.title);
    });
    return items;
  }

  Future<StudentCbtActionResult> start(String testId) async {
    final membership = _requireStudentMembership();
    final item = await _myItem(membership, testId);
    if (item == null) {
      return const StudentCbtActionResult(success: false, message: 'This CBT is not available to you.');
    }
    if (item.test.state != TeacherCbtTestState.published) {
      return const StudentCbtActionResult(success: false, message: 'This CBT is not open right now.');
    }
    if (item.attempt.started) {
      return const StudentCbtActionResult(success: true, message: 'Already started.');
    }

    final started = item.attempt.copyWith(
      startedAt: _now().toUtc().toIso8601String(),
      deadlineAt: _now().add(Duration(minutes: item.test.durationMinutes)).toUtc().toIso8601String(),
      answers: List<int?>.filled(item.test.questionCount, null),
    );
    await _persist(membership, started, payload: {'id': started.id, 'action': 'start'});
    return const StudentCbtActionResult(success: true, message: 'CBT started and queued for synchronization.');
  }

  Future<StudentCbtActionResult> answer(String testId, int questionIndex, int optionIndex) async {
    final membership = _requireStudentMembership();
    final item = await _myItem(membership, testId);
    if (item == null) {
      return const StudentCbtActionResult(success: false, message: 'This CBT is not available to you.');
    }
    final deadline = item.attempt.deadline;
    if (deadline == null || item.attempt.submitted || !_now().isBefore(deadline)) {
      return const StudentCbtActionResult(success: false, message: 'This CBT attempt is not open for answers.');
    }
    if (questionIndex < 0 ||
        questionIndex >= item.test.questionCount ||
        optionIndex < 0 ||
        optionIndex >= item.test.questions[questionIndex].options.length) {
      return const StudentCbtActionResult(success: false, message: 'Invalid answer.');
    }
    final answers = List<int?>.from(item.attempt.answers);
    while (answers.length <= questionIndex) {
      answers.add(null);
    }
    answers[questionIndex] = optionIndex;
    final updated = item.attempt.copyWith(answers: answers);
    await _persist(
      membership,
      updated,
      payload: {'id': updated.id, 'action': 'answer', 'questionIndex': questionIndex, 'optionIndex': optionIndex},
    );
    return const StudentCbtActionResult(success: true, message: 'Answer saved.');
  }

  Future<StudentCbtActionResult> submit(String testId) async {
    final membership = _requireStudentMembership();
    final item = await _myItem(membership, testId);
    if (item == null) {
      return const StudentCbtActionResult(success: false, message: 'This CBT is not available to you.');
    }
    if (!item.attempt.started) {
      return const StudentCbtActionResult(success: false, message: 'Start the CBT before submitting.');
    }
    if (item.attempt.submitted) {
      return const StudentCbtActionResult(success: true, message: 'Already submitted.');
    }

    // Only standalone demo mode computes a score here - see the class doc
    // comment above. A connected server always owns this comparison; the
    // client waits for it to arrive on the next sync.
    final demoScore = LocalDatabase.blockDemoSeeds
        ? null
        : [
            for (var i = 0; i < item.test.questionCount; i++)
              if (i < item.attempt.answers.length && item.attempt.answers[i] == item.test.questions[i].correctIndex) i,
          ].length;
    final updated = item.attempt.copyWith(
      submitted: true,
      submittedAt: _now().toUtc().toIso8601String(),
      score: demoScore,
    );
    await _persist(membership, updated, payload: {'id': updated.id, 'action': 'submit'});
    return const StudentCbtActionResult(
      success: true,
      message: 'Submission queued. Your score is confirmed once the server acknowledges it.',
    );
  }

  Future<StudentCbtItem?> _myItem(SchoolMembership membership, String testId) async {
    for (final item in await loadAvailable()) {
      if (item.test.id == testId) return item;
    }
    return null;
  }

  Future<void> _persist(
    SchoolMembership membership,
    TeacherCbtAttempt attempt, {
    required Map<String, Object?> payload,
  }) async {
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
      operation: SyncOperation.update,
      payload: payload,
    );
  }

  /// The canonical student code this membership's attempts are keyed under -
  /// from the same server-synced class link record Study/Results already
  /// trust for identity. Standalone demo mode has no such sync, so it
  /// self-heals a stable identity into a CBT-only private record instead of
  /// touching student_class_link itself, which StudentRepository's own "My
  /// profile" screen still needs intact.
  Future<String?> _myStudentCode(SchoolMembership membership) async {
    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _classLinkEntityType,
      entityId: membership.id,
    );
    final synced = (record?.payload['studentId'] as String? ?? '').trim();
    if (synced.isNotEmpty) return synced;
    if (LocalDatabase.blockDemoSeeds) return null;

    final identity = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _demoIdentityEntityType,
      entityId: membership.id,
    );
    final existing = (identity?.payload['studentId'] as String? ?? '').trim();
    if (existing.isNotEmpty) return existing;

    final roster = (await _students.load()).students;
    if (roster.isEmpty) return null;
    var me = roster.first;
    for (final student in roster) {
      if (student.className.trim().toLowerCase() == _demoClassName.toLowerCase()) {
        me = student;
        break;
      }
    }
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _demoIdentityEntityType,
      entityId: membership.id,
      payload: {'studentId': me.id},
    );
    return me.id;
  }

  SchoolMembership _requireStudentMembership() {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.student) {
      throw StateError('This CBT belongs to the signed-in student.');
    }
    return membership;
  }
}
