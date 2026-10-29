import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/features/teacher/data/teacher_syllabus_repository.dart' show teacherSyllabusProgressEntityType;

/// Seeds a real, minimal Secondary curriculum - an active session and term, one real `Secondary`
/// class record for every name in [classNames] (so `PrincipalAssignmentsRepository.classOptions`
/// has something real to list), and a compulsory Mathematics class-subject for every name in
/// [mathematicsFor] (defaults to all of [classNames]) - mirroring exactly what the Administrator's
/// real Academics screen would create (payload shape matches the backend's own
/// `serialize_class_subject`/`serialize_topic`). Tests use this so
/// `PrincipalAssignmentsRepository`/`PrincipalAcademicsRepository`'s real "canonical active
/// curriculum" checks have something real to find, instead of refusing everything because no
/// curriculum was ever configured in the fixture.
///
/// Returns each class in [mathematicsFor]'s `classSubjectId`, keyed by class name, so a caller can
/// seed real syllabus topics/progress against it if it needs to.
Future<Map<String, String>> seedSecondaryMathematicsCurriculum(
  LocalDatabase db, {
  required String tenantId,
  List<String> classNames = const ['JSS 2A', 'JSS 2B'],
  List<String>? mathematicsFor,
}) async {
  final withMathematics = (mathematicsFor ?? classNames).toSet();
  const sessionId = 'SESSION-FIXTURE';
  const termId = 'TERM-FIXTURE';
  await db.upsertLocalRecord(
    tenantId: tenantId,
    entityType: 'academic_session',
    entityId: sessionId,
    payload: const {
      'id': sessionId,
      'code': '2026-2027',
      'name': '2026/2027',
      'startsOn': '2026-09-08',
      'endsOn': '2027-07-10',
      'status': 'active',
    },
  );
  await db.upsertLocalRecord(
    tenantId: tenantId,
    entityType: 'academic_term',
    entityId: termId,
    payload: const {
      'id': termId,
      'sessionId': sessionId,
      'code': 'T1',
      'name': 'Term 1',
      'sequence': 1,
      'startsOn': '2026-09-08',
      'endsOn': '2026-12-12',
      'status': 'active',
    },
  );

  final classSubjectIds = <String, String>{};
  var level = 7;
  for (final className in classNames) {
    final slug = className.replaceAll(' ', '-');
    final classId = 'CLASS-$slug';

    await db.upsertLocalRecord(
      tenantId: tenantId,
      entityType: 'academic_class',
      entityId: classId,
      payload: {
        'id': classId,
        'code': className,
        'name': className,
        'section': 'Secondary',
        'levelOrder': level++,
        'stream': '',
        'nextClassId': '',
        'isTerminal': false,
        'isActive': true,
      },
    );
    if (!withMathematics.contains(className)) continue;
    final classSubjectId = 'CS-$slug-MATH';
    classSubjectIds[className] = classSubjectId;
    await db.upsertLocalRecord(
      tenantId: tenantId,
      entityType: 'academic_class_subject',
      entityId: classSubjectId,
      payload: {
        'id': classSubjectId,
        'sessionId': sessionId,
        'classId': classId,
        'className': className,
        'subjectId': 'SUBJ-MATH',
        'subjectCode': 'MATH',
        'subject': 'Mathematics',
        'requirement': 'compulsory',
        'periodsPerWeek': 5,
        'isActive': true,
      },
    );
  }
  return classSubjectIds;
}

/// Seeds one real canonical curriculum topic for [classSubjectId]/[termId] (from
/// [seedSecondaryMathematicsCurriculum]'s return value and `'TERM-FIXTURE'` respectively), and,
/// if [reportedStatus] is given, a real `teacher_syllabus_progress` record for it - the same real
/// entities the Administrator's Academics screen and a teacher's own syllabus report would create.
Future<void> seedCurriculumTopic(
  LocalDatabase db, {
  required String tenantId,
  required String className,
  required String classSubjectId,
  String termId = 'TERM-FIXTURE',
  String title = 'Algebraic expressions',
  String? reportedStatus,
}) async {
  final topicId = 'TOPIC-$classSubjectId-W1';
  await db.upsertLocalRecord(
    tenantId: tenantId,
    entityType: 'academic_curriculum_topic',
    entityId: topicId,
    payload: {
      'id': topicId,
      'classSubjectId': classSubjectId,
      'termId': termId,
      'sequence': 1,
      'title': title,
      'description': '',
    },
  );
  if (reportedStatus == null) return;
  await db.upsertLocalRecord(
    tenantId: tenantId,
    entityType: teacherSyllabusProgressEntityType,
    entityId: topicId,
    payload: {
      'id': topicId,
      'className': className,
      'week': 1,
      'reportedStatus': reportedStatus,
      'actorMembershipId': '',
      'version': 1,
      'updatedAt': '2026-10-01T00:00:00Z',
      'classSubjectId': classSubjectId,
      'subject': 'Mathematics',
      'topic': title,
      'termId': termId,
    },
  );
}
