import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../shared/models/school_membership.dart';
import '../database/local_database.dart';
import '../sync/sync_mutation.dart';
import '../tenancy/school_session_controller.dart';
import 'school_theme.dart';

/// The school's look: its colour theme and its logo. The owner chooses them; everyone in the school sees them.
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

  /// The most a saved logo may weigh (after it has been shrunk). The server refuses larger ones.
  static const maxLogoBytes = 140 * 1024;

  /// The appearance the running app shows, so small widgets (the school logo) can reach it without being passed it.
  static SchoolAppearanceController? shared;

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  SchoolThemePreset _theme = schoolThemePresets.first;
  Uint8List? _logo;
  bool _ready = false;
  int _loadGeneration = 0;

  SchoolThemePreset get theme => _theme;

  /// The school's logo (a PNG or JPEG), or null when none has been chosen.
  Uint8List? get logo => _logo;
  bool get ready => _ready;

  Future<void> initialize() async {
    await _loadForActiveSchool();
  }

  /// Reads the appearance again (after a sync may have brought a newer one).
  Future<void> reload() => _loadForActiveSchool();

  Future<void> applyTheme(SchoolThemePreset preset) => _save(theme: preset, logo: _logo);

  /// Sets the school logo, or removes it with null.
  Future<void> applyLogo(Uint8List? bytes) async {
    if (bytes != null && bytes.length > maxLogoBytes) {
      throw StateError('That logo is too large. Choose a smaller picture.');
    }
    await _save(theme: _theme, logo: bytes);
  }

  Future<void> _save({required SchoolThemePreset theme, required Uint8List? logo}) async {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.proprietor) {
      throw StateError('Only a proprietor membership can change school appearance.');
    }
    if (theme.isCustom) {
      final problem = colourProblem(darkArgb: theme.darkArgb, accentArgb: theme.accentArgb);
      if (problem != null) throw StateError(problem);
    }

    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: _entityId,
    );
    final payload = <String, Object?>{
      'themeId': theme.id,
      if (theme.isCustom) 'primaryArgb': theme.darkArgb,
      if (theme.isCustom) 'accentArgb': theme.accentArgb,
      if (logo != null) 'logo': base64Encode(logo),
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

    _theme = theme;
    _logo = logo;
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
      _logo = null;
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

    final logo = record?.payload['logo'];
    Uint8List? bytes;
    if (logo is String && logo.isNotEmpty) {
      try {
        bytes = base64Decode(logo);
      } on FormatException {
        bytes = null;
      }
    }
    final nextTheme = schoolThemeFromPayload(record?.payload);
    final wasReady = _ready;
    final changed = nextTheme.id != _theme.id ||
        nextTheme.darkArgb != _theme.darkArgb ||
        nextTheme.accentArgb != _theme.accentArgb ||
        !listEquals(bytes, _logo);
    _theme = nextTheme;
    _logo = bytes;
    _ready = true;
    if (changed || !wasReady) notifyListeners();
  }

  @override
  void dispose() {
    _schoolSession.removeListener(_handleSchoolSessionChanged);
    super.dispose();
  }
}
