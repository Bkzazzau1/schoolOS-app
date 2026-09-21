import 'package:flutter/foundation.dart';

import '../../../app/demo_people.dart';
import '../../../core/access/access_catalog_data.dart';
import '../../../core/access/access_view.dart';
import '../../../core/sync/sync_store.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/owner_access_models.dart';
import 'owner_access_source.dart';

/// Who-sees-what for the demo, kept on the device (there is no server to decide it).
///
/// It follows the same rules as the school server so the demo behaves like the real thing: each role has
/// built-in screens, the owner can change what a role sees, can give one person a screen or take one
/// away, and can give a person an extra role (a teacher who is also a parent). Changes take effect
/// at once and are kept, so signing in as the person afterwards shows what the owner decided.
///
/// The owner's own screens cannot be removed from the owner, and a screen every role needs
/// (marked essential) cannot be taken away from anyone.
class LocalOwnerAccess extends ChangeNotifier implements OwnerAccessSource, AccessView {
  LocalOwnerAccess({required SyncStore store, required SchoolSessionController session})
      : _store = store,
        _session = session {
    _session.addListener(_sessionChanged);
    _activeId = _session.activeMembershipId;
  }

  static const entityType = '_demo_access';
  static const _stateId = 'decisions';

  final SyncStore _store;
  final SchoolSessionController _session;
  String? _activeId;
  bool _loaded = false;

  final Map<String, Set<String>> _roleScreens = {};
  final Map<String, List<_Decision>> _decisions = {};
  final Map<String, List<String>> _extraRoles = {};
  final List<AccessChangeEntry> _history = [];

  static final _catalog = _buildCatalog();

  @override
  bool get supportsExtraRoles => true;

  // ---------------------------------------------------------------- keeping decisions

  Future<void> restore() async {
    for (final schoolId in {for (final m in demoMemberships) m.schoolId}) {
      final record = await _store.getLocalRecord(tenantId: schoolId, entityType: entityType, entityId: _stateId);
      if (record == null) continue;
      final data = record.payload;
      for (final e in (data['roles'] as Map? ?? const {}).entries) {
        _roleScreens['$schoolId|${e.key}'] = {for (final a in e.value as List) a as String};
      }
      for (final e in (data['people'] as Map? ?? const {}).entries) {
        final person = Map<String, dynamic>.from(e.value as Map);
        _decisions[e.key as String] = [
          for (final d in (person['decisions'] as List? ?? const [])) _Decision.fromJson(Map<String, dynamic>.from(d as Map)),
        ];
        final extras = [for (final r in (person['extraRoles'] as List? ?? const [])) r as String];
        if (extras.isNotEmpty) _extraRoles[e.key as String] = extras;
      }
      for (final h in (data['history'] as List? ?? const [])) {
        _history.add(AccessChangeEntry.fromJson(Map<String, dynamic>.from(h as Map)));
      }
    }
    _loaded = true;
    await applyToSession();
  }

  Future<void> _keep(String schoolId) async {
    String prefix(String key) => key.split('|').first;
    await _store.upsertLocalRecord(
      tenantId: schoolId,
      entityType: entityType,
      entityId: _stateId,
      payload: {
        'roles': {
          for (final e in _roleScreens.entries)
            if (prefix(e.key) == schoolId) e.key.split('|').last: e.value.toList()..sort(),
        },
        'people': {
          for (final p in demoPeopleAt(schoolId))
            p.id: {
              'decisions': [for (final d in _decisions[p.id] ?? const <_Decision>[]) d.toJson()],
              'extraRoles': _extraRoles[p.id] ?? const <String>[],
            },
        },
        'history': [for (final h in _history) _historyJson(h)],
      },
    );
  }

  /// Every sample membership, with the extra roles the owner has given people added.
  List<SchoolMembership> get memberships => [
        ...demoMemberships,
        for (final m in demoMemberships)
          for (final role in _extraRoles[m.id] ?? const <String>[])
            SchoolMembership(
              id: extraMembershipId(m.id, role),
              schoolId: m.schoolId,
              schoolName: m.schoolName,
              role: SchoolRole.values.byName(role),
            ),
      ];

  static String extraMembershipId(String personId, String role) => '$personId#$role';

  /// Puts the extra roles into the signed-in list, when the session is the demo's.
  Future<void> applyToSession() async {
    if (!_session.memberships.any((m) => demoMemberships.any((d) => d.id == m.id))) return;
    await _session.setMemberships(memberships);
  }

  // ---------------------------------------------------------------- what a person may use

  Set<String> _screensOfRole(String schoolId, String role) =>
      _roleScreens['$schoolId|$role'] ?? {for (final e in accessCatalogEntries) if (e.roles.contains(role)) e.key};

  /// (person id, role) for a membership, including extra-role memberships.
  ({String personId, String role})? _whoIs(String membershipId) {
    final hash = membershipId.indexOf('#');
    if (hash > 0) return (personId: membershipId.substring(0, hash), role: membershipId.substring(hash + 1));
    for (final m in demoMemberships) {
      if (m.id == membershipId) return (personId: m.id, role: m.role.name);
    }
    return null;
  }

  Set<String> _activitiesFor(String schoolId, String personId, Iterable<String> roles) {
    final result = {for (final role in roles) ..._screensOfRole(schoolId, role)};
    final now = DateTime.now();
    for (final d in _decisions[personId] ?? const <_Decision>[]) {
      if (d.expiresAt != null && d.expiresAt!.isBefore(now)) continue;
      d.block ? result.remove(d.activity) : result.add(d.activity);
    }
    return result;
  }

  @override
  bool get known => _loaded && _activeId != null && _whoIs(_activeId!) != null;

  /// Screens that are not in the catalog are never hidden: hiding is only a convenience.
  @override
  bool allows(String activity) {
    if (!known) return true;
    if (!accessCatalogEntries.any((e) => e.key == activity)) return true;
    final who = _whoIs(_activeId!)!;
    final schoolId = _schoolOf(who.personId);
    return _activitiesFor(schoolId, who.personId, [who.role]).contains(activity);
  }

  String _schoolOf(String personId) => demoMemberships.firstWhere((m) => m.id == personId).schoolId;

  void _sessionChanged() {
    final next = _session.activeMembershipId;
    if (next == _activeId) return;
    _activeId = next;
    notifyListeners();
  }

  // ---------------------------------------------------------------- the owner's screen

  @override
  Future<AccessCatalogData> loadCatalog(SchoolMembership owner) async => _catalogFor(owner.schoolId);

  @override
  Future<List<RoleAccess>> loadRoles(SchoolMembership owner) async => [
        for (final role in _rolesAt(owner.schoolId))
          RoleAccess(
            role: role,
            activities: _screensOfRole(owner.schoolId, role),
            customized: _roleScreens.containsKey('${owner.schoolId}|$role'),
            editable: role != 'proprietor',
          ),
      ];

  @override
  Future<void> setRole(SchoolMembership owner, String role, Set<String> activities) async {
    _requireOwner(owner);
    if (role == 'proprietor') throw StateError('The owner always has every owner screen.');
    for (final e in accessCatalogEntries) {
      if (e.essential && e.roles.contains(role) && !activities.contains(e.key)) {
        throw StateError('${e.label} is needed by every ${roleLabel(role).toLowerCase()} and cannot be taken away.');
      }
      if (activities.contains(e.key) && !e.grantable && !e.roles.contains(role)) {
        throw StateError('${e.label} cannot be given to a ${roleLabel(role).toLowerCase()}.');
      }
    }
    final before = _screensOfRole(owner.schoolId, role);
    _roleScreens['${owner.schoolId}|$role'] = {...activities};
    _log(owner, 'role_set', role: role, detail: {
      'added': (activities.difference(before)).toList()..sort(),
      'removed': (before.difference(activities)).toList()..sort(),
    });
    await _changed(owner.schoolId);
  }

  @override
  Future<void> resetRole(SchoolMembership owner, String role) async {
    _requireOwner(owner);
    _roleScreens.remove('${owner.schoolId}|$role');
    _log(owner, 'role_reset', role: role);
    await _changed(owner.schoolId);
  }

  @override
  Future<List<PersonAccess>> loadPeople(SchoolMembership owner) async => [
        for (final p in demoPeopleAt(owner.schoolId))
          PersonAccess(
            membershipId: p.id,
            email: p.email,
            name: p.name,
            role: p.role.name,
            activities: _activitiesFor(owner.schoolId, p.id, [p.role.name, ...?_extraRoles[p.id]]),
            overrides: [
              for (final d in _decisions[p.id] ?? const <_Decision>[])
                AccessOverride(
                  activity: d.activity,
                  isBlock: d.block,
                  state: d.expiresAt != null && d.expiresAt!.isBefore(DateTime.now()) ? OverrideState.expired : OverrideState.inForce,
                  setAt: d.setAt,
                  expiresAt: d.expiresAt,
                  note: d.note,
                ),
            ],
            extraRoles: _extraRoles[p.id] ?? const [],
          ),
      ];

  @override
  Future<void> setOverride(
    SchoolMembership owner,
    String membershipId,
    String activity, {
    required bool block,
    bool immediately = false,
    DateTime? expiresAt,
    String note = '',
  }) async {
    _requireOwner(owner);
    final person = _person(owner, membershipId);
    final entry = _entry(activity);
    if (block) {
      if (membershipId == owner.id) throw StateError('You cannot take screens away from yourself.');
      if (entry.essential) throw StateError('${entry.label} is needed by everyone with this role and cannot be taken away.');
    } else if (!entry.grantable) {
      throw StateError('${entry.label} cannot be given to a single person.');
    }
    _decisions[membershipId] = [
      for (final d in _decisions[membershipId] ?? const <_Decision>[])
        if (d.activity != activity) d,
      _Decision(activity: activity, block: block, setAt: DateTime.now(), expiresAt: expiresAt, note: note.trim()),
    ];
    _log(owner, block ? 'person_block' : 'person_grant', activity: activity, person: person.name, detail: {'note': note.trim()});
    await _changed(owner.schoolId);
  }

  @override
  Future<void> clearOverride(SchoolMembership owner, String membershipId, String activity) async {
    _requireOwner(owner);
    final person = _person(owner, membershipId);
    _decisions[membershipId] = [for (final d in _decisions[membershipId] ?? const <_Decision>[]) if (d.activity != activity) d];
    _log(owner, 'person_clear', activity: activity, person: person.name);
    await _changed(owner.schoolId);
  }

  @override
  Future<void> reassign(
    SchoolMembership owner, {
    required String activity,
    required String fromMembershipId,
    required String toMembershipId,
    bool immediately = false,
    String note = '',
  }) async {
    _requireOwner(owner);
    if (fromMembershipId == toMembershipId) throw StateError('Choose two different people.');
    final to = _person(owner, toMembershipId);
    await setOverride(owner, fromMembershipId, activity, block: true, note: note);
    await setOverride(owner, toMembershipId, activity, block: false, note: note);
    _history.removeRange(_history.length - 2, _history.length);
    _log(owner, 'reassign', activity: activity, person: to.name, detail: {'note': note.trim()});
    await _changed(owner.schoolId);
  }

  @override
  Future<List<AccessChangeEntry>> loadHistory(SchoolMembership owner, {int limit = 100}) async =>
      _history.reversed.take(limit).toList();

  @override
  Future<void> addRole(SchoolMembership owner, String personId, String role) async {
    _requireOwner(owner);
    final person = _person(owner, personId);
    if (role == 'proprietor') throw StateError('There is one owner. That role cannot be given to someone else.');
    if (role == person.role.name || (_extraRoles[personId] ?? const []).contains(role)) {
      throw StateError('${person.name} already has the ${roleLabel(role).toLowerCase()} role.');
    }
    _extraRoles[personId] = [...?_extraRoles[personId], role];
    _log(owner, 'role_added', role: role, person: person.name);
    await _changed(owner.schoolId);
    await applyToSession();
  }

  @override
  Future<void> removeRole(SchoolMembership owner, String personId, String role) async {
    _requireOwner(owner);
    final person = _person(owner, personId);
    if (!(_extraRoles[personId] ?? const []).contains(role)) {
      throw StateError('${roleLabel(role)} is ${person.name}\'s main role and cannot be removed.');
    }
    _extraRoles[personId] = [for (final r in _extraRoles[personId]!) if (r != role) r];
    if (_extraRoles[personId]!.isEmpty) _extraRoles.remove(personId);
    _log(owner, 'role_removed', role: role, person: person.name);
    await _changed(owner.schoolId);
    await applyToSession();
  }

  // ---------------------------------------------------------------- helpers

  void _requireOwner(SchoolMembership owner) {
    if (owner.role != SchoolRole.proprietor) throw StateError('Only the owner can change who sees what.');
  }

  DemoPerson _person(SchoolMembership owner, String membershipId) {
    for (final p in demoPeopleAt(owner.schoolId)) {
      if (p.id == membershipId) return p;
    }
    throw StateError('That person is not at this school.');
  }

  CatalogEntry _entry(String activity) => accessCatalogEntries.firstWhere(
        (e) => e.key == activity,
        orElse: () => throw StateError('That screen does not exist.'),
      );

  Iterable<String> _rolesAt(String schoolId) sync* {
    final seen = <String>{};
    for (final p in demoPeopleAt(schoolId)) {
      if (seen.add(p.role.name)) yield p.role.name;
    }
  }

  AccessCatalogData _catalogFor(String schoolId) {
    final roles = _rolesAt(schoolId).toSet();
    return AccessCatalogData([
      for (final g in _catalog.groups)
        AccessGroup(area: g.area, activities: [
          for (final a in g.activities)
            AccessActivity(
              key: a.key,
              label: a.label,
              essential: a.essential,
              grantable: a.grantable,
              sensitive: a.sensitive,
              defaultRoles: a.defaultRoles,
              rolesInThisSchool: roles,
            ),
        ]),
    ]);
  }

  void _log(SchoolMembership owner, String kind, {String activity = '', String role = '', String? person, Map<String, Object?> detail = const {}}) {
    _history.add(AccessChangeEntry(
      at: DateTime.now(),
      kind: kind,
      activity: activity,
      role: role,
      by: demoPersonNames[owner.id] ?? 'The owner',
      forPerson: person,
      detail: detail,
    ));
  }

  Future<void> _changed(String schoolId) async {
    await _keep(schoolId);
    notifyListeners();
  }

  Map<String, Object?> _historyJson(AccessChangeEntry h) => {
        'at': h.at.toUtc().toIso8601String(),
        'kind': h.kind,
        'activity': h.activity,
        'role': h.role,
        'by': h.by,
        'for': h.forPerson,
        'detail': h.detail,
      };

  static AccessCatalogData _buildCatalog() {
    final byArea = <String, List<AccessActivity>>{};
    for (final e in accessCatalogEntries) {
      byArea.putIfAbsent(e.area, () => []).add(AccessActivity(
            key: e.key,
            label: e.label,
            essential: e.essential,
            grantable: e.grantable,
            sensitive: e.sensitive,
            defaultRoles: e.roles,
            rolesInThisSchool: const {},
          ));
    }
    return AccessCatalogData([for (final e in byArea.entries) AccessGroup(area: e.key, activities: e.value)]);
  }

  @override
  void dispose() {
    _session.removeListener(_sessionChanged);
    super.dispose();
  }
}

class _Decision {
  const _Decision({required this.activity, required this.block, required this.setAt, this.expiresAt, this.note = ''});

  final String activity;
  final bool block;
  final DateTime setAt;
  final DateTime? expiresAt;
  final String note;

  Map<String, Object?> toJson() => {
        'activity': activity,
        'block': block,
        'setAt': setAt.toUtc().toIso8601String(),
        'expiresAt': expiresAt?.toUtc().toIso8601String(),
        'note': note,
      };

  factory _Decision.fromJson(Map<String, dynamic> json) => _Decision(
        activity: json['activity'] as String,
        block: json['block'] as bool,
        setAt: DateTime.parse(json['setAt'] as String),
        expiresAt: json['expiresAt'] == null ? null : DateTime.parse(json['expiresAt'] as String),
        note: json['note'] as String? ?? '',
      );
}
