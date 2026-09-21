import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/administrator_attendance_models.dart';
import '../domain/administrator_students_models.dart';
import 'administrator_attendance_demo_data.dart';
import 'administrator_attendance_desk.dart';

class AdministratorAttendanceSnapshot {
  const AdministratorAttendanceSnapshot({
    required this.events,
    required this.devices,
    required this.corrections,
    required this.permissions,
  });

  final List<AdministratorAttendanceEvent> events;
  final List<AdministratorAttendanceDevice> devices;
  final List<AdministratorAttendanceCorrection> corrections;
  final AdministratorAttendancePermissions permissions;
}

class AdministratorAttendanceRepository {
  AdministratorAttendanceRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _eventEntityType = 'administrator_attendance_event';
  static const _deviceEntityType = 'administrator_attendance_device';
  static const _correctionEntityType = 'administrator_attendance_correction';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  AdministratorAttendancePermissions permissionsFor(SchoolMembership membership) {
    final allowed = membership.role == SchoolRole.administrator;
    return AdministratorAttendancePermissions(
      canViewControlCenter: allowed,
      canReviewCorrections: allowed,
    );
  }

  /// Today's attendance. [students] (the active register) let the demo school have a morning of gate scans to show.
  Future<AdministratorAttendanceSnapshot> load({List<AdministratorStudentRecord> students = const []}) async {
    final membership = _schoolSession.requireActiveMembership();
    final today = schoolDay(DateTime.now());

    var eventRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _eventEntityType,
    );
    if (!eventRecords.any((r) => r.payload['date'] == today) && students.isNotEmpty) {
      // The demo school: a morning of scans for today (a school server has real devices instead, and blocks this).
      for (final item in demoScansFor(students, DateTime.now())) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _eventEntityType,
          entityId: item.entityId,
          payload: item.toJson(),
        );
      }
      eventRecords = await _localDatabase.getLocalRecords(
        tenantId: membership.schoolId,
        entityType: _eventEntityType,
      );
    }

    var deviceRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _deviceEntityType,
    );
    if (deviceRecords.isEmpty) {
      for (final item in administratorAttendanceWebsiteDevices) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _deviceEntityType,
          entityId: item.name,
          payload: item.toJson(),
        );
      }
      deviceRecords = await _localDatabase.getLocalRecords(
        tenantId: membership.schoolId,
        entityType: _deviceEntityType,
      );
    }

    var correctionRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _correctionEntityType,
    );
    if (correctionRecords.isEmpty) {
      for (final item in administratorAttendanceCorrections) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _correctionEntityType,
          entityId: item.id,
          payload: item.toJson(),
        );
      }
      correctionRecords = await _localDatabase.getLocalRecords(
        tenantId: membership.schoolId,
        entityType: _correctionEntityType,
      );
    }

    final events = eventRecords
        .map((record) => AdministratorAttendanceEvent.fromJson(record.payload))
        .where((event) => event.date == today)
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    final devices = deviceRecords
        .map((record) => AdministratorAttendanceDevice.fromJson(record.payload))
        .toList();
    final corrections = correctionRecords
        .map((record) => AdministratorAttendanceCorrection.fromJson(record.payload))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    final deviceOrder = <String, int>{
      for (var i = 0; i < administratorAttendanceWebsiteDevices.length; i++)
        administratorAttendanceWebsiteDevices[i].name: i,
    };
    devices.sort((a, b) =>
        (deviceOrder[a.name] ?? 9999).compareTo(deviceOrder[b.name] ?? 9999));

    return AdministratorAttendanceSnapshot(
      events: events,
      devices: devices,
      corrections: corrections,
      permissions: permissionsFor(membership),
    );
  }

  String exportTodayPreview(List<AdministratorAttendanceEvent> events) {
    final buffer = StringBuffer('time,student,class,device,method,status,parent\n');
    for (final item in events) {
      buffer.writeln([
        item.time,
        item.student,
        item.className,
        item.device,
        item.method,
        item.status.label,
        item.parentState,
      ].map(_csv).join(','));
    }
    return buffer.toString().trimRight();
  }

  static String _csv(String value) => '"${value.replaceAll('"', '""')}"';

  /// School starts at 08:00; anyone checked in after that is late.
  static const lateAfter = '08:00';

  SchoolMembership _requireDesk() {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canReviewCorrections) {
      throw StateError('Only the administrator can change attendance.');
    }
    return membership;
  }

  static String _hhmm(DateTime now) =>
      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

  /// Checks a student in by hand at the front desk (when a gate device did not). After 08:00 they are late.
  Future<AdministratorAttendanceActionResult> checkIn(
    AdministratorStudentRecord student, {
    DateTime? now,
  }) async {
    final SchoolMembership membership;
    try {
      membership = _requireDesk();
    } on StateError catch (error) {
      return AdministratorAttendanceActionResult(success: false, message: error.message);
    }
    final at = now ?? DateTime.now();
    final today = (await load()).events;
    final already = today.any((e) => !e.isUnknown && e.student.trim().toLowerCase() == student.name.trim().toLowerCase());
    if (already) {
      return AdministratorAttendanceActionResult(success: false, message: '${student.name} already has an attendance record today.');
    }
    final time = _hhmm(at);
    final event = AdministratorAttendanceEvent(
      time: time,
      student: student.name,
      className: student.className,
      device: 'Front desk',
      method: 'Manual',
      status: time.compareTo(lateAfter) > 0 ? AdministratorAttendanceEventStatus.late : AdministratorAttendanceEventStatus.checkedIn,
      parentState: 'Queued',
      date: schoolDay(at),
      note: 'Checked in by hand',
    );
    await _saveEvent(membership, event, isNew: true);
    return AdministratorAttendanceActionResult(success: true, message: '${student.name} checked in at $time.');
  }

  /// A scan the device could not match is identified by a person choosing the student. It is never guessed.
  Future<AdministratorAttendanceActionResult> identifyUnknown(
    AdministratorAttendanceEvent scan,
    AdministratorStudentRecord student,
  ) async {
    final SchoolMembership membership;
    try {
      membership = _requireDesk();
    } on StateError catch (error) {
      return AdministratorAttendanceActionResult(success: false, message: error.message);
    }
    if (!scan.isUnknown) {
      return const AdministratorAttendanceActionResult(success: false, message: 'That scan is already identified.');
    }
    final today = (await load()).events;
    if (today.any((e) => !e.isUnknown && e.student.trim().toLowerCase() == student.name.trim().toLowerCase())) {
      return AdministratorAttendanceActionResult(success: false, message: '${student.name} already has an attendance record today.');
    }
    final late = scan.time.compareTo(lateAfter) > 0;
    final identified = scan.copyWith(
      student: student.name,
      className: student.className,
      status: late ? AdministratorAttendanceEventStatus.late : AdministratorAttendanceEventStatus.checkedIn,
      note: 'Scan identified by the administrator',
    );
    await _saveEvent(membership, identified, isNew: false);
    return AdministratorAttendanceActionResult(success: true, message: 'Scan identified as ${student.name}.');
  }

  /// Approves or declines a correction request. Declining needs a reason. Approving adds the change to today's record
  /// (Present, Late or Excused) and keeps who asked, who approved, why and when; the original scan is not erased.
  Future<AdministratorAttendanceActionResult> decideCorrection(
    AdministratorAttendanceCorrection correction, {
    required bool approve,
    String note = '',
    DateTime? now,
  }) async {
    final SchoolMembership membership;
    try {
      membership = _requireDesk();
    } on StateError catch (error) {
      return AdministratorAttendanceActionResult(success: false, message: error.message);
    }
    if (!correction.isPending) {
      return const AdministratorAttendanceActionResult(success: false, message: 'This correction has already been decided.');
    }
    if (!approve && note.trim().isEmpty) {
      return const AdministratorAttendanceActionResult(success: false, message: 'Say why the correction is declined.');
    }
    final at = now ?? DateTime.now();
    if (approve) {
      final status = switch (correction.target.toLowerCase()) {
        'present' => AdministratorAttendanceEventStatus.checkedIn,
        'late' => AdministratorAttendanceEventStatus.late,
        'excused' => AdministratorAttendanceEventStatus.excused,
        _ => null,
      };
      if (status == null) {
        return AdministratorAttendanceActionResult(
          success: false,
          message: 'A correction to "${correction.target}" cannot be applied here. Ask for Present, Late or Excused.',
        );
      }
      final today = (await load()).events;
      final existing = today.where((e) => !e.isUnknown && e.student.trim().toLowerCase() == correction.student.trim().toLowerCase()).toList();
      final reason = 'Correction ${correction.id} approved${note.trim().isEmpty ? '' : ': ${note.trim()}'}';
      if (existing.isNotEmpty) {
        await _saveEvent(membership, existing.first.copyWith(status: status, method: 'Correction', note: reason), isNew: false);
      } else {
        await _saveEvent(
          membership,
          AdministratorAttendanceEvent(
            time: _hhmm(at),
            student: correction.student,
            className: correction.className,
            device: 'Front desk',
            method: 'Correction',
            status: status,
            parentState: 'Not sent',
            date: schoolDay(at),
            note: reason,
          ),
          isNew: true,
        );
      }
    }
    final decided = correction.decided(approved: approve, by: membership.id, note: note.trim());
    await _saveCorrection(membership, decided);
    return AdministratorAttendanceActionResult(
      success: true,
      message: approve ? 'Correction ${correction.id} approved.' : 'Correction ${correction.id} declined.',
    );
  }

  Future<void> _saveEvent(SchoolMembership membership, AdministratorAttendanceEvent event, {required bool isNew}) async {
    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _eventEntityType,
      entityId: event.entityId,
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _eventEntityType,
      entityId: event.entityId,
      payload: event.toJson(),
      serverVersion: existing?.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _eventEntityType,
      entityId: event.entityId,
      operation: isNew && existing == null ? SyncOperation.create : SyncOperation.update,
      payload: event.toJson(),
      baseVersion: existing?.serverVersion,
    );
  }

  Future<void> _saveCorrection(SchoolMembership membership, AdministratorAttendanceCorrection correction) async {
    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _correctionEntityType,
      entityId: correction.id,
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _correctionEntityType,
      entityId: correction.id,
      payload: correction.toJson(),
      serverVersion: existing?.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _correctionEntityType,
      entityId: correction.id,
      operation: existing == null ? SyncOperation.create : SyncOperation.update,
      payload: correction.toJson(),
      baseVersion: existing?.serverVersion,
    );
  }
}

class AdministratorAttendanceActionResult {
  const AdministratorAttendanceActionResult({required this.success, required this.message});

  final bool success;
  final String message;
}
