import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/teacher_attendance_models.dart';
import 'teacher_attendance_demo_data.dart';
import 'teacher_roster.dart';

class TeacherAttendanceActionResult {
  const TeacherAttendanceActionResult({required this.success, required this.message, this.register});
  final bool success;
  final String message;
  final TeacherAttendanceRegister? register;
}

abstract class TeacherAttendanceDataSource {
  Future<TeacherAttendanceSnapshot> load();
  Future<TeacherAttendanceActionResult> setStatus({required String lessonId, required String studentId, required TeacherAttendanceStatus status});
  Future<TeacherAttendanceActionResult> setNote({required String lessonId, required String studentId, required String note});
  Future<TeacherAttendanceActionResult> setTopic({required String lessonId, required String topicId});
  Future<TeacherAttendanceActionResult> markAllPresent({required String lessonId});
  Future<TeacherAttendanceActionResult> submit({required String lessonId});
}

class TeacherAttendanceRepository implements TeacherAttendanceDataSource {
  TeacherAttendanceRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required TeacherRoster roster,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _roster = roster;

  static const registerEntityType = 'teacher_lesson_attendance_register';
  static const privateScheduleEntityType = 'teacher_timetable_schedule';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final TeacherRoster _roster;

  TeacherAttendancePermissions permissionsFor(SchoolMembership membership) {
    final isTeacher = membership.role == SchoolRole.teacher;
    return TeacherAttendancePermissions(
      canViewAssignedRegisters: isTeacher,
      canEditAssignedRegister: isTeacher,
      canSubmitAssignedRegister: isTeacher,
      canEditOtherTeachersRegisters: false,
      canFinalizeUnsyncedAbsence: false,
    );
  }

  @override
  Future<TeacherAttendanceSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    if (!LocalDatabase.blockDemoSeeds) return _loadDemo(membership);

    final scheduleRecord = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: privateScheduleEntityType,
      entityId: membership.id,
    );
    final assignmentTopics = await _topicOptionsByClassSubject(membership);
    final occurrences = _canonicalOccurrences(
      membership: membership,
      schedule: scheduleRecord?.payload ?? const <String, Object?>{},
      topicOptions: assignmentTopics,
    );

    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: registerEntityType,
    );
    final byId = {for (final record in records) record.entityId: record};
    final registers = <TeacherAttendanceRegister>[];

    for (final occurrence in occurrences) {
      final record = byId[occurrence.lesson.id];
      if (record == null) {
        final fresh = occurrence.copyWith(pendingSync: false);
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: registerEntityType,
          entityId: fresh.lesson.id,
          payload: fresh.toLocalJson(),
          isDirty: false,
        );
        registers.add(fresh);
        continue;
      }

      var register = TeacherAttendanceRegister.fromJson(record.payload).copyWith(
        pendingSync: record.isDirty,
      );
      final occurrenceLesson = occurrence.lesson;
      register = register.copyWith(
        lesson: TeacherAttendanceLesson(
          id: register.lesson.id.isEmpty ? occurrenceLesson.id : register.lesson.id,
          timetableEntryId: register.lesson.timetableEntryId.isEmpty ? occurrenceLesson.timetableEntryId : register.lesson.timetableEntryId,
          lessonDate: register.lesson.lessonDate.isEmpty ? occurrenceLesson.lessonDate : register.lesson.lessonDate,
          classSubjectId: register.lesson.classSubjectId.isEmpty ? occurrenceLesson.classSubjectId : register.lesson.classSubjectId,
          termId: register.lesson.termId.isEmpty ? occurrenceLesson.termId : register.lesson.termId,
          className: register.lesson.className.isEmpty ? occurrenceLesson.className : register.lesson.className,
          subject: register.lesson.subject.isEmpty ? occurrenceLesson.subject : register.lesson.subject,
          time: register.lesson.time.isEmpty ? occurrenceLesson.time : register.lesson.time,
          room: occurrenceLesson.room,
          periodNumber: register.lesson.periodNumber == 0 ? occurrenceLesson.periodNumber : register.lesson.periodNumber,
          topicId: register.lesson.topicId,
          topic: register.lesson.topic,
          topicOptions: occurrenceLesson.topicOptions,
        ),
      );
      if (register.submissionState == TeacherAttendanceSubmissionState.draft) {
        register = _reconcileDraftRoster(register, occurrence.entries);
      }
      registers.add(register);
    }

    registers.sort(_registerOrder);
    return TeacherAttendanceSnapshot(
      registers: registers,
      permissions: permissionsFor(membership),
      dateLabel: _weekLabel(DateTime.now()),
      canonical: true,
    );
  }

  Future<Map<String, List<TeacherAttendanceTopicOption>>> _topicOptionsByClassSubject(SchoolMembership membership) async {
    final classes = await _roster.assignedClasses(membership);
    return {
      for (final assigned in classes)
        if (assigned.classSubjectId.isNotEmpty)
          assigned.classSubjectId: [
            for (final topic in assigned.topics)
              TeacherAttendanceTopicOption(id: topic.id, title: topic.title),
          ],
    };
  }

  List<TeacherAttendanceRegister> _canonicalOccurrences({
    required SchoolMembership membership,
    required Map<String, Object?> schedule,
    required Map<String, List<TeacherAttendanceTopicOption>> topicOptions,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - DateTime.monday));
    final currentWeekStart = _isoDate(weekStart);
    final publishedWeekStart = schedule['attendanceWeekStart'] as String? ?? '';
    if (schedule.containsKey('attendanceOccurrences') && publishedWeekStart == currentWeekStart) {
      return _publishedOccurrences(
        membership: membership,
        rawOccurrences: schedule['attendanceOccurrences'],
        topicOptions: topicOptions,
      );
    }

    // Compatibility and stale-snapshot fallback. The recurring schedule is safe
    // to project into the current week; a published occurrence snapshot is
    // accepted only for the exact week it was generated for.
    final entries = _mapList(schedule['entries']);
    final overrides = _mapList(schedule['overrides']);
    final overrideByOccurrence = <String, Map<String, Object?>>{};
    for (final override in overrides) {
      final entryId = override['timetableEntryId'] as String? ?? '';
      final lessonDate = override['lessonDate'] as String? ?? '';
      if (entryId.isNotEmpty && lessonDate.isNotEmpty) {
        overrideByOccurrence['$entryId|$lessonDate'] = override;
      }
    }

    final result = <TeacherAttendanceRegister>[];
    final included = <String>{};
    final baseEntryIds = <String>{};
    for (final entry in entries) {
      if (entry['isActive'] == false) continue;
      final entryId = entry['id'] as String? ?? '';
      final weekday = entry['dayOfWeek'] as int? ?? 0;
      if (entryId.isEmpty || weekday < 1 || weekday > 7) continue;
      baseEntryIds.add(entryId);
      final date = weekStart.add(Duration(days: weekday - 1));
      if (date.isAfter(today)) continue;
      final dateIso = _isoDate(date);
      final override = overrideByOccurrence['$entryId|$dateIso'];
      if (override?['status'] == 'cancelled' || override?['isCancelled'] == true) continue;
      final effectiveTeacher = override?['teacherId'] as String? ?? entry['teacherId'] as String? ?? '';
      if (effectiveTeacher != membership.id) continue;
      final source = override?['lesson'] is Map
          ? Map<String, Object?>.from(override!['lesson'] as Map)
          : entry;
      final register = _occurrenceRegister(
        entryId: entryId,
        lessonDate: dateIso,
        source: source,
        room: override?['room'] as String? ?? source['room'] as String? ?? '',
        topicOptions: topicOptions,
      );
      if (included.add(register.lesson.id)) result.add(register);
    }

    for (final override in overrides) {
      if (override['teacherId'] != membership.id || override['status'] != 'substitution') continue;
      final entryId = override['timetableEntryId'] as String? ?? '';
      if (baseEntryIds.contains(entryId)) continue;
      final date = DateTime.tryParse(override['lessonDate'] as String? ?? '');
      if (date == null || date.isBefore(weekStart) || date.isAfter(today)) continue;
      final rawLesson = override['lesson'];
      if (rawLesson is! Map) continue;
      final source = Map<String, Object?>.from(rawLesson);
      final register = _occurrenceRegister(
        entryId: entryId,
        lessonDate: _isoDate(date),
        source: source,
        room: override['room'] as String? ?? source['room'] as String? ?? '',
        topicOptions: topicOptions,
      );
      if (included.add(register.lesson.id)) result.add(register);
    }

    result.sort(_registerOrder);
    return result;
  }

  List<TeacherAttendanceRegister> _publishedOccurrences({
    required SchoolMembership membership,
    required Object? rawOccurrences,
    required Map<String, List<TeacherAttendanceTopicOption>> topicOptions,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = <TeacherAttendanceRegister>[];
    for (final source in _mapList(rawOccurrences)) {
      if ((source['teacherId'] as String? ?? '') != membership.id) continue;
      if (source['status'] == 'cancelled') continue;
      final lessonDate = source['lessonDate'] as String? ?? '';
      final date = DateTime.tryParse(lessonDate);
      if (date == null || date.isAfter(today)) continue;
      final entryId = source['id'] as String? ?? '';
      if (entryId.isEmpty) continue;
      result.add(
        _occurrenceRegister(
          entryId: entryId,
          lessonDate: lessonDate,
          source: source,
          room: source['room'] as String? ?? '',
          topicOptions: topicOptions,
        ),
      );
    }
    result.sort(_registerOrder);
    return result;
  }

  TeacherAttendanceRegister _occurrenceRegister({
    required String entryId,
    required String lessonDate,
    required Map<String, Object?> source,
    required String room,
    required Map<String, List<TeacherAttendanceTopicOption>> topicOptions,
  }) {
    final classSubjectId = source['classSubjectId'] as String? ?? '';
    final eligible = _eligibleForOccurrence(source, lessonDate);
    final publishedTopics = _mapList(source['topics']);
    final resolvedTopics = topicOptions[classSubjectId] ?? [
      for (final item in publishedTopics)
        if ((item['id'] as String? ?? '').isNotEmpty)
          TeacherAttendanceTopicOption(
            id: item['id'] as String? ?? '',
            title: item['title'] as String? ?? '',
          ),
    ];
    final registerId = _registerId(entryId, lessonDate);
    return TeacherAttendanceRegister(
      lesson: TeacherAttendanceLesson(
        id: registerId,
        timetableEntryId: entryId,
        lessonDate: lessonDate,
        classSubjectId: classSubjectId,
        termId: source['termId'] as String? ?? '',
        className: source['className'] as String? ?? '',
        subject: source['subject'] as String? ?? '',
        time: source['time'] as String? ?? '',
        room: room,
        periodNumber: source['periodNumber'] as int? ?? 0,
        topic: '',
        topicOptions: resolvedTopics,
      ),
      entries: [
        for (var i = 0; i < eligible.length; i++)
          TeacherAttendanceStudentEntry(
            id: i + 1,
            code: eligible[i]['studentName'] as String? ?? eligible[i]['studentId'] as String? ?? '',
            studentId: eligible[i]['studentId'] as String? ?? '',
            status: TeacherAttendanceStatus.unmarked,
            note: '',
          ),
      ],
      submissionState: TeacherAttendanceSubmissionState.draft,
    );
  }

  List<Map<String, Object?>> _eligibleForOccurrence(Map<String, Object?> source, String lessonDate) {
    final rawByDate = source['eligibleStudentsByDate'];
    if (rawByDate is Map) {
      final dated = rawByDate[lessonDate];
      if (dated != null) return _mapList(dated);
    }
    return _mapList(source['eligibleStudents']);
  }

  TeacherAttendanceRegister _reconcileDraftRoster(TeacherAttendanceRegister existing, List<TeacherAttendanceStudentEntry> canonical) {
    final prior = {for (final item in existing.entries) item.studentId: item};
    return existing.copyWith(
      entries: [
        for (var i = 0; i < canonical.length; i++)
          TeacherAttendanceStudentEntry(
            id: i + 1,
            code: canonical[i].code,
            studentId: canonical[i].studentId,
            status: prior[canonical[i].studentId]?.status ?? TeacherAttendanceStatus.unmarked,
            note: prior[canonical[i].studentId]?.note ?? '',
          ),
      ],
    );
  }

  @override
  Future<TeacherAttendanceActionResult> setStatus({required String lessonId, required String studentId, required TeacherAttendanceStatus status}) =>
      _editRegister(
        lessonId: lessonId,
        mutate: (register) => register.copyWith(
          entries: [
            for (final entry in register.entries)
              entry.studentId == studentId ? entry.copyWith(status: status) : entry,
          ],
        ),
        successMessage: 'Attendance status saved locally and queued for synchronization.',
      );

  @override
  Future<TeacherAttendanceActionResult> setNote({required String lessonId, required String studentId, required String note}) =>
      _editRegister(
        lessonId: lessonId,
        mutate: (register) => register.copyWith(
          entries: [
            for (final entry in register.entries)
              entry.studentId == studentId ? entry.copyWith(note: note) : entry,
          ],
        ),
        successMessage: 'Attendance note saved locally and queued for synchronization.',
      );

  @override
  Future<TeacherAttendanceActionResult> setTopic({required String lessonId, required String topicId}) =>
      _editRegister(
        lessonId: lessonId,
        mutate: (register) {
          final selected = register.lesson.topicOptions.where((item) => item.id == topicId);
          final title = selected.isEmpty ? '' : selected.first.title;
          return register.copyWith(lesson: register.lesson.copyWith(topicId: topicId, topic: title));
        },
        successMessage: topicId.isEmpty
            ? 'Curriculum topic cleared locally and queued for synchronization.'
            : 'Curriculum topic linked to this lesson occurrence and queued for synchronization.',
      );

  @override
  Future<TeacherAttendanceActionResult> markAllPresent({required String lessonId}) =>
      _editRegister(
        lessonId: lessonId,
        mutate: (register) => register.copyWith(
          entries: [for (final entry in register.entries) entry.copyWith(status: TeacherAttendanceStatus.present)],
        ),
        successMessage: 'All eligible students marked present locally. Review before submitting.',
      );

  @override
  Future<TeacherAttendanceActionResult> submit({required String lessonId}) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canSubmitAssignedRegister) {
      return const TeacherAttendanceActionResult(success: false, message: 'This membership cannot submit subject attendance.');
    }
    final register = await _readRegister(membership, lessonId);
    if (register == null) return const TeacherAttendanceActionResult(success: false, message: 'Attendance register not found.');
    if (register.submissionState == TeacherAttendanceSubmissionState.queued) {
      return TeacherAttendanceActionResult(
        success: false,
        message: 'This attendance submission is already queued and is waiting for server acknowledgement.',
        register: register,
      );
    }
    if (register.submissionState == TeacherAttendanceSubmissionState.submitted) {
      return TeacherAttendanceActionResult(
        success: false,
        message: 'This occurrence is canonically submitted. Later changes require an audited correction workflow.',
        register: register,
      );
    }
    if (register.entries.isEmpty) {
      return TeacherAttendanceActionResult(success: false, message: 'This lesson has no canonical subject-eligible students to submit.', register: register);
    }
    if (register.unmarkedCount > 0) {
      return TeacherAttendanceActionResult(
        success: false,
        message: '${register.unmarkedCount} eligible student(s) are still unmarked. Give every student an explicit status before submission.',
        register: register,
      );
    }

    if (!LocalDatabase.blockDemoSeeds) {
      final submitted = register.copyWith(
        submissionState: TeacherAttendanceSubmissionState.submitted,
        submittedAt: DateTime.now().toUtc().toIso8601String(),
        submittedByMembershipId: membership.id,
        pendingSync: false,
      );
      await _persistAndQueue(membership, submitted);
      return TeacherAttendanceActionResult(success: true, message: 'Demo attendance marked submitted locally.', register: submitted);
    }

    final queued = register.copyWith(
      submissionState: TeacherAttendanceSubmissionState.queued,
      pendingSync: true,
      clearSubmission: true,
    );
    await _persistAndQueue(membership, queued);
    return TeacherAttendanceActionResult(
      success: true,
      message: 'Attendance submission queued. It is not canonical until the server acknowledges it.',
      register: queued,
    );
  }

  Future<TeacherAttendanceActionResult> _editRegister({
    required String lessonId,
    required TeacherAttendanceRegister Function(TeacherAttendanceRegister register) mutate,
    required String successMessage,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canEditAssignedRegister) {
      return const TeacherAttendanceActionResult(success: false, message: 'This membership cannot edit subject attendance.');
    }
    final register = await _readRegister(membership, lessonId);
    if (register == null) return const TeacherAttendanceActionResult(success: false, message: 'Attendance register not found.');
    if (register.submissionState != TeacherAttendanceSubmissionState.draft) {
      return TeacherAttendanceActionResult(
        success: false,
        message: register.submissionState == TeacherAttendanceSubmissionState.queued
            ? 'Submission is queued and locked locally while server acknowledgement is pending.'
            : 'Canonical submitted attendance is locked. Use an audited correction workflow for later changes.',
        register: register,
      );
    }

    final updated = mutate(register).copyWith(
      submissionState: TeacherAttendanceSubmissionState.draft,
      pendingSync: LocalDatabase.blockDemoSeeds,
      clearSubmission: true,
    );
    await _persistAndQueue(membership, updated);
    return TeacherAttendanceActionResult(success: true, message: successMessage, register: updated);
  }

  Future<TeacherAttendanceRegister?> _readRegister(SchoolMembership membership, String lessonId) async {
    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: registerEntityType,
      entityId: lessonId,
    );
    if (record == null) return null;
    return TeacherAttendanceRegister.fromJson(record.payload).copyWith(pendingSync: record.isDirty);
  }

  Future<void> _persistAndQueue(SchoolMembership membership, TeacherAttendanceRegister register) async {
    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: registerEntityType,
      entityId: register.lesson.id,
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: registerEntityType,
      entityId: register.lesson.id,
      payload: register.toLocalJson(),
      serverVersion: existing?.serverVersion,
      isDirty: LocalDatabase.blockDemoSeeds,
    );
    if (!LocalDatabase.blockDemoSeeds) return;
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: registerEntityType,
      entityId: register.lesson.id,
      operation: existing?.serverVersion == null ? SyncOperation.create : SyncOperation.update,
      payload: register.toJson(),
      baseVersion: existing?.serverVersion,
    );
  }

  Future<TeacherAttendanceSnapshot> _loadDemo(SchoolMembership membership) async {
    final registers = <TeacherAttendanceRegister>[];
    for (final lesson in teacherAttendanceLessons) {
      final existing = await _localDatabase.getLocalRecord(
        tenantId: membership.schoolId,
        entityType: registerEntityType,
        entityId: lesson.id,
      );
      if (existing == null) {
        final register = TeacherAttendanceRegister(
          lesson: lesson,
          entries: teacherAttendanceInitialStudents,
          submissionState: TeacherAttendanceSubmissionState.draft,
        );
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: registerEntityType,
          entityId: lesson.id,
          payload: register.toLocalJson(),
        );
        registers.add(register);
      } else {
        registers.add(TeacherAttendanceRegister.fromJson(existing.payload).copyWith(pendingSync: existing.isDirty));
      }
    }
    return TeacherAttendanceSnapshot(
      registers: registers,
      permissions: permissionsFor(membership),
      dateLabel: teacherAttendanceDateLabel,
      canonical: false,
    );
  }

  List<Map<String, Object?>> _mapList(Object? raw) => [
        for (final item in raw is List ? raw : const [])
          if (item is Map) Map<String, Object?>.from(item),
      ];

  String _registerId(String entryId, String lessonDate) => 'attendance|$entryId|$lessonDate';

  String _isoDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String _weekLabel(DateTime value) {
    final today = DateTime(value.year, value.month, value.day);
    final start = today.subtract(Duration(days: today.weekday - DateTime.monday));
    final end = start.add(const Duration(days: 6));
    return '${_shortDate(start)}–${_shortDate(end)}';
  }

  String _shortDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  int _registerOrder(TeacherAttendanceRegister a, TeacherAttendanceRegister b) {
    final byDate = b.lesson.lessonDate.compareTo(a.lesson.lessonDate);
    if (byDate != 0) return byDate;
    final byTime = a.lesson.time.compareTo(b.lesson.time);
    if (byTime != 0) return byTime;
    return a.lesson.className.compareTo(b.lesson.className);
  }
}
