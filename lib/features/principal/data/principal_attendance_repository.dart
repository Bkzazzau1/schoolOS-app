import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/data/administrator_attendance_desk.dart';
import '../../administrator/data/administrator_attendance_repository.dart';
import '../../administrator/data/administrator_students_repository.dart';
import '../../administrator/domain/administrator_attendance_models.dart';
import '../../administrator/domain/administrator_students_models.dart';
import '../domain/principal_attendance_models.dart';
import 'principal_attendance_demo_data.dart';

class PrincipalSubjectAttendanceSummary {
  const PrincipalSubjectAttendanceSummary({
    required this.id,
    required this.lessonDate,
    required this.time,
    required this.className,
    required this.subject,
    required this.teacher,
    required this.topic,
    required this.state,
    required this.total,
    required this.unmarked,
    required this.present,
    required this.absent,
    required this.late,
    required this.excused,
  });

  final String id;
  final String lessonDate;
  final String time;
  final String className;
  final String subject;
  final String teacher;
  final String topic;
  final String state;
  final int total;
  final int unmarked;
  final int present;
  final int absent;
  final int late;
  final int excused;

  bool get submitted => state == 'submitted';
  int get presentRate => total == 0 ? 0 : (present * 100 / total).round();
}

class PrincipalAttendanceSnapshot {
  const PrincipalAttendanceSnapshot({
    required this.classes,
    required this.subjectLessons,
    required this.staff,
    required this.followUps,
    required this.scanners,
    required this.biometricEvents,
    required this.permissions,
    required this.pendingBiometricMutations,
  });

  /// Daily/gate presence evidence. This is intentionally separate from
  /// [subjectLessons], which represents attendance in a specific lesson period.
  final List<PrincipalClassAttendance> classes;
  final List<PrincipalSubjectAttendanceSummary> subjectLessons;

  /// Always empty: there is no real per-day staff check-in feed yet, only a
  /// period attendance average (visible on the Teachers screen).
  final List<PrincipalStaffAttendance> staff;

  /// Always empty until real multi-day evidence exists.
  final List<PrincipalAttendanceFollowUp> followUps;
  final List<PrincipalBiometricScanner> scanners;
  final List<PrincipalBiometricAttendanceEvent> biometricEvents;
  final PrincipalAttendancePermissions permissions;
  final int pendingBiometricMutations;
}

class PrincipalAttendanceActionResult {
  const PrincipalAttendanceActionResult({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;
}

/// Vendor-specific palm/fingerprint SDKs should adapt their local capture result
/// into this repository call. SchoolOS never needs internet to accept the event.
abstract interface class PrincipalBiometricScannerAdapter {
  String get scannerId;
  PrincipalBiometricModality get modality;
  PrincipalScannerTransport get transport;

  Future<void> start();
  Future<void> stop();
}

class PrincipalAttendanceRepository {
  PrincipalAttendanceRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required AdministratorStudentsRepository students,
    required AdministratorAttendanceRepository attendance,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _students = students,
        _attendance = attendance;

  static const _scannerType = 'principal_biometric_scanner';
  static const _eventType = 'principal_biometric_attendance_event';
  static const _subjectAttendanceType = 'teacher_lesson_attendance_register';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final AdministratorStudentsRepository _students;
  final AdministratorAttendanceRepository _attendance;

  PrincipalAttendancePermissions permissionsFor(SchoolMembership membership) =>
      PrincipalAttendancePermissions(
        canViewSecondaryAttendance: membership.role == SchoolRole.principal,
        canResolveFollowUps: membership.role == SchoolRole.principal,
        canIngestOfflineBiometricEvents: membership.role == SchoolRole.principal,
        canManagePrimary: false,
      );

  static String _key(String name) => name.trim().toLowerCase();

  /// Today's real Secondary gate/daily presence, grouped by class. It is not
  /// evidence that a learner attended a specific subject period.
  Future<List<PrincipalClassAttendance>> _classAttendance() async {
    final register = (await _students.load()).students.where(
      (student) =>
          student.status != AdministratorStudentStatus.transferredOut &&
          sectionOfClass(student.className) == 'Secondary',
    ).toList();
    final events = (await _attendance.load(students: register)).events;

    final presentNames = {
      for (final event in events)
        if (!event.isUnknown && event.countsAsPresent) _key(event.student),
    };
    final lateNames = {
      for (final event in events)
        if (!event.isUnknown &&
            event.status == AdministratorAttendanceEventStatus.late)
          _key(event.student),
    };
    final excusedNames = {
      for (final event in events)
        if (!event.isUnknown &&
            event.status == AdministratorAttendanceEventStatus.excused)
          _key(event.student),
    };

    final byClass = <String, List<AdministratorStudentRecord>>{};
    for (final student in register) {
      byClass.putIfAbsent(student.className, () => []).add(student);
    }

    return [
      for (final className in byClass.keys.toList()..sort())
        () {
          final rows = byClass[className]!;
          final total = rows.length;
          final present = rows
              .where((student) => presentNames.contains(_key(student.name)))
              .length;
          final late = rows
              .where((student) => lateNames.contains(_key(student.name)))
              .length;
          final excused = rows
              .where((student) => excusedNames.contains(_key(student.name)))
              .length;
          final absent = total - present - excused;
          final rate = total == 0 ? 0 : (present * 100 / total).round();
          return PrincipalClassAttendance(
            className: className,
            total: total,
            present: present,
            absent: absent,
            late: late,
            excused: excused,
            rate: rate,
            trend: 0,
            status: rate >= 95
                ? PrincipalAttendanceHealth.strong
                : (rate >= 85
                    ? PrincipalAttendanceHealth.watch
                    : PrincipalAttendanceHealth.needsAttention),
          );
        }(),
    ];
  }

  Future<List<PrincipalSubjectAttendanceSummary>> _subjectAttendance(
    SchoolMembership membership,
  ) async {
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _subjectAttendanceType,
    );
    final rows = <PrincipalSubjectAttendanceSummary>[];
    for (final record in records) {
      final payload = record.payload;
      if ((payload['section'] as String? ?? '').trim().toLowerCase() !=
          'secondary') {
        continue;
      }
      var present = 0;
      var absent = 0;
      var late = 0;
      var excused = 0;
      var unmarked = 0;
      final entries = payload['entries'] as List? ?? const [];
      for (final raw in entries) {
        if (raw is! Map) continue;
        switch (raw['status']) {
          case 'present':
            present++;
          case 'absent':
            absent++;
          case 'late':
            late++;
          case 'excused':
            excused++;
          default:
            unmarked++;
        }
      }
      rows.add(
        PrincipalSubjectAttendanceSummary(
          id: payload['id'] as String? ?? record.entityId,
          lessonDate: payload['lessonDate'] as String? ?? '',
          time: payload['time'] as String? ?? '',
          className: payload['className'] as String? ?? '',
          subject: payload['subject'] as String? ?? '',
          teacher: payload['teacher'] as String? ?? '',
          topic: payload['topic'] as String? ?? '',
          state: payload['state'] as String? ?? 'draft',
          total: entries.length,
          unmarked: unmarked,
          present: present,
          absent: absent,
          late: late,
          excused: excused,
        ),
      );
    }
    rows.sort((left, right) {
      final byDate = right.lessonDate.compareTo(left.lessonDate);
      if (byDate != 0) return byDate;
      final byTime = left.time.compareTo(right.time);
      if (byTime != 0) return byTime;
      return left.className.compareTo(right.className);
    });
    return rows;
  }

  Future<PrincipalAttendanceSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    await _seedIfNeeded(membership);

    final classes = await _classAttendance();
    final subjectLessons = await _subjectAttendance(membership);

    final scannerRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _scannerType,
    );
    final eventRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _eventType,
    );

    final scanners = scannerRecords
        .map((record) => PrincipalBiometricScanner.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));
    final biometricEvents = eventRecords
        .map(
          (record) =>
              PrincipalBiometricAttendanceEvent.fromJson(record.payload),
        )
        .toList(growable: false)
      ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    final pendingBiometricMutations =
        eventRecords.where((record) => record.isDirty).length;

    return PrincipalAttendanceSnapshot(
      classes: classes,
      subjectLessons: subjectLessons,
      staff: const [],
      followUps: const [],
      scanners: scanners,
      biometricEvents: biometricEvents,
      permissions: permissionsFor(membership),
      pendingBiometricMutations: pendingBiometricMutations,
    );
  }

  Future<PrincipalAttendanceActionResult> resolveFollowUp(
    String followUpId,
  ) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canResolveFollowUps) {
      return const PrincipalAttendanceActionResult(
        success: false,
        message:
            'This membership cannot resolve Secondary attendance follow-ups.',
      );
    }
    return const PrincipalAttendanceActionResult(
      success: false,
      message: 'No real attendance follow-up evidence exists yet to resolve.',
    );
  }

  Future<PrincipalAttendanceActionResult> ingestOfflineBiometricMatch({
    required String scannerId,
    required int localSequence,
    required PrincipalAttendancePersonType personType,
    required String personReference,
    required String classOrRole,
    required String templateReference,
    required double matchScore,
    required String capturedAt,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canIngestOfflineBiometricEvents) {
      return const PrincipalAttendanceActionResult(
        success: false,
        message:
            'This membership cannot ingest Secondary biometric attendance events.',
      );
    }
    if (localSequence < 0) {
      return const PrincipalAttendanceActionResult(
        success: false,
        message: 'Scanner local sequence must be non-negative.',
      );
    }
    if (matchScore < 0 || matchScore > 1) {
      return const PrincipalAttendanceActionResult(
        success: false,
        message: 'Biometric match score must be between 0 and 1.',
      );
    }
    if (templateReference.trim().isEmpty ||
        !templateReference.startsWith('tpl:')) {
      return const PrincipalAttendanceActionResult(
        success: false,
        message:
            'Use an opaque protected template reference; raw biometric images are not accepted.',
      );
    }

    final scannerRecord = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _scannerType,
      entityId: scannerId,
    );
    if (scannerRecord == null) {
      return const PrincipalAttendanceActionResult(
        success: false,
        message:
            'Scanner is not registered in the local Secondary attendance scope.',
      );
    }
    final scanner = PrincipalBiometricScanner.fromJson(scannerRecord.payload);
    final eventId = '$scannerId-$localSequence';
    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _eventType,
      entityId: eventId,
    );
    if (existing != null) {
      return const PrincipalAttendanceActionResult(
        success: true,
        message:
            'Duplicate scanner sequence ignored; the existing offline attendance event is preserved.',
      );
    }

    final normalizedPerson = personReference.trim();
    final status = normalizedPerson.isEmpty || matchScore < 0.85
        ? PrincipalBiometricMatchStatus.unknown
        : PrincipalBiometricMatchStatus.matched;
    final event = PrincipalBiometricAttendanceEvent(
      id: eventId,
      personReference: normalizedPerson.isEmpty ? 'UNKNOWN' : normalizedPerson,
      personType: personType,
      classOrRole: classOrRole.trim(),
      scannerId: scannerId,
      modality: scanner.modality,
      capturedAt: capturedAt,
      localSequence: localSequence,
      templateReference: templateReference,
      matchScore: matchScore,
      matchStatus: status,
      synced: false,
    );

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _eventType,
      entityId: event.id,
      payload: event.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _eventType,
      entityId: event.id,
      operation: SyncOperation.create,
      payload: event.toJson(),
    );

    return PrincipalAttendanceActionResult(
      success: true,
      message: status == PrincipalBiometricMatchStatus.matched
          ? 'Biometric attendance captured fully offline and queued for later sync.'
          : 'Uncertain biometric scan stored offline for human review; no identity was inferred.',
    );
  }

  Future<void> _seedIfNeeded(SchoolMembership membership) async {
    // Demo evidence must never appear in a backend-connected Principal workspace.
    if (LocalDatabase.blockDemoSeeds) return;

    if ((await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _scannerType,
    ))
        .isEmpty) {
      for (final row in principalBiometricScanners) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _scannerType,
          entityId: row.id,
          payload: row.toJson(),
        );
      }
    }
    if ((await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _eventType,
    ))
        .isEmpty) {
      for (final row in principalBiometricSeedEvents) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _eventType,
          entityId: row.id,
          payload: row.toJson(),
        );
      }
    }
  }
}
