import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/assembly_models.dart';

class AssemblySnapshot {
  const AssemblySnapshot({
    required this.sessions,
    required this.permissions,
  });

  final List<AssemblySession> sessions;
  final AssemblyPermissions permissions;
}

class AssemblyActionResult {
  const AssemblyActionResult(this.success, this.message);
  final bool success;
  final String message;
}

class AssemblyRepository {
  AssemblyRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _entityType = 'assembly_session';

  // Mirrors apps.schoollife.specs.calendar.ASSEMBLY exactly: manage=MANAGERS (proprietor,
  // principal, administrator), contribute={"teacher"} - a teacher may add a session, a manager
  // may add or change any of them.
  static const _managers = {SchoolRole.proprietor, SchoolRole.principal, SchoolRole.administrator};
  static const _contributors = {SchoolRole.teacher};

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  AssemblyPermissions permissionsFor(SchoolMembership membership) {
    return AssemblyPermissions(
      canCreate: _managers.contains(membership.role) || _contributors.contains(membership.role),
      canManageAll: _managers.contains(membership.role),
    );
  }

  Future<AssemblySnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );

    final sessions = records
        .map((record) => AssemblySession.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));

    return AssemblySnapshot(
      sessions: sessions,
      permissions: permissionsFor(membership),
    );
  }

  Future<AssemblyActionResult> create({
    required String title,
    required AssemblySessionType type,
    required String audience,
    required String day,
    required String time,
    required String venue,
    required String lead,
    required String participation,
    required String note,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canCreate) {
      return const AssemblyActionResult(false, 'This membership cannot add an assembly session.');
    }
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      return const AssemblyActionResult(false, 'Enter a session title.');
    }

    final now = DateTime.now().toUtc();
    final session = AssemblySession(
      id: 'ASM-${now.microsecondsSinceEpoch}',
      title: cleanTitle,
      type: type,
      audience: audience.trim(),
      day: day.trim(),
      time: time.trim(),
      venue: venue.trim(),
      lead: lead.trim(),
      participation: participation.trim(),
      note: note.trim(),
    );
    await _save(session, SyncOperation.create);
    return const AssemblyActionResult(true, 'Session added and queued for sync.');
  }

  Future<AssemblyActionResult> edit({
    required String id,
    required String title,
    required AssemblySessionType type,
    required String audience,
    required String day,
    required String time,
    required String venue,
    required String lead,
    required String participation,
    required String note,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canManageAll) {
      return const AssemblyActionResult(false, 'This membership cannot edit an assembly session.');
    }
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      return const AssemblyActionResult(false, 'Enter a session title.');
    }
    final session = await _requireSession(id);
    final updated = session.copyWith(
      title: cleanTitle,
      type: type,
      audience: audience.trim(),
      day: day.trim(),
      time: time.trim(),
      venue: venue.trim(),
      lead: lead.trim(),
      participation: participation.trim(),
      note: note.trim(),
    );
    await _save(updated, SyncOperation.update);
    return const AssemblyActionResult(true, 'Session update saved and queued for sync.');
  }

  Future<AssemblySession> _requireSession(String id) async {
    final membership = _schoolSession.requireActiveMembership();
    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: id,
    );
    if (record == null) throw StateError('Assembly session $id was not found in this school.');
    return AssemblySession.fromJson(record.payload);
  }

  Future<void> _save(AssemblySession session, SyncOperation operation) async {
    final membership = _schoolSession.requireActiveMembership();
    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: session.id,
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: session.id,
      payload: session.toJson(),
      serverVersion: existing?.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _entityType,
      entityId: session.id,
      operation: operation,
      payload: session.toJson(),
      baseVersion: existing?.serverVersion,
    );
  }
}
