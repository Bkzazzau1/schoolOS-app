import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/data/administrator_academics_repository.dart';
import '../../administrator/domain/administrator_academics_models.dart';
import '../domain/gallery_models.dart';
import 'gallery_demo_data.dart';

class GallerySnapshot {
  const GallerySnapshot({
    required this.items,
    required this.permissions,
    required this.availableSessions,
    required this.availableTerms,
    required this.availableClasses,
  });

  final List<GalleryMediaItem> items;
  final GalleryPermissions permissions;

  /// The academic sessions each term in [availableTerms] belongs to.
  final List<AdministratorAcademicSession> availableSessions;

  /// Real academic terms a new album can be tied to.
  final List<AdministratorAcademicTerm> availableTerms;

  /// Real classes an album can optionally be linked to.
  final List<AdministratorAcademicClass> availableClasses;
}

class GalleryActionResult {
  const GalleryActionResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class GalleryRepository {
  GalleryRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _academics = AdministratorAcademicsRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
        );

  static const _entityType = 'gallery_media_album';
  static const _managers = {
    SchoolRole.proprietor,
    SchoolRole.principal,
    SchoolRole.administrator,
  };
  static const _contributors = {SchoolRole.teacher, SchoolRole.staff};
  static const _leaders = {SchoolRole.proprietor, SchoolRole.principal};

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final AdministratorAcademicsRepository _academics;

  GalleryPermissions permissionsFor(SchoolMembership membership) {
    return GalleryPermissions(
      canManage: _managers.contains(membership.role),
      canContribute: _contributors.contains(membership.role),
      canApproveVisibility: _leaders.contains(membership.role),
    );
  }

  Future<GallerySnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    var records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );

    if (records.isEmpty) {
      for (final item in galleryWebsiteSeed) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _entityType,
          entityId: item.id,
          payload: item.toJson(),
        );
      }
      records = await _localDatabase.getLocalRecords(
        tenantId: membership.schoolId,
        entityType: _entityType,
      );
    }

    final items = records
        .map((record) => GalleryMediaItem.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));

    final academics = await _academics.load();

    return GallerySnapshot(
      items: items,
      permissions: permissionsFor(membership),
      availableSessions: academics.sessions,
      availableTerms: academics.terms,
      availableClasses:
          academics.classes.where((item) => item.isActive).toList(growable: false),
    );
  }

  Future<GalleryActionResult> createAlbum({
    required String title,
    required String album,
    required String owner,
    required String date,
    required int count,
    required GalleryVisibility visibility,
    required String consent,
    required String note,
    required AdministratorAcademicTerm term,
    required AdministratorAcademicSession session,
    AdministratorAcademicClass? academicClass,
    String excursionId = '',
    String excursionTitle = '',
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = permissionsFor(membership);
    if (!permissions.canCreateAlbum) {
      return const GalleryActionResult(
        success: false,
        message: 'This membership cannot add gallery albums.',
      );
    }
    if (visibility == GalleryVisibility.publicShowcase &&
        !permissions.canApproveVisibility) {
      return const GalleryActionResult(
        success: false,
        message: 'Only the Proprietor or Principal can publish a public showcase album.',
      );
    }
    if (title.trim().isEmpty) {
      return const GalleryActionResult(
        success: false,
        message: 'An album needs at least a title.',
      );
    }

    final audience = academicClass?.name ?? excursionTitle;
    final item = GalleryMediaItem(
      id: AdministratorAcademicsRepository.newId(),
      title: title.trim(),
      album: album.trim().isEmpty ? title.trim() : album.trim(),
      audience: audience.isEmpty ? 'Whole school' : audience,
      owner: owner.trim(),
      date: date.trim(),
      count: count,
      visibility: visibility,
      consent: consent.trim(),
      note: note.trim(),
      termId: term.id,
      termName: term.name,
      sessionName: session.name,
      classId: academicClass?.id ?? '',
      className: academicClass?.name ?? '',
      excursionId: excursionId,
      excursionTitle: excursionTitle,
    );

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: item.id,
      payload: item.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _entityType,
      entityId: item.id,
      operation: SyncOperation.create,
      payload: item.toJson(),
    );

    return const GalleryActionResult(
      success: true,
      message: 'Album added and queued for sync.',
    );
  }
}
