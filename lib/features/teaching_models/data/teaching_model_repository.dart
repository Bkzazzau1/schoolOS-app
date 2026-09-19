import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/teaching_model_models.dart';
import 'teaching_model_demo_data.dart';

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

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  TeachingModelPermissions permissionsFor(SchoolMembership membership) {
    return TeachingModelPermissions(
      canConfigureAllSections: membership.role == SchoolRole.proprietor,
    );
  }

  Future<TeachingModelSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    var records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );

    if (records.isEmpty) {
      for (final config in teachingModelWebsiteSeed) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _entityType,
          entityId: config.id,
          payload: config.toJson(),
        );
      }
      records = await _localDatabase.getLocalRecords(
        tenantId: membership.schoolId,
        entityType: _entityType,
      );
    }

    final configurations = records
        .map((record) => TeachingClassConfig.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));

    return TeachingModelSnapshot(
      configurations: configurations,
      permissions: permissionsFor(membership),
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
