import '../../../core/database/local_database.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/alumni_profile_models.dart';
import 'alumni_server_api.dart';

class AlumniProfileRepository {
  AlumniProfileRepository({
    required LocalDatabase localDatabase,
    required SchoolMembership membership,
    required AlumniServerApi? remote,
  })  : _localDatabase = localDatabase,
        _membership = membership,
        _remote = remote;

  static const cacheEntityType = '_alumni_profile_cache';

  final LocalDatabase _localDatabase;
  final SchoolMembership _membership;
  final AlumniServerApi? _remote;

  bool get hasServer => _remote != null;

  Future<AlumniProfileRecord?> load() async {
    final cached = await _cached();
    final remote = _remote;
    if (remote == null) return cached;

    try {
      final fresh = await remote.loadMyProfile(_membership);
      if (fresh == null) {
        await _localDatabase.deleteLocalRecord(
          tenantId: _membership.schoolId,
          entityType: cacheEntityType,
          entityId: _membership.id,
        );
        return null;
      }
      await _cache(fresh);
      return fresh;
    } catch (_) {
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<AlumniProfileRecord?> loadCached() => _cached();

  Future<AlumniProfileRecord> save({
    required String originalStudentReference,
    required String admissionNumber,
    required int? graduationYear,
    required String graduationSet,
    required String profession,
    required String organisation,
    required String locationText,
    required String bio,
    required bool directoryVisible,
  }) async {
    final remote = _remote;
    if (remote == null) {
      throw StateError(
        'Alumni profile submission requires the SchoolOS server. Your last downloaded profile remains available offline.',
      );
    }
    final saved = await remote.saveMyProfile(
      _membership,
      originalStudentReference: originalStudentReference,
      admissionNumber: admissionNumber,
      graduationYear: graduationYear,
      graduationSet: graduationSet,
      profession: profession,
      organisation: organisation,
      locationText: locationText,
      bio: bio,
      directoryVisible: directoryVisible,
    );
    await _cache(saved);
    return saved;
  }

  Future<AlumniProfileRecord?> _cached() async {
    final record = await _localDatabase.getLocalRecord(
      tenantId: _membership.schoolId,
      entityType: cacheEntityType,
      entityId: _membership.id,
    );
    if (record == null) return null;
    return AlumniProfileRecord.fromJson(
      Map<String, dynamic>.from(record.payload),
    );
  }

  Future<void> _cache(AlumniProfileRecord profile) =>
      _localDatabase.upsertLocalRecord(
        tenantId: _membership.schoolId,
        entityType: cacheEntityType,
        entityId: _membership.id,
        payload: profile.toJson(),
      );
}
