import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';

const studentAssignmentEntityType = 'academic_assignment';
const studentAssignmentSubmissionEntityType = 'student_assignment_submission';

enum StudentAssignmentState { published, closed }
enum StudentAssignmentSubmissionState { draft, queued, submitted, returned, graded }

class StudentAssignment {
  const StudentAssignment({
    required this.id,
    required this.title,
    required this.instructions,
    required this.className,
    required this.subject,
    required this.type,
    required this.dueAt,
    required this.maximumScore,
    required this.state,
    this.topic = '',
    this.publicationRevision = 0,
  });

  final String id;
  final String title;
  final String instructions;
  final String className;
  final String subject;
  final String type;
  final String dueAt;
  final int maximumScore;
  final StudentAssignmentState state;
  final String topic;
  final int publicationRevision;

  bool get open => state == StudentAssignmentState.published;

  factory StudentAssignment.fromJson(Map<String, Object?> json) => StudentAssignment(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        instructions: json['instructions'] as String? ?? '',
        className: json['className'] as String? ?? '',
        subject: json['subject'] as String? ?? '',
        type: json['type'] as String? ?? 'homework',
        dueAt: json['dueAt'] as String? ?? '',
        maximumScore: (json['maximumScore'] as num?)?.toInt() ?? 0,
        state: json['state'] == 'closed'
            ? StudentAssignmentState.closed
            : StudentAssignmentState.published,
        topic: json['topic'] as String? ?? '',
        publicationRevision:
            (json['publicationRevision'] as num?)?.toInt() ?? 0,
      );
}

class StudentAssignmentSubmission {
  const StudentAssignmentSubmission({
    required this.id,
    required this.assignmentId,
    required this.state,
    required this.responseText,
    this.attemptNumber = 0,
    this.submittedAt,
    this.isLate = false,
    this.score,
    this.feedback = '',
    this.gradedAt,
    this.pendingSync = false,
    this.pendingAction = '',
    this.serverVersion,
  });

  final String id;
  final String assignmentId;
  final StudentAssignmentSubmissionState state;
  final String responseText;
  final int attemptNumber;
  final String? submittedAt;
  final bool isLate;
  final double? score;
  final String feedback;
  final String? gradedAt;
  final bool pendingSync;
  final String pendingAction;
  final int? serverVersion;

  bool get locked =>
      pendingAction == 'submit' ||
      state == StudentAssignmentSubmissionState.submitted ||
      state == StudentAssignmentSubmissionState.graded;

  bool get canEdit => !locked;

  factory StudentAssignmentSubmission.fromJson(Map<String, Object?> json) {
    final raw = json['state'] as String? ?? 'draft';
    final state = StudentAssignmentSubmissionState.values.firstWhere(
      (item) => item.name == raw,
      orElse: () => StudentAssignmentSubmissionState.draft,
    );
    final pendingAction = json['pendingAction'] as String? ?? '';
    return StudentAssignmentSubmission(
      id: json['id'] as String? ?? '',
      assignmentId: json['assignmentId'] as String? ?? '',
      state: pendingAction == 'submit' ? StudentAssignmentSubmissionState.queued : state,
      responseText: json['responseText'] as String? ?? '',
      attemptNumber: (json['attemptNumber'] as num?)?.toInt() ?? 0,
      submittedAt: json['submittedAt'] as String?,
      isLate: json['isLate'] == true,
      score: (json['score'] as num?)?.toDouble(),
      feedback: json['feedback'] as String? ?? '',
      gradedAt: json['gradedAt'] as String?,
      pendingAction: pendingAction,
    );
  }

  Map<String, Object?> toLocalJson() => {
        'id': id,
        'assignmentId': assignmentId,
        'state': state == StudentAssignmentSubmissionState.queued ? 'draft' : state.name,
        'responseText': responseText,
        'attemptNumber': attemptNumber,
        'submittedAt': submittedAt,
        'isLate': isLate,
        'score': score,
        'feedback': feedback,
        'gradedAt': gradedAt,
        'pendingAction': pendingAction,
      };
}

class StudentAssignmentItem {
  const StudentAssignmentItem({required this.assignment, this.submission});

  final StudentAssignment assignment;
  final StudentAssignmentSubmission? submission;
}

class StudentAssignmentActionResult {
  const StudentAssignmentActionResult({required this.success, required this.message});
  final bool success;
  final String message;
}

class StudentAssignmentRepository {
  StudentAssignmentRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  Future<List<StudentAssignmentItem>> load() async {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.student) return const [];

    final assignmentRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: studentAssignmentEntityType,
    );
    final submissionRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: studentAssignmentSubmissionEntityType,
    );
    final submissions = <String, StudentAssignmentSubmission>{};
    for (final record in submissionRecords) {
      final parsed = StudentAssignmentSubmission.fromJson(record.payload);
      submissions[parsed.assignmentId] = StudentAssignmentSubmission(
        id: parsed.id,
        assignmentId: parsed.assignmentId,
        state: parsed.state,
        responseText: parsed.responseText,
        attemptNumber: parsed.attemptNumber,
        submittedAt: parsed.submittedAt,
        isLate: parsed.isLate,
        score: parsed.score,
        feedback: parsed.feedback,
        gradedAt: parsed.gradedAt,
        pendingSync: record.isDirty,
        pendingAction: parsed.pendingAction,
        serverVersion: record.serverVersion,
      );
    }

    final items = <StudentAssignmentItem>[];
    for (final record in assignmentRecords) {
      final state = record.payload['state'] as String? ?? '';
      if (state != 'published' && state != 'closed') continue;
      final assignment = StudentAssignment.fromJson(record.payload);
      items.add(
        StudentAssignmentItem(
          assignment: assignment,
          submission: submissions[assignment.id],
        ),
      );
    }
    items.sort((a, b) => a.assignment.dueAt.compareTo(b.assignment.dueAt));
    return items;
  }

  Future<StudentAssignmentActionResult> saveDraft(
    StudentAssignment assignment,
    String responseText,
  ) async {
    return _queueStudentAction(
      assignment,
      responseText,
      action: 'saveDraft',
    );
  }

  Future<StudentAssignmentActionResult> submit(
    StudentAssignment assignment,
    String responseText,
  ) async {
    if (responseText.trim().isEmpty) {
      return const StudentAssignmentActionResult(
        success: false,
        message: 'Add your response before submitting.',
      );
    }
    return _queueStudentAction(
      assignment,
      responseText,
      action: 'submit',
    );
  }

  Future<StudentAssignmentActionResult> _queueStudentAction(
    StudentAssignment assignment,
    String responseText, {
    required String action,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.student) {
      return const StudentAssignmentActionResult(
        success: false,
        message: 'Only a Student membership can change assignment responses.',
      );
    }
    if (!assignment.open) {
      return const StudentAssignmentActionResult(
        success: false,
        message: 'This assignment is closed and no longer accepts responses.',
      );
    }

    final existing = await _submissionFor(membership, assignment.id);
    if (existing != null && existing.locked) {
      return const StudentAssignmentActionResult(
        success: false,
        message: 'Submitted work is locked unless your Teacher returns it for revision.',
      );
    }

    final id = existing?.id ?? _submissionId(membership, assignment.id);
    final pendingState = action == 'submit'
        ? StudentAssignmentSubmissionState.queued
        : (existing?.state == StudentAssignmentSubmissionState.returned
            ? StudentAssignmentSubmissionState.returned
            : StudentAssignmentSubmissionState.draft);
    final local = StudentAssignmentSubmission(
      id: id,
      assignmentId: assignment.id,
      state: pendingState,
      responseText: responseText.trim(),
      attemptNumber: existing?.attemptNumber ?? 0,
      submittedAt: existing?.submittedAt,
      isLate: existing?.isLate ?? false,
      score: existing?.score,
      feedback: existing?.feedback ?? '',
      gradedAt: existing?.gradedAt,
      pendingSync: true,
      pendingAction: action,
      serverVersion: existing?.serverVersion,
    );

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: studentAssignmentSubmissionEntityType,
      entityId: id,
      payload: local.toLocalJson(),
      serverVersion: existing?.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: studentAssignmentSubmissionEntityType,
      entityId: id,
      operation: existing?.serverVersion == null ? SyncOperation.create : SyncOperation.update,
      payload: {
        'id': id,
        'assignmentId': assignment.id,
        'action': action,
        'responseText': responseText.trim(),
      },
      baseVersion: existing?.pendingSync == true ? null : existing?.serverVersion,
    );
    return StudentAssignmentActionResult(
      success: true,
      message: action == 'submit'
          ? 'Submission queued. It is not server-confirmed until synchronization succeeds.'
          : 'Draft saved locally and queued privately for synchronization.',
    );
  }

  Future<StudentAssignmentSubmission?> _submissionFor(
    SchoolMembership membership,
    String assignmentId,
  ) async {
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: studentAssignmentSubmissionEntityType,
    );
    for (final record in records) {
      if (record.payload['assignmentId'] != assignmentId) continue;
      final parsed = StudentAssignmentSubmission.fromJson(record.payload);
      return StudentAssignmentSubmission(
        id: parsed.id,
        assignmentId: parsed.assignmentId,
        state: parsed.state,
        responseText: parsed.responseText,
        attemptNumber: parsed.attemptNumber,
        submittedAt: parsed.submittedAt,
        isLate: parsed.isLate,
        score: parsed.score,
        feedback: parsed.feedback,
        gradedAt: parsed.gradedAt,
        pendingSync: record.isDirty,
        pendingAction: parsed.pendingAction,
        serverVersion: record.serverVersion,
      );
    }
    return null;
  }

  String _submissionId(SchoolMembership membership, String assignmentId) {
    final hash = _fnv1a32(assignmentId);
    return 'sub-${membership.id}-$hash';
  }

  String _fnv1a32(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
