import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/teacher_lesson_plan_models.dart';
import 'teacher_lesson_plan_demo_data.dart';
import 'teacher_roster.dart';

class TeacherLessonPlanSnapshot {
  const TeacherLessonPlanSnapshot({
    required this.plans,
    required this.classOptions,
    required this.occurrenceOptions,
    required this.deliveries,
    required this.events,
    required this.permissions,
    this.canonical = false,
  });

  final List<TeacherLessonPlan> plans;
  final List<String> classOptions;
  final List<TeacherLessonPlanOccurrenceOption> occurrenceOptions;
  final List<TeacherLessonDelivery> deliveries;
  final List<TeacherLessonPlanEvent> events;
  final TeacherLessonPlanPermissions permissions;
  final bool canonical;

  TeacherLessonDelivery? deliveryFor(String planId) {
    for (final item in deliveries) {
      if (item.planId == planId) return item;
    }
    return null;
  }
}

class TeacherLessonPlanActionResult {
  const TeacherLessonPlanActionResult({
    required this.success,
    required this.message,
    this.plan,
    this.delivery,
  });

  final bool success;
  final String message;
  final TeacherLessonPlan? plan;
  final TeacherLessonDelivery? delivery;
}

class TeacherLessonPlanRepository {
  TeacherLessonPlanRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required TeacherRoster roster,
  })  : _db = localDatabase,
        _session = schoolSession,
        _roster = roster;

  static const planType = 'teacher_lesson_plan';
  static const deliveryType = 'lesson_delivery_record';
  static const privateScheduleType = 'teacher_timetable_schedule';
  static const _legacyEventType = 'teacher_lesson_plan_event';

  final LocalDatabase _db;
  final SchoolSessionController _session;
  final TeacherRoster _roster;

  TeacherLessonPlanPermissions permissionsFor(SchoolMembership membership) {
    final teacher = membership.role == SchoolRole.teacher;
    return TeacherLessonPlanPermissions(
      canViewAssignedPlans: teacher,
      canEditDrafts: teacher,
      canSubmitForApproval: teacher,
      canApprovePlans: false,
      canOverrideReviewerStatus: false,
      canRecordDelivery: teacher,
    );
  }

  Future<TeacherLessonPlanSnapshot> load() async {
    final membership = _session.requireActiveMembership();
    if (!LocalDatabase.blockDemoSeeds) {
      return _loadDemo(membership);
    }

    final schedule = await _db.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: privateScheduleType,
      entityId: membership.id,
    );
    final occurrenceOptions = _occurrences(
      membership: membership,
      payload: schedule?.payload ?? const <String, Object?>{},
    );

    final planRecords = await _db.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: planType,
    );
    final plans = <TeacherLessonPlan>[];
    for (final record in planRecords) {
      final parsed = TeacherLessonPlan.fromJson(record.payload);
      final authorized = parsed.effectiveTeacherId == membership.id &&
          parsed.occurrenceStatus != 'cancelled' &&
          parsed.occurrenceStatus != 'uncovered';
      final plan = parsed.copyWith(
        pendingSync: record.isDirty,
        currentTeacherAuthorized: authorized,
      );
      if (plan.authorMembershipId == membership.id ||
          plan.effectiveTeacherId == membership.id ||
          plan.authorMembershipId.isEmpty) {
        plans.add(plan);
      }
    }
    plans.sort(_planOrder);

    final deliveryRecords = await _db.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: deliveryType,
    );
    final deliveries = <TeacherLessonDelivery>[];
    final visiblePlanIds = {for (final plan in plans) plan.id};
    for (final record in deliveryRecords) {
      final item = TeacherLessonDelivery.fromJson(record.payload).copyWith(
        pendingSync: record.isDirty,
      );
      if (visiblePlanIds.contains(item.planId)) deliveries.add(item);
    }
    deliveries.sort((a, b) => b.lessonDate.compareTo(a.lessonDate));

    final classes = {
      for (final item in occurrenceOptions) item.className,
      for (final item in plans) item.className,
    }.where((item) => item.isNotEmpty).toList()
      ..sort();

    return TeacherLessonPlanSnapshot(
      plans: plans,
      classOptions: classes,
      occurrenceOptions: occurrenceOptions,
      deliveries: deliveries,
      events: const [],
      permissions: permissionsFor(membership),
      canonical: true,
    );
  }

  List<TeacherLessonPlanOccurrenceOption> _occurrences({
    required SchoolMembership membership,
    required Map<String, Object?> payload,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayIso = _isoDate(today);
    final generatedOn = payload['planningGeneratedOn'] as String? ?? '';
    final published = _mapList(payload['planningOccurrences']);
    if (generatedOn == todayIso && published.isNotEmpty) {
      return _publishedPlanningOccurrences(
        membership: membership,
        rawOccurrences: published,
      );
    }
    return _rebuildPlanningOccurrences(
      membership: membership,
      payload: payload,
      today: today,
    );
  }

  List<TeacherLessonPlanOccurrenceOption> _publishedPlanningOccurrences({
    required SchoolMembership membership,
    required List<Map<String, Object?>> rawOccurrences,
  }) {
    final result = <TeacherLessonPlanOccurrenceOption>[];
    for (final raw in rawOccurrences) {
      final parsed = _parseOccurrence(raw, membership.id);
      if (parsed != null) result.add(parsed);
    }
    result.sort(_occurrenceOrder);
    return result;
  }

  List<TeacherLessonPlanOccurrenceOption> _rebuildPlanningOccurrences({
    required SchoolMembership membership,
    required Map<String, Object?> payload,
    required DateTime today,
  }) {
    final horizon = payload['planningHorizonDays'] as int? ?? 21;
    final end = today.add(Duration(days: horizon > 0 ? horizon - 1 : 20));
    final entries = _mapList(payload['entries']);
    final overrides = _mapList(payload['overrides']);
    final overrideByOccurrence = <String, Map<String, Object?>>{};
    for (final override in overrides) {
      final entryId = override['timetableEntryId'] as String? ?? '';
      final lessonDate = override['lessonDate'] as String? ?? '';
      if (entryId.isNotEmpty && lessonDate.isNotEmpty) {
        overrideByOccurrence['$entryId|$lessonDate'] = override;
      }
    }

    final result = <TeacherLessonPlanOccurrenceOption>[];
    final included = <String>{};
    for (final entry in entries) {
      final entryId = entry['id'] as String? ?? '';
      final weekday = entry['dayOfWeek'] as int? ?? 0;
      final termStart = DateTime.tryParse(entry['termStartsOn'] as String? ?? '');
      final termEnd = DateTime.tryParse(entry['termEndsOn'] as String? ?? '');
      if (entryId.isEmpty ||
          weekday < 1 ||
          weekday > 7 ||
          termStart == null ||
          termEnd == null) {
        continue;
      }
      var date = today;
      while (!date.isAfter(end)) {
        if (date.weekday == weekday &&
            !date.isBefore(termStart) &&
            !date.isAfter(termEnd)) {
          final dateIso = _isoDate(date);
          final override = overrideByOccurrence['$entryId|$dateIso'];
          if (override?['status'] != 'cancelled' &&
              override?['isCancelled'] != true) {
            final effectiveTeacher = override?['teacherId'] as String? ??
                entry['teacherId'] as String? ??
                membership.id;
            if (effectiveTeacher == membership.id) {
              final rawLesson = override?['lesson'];
              final source = rawLesson is Map
                  ? Map<String, Object?>.from(rawLesson)
                  : Map<String, Object?>.from(entry);
              source['id'] = entryId;
              source['lessonDate'] = dateIso;
              source['teacherId'] = membership.id;
              source['effectiveTeacherId'] = membership.id;
              source['room'] = override?['room'] as String? ??
                  source['room'] as String? ??
                  '';
              final parsed = _parseOccurrence(source, membership.id);
              if (parsed != null && included.add(parsed.id)) result.add(parsed);
            }
          }
        }
        date = date.add(const Duration(days: 1));
      }
    }

    for (final override in overrides) {
      if (override['teacherId'] != membership.id ||
          override['status'] != 'substitution' ||
          override['isCancelled'] == true) {
        continue;
      }
      final entryId = override['timetableEntryId'] as String? ?? '';
      final date = DateTime.tryParse(override['lessonDate'] as String? ?? '');
      if (entryId.isEmpty ||
          date == null ||
          date.isBefore(today) ||
          date.isAfter(end)) {
        continue;
      }
      final rawLesson = override['lesson'];
      if (rawLesson is! Map) continue;
      final source = Map<String, Object?>.from(rawLesson);
      source['id'] = entryId;
      source['lessonDate'] = _isoDate(date);
      source['teacherId'] = membership.id;
      source['effectiveTeacherId'] = membership.id;
      source['room'] =
          override['room'] as String? ?? source['room'] as String? ?? '';
      final parsed = _parseOccurrence(source, membership.id);
      if (parsed != null && included.add(parsed.id)) result.add(parsed);
    }

    result.sort(_occurrenceOrder);
    return result;
  }

  TeacherLessonPlanOccurrenceOption? _parseOccurrence(
    Map<String, Object?> raw,
    String membershipId,
  ) {
    final effectiveTeacher = raw['effectiveTeacherId'] as String? ??
        raw['teacherId'] as String? ??
        '';
    if (effectiveTeacher != membershipId) return null;
    if (raw['occurrenceStatus'] == 'cancelled' || raw['status'] == 'cancelled') {
      return null;
    }
    final topics = <TeacherLessonPlanTopicOption>[];
    for (final topic in _mapList(raw['topics'])) {
      final id = topic['id'] as String? ?? '';
      if (id.isEmpty) continue;
      topics.add(
        TeacherLessonPlanTopicOption(
          id: id,
          title: topic['title'] as String? ?? '',
          sequence: topic['sequence'] as int? ?? 1,
        ),
      );
    }
    final date = raw['lessonDate'] as String? ?? '';
    final entryId = raw['id'] as String? ?? '';
    final classSubjectId = raw['classSubjectId'] as String? ?? '';
    if (date.isEmpty ||
        entryId.isEmpty ||
        classSubjectId.isEmpty ||
        topics.isEmpty) {
      return null;
    }
    return TeacherLessonPlanOccurrenceOption(
      timetableEntryId: entryId,
      lessonDate: date,
      classSubjectId: classSubjectId,
      termId: raw['termId'] as String? ?? '',
      className: raw['className'] as String? ?? '',
      subject: raw['subject'] as String? ?? '',
      time: raw['time'] as String? ?? '',
      room: raw['room'] as String? ?? '',
      periodNumber: raw['periodNumber'] as int? ?? 0,
      topics: topics,
    );
  }

  Future<TeacherLessonPlanActionResult> createPlan({
    required TeacherLessonPlanOccurrenceOption occurrence,
    required TeacherLessonPlanTopicOption topic,
  }) async {
    final membership = _session.requireActiveMembership();
    if (!LocalDatabase.blockDemoSeeds) {
      return const TeacherLessonPlanActionResult(
        success: false,
        message: 'Canonical occurrence plans require a server-backed timetable.',
      );
    }
    if (!permissionsFor(membership).canEditDrafts) {
      return const TeacherLessonPlanActionResult(
        success: false,
        message: 'This membership cannot create lesson plans.',
      );
    }
    final current = await load();
    if (!current.occurrenceOptions.any((item) => item.id == occurrence.id)) {
      return const TeacherLessonPlanActionResult(
        success: false,
        message: 'This lesson occurrence is no longer assigned to you. Reload first.',
      );
    }
    if (current.plans.any((plan) =>
        plan.timetableEntryId == occurrence.timetableEntryId &&
        plan.lessonDate == occurrence.lessonDate)) {
      return const TeacherLessonPlanActionResult(
        success: false,
        message: 'This lesson occurrence already has a plan.',
      );
    }
    if (!occurrence.topics.any((item) => item.id == topic.id)) {
      return const TeacherLessonPlanActionResult(
        success: false,
        message: 'Choose a curriculum topic from this occurrence\'s active term.',
      );
    }

    final id = 'plan|${occurrence.timetableEntryId}|${occurrence.lessonDate}';
    final plan = TeacherLessonPlan(
      id: id,
      className: occurrence.className,
      week: occurrence.lessonDate,
      topic: topic.title,
      status: TeacherLessonPlanStatus.draft,
      updatedLabel: 'Draft created locally',
      timetableEntryId: occurrence.timetableEntryId,
      lessonDate: occurrence.lessonDate,
      classSubjectId: occurrence.classSubjectId,
      termId: occurrence.termId,
      subject: occurrence.subject,
      time: occurrence.time,
      room: occurrence.room,
      topicId: topic.id,
      effectiveTeacherId: membership.id,
      authorMembershipId: membership.id,
      occurrenceStatus: 'scheduled',
      currentTeacherAuthorized: true,
      pendingSync: true,
    );
    await _writePlan(
      membership: membership,
      plan: plan,
      action: 'saveDraft',
      operation: SyncOperation.create,
    );
    return TeacherLessonPlanActionResult(
      success: true,
      message:
          'Occurrence lesson plan created locally and queued for server validation.',
      plan: plan,
    );
  }

  Future<TeacherLessonPlanActionResult> saveDraft({
    required TeacherLessonPlan plan,
  }) async {
    final membership = _session.requireActiveMembership();
    final current = await _readPlan(membership, plan.id);
    if (current == null) {
      return const TeacherLessonPlanActionResult(
        success: false,
        message: 'Lesson plan not found.',
      );
    }
    if (!current.teacherEditable) {
      return TeacherLessonPlanActionResult(
        success: false,
        message:
            '${teacherLessonPlanStatusLabel(current.status)} plans are not editable by this Teacher.',
        plan: current,
      );
    }
    final demo = !LocalDatabase.blockDemoSeeds;
    final next = plan.copyWith(
      status: current.status == TeacherLessonPlanStatus.needsChanges
          ? TeacherLessonPlanStatus.needsChanges
          : TeacherLessonPlanStatus.draft,
      updatedLabel:
          demo ? 'Draft saved in demo' : 'Draft saved locally · sync pending',
      pendingSync: !demo,
    );
    await _writePlan(
      membership: membership,
      plan: next,
      action: 'saveDraft',
      operation: SyncOperation.update,
    );
    return TeacherLessonPlanActionResult(
      success: true,
      message: demo
          ? 'Demo lesson-plan draft saved locally.'
          : 'Draft saved locally and queued. Canonical plan metadata stays server-controlled.',
      plan: next,
    );
  }

  Future<TeacherLessonPlanActionResult> submit({
    required TeacherLessonPlan plan,
  }) async {
    final membership = _session.requireActiveMembership();
    final current = await _readPlan(membership, plan.id);
    if (current == null) {
      return const TeacherLessonPlanActionResult(
        success: false,
        message: 'Lesson plan not found.',
      );
    }
    if (!current.teacherEditable) {
      return TeacherLessonPlanActionResult(
        success: false,
        message: current.waitingForServer
            ? 'This submission is already queued.'
            : 'This plan is not editable by this Teacher.',
        plan: current,
      );
    }
    if (plan.objectives.trim().isEmpty ||
        plan.activities.trim().isEmpty ||
        plan.assessment.trim().isEmpty) {
      return const TeacherLessonPlanActionResult(
        success: false,
        message:
            'Add learning objectives, teaching activities and assessment evidence before submission.',
      );
    }

    if (!LocalDatabase.blockDemoSeeds) {
      final submitted = plan.copyWith(
        status: TeacherLessonPlanStatus.submitted,
        updatedLabel: 'Submitted in demo',
        pendingSync: false,
        clearReview: true,
      );
      await _writePlan(
        membership: membership,
        plan: submitted,
        action: 'submit',
        operation: SyncOperation.update,
      );
      return TeacherLessonPlanActionResult(
        success: true,
        message: 'Demo lesson plan marked submitted locally.',
        plan: submitted,
      );
    }

    final queued = plan.copyWith(
      status: TeacherLessonPlanStatus.queuedSubmission,
      updatedLabel: 'Submission queued · awaiting server acknowledgement',
      pendingSync: true,
      clearReview: true,
    );
    await _writePlan(
      membership: membership,
      plan: queued,
      action: 'submit',
      operation: SyncOperation.update,
    );
    return TeacherLessonPlanActionResult(
      success: true,
      message:
          'Lesson plan submission queued. It is not submitted or approved until the server acknowledges it.',
      plan: queued,
    );
  }

  Future<TeacherLessonPlanActionResult> saveDeliveryDraft({
    required TeacherLessonPlan plan,
    required String reflection,
    required String homework,
    required bool topicCompleted,
  }) =>
      _writeDelivery(
        plan: plan,
        reflection: reflection,
        homework: homework,
        topicCompleted: topicCompleted,
        deliver: false,
      );

  Future<TeacherLessonPlanActionResult> recordDelivered({
    required TeacherLessonPlan plan,
    required String reflection,
    required String homework,
    required bool topicCompleted,
  }) =>
      _writeDelivery(
        plan: plan,
        reflection: reflection,
        homework: homework,
        topicCompleted: topicCompleted,
        deliver: true,
      );

  Future<TeacherLessonPlanActionResult> _writeDelivery({
    required TeacherLessonPlan plan,
    required String reflection,
    required String homework,
    required bool topicCompleted,
    required bool deliver,
  }) async {
    if (!LocalDatabase.blockDemoSeeds) {
      return const TeacherLessonPlanActionResult(
        success: false,
        message:
            'Canonical lesson delivery is available only in server-backed mode.',
      );
    }
    final membership = _session.requireActiveMembership();
    if (!plan.canonicalApproved) {
      return const TeacherLessonPlanActionResult(
        success: false,
        message: 'Only a server-approved lesson plan can become delivery evidence.',
      );
    }
    if (!plan.currentTeacherAuthorized) {
      return const TeacherLessonPlanActionResult(
        success: false,
        message: 'This occurrence is no longer assigned to your Teacher membership.',
      );
    }
    final date = DateTime.tryParse(plan.lessonDate);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (date == null || date.isAfter(today)) {
      return const TeacherLessonPlanActionResult(
        success: false,
        message:
            'Lesson delivery can be recorded only on or after the scheduled lesson date.',
      );
    }

    final id = 'delivery|${plan.timetableEntryId}|${plan.lessonDate}';
    final existing = await _db.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: deliveryType,
      entityId: id,
    );
    final current = existing == null
        ? TeacherLessonDelivery(
            id: id,
            planId: plan.id,
            timetableEntryId: plan.timetableEntryId,
            lessonDate: plan.lessonDate,
            topicId: plan.topicId,
            state: TeacherLessonDeliveryState.draft,
          )
        : TeacherLessonDelivery.fromJson(existing.payload).copyWith(
            pendingSync: existing.isDirty,
          );
    if (current.locked) {
      return TeacherLessonPlanActionResult(
        success: false,
        message: current.state == TeacherLessonDeliveryState.queued
            ? 'Lesson delivery is already queued and locked until server acknowledgement.'
            : 'Delivered lesson evidence is canonical and locked.',
        delivery: current,
      );
    }

    final next = current.copyWith(
      state: deliver
          ? TeacherLessonDeliveryState.queued
          : TeacherLessonDeliveryState.draft,
      reflection: reflection.trim(),
      homework: homework.trim(),
      topicCompleted: topicCompleted,
      pendingSync: true,
    );
    await _db.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: deliveryType,
      entityId: id,
      payload: next.toLocalJson(),
      serverVersion: existing?.serverVersion,
      isDirty: true,
    );
    await _db.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: deliveryType,
      entityId: id,
      operation: existing == null ? SyncOperation.create : SyncOperation.update,
      payload: next.toMutationJson(action: deliver ? 'deliver' : 'saveDraft'),
      baseVersion: existing?.serverVersion,
    );
    return TeacherLessonPlanActionResult(
      success: true,
      message: deliver
          ? 'Lesson delivery queued. Syllabus progress changes only after server acknowledgement.'
          : 'Delivery reflection saved locally and queued.',
      delivery: next,
    );
  }

  Future<TeacherLessonPlan?> _readPlan(
    SchoolMembership membership,
    String id,
  ) async {
    final record = await _db.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: planType,
      entityId: id,
    );
    if (record == null) return null;
    final parsed = TeacherLessonPlan.fromJson(record.payload);
    final authorized = !LocalDatabase.blockDemoSeeds ||
        (parsed.effectiveTeacherId == membership.id &&
            parsed.occurrenceStatus != 'cancelled' &&
            parsed.occurrenceStatus != 'uncovered');
    return parsed.copyWith(
      pendingSync: record.isDirty,
      currentTeacherAuthorized: authorized,
    );
  }

  Future<void> _writePlan({
    required SchoolMembership membership,
    required TeacherLessonPlan plan,
    required String action,
    required SyncOperation operation,
  }) async {
    final existing = await _db.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: planType,
      entityId: plan.id,
    );
    final connected = LocalDatabase.blockDemoSeeds;
    await _db.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: planType,
      entityId: plan.id,
      payload: plan.toLocalJson(),
      serverVersion: existing?.serverVersion,
      isDirty: connected,
    );
    if (!connected) return;
    await _db.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: planType,
      entityId: plan.id,
      operation: operation,
      payload: plan.toMutationJson(action: action),
      baseVersion: existing?.serverVersion,
    );
  }

  Future<TeacherLessonPlanSnapshot> _loadDemo(
    SchoolMembership membership,
  ) async {
    final records = await _db.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: planType,
    );
    if (records.isEmpty) {
      for (final plan in teacherLessonPlans) {
        await _db.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: planType,
          entityId: plan.id,
          payload: plan.toLocalJson(),
        );
      }
    }
    final seeded = await _db.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: planType,
    );
    final plans = [
      for (final record in seeded)
        TeacherLessonPlan.fromJson(record.payload).copyWith(
          pendingSync: record.isDirty,
          currentTeacherAuthorized: true,
        ),
    ]..sort(_planOrder);
    final classes = {for (final item in plans) item.className}.toList()..sort();
    final events = await _db.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _legacyEventType,
    );
    return TeacherLessonPlanSnapshot(
      plans: plans,
      classOptions: classes,
      occurrenceOptions: const [],
      deliveries: const [],
      events: [
        for (final record in events)
          TeacherLessonPlanEvent.fromJson(record.payload),
      ],
      permissions: permissionsFor(membership),
      canonical: false,
    );
  }

  List<Map<String, Object?>> _mapList(Object? raw) => [
        for (final item in raw is List ? raw : const [])
          if (item is Map) Map<String, Object?>.from(item),
      ];

  String _isoDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  int _occurrenceOrder(
    TeacherLessonPlanOccurrenceOption a,
    TeacherLessonPlanOccurrenceOption b,
  ) {
    final byDate = a.lessonDate.compareTo(b.lessonDate);
    if (byDate != 0) return byDate;
    final byTime = a.time.compareTo(b.time);
    if (byTime != 0) return byTime;
    return a.className.compareTo(b.className);
  }

  int _planOrder(TeacherLessonPlan a, TeacherLessonPlan b) {
    final byDate = b.lessonDate.compareTo(a.lessonDate);
    if (byDate != 0) return byDate;
    final byTime = a.time.compareTo(b.time);
    if (byTime != 0) return byTime;
    return a.className.compareTo(b.className);
  }
}
