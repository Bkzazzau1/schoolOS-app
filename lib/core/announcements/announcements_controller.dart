import 'package:flutter/foundation.dart';

import '../../shared/models/school_membership.dart';
import '../network/api_client.dart';
import '../sync/sync_store.dart';

class PlatformAnnouncement {
  const PlatformAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    required this.startsAt,
  });

  final String id;
  final String title;
  final String body;
  final DateTime startsAt;

  Map<String, Object?> toJson() => {
        'id': id, 'title': title, 'body': body, 'startsAt': startsAt.toUtc().toIso8601String(),
      };

  factory PlatformAnnouncement.fromJson(Map<String, dynamic> json) => PlatformAnnouncement(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        startsAt: DateTime.tryParse(json['startsAt'] as String? ?? '') ?? DateTime.now(),
      );
}

/// Pop messages SkulGen's own staff send to schools - platform-wide, or targeted at this
/// school's organization. Read-only from the server: dismissing one is remembered only
/// on this device (the same "local-only cache" pattern as NotificationsController), so
/// a message is never shown again here once the person has seen and closed it once.
class AnnouncementsController extends ChangeNotifier {
  AnnouncementsController({required ApiClient api, required SyncStore store})
      : _api = api,
        _store = store;

  static const entityType = '_announcements_cache';

  final ApiClient _api;
  final SyncStore _store;

  List<PlatformAnnouncement> _items = const [];
  Set<String> _dismissed = const {};

  /// Currently-active announcements this person has not already dismissed, oldest
  /// decision first so a popup shows the longest-standing message first.
  List<PlatformAnnouncement> get toShow =>
      List.unmodifiable(_items.where((a) => !_dismissed.contains(a.id)));

  Future<void> restore(SchoolMembership membership) async {
    final record = await _store.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: entityType,
      entityId: membership.id,
    );
    if (record == null) {
      _replace(const [], const {});
      return;
    }
    _replace(
      [for (final a in (record.payload['announcements'] as List? ?? const [])) PlatformAnnouncement.fromJson(Map<String, dynamic>.from(a as Map))],
      Set<String>.from((record.payload['dismissed'] as List? ?? const [])),
    );
  }

  /// Reads what's currently active from the server. Throws what [ApiClient] throws.
  Future<void> refresh(SchoolMembership membership) async {
    final data = await _api.get('schools/${membership.schoolId}/announcements/active/');
    if (data is! Map || data['announcements'] is! List) return;
    final items = [
      for (final a in (data['announcements'] as List)) PlatformAnnouncement.fromJson(Map<String, dynamic>.from(a as Map)),
    ];
    // A dismissal only ever makes sense for an announcement that still exists - drop
    // stale ids for ones that have since ended, so the saved set never grows forever.
    final stillRelevant = _dismissed.intersection(items.map((a) => a.id).toSet());
    await _keep(membership, items, stillRelevant);
  }

  Future<void> dismiss(SchoolMembership membership, String id) async {
    if (_dismissed.contains(id)) return;
    await _keep(membership, _items, {..._dismissed, id});
  }

  void clear() => _replace(const [], const {});

  Future<void> _keep(SchoolMembership membership, List<PlatformAnnouncement> items, Set<String> dismissed) async {
    await _store.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: entityType,
      entityId: membership.id,
      payload: {
        'announcements': [for (final a in items) a.toJson()],
        'dismissed': dismissed.toList(),
      },
    );
    _replace(items, dismissed);
  }

  void _replace(List<PlatformAnnouncement> items, Set<String> dismissed) {
    _items = items;
    _dismissed = dismissed;
    notifyListeners();
  }
}
