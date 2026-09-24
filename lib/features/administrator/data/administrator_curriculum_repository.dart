import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/administrator_curriculum_models.dart';
import 'administrator_academics_repository.dart';

class AdministratorCurriculumRepository {
  AdministratorCurriculumRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const subjectType = 'academic_subject';
  static const classSubjectType = 'academic_class_subject';
  static const selectionType = 'academic_student_subject_selection';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  SchoolMembership _requireAdministrator() {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.administrator) {
      throw StateError('Subjects and class curriculum require the Administrator workspace.');
    }
    return membership;
  }

  Future<AdministratorCurriculumSnapshot> load() async {
    final membership = _requireAdministrator();
    if (!LocalDatabase.blockDemoSeeds) {
      await _ensureDemoSeed(membership);
    }
    final subjects = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: subjectType,
    );
    final offerings = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: classSubjectType,
    );
    final selections = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: selectionType,
    );
    final subjectValues = subjects
        .map(
          (record) => AdministratorSubject.fromJson(
            record.payload,
            pendingSync: record.isDirty,
          ),
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final offeringValues = offerings
        .map(
          (record) => AdministratorClassSubject.fromJson(
            record.payload,
            pendingSync: record.isDirty,
          ),
        )
        .toList()
      ..sort((a, b) {
        final byClass = a.className.compareTo(b.className);
        return byClass != 0 ? byClass : a.subjectName.compareTo(b.subjectName);
      });
    final selectionValues = selections
        .map(
          (record) => AdministratorStudentSubjectSelection.fromJson(
            record.payload,
            pendingSync: record.isDirty,
          ),
        )
        .toList();
    return AdministratorCurriculumSnapshot(
      subjects: subjectValues,
      classSubjects: offeringValues,
      selections: selectionValues,
    );
  }

  Future<void> saveSubject(AdministratorSubject subject) =>
      _save(subjectType, subject.id, subject.toJson());

  Future<void> saveClassSubject(AdministratorClassSubject offering) =>
      _save(classSubjectType, offering.id, offering.toJson());

  Future<void> setElective({
    required String studentId,
    required String classSubjectId,
    required bool selected,
  }) async {
    final id = '$studentId|$classSubjectId';
    final value = AdministratorStudentSubjectSelection(
      id: id,
      studentId: studentId,
      classSubjectId: classSubjectId,
      selected: selected,
      pendingSync: true,
    );
    await _save(selectionType, id, value.toJson());
  }

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
      entityType: subjectType,
    );
    if (existing.isNotEmpty) return;
    const subjects = [
      AdministratorSubject(
        id: '71111111-1111-4111-8111-111111111111',
        code: 'MATH',
        name: 'Mathematics',
        description: 'Core mathematics',
        isActive: true,
      ),
      AdministratorSubject(
        id: '72222222-2222-4222-8222-222222222222',
        code: 'ENG',
        name: 'English Language',
        description: 'English language and communication',
        isActive: true,
      ),
      AdministratorSubject(
        id: '73333333-3333-4333-8333-333333333333',
        code: 'BST',
        name: 'Basic Science',
        description: 'Basic science',
        isActive: true,
      ),
    ];
    for (final subject in subjects) {
      await _localDatabase.upsertLocalRecord(
        tenantId: membership.schoolId,
        entityType: subjectType,
        entityId: subject.id,
        payload: subject.toJson(),
      );
    }

    final academics = await AdministratorAcademicsRepository(
      localDatabase: _localDatabase,
      schoolSession: _schoolSession,
    ).load();
    final session = academics.activeSession;
    final academicClass = academics.classes.where((item) => item.name == 'JSS 2A').firstOrNull;
    if (session == null || academicClass == null) return;
    for (var index = 0; index < subjects.length; index++) {
      final subject = subjects[index];
      final id = '8${index + 1}111111-1111-4111-8111-111111111111';
      final offering = AdministratorClassSubject(
        id: id,
        sessionId: session.id,
        classId: academicClass.id,
        className: academicClass.name,
        subjectId: subject.id,
        subjectCode: subject.code,
        subjectName: subject.name,
        requirement: index == 2 ? 'elective' : 'compulsory',
        periodsPerWeek: index == 0 ? 5 : 4,
        isActive: true,
      );
      await _localDatabase.upsertLocalRecord(
        tenantId: membership.schoolId,
        entityType: classSubjectType,
        entityId: offering.id,
        payload: offering.toJson(),
      );
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
