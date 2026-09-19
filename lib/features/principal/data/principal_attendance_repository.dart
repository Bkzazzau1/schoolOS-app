import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/principal_attendance_models.dart';
import 'principal_attendance_demo_data.dart';

class PrincipalAttendanceSnapshot {
  const PrincipalAttendanceSnapshot({
    required this.classes,
    required this.staff,
    required this.followUps,
    required this.scanners,
    required this.biometricEvents,
    required this.permissions,
    required this.pendingBiometricMutations,
  });

  final List<PrincipalClassAttendance> classes;
  final List<PrincipalStaffAttendance> staff;
  final List<PrincipalAttendanceFollowUp> followUps;
  final List<PrincipalBiometricScanner> scanners;
  final List<PrincipalBiometricAttendanceEvent> biometricEvents;
  final PrincipalAttendancePermissions permissions;
  final int pendingBiometricMutations;
}

class PrincipalAttendanceActionResult {
  const PrincipalAttendanceActionResult({required this.success, required this.message});
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
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _classType = 'principal_attendance_class';
  static const _staffType = 'principal_attendance_staff';
  static const _followUpType = 'principal_attendance_followup';
  static const _scannerType = 'principal_biometric_scanner';
  static const _eventType = 'principal_biometric_attendance_event';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  PrincipalAttendancePermissions permissionsFor(SchoolMembership membership) => PrincipalAttendancePermissions(
        canViewSecondaryAttendance: membership.role == SchoolRole.principal,
        canResolveFollowUps: membership.role == SchoolRole.principal,
        canIngestOfflineBiometricEvents: membership.role == SchoolRole.principal,
        canManagePrimary: false,
      );

  Future<PrincipalAttendanceSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    await _seedIfNeeded(membership);

    final classRecords = await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: _classType);
    final staffRecords = await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: _staffType);
    final followUpRecords = await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: _followUpType);
    final scannerRecords = await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: _scannerType);
    final eventRecords = await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: _eventType);

    final classes = classRecords.map((record) => PrincipalClassAttendance.fromJson(record.payload)).toList(growable: false)
      ..sort((a, b) => a.className.compareTo(b.className));
    final staff = staffRecords.map((record) => PrincipalStaffAttendance.fromJson(record.payload)).toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));
    final followUps = followUpRecords.map((record) => PrincipalAttendanceFollowUp.fromJson(record.payload)).toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));
    final scanners = scannerRecords.map((record) => PrincipalBiometricScanner.fromJson(record.payload)).toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));
    final biometricEvents = eventRecords.map((record) => PrincipalBiometricAttendanceEvent.fromJson(record.payload)).toList(growable: false)
      ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    final pendingBiometricMutations = eventRecords.where((record) => record.isDirty).length;

    return PrincipalAttendanceSnapshot(
      classes: classes,
      staff: staff,
      followUps: followUps,
      scanners: scanners,
      biometricEvents: biometricEvents,
      permissions: permissionsFor(membership),
      pendingBiometricMutations: pendingBiometricMutations,
    );
  }

  Future<PrincipalAttendanceActionResult> resolveFollowUp(String followUpId) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canResolveFollowUps) {
      return const PrincipalAttendanceActionResult(success: false, message: 'This membership cannot resolve Secondary attendance follow-ups.');
    }

    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _followUpType,
      entityId: followUpId,
    );
    if (record == null) {
      return const PrincipalAttendanceActionResult(success: false, message: 'Attendance follow-up not found.');
    }

    final current = PrincipalAttendanceFollowUp.fromJson(record.payload);
    if (current.resolved) {
      return const PrincipalAttendanceActionResult(success: true, message: 'This follow-up is already resolved.');
    }

    final updated = current.copyWith(
      resolved: true,
      resolvedAt: DateTime.now().toUtc().toIso8601String(),
      resolvedByMembershipId: membership.id,
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _followUpType,
      entityId: updated.id,
      payload: updated.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _followUpType,
      entityId: updated.id,
      operation: SyncOperation.update,
      payload: updated.toJson(),
    );
    return const PrincipalAttendanceActionResult(success: true, message: 'Follow-up resolved offline and queued for synchronization.');
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
      return const PrincipalAttendanceActionResult(success: false, message: 'This membership cannot ingest Secondary biometric attendance events.');
    }
    if (localSequence < 0) {
      return const PrincipalAttendanceActionResult(success: false, message: 'Scanner local sequence must be non-negative.');
    }
    if (matchScore < 0 || matchScore > 1) {
      return const PrincipalAttendanceActionResult(success: false, message: 'Biometric match score must be between 0 and 1.');
    }
    if (templateReference.trim().isEmpty || !templateReference.startsWith('tpl:')) {
      return const PrincipalAttendanceActionResult(success: false, message: 'Use an opaque protected template reference; raw biometric images are not accepted.');
    }

    final scannerRecord = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _scannerType,
      entityId: scannerId,
    );
    if (scannerRecord == null) {
      return const PrincipalAttendanceActionResult(success: false, message: 'Scanner is not registered in the local Secondary attendance scope.');
    }
    final scanner = PrincipalBiometricScanner.fromJson(scannerRecord.payload);
    final eventId = '$scannerId-$localSequence';
    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _eventType,
      entityId: eventId,
    );
    if (existing != null) {
      return const PrincipalAttendanceActionResult(success: true, message: 'Duplicate scanner sequence ignored; the existing offline attendance event is preserved.');
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
    if ((await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: _classType)).isEmpty) {
      for (final row in principalAttendanceClasses) {
        await _localDatabase.upsertLocalRecord(tenantId: membership.schoolId, entityType: _classType, entityId: row.className, payload: row.toJson());
      }
    }
    if ((await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: _staffType)).isEmpty) {
      for (final row in principalAttendanceStaff) {
        await _localDatabase.upsertLocalRecord(tenantId: membership.schoolId, entityType: _staffType, entityId: row.id, payload: row.toJson());
      }
    }
    if ((await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: _followUpType)).isEmpty) {
      for (final row in principalAttendanceFollowUps) {
        await _localDatabase.upsertLocalRecord(tenantId: membership.schoolId, entityType: _followUpType, entityId: row.id, payload: row.toJson());
      }
    }
    if ((await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: _scannerType)).isEmpty) {
      for (final row in principalBiometricScanners) {
        await _localDatabase.upsertLocalRecord(tenantId: membership.schoolId, entityType: _scannerType, entityId: row.id, payload: row.toJson());
      }
    }
    if ((await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: _eventType)).isEmpty) {
      for (final row in principalBiometricSeedEvents) {
        await _localDatabase.upsertLocalRecord(tenantId: membership.schoolId, entityType: _eventType, entityId: row.id, payload: row.toJson());
      }
    }
  }
}
