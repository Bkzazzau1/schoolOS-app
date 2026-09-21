import 'package:flutter/foundation.dart';

import '../../shared/models/school_membership.dart';
import '../network/api_client.dart';
import '../sync/sync_store.dart';
import 'access_view.dart';

/// A block the owner has made that is not in force yet. The person keeps the
/// activity until the app has sent its unsent work for it (and says so), or until
/// [finalizeAt], whichever comes first.
class AccessBlock {
  const AccessBlock({required this.activity, required this.finalizeAt});

  final String activity;
  final DateTime finalizeAt;

  Map<String, Object?> toJson() => {'activity': activity, 'finalizeAt': finalizeAt.toUtc().toIso8601String()};

  factory AccessBlock.fromJson(Map<String, dynamic> json) => AccessBlock(
        activity: json['activity'] as String,
        finalizeAt: DateTime.parse(json['finalizeAt'] as String),
      );
}

class AccessSnapshot {
  const AccessSnapshot({required this.membershipId, required this.activities, required this.blocking});

  final String membershipId;

  /// Every activity (screen) the person may use, as `<workspace>.<screen>`.
  final Set<String> activities;
  final List<AccessBlock> blocking;

  Map<String, Object?> toJson() => {
        'membershipId': membershipId,
        'activities': activities.toList()..sort(),
        'blocking': [for (final b in blocking) b.toJson()],
      };

  factory AccessSnapshot.fromJson(Map<String, dynamic> json) => AccessSnapshot(
        membershipId: json['membershipId'] as String,
        activities: {for (final a in (json['activities'] as List? ?? const [])) a as String},
        blocking: [
          for (final b in (json['blocking'] as List? ?? const [])) AccessBlock.fromJson(Map<String, dynamic>.from(b as Map)),
        ],
      );

  bool sameAs(AccessSnapshot other) =>
      membershipId == other.membershipId &&
      setEquals(activities, other.activities) &&
      listEquals([for (final b in blocking) b.activity], [for (final b in other.blocking) b.activity]);
}

/// Which screens the signed-in person may use in the school they are in, as the
/// owner has decided.
///
/// It is read from the server after every sync round and kept on the device, so
/// the menus are right offline too. Until it is known (demo data, or before the
/// first answer) nothing is hidden: hiding a menu item is only a convenience, and
/// the server refuses the data itself.
class AccessController extends ChangeNotifier implements AccessView {
  AccessController({required ApiClient api, required SyncStore store})
      : _api = api,
        _store = store;

  /// Local-only: never sent to the server. The leading underscore keeps it apart from school records.
  static const entityType = '_access_snapshot';

  final ApiClient _api;
  final SyncStore _store;

  AccessSnapshot? _snapshot;

  AccessSnapshot? get snapshot => _snapshot;

  /// True once the person's access has been read (from the server or the device).
  @override
  bool get known => _snapshot != null;

  List<AccessBlock> get blocking => _snapshot?.blocking ?? const [];

  /// May the person use this screen? `true` while access is not known.
  @override
  bool allows(String activity) => _snapshot == null || _snapshot!.activities.contains(activity);

  /// Loads what was kept on the device for this membership (a different
  /// membership's access is never used).
  Future<void> restore(SchoolMembership membership) async {
    final record = await _store.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: entityType,
      entityId: membership.id,
    );
    _set(record == null ? null : AccessSnapshot.fromJson(Map<String, dynamic>.from(record.payload)));
  }

  /// Asks the server what the person may use now, and keeps the answer.
  /// Throws what [ApiClient] throws (offline, session ended, refused).
  Future<void> refresh(SchoolMembership membership) async {
    final data = await _api.get('schools/${membership.schoolId}/access/me/', query: {'membership': membership.id});
    await _keep(membership, data);
  }

  /// Tells the server the app has fetched the latest and sent its unsent work
  /// for these activities, so the owner's waiting blocks on them take effect now.
  Future<void> acknowledge(SchoolMembership membership, Iterable<String> activities) async {
    final list = activities.toList();
    if (list.isEmpty) return;
    final data = await _api.post(
      'schools/${membership.schoolId}/access/acknowledge/',
      body: {'activities': list},
    );
    await _keep(membership, data);
  }

  Future<void> _keep(SchoolMembership membership, Object? data) async {
    if (data is! Map || data['activities'] is! List) return;
    final fresh = AccessSnapshot.fromJson(Map<String, dynamic>.from(data));
    await _store.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: entityType,
      entityId: membership.id,
      payload: fresh.toJson(),
    );
    _set(fresh);
  }

  /// Forgets everything (signed out).
  void clear() => _set(null);

  void _set(AccessSnapshot? next) {
    final current = _snapshot;
    if (current == null && next == null) return;
    if (current != null && next != null && current.sameAs(next)) {
      _snapshot = next; // same access; keep the newer deadlines quietly
      return;
    }
    _snapshot = next;
    notifyListeners();
  }
}
