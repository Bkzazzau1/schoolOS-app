enum OrganizationRole {
  owner,
  administrator,
  billingAdministrator,
}

class OrganizationMembership {
  const OrganizationMembership({
    required this.id,
    required this.organizationId,
    required this.organizationName,
    required this.role,
  });

  final String id;
  final String organizationId;
  final String organizationName;
  final OrganizationRole role;

  bool get canCreateSchools =>
      role == OrganizationRole.owner || role == OrganizationRole.administrator;

  bool get canManageBilling =>
      role == OrganizationRole.owner || role == OrganizationRole.billingAdministrator;

  String get roleLabel => switch (role) {
        OrganizationRole.owner => 'Account owner',
        OrganizationRole.administrator => 'Account administrator',
        OrganizationRole.billingAdministrator => 'Billing administrator',
      };

  factory OrganizationMembership.fromJson(Map<String, dynamic> json) {
    final organization = json['organization'];
    final organizationMap = organization is Map
        ? Map<String, dynamic>.from(organization)
        : const <String, dynamic>{};

    final organizationId = _string(
      json['organizationId'] ??
          json['organization_id'] ??
          organizationMap['id'],
    );
    final organizationName = _string(
      json['organizationName'] ??
          json['organization_name'] ??
          organizationMap['name'],
    );

    if (organizationId.isEmpty) {
      throw const FormatException('Organization membership is missing an organization id.');
    }

    return OrganizationMembership(
      id: _string(json['id']),
      organizationId: organizationId,
      organizationName: organizationName,
      role: _roleFrom(json['role']),
    );
  }

  static OrganizationRole _roleFrom(Object? raw) {
    final value = _string(raw).toLowerCase().replaceAll('-', '_');
    return switch (value) {
      'owner' || 'account_owner' => OrganizationRole.owner,
      'administrator' || 'admin' || 'account_administrator' =>
        OrganizationRole.administrator,
      'billing_administrator' || 'billing_admin' =>
        OrganizationRole.billingAdministrator,
      _ => throw FormatException('Unknown organization role: $value'),
    };
  }

  static String _string(Object? value) => value is String ? value.trim() : '';
}
