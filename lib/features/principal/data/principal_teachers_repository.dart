import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/domain/administrator_staff_models.dart';
import '../../proprietor/data/owner_staff_profile_repository.dart';
import '../../proprietor/domain/owner_staff_profile_models.dart';
import '../domain/principal_teachers_models.dart';

class PrincipalTeachersSnapshot {
  const PrincipalTeachersSnapshot({
    required this.teachers,
    required this.profiles,
    required this.notes,
    required this.permissions,
  });

  final List<PrincipalTeacher> teachers;
  final List<PrincipalTeacherProfile> profiles;
  final Map<String, PrincipalTeacherNote> notes;
  final PrincipalTeacherPermissions permissions;
}

class PrincipalTeacherActionResult {
  const PrincipalTeacherActionResult({required this.success, required this.message});
  final bool success;
  final String message;
}

const _notEvaluatedNote =
    'No teaching-load, syllabus or assessment evidence has been recorded for this teacher yet.';

String _initialsOf(String name) =>
    name.split(' ').where((part) => part.isNotEmpty && part != 'Mr.' && part != 'Mrs.' && part != 'Mallam' && part != 'Alhaji').take(2).map((part) => part[0]).join().toUpperCase();

/// A real member of staff counts as a teacher for this screen the same way the owner's Staff & HR overview
/// decides it (StaffOverviewPerson.teaches): their role names them as one.
bool _teaches(AdministratorStaffRecord record) => record.role.toLowerCase().contains('teacher');

class PrincipalTeachersRepository {
  PrincipalTeachersRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required OwnerStaffProfileRepository staff,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _staff = staff;

  static const _noteEntity = 'principal_teacher_note';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final OwnerStaffProfileRepository _staff;

  PrincipalTeacherPermissions permissionsFor(SchoolMembership membership) => PrincipalTeacherPermissions(
        canReviewSecondaryTeachers: membership.role == SchoolRole.principal,
        canSavePrivateNotes: membership.role == SchoolRole.principal,
        canViewConfidentialPayroll: false,
      );

  Future<List<AdministratorStaffRecord>> _secondaryTeachers() async {
    final all = await _staff.people();
    return [for (final s in all) if (s.section == 'Secondary' && _teaches(s)) s];
  }

  PrincipalTeacher _summaryOf(AdministratorStaffRecord s) => PrincipalTeacher(
        id: s.id,
        name: s.name,
        initials: _initialsOf(s.name),
        department: 'Not recorded yet',
        subjects: 'Not recorded yet',
        classes: 0,
        students: 0,
        attendance: 0,
        punctuality: 0,
        lessonPlans: 0,
        syllabus: 0,
        assessments: 0,
        workload: 'Not recorded yet',
        status: 'Not evaluated',
        pending: 0,
        note: _notEvaluatedNote,
      );

  PrincipalTeacherProfile _profileOf(StaffProfileView view) {
    final s = view.person;
    final p = view.profile;
    final rate = view.attendanceRate;
    String orNotRecorded(String value) => value.trim().isEmpty ? 'Not recorded yet' : value.trim();
    return PrincipalTeacherProfile(
      directoryId: s.id,
      staffId: orNotRecorded(p.staffId),
      payrollId: 'Not recorded yet',
      name: s.name,
      section: s.section,
      campus: 'Not recorded yet',
      jobTitle: s.role,
      department: 'Not recorded yet',
      employmentType: orNotRecorded(p.personal.employmentType),
      employmentStatus: 'Not recorded yet',
      hireDate: orNotRecorded(p.personal.employmentDate),
      qualification: p.highestLevel ?? 'Not recorded yet',
      professionalId: 'Not recorded yet',
      phone: orNotRecorded(p.personal.phone),
      email: orNotRecorded(p.personal.email),
      nextOfKin: orNotRecorded(p.personal.nextOfKinName),
      emergencyPhone: orNotRecorded(p.personal.nextOfKinPhone),
      attendance: rate == null ? 0 : rate.round(),
      punctuality: 0,
      weeklyPeriods: 0,
      workload: 'Not recorded yet',
      classResponsibility: 'Not recorded yet',
      subjects: const [],
      assignments: const [],
      leave: const [],
      documents: [
        for (final d in p.documents)
          PrincipalTeacherDocument(name: d.name, status: _documentStatusLabel(d.status), visibility: 'HR + authorized leadership'),
      ],
      timeline: const [],
      supportNote: _notEvaluatedNote,
    );
  }

  Future<PrincipalTeachersSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    final secondaryTeachers = await _secondaryTeachers();
    final teachers = secondaryTeachers.map(_summaryOf).toList()..sort((a, b) => a.id.compareTo(b.id));

    final profiles = <PrincipalTeacherProfile>[];
    for (final record in secondaryTeachers) {
      profiles.add(_profileOf(await _staff.view(record)));
    }
    profiles.sort((a, b) => a.directoryId.compareTo(b.directoryId));

    final noteRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _noteEntity,
    );
    final notes = <String, PrincipalTeacherNote>{
      for (final record in noteRecords)
        PrincipalTeacherNote.fromJson(record.payload).teacherId: PrincipalTeacherNote.fromJson(record.payload),
    };

    return PrincipalTeachersSnapshot(
      teachers: teachers,
      profiles: profiles,
      notes: notes,
      permissions: permissionsFor(membership),
    );
  }

  Future<PrincipalTeacherActionResult> savePrivateNote({
    required String teacherId,
    required String text,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canSavePrivateNotes) {
      return const PrincipalTeacherActionResult(
        success: false,
        message: 'This membership cannot save private Principal notes.',
      );
    }
    final normalized = text.trim();
    final note = PrincipalTeacherNote(teacherId: teacherId, text: normalized);
    final existing = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _noteEntity,
    );
    final alreadyExists = existing.any((record) => record.entityId == teacherId);

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _noteEntity,
      entityId: teacherId,
      payload: note.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _noteEntity,
      entityId: teacherId,
      operation: alreadyExists ? SyncOperation.update : SyncOperation.create,
      payload: note.toJson(),
    );

    return PrincipalTeacherActionResult(
      success: true,
      message: normalized.isEmpty
          ? 'Private Principal note cleared offline and queued for sync.'
          : 'Private Principal note saved offline and queued for sync.',
    );
  }
}

String _documentStatusLabel(StaffDocumentStatus status) => switch (status) {
      StaffDocumentStatus.requested => 'Requested',
      StaffDocumentStatus.received => 'Received',
      StaffDocumentStatus.verified => 'Verified',
    };
