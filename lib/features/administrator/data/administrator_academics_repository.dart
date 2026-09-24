import 'dart:math';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/administrator_academics_models.dart';

class AdministratorAcademicsRepository {
  AdministratorAcademicsRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const sessionEntityType = 'academic_session';
  static const termEntityType = 'academic_term';
  static const classEntityType = 'academic_class';
  static const subjectEntityType = 'academic_subject';
  static const classSubjectEntityType = 'academic_class_subject';
  static const curriculumTopicEntityType = 'academic_curriculum_topic';
  static const batchEntityType = 'academic_progression_batch';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  SchoolMembership _requireAdministrator() {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.administrator) {
      throw StateError('Academic structure changes require the Administrator workspace.');
    }
    return membership;
  }

  Future<AdministratorAcademicsSnapshot> load() async {
    final membership = _requireAdministrator();
    if (!LocalDatabase.blockDemoSeeds) {
      await _ensureDemoSeed(membership);
    }

    final sessionRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: sessionEntityType,
    );
    final termRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: termEntityType,
    );
    final classRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: classEntityType,
    );
    final subjectRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: subjectEntityType,
    );
    final classSubjectRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: classSubjectEntityType,
    );
    final topicRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: curriculumTopicEntityType,
    );
    final batchRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: batchEntityType,
    );

    final sessions = sessionRecords
        .map(
          (record) => AdministratorAcademicSession.fromJson(
            record.payload,
            pendingSync: record.isDirty,
          ),
        )
        .toList();
    sessions.sort((a, b) => b.startsOn.compareTo(a.startsOn));

    final terms = termRecords
        .map(
          (record) => AdministratorAcademicTerm.fromJson(
            record.payload,
            pendingSync: record.isDirty,
          ),
        )
        .toList();
    terms.sort((a, b) {
      final bySession = a.sessionId.compareTo(b.sessionId);
      return bySession != 0 ? bySession : a.sequence.compareTo(b.sequence);
    });

    final classes = classRecords
        .map(
          (record) => AdministratorAcademicClass.fromJson(
            record.payload,
            pendingSync: record.isDirty,
          ),
        )
        .toList();
    classes.sort((a, b) {
      final order = a.levelOrder.compareTo(b.levelOrder);
      return order != 0 ? order : a.name.compareTo(b.name);
    });

    final subjects = subjectRecords
        .map(
          (record) => AdministratorSubject.fromJson(
            record.payload,
            pendingSync: record.isDirty,
          ),
        )
        .toList();
    subjects.sort((a, b) => a.name.compareTo(b.name));

    final classSubjects = classSubjectRecords
        .map(
          (record) => AdministratorClassSubject.fromJson(
            record.payload,
            pendingSync: record.isDirty,
          ),
        )
        .toList();
    classSubjects.sort((a, b) {
      final byClass = a.className.compareTo(b.className);
      if (byClass != 0) return byClass;
      final left = a.subject.isEmpty ? a.subjectId : a.subject;
      final right = b.subject.isEmpty ? b.subjectId : b.subject;
      return left.compareTo(right);
    });

    final topics = topicRecords
        .map(
          (record) => AdministratorCurriculumTopic.fromJson(
            record.payload,
            pendingSync: record.isDirty,
          ),
        )
        .toList();
    topics.sort((a, b) {
      final bySubject = a.classSubjectId.compareTo(b.classSubjectId);
      if (bySubject != 0) return bySubject;
      final byTerm = a.termId.compareTo(b.termId);
      return byTerm != 0 ? byTerm : a.sequence.compareTo(b.sequence);
    });

    final batches = batchRecords
        .map(
          (record) => AdministratorProgressionBatch.fromJson(
            record.payload,
            pendingSync: record.isDirty,
          ),
        )
        .toList();

    return AdministratorAcademicsSnapshot(
      sessions: sessions,
      terms: terms,
      classes: classes,
      subjects: subjects,
      classSubjects: classSubjects,
      topics: topics,
      batches: batches,
    );
  }

  Future<void> saveSession(AdministratorAcademicSession session) =>
      _save(sessionEntityType, session.id, session.toJson());

  Future<void> saveTerm(AdministratorAcademicTerm term) =>
      _save(termEntityType, term.id, term.toJson());

  Future<void> saveClass(AdministratorAcademicClass academicClass) =>
      _save(classEntityType, academicClass.id, academicClass.toJson());

  Future<void> saveSubject(AdministratorSubject subject) =>
      _save(subjectEntityType, subject.id, subject.toJson());

  Future<void> saveClassSubject(AdministratorClassSubject classSubject) =>
      _save(classSubjectEntityType, classSubject.id, classSubject.toJson());

  Future<void> saveCurriculumTopic(AdministratorCurriculumTopic topic) =>
      _save(curriculumTopicEntityType, topic.id, topic.toJson());

  Future<void> saveBatch(AdministratorProgressionBatch batch) =>
      _save(batchEntityType, batch.id, batch.toJson());

  Future<void> _save(
    String entityType,
    String entityId,
    Map<String, Object?> payload,
  ) async {
    final membership = _requireAdministrator();
    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: entityType,
      entityId: entityId,
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: entityType,
      entityId: entityId,
      payload: payload,
      serverVersion: existing?.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: entityType,
      entityId: entityId,
      operation: existing?.serverVersion == null
          ? SyncOperation.create
          : SyncOperation.update,
      payload: payload,
      baseVersion: existing?.serverVersion,
    );
  }

  Future<void> _ensureDemoSeed(SchoolMembership membership) async {
    final existing = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: sessionEntityType,
    );
    if (existing.isNotEmpty) return;

    const currentSessionId = '11111111-1111-4111-8111-111111111111';
    const nextSessionId = '22222222-2222-4222-8222-222222222222';
    const jss1Id = '31111111-1111-4111-8111-111111111111';
    const jss2Id = '32222222-2222-4222-8222-222222222222';
    const jss3Id = '33333333-3333-4333-8333-333333333333';
    const firstTermId = '41111111-1111-4111-8111-111111111111';
    const mathematicsId = '51111111-1111-4111-8111-111111111111';
    const englishId = '52222222-2222-4222-8222-222222222222';
    const basicScienceId = '53333333-3333-4333-8333-333333333333';

    for (final session in const [
      AdministratorAcademicSession(
        id: currentSessionId,
        code: '2026-2027',
        name: '2026/2027',
        startsOn: '2026-09-14',
        endsOn: '2027-07-23',
        status: 'active',
      ),
      AdministratorAcademicSession(
        id: nextSessionId,
        code: '2027-2028',
        name: '2027/2028',
        startsOn: '2027-09-13',
        endsOn: '2028-07-21',
        status: 'planned',
      ),
    ]) {
      await _localDatabase.upsertLocalRecord(
        tenantId: membership.schoolId,
        entityType: sessionEntityType,
        entityId: session.id,
        payload: session.toJson(),
      );
    }

    for (final term in const [
      AdministratorAcademicTerm(
        id: firstTermId,
        sessionId: currentSessionId,
        code: 'T1',
        name: 'First Term',
        sequence: 1,
        startsOn: '2026-09-14',
        endsOn: '2026-12-18',
        status: 'active',
      ),
      AdministratorAcademicTerm(
        id: '42222222-2222-4222-8222-222222222222',
        sessionId: currentSessionId,
        code: 'T2',
        name: 'Second Term',
        sequence: 2,
        startsOn: '2027-01-11',
        endsOn: '2027-04-09',
        status: 'planned',
      ),
      AdministratorAcademicTerm(
        id: '43333333-3333-4333-8333-333333333333',
        sessionId: currentSessionId,
        code: 'T3',
        name: 'Third Term',
        sequence: 3,
        startsOn: '2027-04-26',
        endsOn: '2027-07-23',
        status: 'planned',
      ),
    ]) {
      await _localDatabase.upsertLocalRecord(
        tenantId: membership.schoolId,
        entityType: termEntityType,
        entityId: term.id,
        payload: term.toJson(),
      );
    }

    for (final academicClass in const [
      AdministratorAcademicClass(
        id: jss1Id,
        code: 'JSS1A',
        name: 'JSS 1A',
        section: 'Secondary',
        levelOrder: 7,
        stream: 'A',
        nextClassId: jss2Id,
        isTerminal: false,
        isActive: true,
      ),
      AdministratorAcademicClass(
        id: jss2Id,
        code: 'JSS2A',
        name: 'JSS 2A',
        section: 'Secondary',
        levelOrder: 8,
        stream: 'A',
        nextClassId: jss3Id,
        isTerminal: false,
        isActive: true,
      ),
      AdministratorAcademicClass(
        id: jss3Id,
        code: 'JSS3A',
        name: 'JSS 3A',
        section: 'Secondary',
        levelOrder: 9,
        stream: 'A',
        nextClassId: '',
        isTerminal: true,
        isActive: true,
      ),
    ]) {
      await _localDatabase.upsertLocalRecord(
        tenantId: membership.schoolId,
        entityType: classEntityType,
        entityId: academicClass.id,
        payload: academicClass.toJson(),
      );
    }

    for (final subject in const [
      AdministratorSubject(
        id: mathematicsId,
        code: 'MATH',
        name: 'Mathematics',
        shortName: 'Maths',
        section: 'Secondary',
        isActive: true,
      ),
      AdministratorSubject(
        id: englishId,
        code: 'ENG',
        name: 'English Language',
        shortName: 'English',
        section: '',
        isActive: true,
      ),
      AdministratorSubject(
        id: basicScienceId,
        code: 'BSC',
        name: 'Basic Science',
        shortName: 'Basic Sci.',
        section: 'Secondary',
        isActive: true,
      ),
    ]) {
      await _localDatabase.upsertLocalRecord(
        tenantId: membership.schoolId,
        entityType: subjectEntityType,
        entityId: subject.id,
        payload: subject.toJson(),
      );
    }

    const demoRequirements = [
      (id: '61111111-1111-4111-8111-111111111111', classId: jss1Id, subjectId: mathematicsId, periods: 5),
      (id: '62222222-2222-4222-8222-222222222222', classId: jss1Id, subjectId: englishId, periods: 5),
      (id: '63333333-3333-4333-8333-333333333333', classId: jss1Id, subjectId: basicScienceId, periods: 4),
      (id: '64444444-4444-4444-8444-444444444444', classId: jss2Id, subjectId: mathematicsId, periods: 5),
      (id: '65555555-5555-4555-8555-555555555555', classId: jss2Id, subjectId: englishId, periods: 5),
      (id: '66666666-6666-4666-8666-666666666666', classId: jss2Id, subjectId: basicScienceId, periods: 4),
    ];
    for (final item in demoRequirements) {
      final requirement = AdministratorClassSubject(
        id: item.id,
        sessionId: currentSessionId,
        classId: item.classId,
        subjectId: item.subjectId,
        requirement: 'compulsory',
        periodsPerWeek: item.periods,
        isActive: true,
      );
      await _localDatabase.upsertLocalRecord(
        tenantId: membership.schoolId,
        entityType: classSubjectEntityType,
        entityId: requirement.id,
        payload: requirement.toJson(),
      );
    }

    const firstMathRequirement = '61111111-1111-4111-8111-111111111111';
    for (final topic in const [
      AdministratorCurriculumTopic(
        id: '71111111-1111-4111-8111-111111111111',
        classSubjectId: firstMathRequirement,
        termId: firstTermId,
        sequence: 1,
        title: 'Whole numbers and place value',
        description: 'Read, write, compare and operate with whole numbers.',
      ),
      AdministratorCurriculumTopic(
        id: '72222222-2222-4222-8222-222222222222',
        classSubjectId: firstMathRequirement,
        termId: firstTermId,
        sequence: 2,
        title: 'Fractions and decimals',
        description: 'Equivalent fractions, decimals and basic operations.',
      ),
    ]) {
      await _localDatabase.upsertLocalRecord(
        tenantId: membership.schoolId,
        entityType: curriculumTopicEntityType,
        entityId: topic.id,
        payload: topic.toJson(),
      );
    }
  }

  static String newId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int value) => value.toRadixString(16).padLeft(2, '0');
    final value = bytes.map(hex).join();
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-${value.substring(12, 16)}-${value.substring(16, 20)}-${value.substring(20)}';
  }
}
