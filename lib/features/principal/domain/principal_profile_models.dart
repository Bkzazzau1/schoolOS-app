enum PrincipalPreferenceKey {
  approvals,
  attendance,
  incidents,
  reports,
  messages,
  aiBrief,
}

extension PrincipalPreferenceKeyX on PrincipalPreferenceKey {
  String get label => switch (this) {
        PrincipalPreferenceKey.approvals => 'Approval requests',
        PrincipalPreferenceKey.attendance => 'Attendance alerts',
        PrincipalPreferenceKey.incidents => 'Incident alerts',
        PrincipalPreferenceKey.reports => 'Result release alerts',
        PrincipalPreferenceKey.messages => 'Priority messages',
        PrincipalPreferenceKey.aiBrief => 'Principal AI daily brief',
      };

  String get description => switch (this) {
        PrincipalPreferenceKey.approvals => 'Teacher submissions, report cards and score corrections',
        PrincipalPreferenceKey.attendance => 'Repeated student absence, staff absence and lateness',
        PrincipalPreferenceKey.incidents => 'High-priority behaviour, safeguarding and safety cases',
        PrincipalPreferenceKey.reports => 'Batches waiting for approval or release',
        PrincipalPreferenceKey.messages => 'Urgent staff or guardian communication',
        PrincipalPreferenceKey.aiBrief => 'Summary of Secondary School issues, risks and recommended actions',
      };
}

class PrincipalAccountProfile {
  const PrincipalAccountProfile({
    required this.fullName,
    required this.displayName,
    required this.email,
    required this.phone,
    required this.role,
    required this.academicSection,
  });

  final String fullName;
  final String displayName;
  final String email;
  final String phone;
  final String role;
  final String academicSection;

  PrincipalAccountProfile copyWith({String? fullName, String? displayName, String? email, String? phone}) =>
      PrincipalAccountProfile(
        fullName: fullName ?? this.fullName,
        displayName: displayName ?? this.displayName,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        role: role,
        academicSection: academicSection,
      );

  Map<String, Object?> toJson() => {
        'fullName': fullName,
        'displayName': displayName,
        'email': email,
        'phone': phone,
        'role': role,
        'academicSection': academicSection,
      };

  factory PrincipalAccountProfile.fromJson(Map<String, dynamic> json) => PrincipalAccountProfile(
        fullName: json['fullName'] as String,
        displayName: json['displayName'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String,
        role: json['role'] as String,
        academicSection: json['academicSection'] as String,
      );
}

class PrincipalNotificationPreferences {
  const PrincipalNotificationPreferences({required this.values});
  final Map<PrincipalPreferenceKey, bool> values;

  bool isEnabled(PrincipalPreferenceKey key) => values[key] ?? false;

  PrincipalNotificationPreferences toggled(PrincipalPreferenceKey key) => PrincipalNotificationPreferences(
        values: {...values, key: !isEnabled(key)},
      );

  Map<String, Object?> toJson() => {
        for (final entry in values.entries) entry.key.name: entry.value,
      };

  factory PrincipalNotificationPreferences.fromJson(Map<String, dynamic> json) => PrincipalNotificationPreferences(
        values: {
          for (final key in PrincipalPreferenceKey.values) key: json[key.name] as bool? ?? false,
        },
      );
}

/// One real action this Principal actually took, drawn from the Incidents, Approvals or
/// Communication audit trail. [time] is the real ISO timestamp recorded when it happened.
class PrincipalProfileActivity {
  const PrincipalProfileActivity({required this.time, required this.action});
  final String time;
  final String action;
}

/// [name] is the real school name from the active membership. Nothing else about the
/// school's physical identity (address, phone, branches) has a real source anywhere in the
/// app yet, so those stay `null`/empty rather than inventing a plausible-looking address.
class PrincipalSchoolIdentity {
  const PrincipalSchoolIdentity({
    required this.name,
    this.address,
    this.phone,
    this.branches = const [],
  });
  final String name;
  final String? address;
  final String? phone;
  final List<String> branches;
}

class PrincipalProfilePermissions {
  const PrincipalProfilePermissions({
    required this.canEditOwnContactProfile,
    required this.canEditNotificationPreferences,
    required this.canEditSchoolIdentity,
    required this.canAccessFinance,
    required this.canLeadPrimaryOrNursery,
  });
  final bool canEditOwnContactProfile;
  final bool canEditNotificationPreferences;
  final bool canEditSchoolIdentity;
  final bool canAccessFinance;
  final bool canLeadPrimaryOrNursery;
}
