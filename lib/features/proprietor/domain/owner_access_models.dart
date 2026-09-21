class AccessActivity {
  const AccessActivity({
    required this.key,
    required this.label,
    required this.essential,
    required this.grantable,
    required this.sensitive,
    required this.defaultRoles,
    required this.rolesInThisSchool,
  });

  final String key;
  final String label;
  final bool essential;
  final bool grantable;
  final bool sensitive;
  final Set<String> defaultRoles;
  final Set<String> rolesInThisSchool;

  factory AccessActivity.fromJson(Map<String, dynamic> json) => AccessActivity(
        key: json['key'] as String,
        label: json['label'] as String,
        essential: json['essential'] as bool? ?? false,
        grantable: json['grantable'] as bool? ?? true,
        sensitive: json['sensitive'] as bool? ?? false,
        defaultRoles: {for (final r in (json['defaultRoles'] as List? ?? const [])) r as String},
        rolesInThisSchool: {for (final r in (json['rolesInThisSchool'] as List? ?? const [])) r as String},
      );
}

class AccessGroup {
  const AccessGroup({required this.area, required this.activities});
  final String area;
  final List<AccessActivity> activities;

  factory AccessGroup.fromJson(Map<String, dynamic> json) => AccessGroup(
        area: json['area'] as String,
        activities: [
          for (final a in (json['activities'] as List? ?? const []))
            AccessActivity.fromJson(Map<String, dynamic>.from(a as Map)),
        ],
      );
}

class AccessCatalogData {
  const AccessCatalogData(this.groups);
  final List<AccessGroup> groups;

  Iterable<AccessActivity> get all => groups.expand((g) => g.activities);

  AccessActivity? byKey(String key) {
    for (final a in all) {
      if (a.key == key) return a;
    }
    return null;
  }

  String labelOf(String key) => byKey(key)?.label ?? key;

  factory AccessCatalogData.fromJson(Map<String, dynamic> json) => AccessCatalogData([
        for (final g in (json['groups'] as List? ?? const []))
          AccessGroup.fromJson(Map<String, dynamic>.from(g as Map)),
      ]);
}

class RoleAccess {
  const RoleAccess({required this.role, required this.activities, required this.customized, required this.editable});
  final String role;
  final Set<String> activities;
  final bool customized;
  final bool editable;

  factory RoleAccess.fromJson(Map<String, dynamic> json) => RoleAccess(
        role: json['role'] as String,
        activities: {for (final a in (json['activities'] as List? ?? const [])) a as String},
        customized: json['customized'] as bool? ?? false,
        editable: json['editable'] as bool? ?? true,
      );
}

enum OverrideState { inForce, waitingForSync, expired }

class AccessOverride {
  const AccessOverride({
    required this.activity,
    required this.isBlock,
    required this.state,
    required this.setAt,
    this.expiresAt,
    this.takesEffectBy,
    this.note = '',
  });

  final String activity;
  final bool isBlock;
  final OverrideState state;
  final DateTime setAt;
  final DateTime? expiresAt;
  final DateTime? takesEffectBy;
  final String note;

  factory AccessOverride.fromJson(Map<String, dynamic> json) => AccessOverride(
        activity: json['activity'] as String,
        isBlock: json['effect'] == 'block',
        state: switch (json['state']) {
          'waiting_for_sync' => OverrideState.waitingForSync,
          'expired' => OverrideState.expired,
          _ => OverrideState.inForce,
        },
        setAt: DateTime.parse(json['setAt'] as String),
        expiresAt: json['expiresAt'] == null ? null : DateTime.parse(json['expiresAt'] as String),
        takesEffectBy: json['takesEffectBy'] == null ? null : DateTime.parse(json['takesEffectBy'] as String),
        note: json['note'] as String? ?? '',
      );
}

class PersonAccess {
  const PersonAccess({
    required this.membershipId,
    required this.email,
    required this.name,
    required this.role,
    required this.activities,
    required this.overrides,
  });

  final String membershipId;
  final String email;
  final String name;
  final String role;
  final Set<String> activities;
  final List<AccessOverride> overrides;

  String get displayName => name.trim().isEmpty ? email : name;

  AccessOverride? overrideFor(String activity) {
    for (final o in overrides) {
      if (o.activity == activity && o.state != OverrideState.expired) return o;
    }
    return null;
  }

  factory PersonAccess.fromJson(Map<String, dynamic> json) => PersonAccess(
        membershipId: json['membershipId'] as String,
        email: json['email'] as String? ?? '',
        name: json['name'] as String? ?? '',
        role: json['role'] as String,
        activities: {for (final a in (json['activities'] as List? ?? const [])) a as String},
        overrides: [
          for (final o in (json['overrides'] as List? ?? const []))
            AccessOverride.fromJson(Map<String, dynamic>.from(o as Map)),
        ],
      );
}

class AccessChangeEntry {
  const AccessChangeEntry({
    required this.at,
    required this.kind,
    required this.activity,
    required this.role,
    required this.by,
    required this.forPerson,
    required this.detail,
  });

  final DateTime at;
  final String kind;
  final String activity;
  final String role;
  final String? by;
  final String? forPerson;
  final Map<String, Object?> detail;

  factory AccessChangeEntry.fromJson(Map<String, dynamic> json) => AccessChangeEntry(
        at: DateTime.parse(json['at'] as String),
        kind: json['kind'] as String? ?? '',
        activity: json['activity'] as String? ?? '',
        role: json['role'] as String? ?? '',
        by: json['by'] as String?,
        forPerson: json['for'] as String?,
        detail: Map<String, Object?>.from((json['detail'] as Map?) ?? const {}),
      );
}

const roleLabels = <String, String>{
  'proprietor': 'Owner',
  'administrator': 'Administrator',
  'principal': 'Principal',
  'teacher': 'Teacher',
  'accountant': 'Finance officer',
  'parent': 'Parent',
  'student': 'Student',
  'alumni': 'Alumni',
  'staff': 'Support / other staff',
  'driver': 'Driver',
};

String roleLabel(String role) => roleLabels[role] ?? role;
