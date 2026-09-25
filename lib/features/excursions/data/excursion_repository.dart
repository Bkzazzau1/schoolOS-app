import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/data/administrator_academics_repository.dart';
import '../../administrator/domain/administrator_academics_models.dart';
import '../domain/excursion_models.dart';
import 'excursion_demo_data.dart';

class ExcursionSnapshot {
  const ExcursionSnapshot({
    required this.trips,
    required this.permissions,
    required this.availableSessions,
    required this.availableTerms,
    required this.availableClasses,
  });

  final List<SchoolTrip> trips;
  final ExcursionPermissions permissions;

  /// The academic sessions each term in [availableTerms] belongs to.
  final List<AdministratorAcademicSession> availableSessions;

  /// Real academic terms a new trip can be tied to, most recent first.
  final List<AdministratorAcademicTerm> availableTerms;

  /// Real classes a trip can optionally be linked to.
  final List<AdministratorAcademicClass> availableClasses;
}

class ExcursionActionResult {
  const ExcursionActionResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class ExcursionRepository {
  ExcursionRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _academics = AdministratorAcademicsRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
        );

  static const _entityType = 'school_excursion';
  static const _managers = {
    SchoolRole.proprietor,
    SchoolRole.principal,
    SchoolRole.administrator,
  };
  static const _leaders = {SchoolRole.proprietor, SchoolRole.principal};

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final AdministratorAcademicsRepository _academics;

  ExcursionPermissions permissionsFor(SchoolMembership membership) {
    final manage = _managers.contains(membership.role);
    return ExcursionPermissions(
      canManage: manage,
      canContribute: membership.role == SchoolRole.teacher,
      canReviewReadiness: _leaders.contains(membership.role),
    );
  }

  Future<ExcursionSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    var records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );

    if (records.isEmpty) {
      for (final trip in excursionWebsiteSeed) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _entityType,
          entityId: trip.id,
          payload: trip.toJson(),
        );
      }
      records = await _localDatabase.getLocalRecords(
        tenantId: membership.schoolId,
        entityType: _entityType,
      );
    }

    final trips = records
        .map((record) => SchoolTrip.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));

    final academics = await _academics.load();

    return ExcursionSnapshot(
      trips: trips,
      permissions: permissionsFor(membership),
      availableSessions: academics.sessions,
      availableTerms: academics.terms,
      availableClasses:
          academics.classes.where((item) => item.isActive).toList(growable: false),
    );
  }

  Future<ExcursionActionResult> createTrip({
    required String title,
    required String date,
    required String destination,
    required String coordinator,
    required int students,
    required String transport,
    required String emergency,
    required String note,
    required AdministratorAcademicTerm term,
    required AdministratorAcademicSession session,
    AdministratorAcademicClass? academicClass,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = permissionsFor(membership);
    if (!permissions.canCreateTrip) {
      return const ExcursionActionResult(
        success: false,
        message: 'This membership cannot add excursions.',
      );
    }
    if (title.trim().isEmpty || date.trim().isEmpty) {
      return const ExcursionActionResult(
        success: false,
        message: 'A trip needs at least a title and a date.',
      );
    }

    final trip = SchoolTrip(
      id: AdministratorAcademicsRepository.newId(),
      title: title.trim(),
      audience: academicClass?.name ?? title.trim(),
      date: date.trim(),
      destination: destination.trim(),
      coordinator: coordinator.trim(),
      students: students,
      consentReceived: 0,
      transport: transport.trim(),
      emergency: emergency.trim(),
      status: TripStatus.planning,
      note: note.trim(),
      termId: term.id,
      termName: term.name,
      sessionName: session.name,
      classId: academicClass?.id ?? '',
      className: academicClass?.name ?? '',
    );

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: trip.id,
      payload: trip.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _entityType,
      entityId: trip.id,
      operation: SyncOperation.create,
      payload: trip.toJson(),
    );

    return const ExcursionActionResult(
      success: true,
      message: 'Trip added and queued for sync.',
    );
  }

  Future<ExcursionActionResult> toggleReadinessReview(String tripId) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canReviewReadiness) {
      return const ExcursionActionResult(
        success: false,
        message: 'This membership cannot review excursion readiness.',
      );
    }

    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: tripId,
    );
    if (record == null) {
      return const ExcursionActionResult(
        success: false,
        message: 'Trip was not found for this school.',
      );
    }

    final current = SchoolTrip.fromJson(record.payload);
    final updated = current.copyWith(
      readinessReviewed: !current.readinessReviewed,
    );

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: updated.id,
      payload: updated.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _entityType,
      entityId: updated.id,
      operation: SyncOperation.update,
      payload: updated.toJson(),
    );

    return ExcursionActionResult(
      success: true,
      message: updated.readinessReviewed
          ? 'Readiness review saved offline.'
          : 'Readiness review reopened and queued for sync.',
    );
  }
}
