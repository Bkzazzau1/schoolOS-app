import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/administrator_academics_models.dart';
import '../domain/administrator_timetable_models.dart';
import 'administrator_academics_repository.dart';
import 'administrator_staff_repository.dart';

class AdministratorTimetableRepository {
  AdministratorTimetableRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required AdministratorAcademicsRepository academics,
    required AdministratorStaffRepository staff,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _academics = academics,
        _staff = staff;

  static const entryEntityType = 'academic_timetable_entry';
  static const overrideEntityType = 'academic_timetable_override';
  static const _assignmentEntityType = 'principal_teaching_assignment';
  static const _staffProfileEntityType = 'owner_staff_profile';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final AdministratorAcademicsRepository _academics;
  final AdministratorStaffRepository _staff;

  SchoolMembership _requireAdministrator() {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.administrator) {
      throw StateError('Timetable publishing requires the Administrator workspace.');
    }
    return membership;
  }

  Future<AdministratorTimetableSnapshot> load() async {
    final membership = _requireAdministrator();
    final academics = await _academics.load();
    final activeSession = academics.activeSession;
    final activeTerm = activeSession == null
        ? null
        : academics.activeTermFor(activeSession.id);
    final curriculum = activeSession == null
        ? const <AdministratorClassSubject>[]
        : academics.classSubjects
            .where((item) => item.sessionId == activeSession.id && item.isActive)
            .toList(growable: false);
    final curriculumById = {
      for (final item in curriculum) item.id: item,
    };

    final teachers = await _teachers(membership);
    final teacherNames = {
      for (final teacher in teachers) teacher.membershipId: teacher.name,
    };
    final assignments = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _assignmentEntityType,
    );
    final assignmentTeacherByClassSubject = <String, String>{};
    for (final record in assignments) {
      final payload = record.payload;
      if (payload['endedAt'] != null && payload['endedAt'] != '') continue;
      final classSubjectId = payload['classSubjectId'] as String? ?? '';
      final teacherId = payload['teacherId'] as String? ?? '';
      if (classSubjectId.isNotEmpty && teacherId.isNotEmpty) {
        assignmentTeacherByClassSubject[classSubjectId] = teacherId;
      }
    }

    final entryRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: entryEntityType,
    );
    final entries = <AdministratorTimetableEntry>[];
    for (final record in entryRecords) {
      final payload = Map<String, Object?>.from(record.payload);
      final termId = payload['termId'] as String? ?? '';
      if (activeTerm == null || termId != activeTerm.id) continue;
      final classSubjectId = payload['classSubjectId'] as String? ?? '';
      final requirement = curriculumById[classSubjectId];
      if (requirement == null && record.isDirty) continue;
      final teacherId = payload['teacherId'] as String? ??
          assignmentTeacherByClassSubject[classSubjectId] ??
          '';
      final enriched = <String, Object?>{
        ...payload,
        'id': payload['id'] as String? ?? record.entityId,
        'classId': payload['classId'] as String? ?? requirement?.classId ?? '',
        'className': payload['className'] as String? ?? requirement?.className ?? '',
        'subjectId': payload['subjectId'] as String? ?? requirement?.subjectId ?? '',
        'subject': payload['subject'] as String? ?? requirement?.subject ?? '',
        'teacherId': teacherId,
        'teacher': payload['teacher'] as String? ?? teacherNames[teacherId] ?? '',
        'day': payload['day'] as String? ?? _dayName(payload['dayOfWeek'] as int? ?? 0),
        'status': payload['status'] as String? ??
            (teacherId.isEmpty ? 'uncovered' : 'scheduled'),
      };
      entries.add(
        AdministratorTimetableEntry.fromJson(
          enriched,
          pendingSync: record.isDirty,
        ),
      );
    }
    entries.sort((a, b) {
      final byDay = a.dayOfWeek.compareTo(b.dayOfWeek);
      if (byDay != 0) return byDay;
      final byTime = a.startTime.compareTo(b.startTime);
      if (byTime != 0) return byTime;
      return a.className.compareTo(b.className);
    });

    final activeEntryIds = {for (final entry in entries) entry.id};
    final overrideRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: overrideEntityType,
    );
    final overrides = <AdministratorTimetableOverride>[];
    for (final record in overrideRecords) {
      final override = AdministratorTimetableOverride.fromJson(
        record.payload,
        pendingSync: record.isDirty,
      );
      if (!activeEntryIds.contains(override.timetableEntryId)) continue;
      overrides.add(override);
    }
    overrides.sort((a, b) => a.lessonDate.compareTo(b.lessonDate));

    return AdministratorTimetableSnapshot(
      activeTerm: activeTerm,
      curriculum: curriculum,
      entries: entries,
      overrides: overrides,
      teachers: teachers,
    );
  }

  Future<List<AdministratorTimetableTeacher>> _teachers(
    SchoolMembership membership,
  ) async {
    final people = (await _staff.load()).staff;
    final profiles = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _staffProfileEntityType,
    );
    final profileByStaff = {
      for (final record in profiles) record.entityId: record.payload,
    };
    final result = <AdministratorTimetableTeacher>[];
    for (final person in people) {
      final profile = profileByStaff[person.id];
      final membershipId = profile?['linkedMembershipId'] as String? ?? '';
      final systemRole = profile?['systemRole'] as String? ?? '';
      if (membershipId.isEmpty || systemRole != 'teacher') continue;
      result.add(
        AdministratorTimetableTeacher(
          membershipId: membershipId,
          staffId: person.id,
          name: person.name,
          section: person.section,
        ),
      );
    }
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  Future<void> saveEntry({
    String? id,
    required String termId,
    required AdministratorClassSubject classSubject,
    required int dayOfWeek,
    required int periodNumber,
    required String startTime,
    required String endTime,
    required String room,
    bool isActive = true,
  }) async {
    final membership = _requireAdministrator();
    if (termId.isEmpty) throw StateError('Activate an academic term first.');
    if (!classSubject.isActive) {
      throw StateError('Choose an active class curriculum requirement.');
    }
    if (dayOfWeek < 1 || dayOfWeek > 7) {
      throw ArgumentError('Choose a valid timetable day.');
    }
    if (periodNumber < 1 || periodNumber > 30) {
      throw ArgumentError('Period number must be between 1 and 30.');
    }
    if (!_validTime(startTime) || !_validTime(endTime) || startTime.compareTo(endTime) >= 0) {
      throw ArgumentError('Enter a valid start and end time.');
    }
    final entryId = id ?? 'tt-${DateTime.now().microsecondsSinceEpoch}';
    final payload = <String, Object?>{
      'id': entryId,
      'termId': termId,
      'classSubjectId': classSubject.id,
      'dayOfWeek': dayOfWeek,
      'periodNumber': periodNumber,
      'startTime': startTime,
      'endTime': endTime,
      'room': room.trim(),
      'isActive': isActive,
    };
    await _queue(
      membership: membership,
      entityType: entryEntityType,
      entityId: entryId,
      payload: payload,
    );
  }

  Future<void> deactivateEntry(AdministratorTimetableEntry entry) async {
    final membership = _requireAdministrator();
    await _queue(
      membership: membership,
      entityType: entryEntityType,
      entityId: entry.id,
      payload: {
        ...entry.toMutationJson(),
        'isActive': false,
      },
    );
  }

  Future<void> saveOverride({
    String? id,
    required AdministratorTimetableEntry entry,
    required String lessonDate,
    String substituteTeacherId = '',
    String room = '',
    String note = '',
    bool isCancelled = false,
  }) async {
    final membership = _requireAdministrator();
    final date = DateTime.tryParse(lessonDate);
    if (date == null) throw ArgumentError('Choose a valid lesson date.');
    if (date.weekday != entry.dayOfWeek) {
      throw ArgumentError('Override date must match the recurring lesson weekday.');
    }
    final overrideId = id ?? 'tt-override-${DateTime.now().microsecondsSinceEpoch}';
    final payload = <String, Object?>{
      'id': overrideId,
      'timetableEntryId': entry.id,
      'lessonDate': lessonDate,
      'substituteTeacherId': substituteTeacherId,
      'room': room.trim(),
      'note': note.trim(),
      'isCancelled': isCancelled,
    };
    await _queue(
      membership: membership,
      entityType: overrideEntityType,
      entityId: overrideId,
      payload: payload,
    );
  }

  Future<void> _queue({
    required SchoolMembership membership,
    required String entityType,
    required String entityId,
    required Map<String, Object?> payload,
  }) async {
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

  bool _validTime(String value) => RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value);

  String _dayName(int day) => const {
        1: 'Monday',
        2: 'Tuesday',
        3: 'Wednesday',
        4: 'Thursday',
        5: 'Friday',
        6: 'Saturday',
        7: 'Sunday',
      }[day] ?? '';
}