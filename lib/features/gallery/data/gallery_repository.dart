import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/gallery_models.dart';
import 'gallery_demo_data.dart';

class GallerySnapshot {
  const GallerySnapshot({required this.items, required this.permissions});

  final List<GalleryMediaItem> items;
  final GalleryPermissions permissions;
}

class GalleryRepository {
  GalleryRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _entityType = 'gallery_media_album';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  GalleryPermissions permissionsFor(SchoolMembership membership) {
    return GalleryPermissions(
      canApproveVisibility: membership.role == SchoolRole.proprietor,
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

    return GallerySnapshot(
      items: items,
      permissions: permissionsFor(membership),
    );
  }
}
