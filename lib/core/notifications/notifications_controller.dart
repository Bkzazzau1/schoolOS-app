import 'package:flutter/foundation.dart';

import '../../shared/models/school_membership.dart';
import '../network/api_client.dart';
import '../network/api_exceptions.dart';
import '../sync/sync_store.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.read,
    this.data = const {},
  });

  final int id;

  /// What it is about (for example `access_changed`, `staff_proposal`, `payroll_batch`).
  final String kind;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool read;
  final Map<String, Object?> data;

  AppNotification asRead() => AppNotification(
        id: id, kind: kind, title: title, message: message, createdAt: createdAt, read: true, data: data,
      );

  Map<String, Object?> toJson() => {
        'id': id, 'kind': kind, 'title': title, 'message': message,
        'createdAt': createdAt.toUtc().toIso8601String(), 'read': read, 'data': data,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as int,
        kind: json['kind'] as String? ?? '',
        title: json['title'] as String? ?? '',
        message: json['message'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        read: json['read'] as bool? ?? false,
        data: Map<String, Object?>.from((json['data'] as Map?) ?? const {}),
      );
}

/// The person's inbox for the school they are in: messages the school's
/// system sends them (a change to their access, something waiting for their
/// approval, an answer to a request).
///
/// It is read after every sync round and kept on the device, so the last
/// messages and the unread count are there offline. Reading a message offline is
/// remembered and told to the server next time.
class NotificationsController extends ChangeNotifier {
  NotificationsController({required ApiClient api, required SyncStore store, this.limit = 100})
      : _api = api,
        _store = store;

  /// Local-only cache, never sent to the server.
  static const entityType = '_notifications_cache';

  final ApiClient _api;
  final SyncStore _store;
  final int limit;

  List<AppNotification> _items = const [];
  int _unread = 0;
  final _readOffline = <int>{};

  List<AppNotification> get items => List.unmodifiable(_items);
  int get unread => _unread;

  Future<void> restore(SchoolMembership membership) async {
    final record = await _store.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: entityType,
      entityId: membership.id,
    );
    if (record == null) {
      _replace(const [], 0);
      return;
    }
    _replace(
      [for (final n in (record.payload['notifications'] as List? ?? const [])) AppNotification.fromJson(Map<String, dynamic>.from(n as Map))],
      record.payload['unread'] as int? ?? 0,
    );
  }

  /// Reads the inbox from the server. Throws what [ApiClient] throws.
  Future<void> refresh(SchoolMembership membership) async {
    await _sendOfflineReads(membership);
    final data = await _api.get(
      'schools/${membership.schoolId}/notifications/',
      query: {'membership': membership.id, 'limit': '$limit'},
    );
    if (data is! Map || data['notifications'] is! List) return;
    final items = [
      for (final n in (data['notifications'] as List)) AppNotification.fromJson(Map<String, dynamic>.from(n as Map)),
    ];
    await _keep(membership, items, data['unread'] as int? ?? 0);
  }

  Future<void> markRead(SchoolMembership membership, int id) async {
    final index = _items.indexWhere((n) => n.id == id);
    if (index == -1 || _items[index].read) return;
    final items = [..._items]..[index] = _items[index].asRead();
    await _keep(membership, items, _unread > 0 ? _unread - 1 : 0);
    try {
      await _api.post('schools/${membership.schoolId}/notifications/$id/read/', body: const {});
    } catch (_) {
      _readOffline.add(id); // told to the server on the next refresh
    }
  }

  Future<void> markAllRead(SchoolMembership membership) async {
    if (_unread == 0 && _items.every((n) => n.read)) return;
    await _keep(membership, [for (final n in _items) n.asRead()], 0);
    try {
      await _api.post('schools/${membership.schoolId}/notifications/read-all/', body: const {});
    } catch (_) {
      _readOffline.addAll(_items.map((n) => n.id));
    }
  }

  Future<void> _sendOfflineReads(SchoolMembership membership) async {
    for (final id in _readOffline.toList()) {
      try {
        await _api.post('schools/${membership.schoolId}/notifications/$id/read/', body: const {});
      } on ApiException {
        // The message is gone or was never theirs: nothing left to tell, and it must not block the inbox.
      }
      _readOffline.remove(id);
    }
  }

  Future<void> _keep(SchoolMembership membership, List<AppNotification> items, int unread) async {
    await _store.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: entityType,
      entityId: membership.id,
      payload: {'unread': unread, 'notifications': [for (final n in items) n.toJson()]},
    );
    _replace(items, unread);
  }

  void clear() => _replace(const [], 0);

  void _replace(List<AppNotification> items, int unread) {
    _items = items;
    _unread = unread;
    notifyListeners();
  }
}
