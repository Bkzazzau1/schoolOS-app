import 'package:flutter/foundation.dart';

import '../../shared/models/school_membership.dart';
import '../database/local_database.dart';
import '../sync/sync_mutation.dart';
import '../tenancy/school_session_controller.dart';
import 'school_theme.dart';

class SchoolAppearanceController extends ChangeNotifier {
  SchoolAppearanceController({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession {
    _schoolSession.addListener(_handleSchoolSessionChanged);
  }

  static const _entityType = 'school_appearance';
  static const _entityId = 'theme';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  SchoolThemePreset _theme = schoolThemePresets.first;
  bool _ready = false;
  int _loadGeneration = 0;

  SchoolThemePreset get theme => _theme;
  bool get ready => _ready;

  Future<void> initialize() async {
    await _loadForActiveSchool();
  }

  Future<void> applyTheme(SchoolThemePreset preset) async {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.proprietor) {
      throw StateError('Only a proprietor membership can change school appearance.');
    }

    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: _entityId,
    );
    final payload = <String, Object?>{
      'themeId': preset.id,
      'updatedByMembershipId': membership.id,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: _entityId,
      payload: payload,
      serverVersion: existing?.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _entityType,
      entityId: _entityId,
      operation: existing == null ? SyncOperation.create : SyncOperation.update,
      payload: payload,
      baseVersion: existing?.serverVersion,
    );

    _theme = preset;
    _ready = true;
    notifyListeners();
  }

  void _handleSchoolSessionChanged() {
    _loadForActiveSchool();
  }

  Future<void> _loadForActiveSchool() async {
    final generation = ++_loadGeneration;
    final membership = _schoolSession.activeMembership;

    if (membership == null) {
      _theme = schoolThemePresets.first;
      _ready = true;
      notifyListeners();
      return;
    }

    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: _entityId,
    );
    if (generation != _loadGeneration) return;

    _theme = schoolThemeById(record?.payload['themeId'] as String?);
    _ready = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _schoolSession.removeListener(_handleSchoolSessionChanged);
    super.dispose();
  }
}
