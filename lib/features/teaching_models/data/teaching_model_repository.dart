import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/teaching_model_models.dart';

class TeachingModelSnapshot {
  const TeachingModelSnapshot({
    required this.configurations,
    required this.permissions,
  });

  final List<TeachingClassConfig> configurations;
  final TeachingModelPermissions permissions;
}

class TeachingModelActionResult {
  const TeachingModelActionResult({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;
}

class TeachingModelRepository {
  TeachingModelRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _entityType = 'teaching_model_config';

  // Mirrors apps.schoollife.specs.programmes.TEACHING_MODELS exactly: manage=LEADERS - proprietor
  // and principal only, no administrator and no contribute tier at all (the simplest permission
  // shape in this cluster).
  static const _leaders = {SchoolRole.proprietor, SchoolRole.principal};

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  TeachingModelPermissions permissionsFor(SchoolMembership membership) {
    return TeachingModelPermissions(
      canConfigureAllSections: _leaders.contains(membership.role),
    );
  }

  Future<TeachingModelSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );

    final configurations = records
        .map((record) => TeachingClassConfig.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));

    return TeachingModelSnapshot(
      configurations: configurations,
      permissions: permissionsFor(membership),
    );
  }

  Future<TeachingModelActionResult> create({
    required String section,
    required String className,
    required TeachingModelType model,
    required String leadTeacher,
    required String specialistCoverage,
    required String note,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canConfigureAllSections) {
      return const TeachingModelActionResult(
        success: false,
        message: 'This membership cannot configure teaching models.',
      );
    }
    final cleanSection = section.trim();
    final cleanClassName = className.trim();
    if (cleanSection.isEmpty || cleanClassName.isEmpty) {
      return const TeachingModelActionResult(
        success: false,
        message: 'Section and class name are required.',
      );
    }

    final now = DateTime.now().toUtc();
    final config = TeachingClassConfig(
      id: 'TM-${now.microsecondsSinceEpoch}',
      section: cleanSection,
      className: cleanClassName,
      model: model,
      leadTeacher: leadTeacher.trim(),
      specialistCoverage: specialistCoverage.trim(),
      note: note.trim(),
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: config.id,
      payload: config.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _entityType,
      entityId: config.id,
      operation: SyncOperation.create,
      payload: config.toJson(),
    );
    return const TeachingModelActionResult(
      success: true,
      message: 'Class configuration added and queued for sync.',
    );
  }

  Future<TeachingModelActionResult> updateModel({
    required String configurationId,
    required TeachingModelType model,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canConfigureAllSections) {
      return const TeachingModelActionResult(
        success: false,
        message: 'This membership cannot configure teaching models.',
      );
    }

    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: configurationId,
    );
    if (record == null) {
      return const TeachingModelActionResult(
        success: false,
        message: 'Teaching-model configuration was not found for this school.',
      );
    }

    final current = TeachingClassConfig.fromJson(record.payload);
    if (current.model == model) {
      return const TeachingModelActionResult(
        success: true,
        message: 'Teaching model is already set to this value.',
      );
    }

    final updated = current.copyWith(model: model);
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

    return TeachingModelActionResult(
      success: true,
      message:
          '${updated.className} changed to ${updated.model.label} offline and queued for sync. Lead/tutor and specialist assignments were not changed automatically.',
    );
  }
}
