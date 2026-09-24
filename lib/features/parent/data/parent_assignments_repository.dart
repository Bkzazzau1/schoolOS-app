import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';

const parentAssignmentEntityType = 'academic_assignment';
const parentAssignmentSubmissionEntityType = 'student_assignment_submission';

class ParentAssignmentRecipient {
  const ParentAssignmentRecipient({
    required this.studentId,
    required this.studentName,
    required this.admissionNumber,
  });

  final String studentId;
  final String studentName;
  final String admissionNumber;

  factory ParentAssignmentRecipient.fromJson(Map<String, Object?> json) =>
      ParentAssignmentRecipient(
        studentId: json['studentId'] as String? ?? '',
        studentName: json['studentName'] as String? ?? '',
        admissionNumber: json['admissionNumber'] as String? ?? '',
      );
}

class ParentAssignmentSubmission {
  const ParentAssignmentSubmission({
    required this.assignmentId,
    required this.studentId,
    required this.studentName,
    required this.state,
    required this.maximumScore,
    this.submittedAt,
    this.isLate = false,
    this.score,
    this.feedback = '',
    this.gradedAt,
  });

  final String assignmentId;
  final String studentId;
  final String studentName;
  final String state;
  final int maximumScore;
  final String? submittedAt;
  final bool isLate;
  final double? score;
  final String feedback;
  final String? gradedAt;

  factory ParentAssignmentSubmission.fromJson(Map<String, Object?> json) =>
      ParentAssignmentSubmission(
        assignmentId: json['assignmentId'] as String? ?? '',
        studentId: json['studentId'] as String? ?? '',
        studentName: json['studentName'] as String? ?? '',
        state: json['state'] as String? ?? 'submitted',
        maximumScore: (json['maximumScore'] as num?)?.toInt() ?? 0,
        submittedAt: json['submittedAt'] as String?,
        isLate: json['isLate'] == true,
        score: (json['score'] as num?)?.toDouble(),
        feedback: json['feedback'] as String? ?? '',
        gradedAt: json['gradedAt'] as String?,
      );
}

class ParentAssignment {
  const ParentAssignment({
    required this.id,
    required this.title,
    required this.instructions,
    required this.className,
    required this.subject,
    required this.type,
    required this.state,
    required this.dueAt,
    required this.maximumScore,
    required this.recipients,
    required this.submissions,
    this.topic = '',
    this.publicationRevision = 0,
  });

  final String id;
  final String title;
  final String instructions;
  final String className;
  final String subject;
  final String type;
  final String state;
  final String dueAt;
  final int maximumScore;
  final String topic;
  final int publicationRevision;
  final List<ParentAssignmentRecipient> recipients;
  final List<ParentAssignmentSubmission> submissions;

  ParentAssignmentSubmission? submissionFor(String studentId) {
    for (final item in submissions) {
      if (item.studentId == studentId) return item;
    }
    return null;
  }
}

class ParentAssignmentsRepository {
  ParentAssignmentsRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  Future<List<ParentAssignment>> load() async {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.parent) return const [];

    final submissionRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: parentAssignmentSubmissionEntityType,
    );
    final submissionsByAssignment = <String, List<ParentAssignmentSubmission>>{};
    for (final record in submissionRecords) {
      final payload = record.payload;
      if ((payload['state'] as String? ?? 'draft') == 'draft') continue;
      final item = ParentAssignmentSubmission.fromJson(payload);
      submissionsByAssignment
          .putIfAbsent(item.assignmentId, () => <ParentAssignmentSubmission>[])
          .add(item);
    }

    final assignmentRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: parentAssignmentEntityType,
    );
    final assignments = <ParentAssignment>[];
    for (final record in assignmentRecords) {
      final payload = record.payload;
      final state = payload['state'] as String? ?? '';
      if (state != 'published' && state != 'closed') continue;
      final recipients = <ParentAssignmentRecipient>[
        for (final raw in (payload['familyRecipients'] as List? ?? const []))
          if (raw is Map)
            ParentAssignmentRecipient.fromJson(
              Map<String, Object?>.from(raw),
            ),
      ];
      // Connected Family sync deliberately publishes only this guardian's
      // linked recipients. Old cached records without that field are ignored
      // rather than guessed from class name or another family record.
      if (LocalDatabase.blockDemoSeeds && recipients.isEmpty) continue;
      assignments.add(
        ParentAssignment(
          id: payload['id'] as String? ?? '',
          title: payload['title'] as String? ?? '',
          instructions: payload['instructions'] as String? ?? '',
          className: payload['className'] as String? ?? '',
          subject: payload['subject'] as String? ?? '',
          type: payload['type'] as String? ?? 'homework',
          state: state,
          dueAt: payload['dueAt'] as String? ?? '',
          maximumScore: (payload['maximumScore'] as num?)?.toInt() ?? 0,
          topic: payload['topic'] as String? ?? '',
          publicationRevision:
              (payload['publicationRevision'] as num?)?.toInt() ?? 0,
          recipients: recipients,
          submissions: submissionsByAssignment[payload['id'] as String? ?? ''] ??
              const [],
        ),
      );
    }
    assignments.sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return assignments;
  }
}
