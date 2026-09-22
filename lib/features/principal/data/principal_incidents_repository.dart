import '../../administrator/data/administrator_students_repository.dart';
import '../../administrator/domain/administrator_students_models.dart';
import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/principal_incidents_models.dart';
import '../../administrator/data/administrator_attendance_desk.dart'
    show sectionOfClass;

class PrincipalIncidentsSnapshot {
  const PrincipalIncidentsSnapshot({
    required this.cases,
    required this.audit,
    required this.permissions,
  });
  final List<PrincipalIncident> cases;
  final List<PrincipalIncidentAuditEvent> audit;
  final PrincipalIncidentPermissions permissions;

  int get openCases =>
      cases.where((e) => e.status != PrincipalIncidentStatus.resolved).length;
  int get highPriority => cases
      .where(
        (e) =>
            e.status != PrincipalIncidentStatus.resolved &&
            (e.severity == PrincipalIncidentSeverity.high ||
                e.severity == PrincipalIncidentSeverity.critical),
      )
      .length;
  int get safeguarding => cases
      .where(
        (e) =>
            e.category == PrincipalIncidentCategory.safeguarding &&
            e.status != PrincipalIncidentStatus.resolved,
      )
      .length;
  int get awaitingGuardian => cases
      .where((e) => e.guardianContact == PrincipalGuardianContact.pending)
      .length;
}

class PrincipalIncidentActionResult {
  const PrincipalIncidentActionResult(this.success, this.message);
  final bool success;
  final String message;
}

class PrincipalIncidentsRepository {
  PrincipalIncidentsRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  }) : _db = localDatabase,
       _session = schoolSession;

  static const _caseType = 'principal_recorded_incident_case';
  static const _auditType = 'principal_recorded_incident_audit';
  final LocalDatabase _db;
  final SchoolSessionController _session;

  PrincipalIncidentPermissions permissionsFor(SchoolMembership membership) =>
      PrincipalIncidentPermissions(
        canViewSecondaryIncidents: membership.role == SchoolRole.principal,
        canViewRestrictedSafeguardingSummary:
            membership.role == SchoolRole.principal,
        canAddInternalNote: membership.role == SchoolRole.principal,
        canChangeCaseStatus: membership.role == SchoolRole.principal,
        canManagePrimaryOrEarlyYears: false,
      );

  Future<Set<String>> _secondaryClasses() async {
    final register = await AdministratorStudentsRepository(
      localDatabase: _db,
      schoolSession: _session,
    ).load();
    return {
      for (final student in register.students)
        if (student.status != AdministratorStudentStatus.transferredOut &&
            sectionOfClass(student.className) == 'Secondary')
          student.className,
    };
  }

  Future<PrincipalIncidentsSnapshot> load() async {
    final membership = _session.requireActiveMembership();
    if (!permissionsFor(membership).canViewSecondaryIncidents) {
      return PrincipalIncidentsSnapshot(
        cases: const [],
        audit: const [],
        permissions: permissionsFor(membership),
      );
    }
    final caseRecords = await _db.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _caseType,
    );
    final auditRecords = await _db.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _auditType,
    );
    final allowedClasses = await _secondaryClasses();
    final cases =
        caseRecords
            .where((e) => allowedClasses.contains(e.payload['context']))
            .map((e) => PrincipalIncident.fromJson(e.payload))
            .toList()
          ..sort((a, b) => b.id.compareTo(a.id));
    final audit =
        auditRecords
            .where((e) => cases.any((c) => c.id == e.payload['incidentId']))
            .map((e) => PrincipalIncidentAuditEvent.fromJson(e.payload))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return PrincipalIncidentsSnapshot(
      cases: cases,
      audit: audit,
      permissions: permissionsFor(membership),
    );
  }

  Future<PrincipalIncidentActionResult> saveNote({
    required String incidentId,
    required String note,
  }) async {
    final membership = _session.requireActiveMembership();
    if (!permissionsFor(membership).canAddInternalNote) {
      return const PrincipalIncidentActionResult(
        false,
        'This membership cannot add Secondary incident notes.',
      );
    }
    final text = note.trim();
    if (text.isEmpty) {
      return const PrincipalIncidentActionResult(
        false,
        'Add a case note first.',
      );
    }
    final existing = await _db.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _caseType,
      entityId: incidentId,
    );
    if (existing == null ||
        !(await _secondaryClasses()).contains(existing.payload['context'])) {
      return const PrincipalIncidentActionResult(
        false,
        'Incident not found in this school.',
      );
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final event = PrincipalIncidentAuditEvent(
      id: 'note-${DateTime.now().microsecondsSinceEpoch}',
      incidentId: incidentId,
      action: 'case_note',
      actorMembershipId: membership.id,
      createdAt: now,
      note: text,
    );
    await _persistAudit(membership, event);
    return const PrincipalIncidentActionResult(
      true,
      'Case note saved offline and queued for synchronization.',
    );
  }

  Future<PrincipalIncidentActionResult> changeStatus({
    required String incidentId,
    required PrincipalIncidentStatus status,
  }) async {
    final membership = _session.requireActiveMembership();
    if (!permissionsFor(membership).canChangeCaseStatus) {
      return const PrincipalIncidentActionResult(
        false,
        'This membership cannot change Secondary incident status.',
      );
    }
    final existing = await _db.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _caseType,
      entityId: incidentId,
    );
    if (existing == null ||
        !(await _secondaryClasses()).contains(existing.payload['context'])) {
      return const PrincipalIncidentActionResult(
        false,
        'Incident not found in this school.',
      );
    }
    final current = PrincipalIncident.fromJson(existing.payload);
    final now = DateTime.now().toUtc().toIso8601String();
    final updated = current.copyWith(
      status: status,
      lastUpdatedByMembershipId: membership.id,
      lastUpdatedAt: now,
    );
    await _db.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _caseType,
      entityId: incidentId,
      payload: updated.toJson(),
      isDirty: true,
    );
    await _db.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _caseType,
      entityId: incidentId,
      operation: SyncOperation.update,
      payload: updated.toJson(),
    );
    await _persistAudit(
      membership,
      PrincipalIncidentAuditEvent(
        id: 'status-${DateTime.now().microsecondsSinceEpoch}',
        incidentId: incidentId,
        action: 'status_change',
        actorMembershipId: membership.id,
        createdAt: now,
        previousStatus: current.status,
        newStatus: status,
      ),
    );
    return PrincipalIncidentActionResult(
      true,
      status == PrincipalIncidentStatus.resolved
          ? 'Case resolution recorded offline. History remains preserved and queued for sync.'
          : 'Case status updated offline and queued for synchronization.',
    );
  }

  Future<void> _persistAudit(
    SchoolMembership membership,
    PrincipalIncidentAuditEvent event,
  ) async {
    await _db.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _auditType,
      entityId: event.id,
      payload: event.toJson(),
      isDirty: true,
    );
    await _db.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _auditType,
      entityId: event.id,
      operation: SyncOperation.create,
      payload: event.toJson(),
    );
  }
}
