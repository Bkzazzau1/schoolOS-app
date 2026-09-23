class BillingPlan {
  const BillingPlan({
    required this.code,
    required this.name,
    required this.description,
    required this.currency,
    required this.baseAmountMinor,
    required this.studentUnitAmountMinor,
    this.billingInterval,
  });

  final String code;
  final String name;
  final String description;
  final String currency;
  final String? billingInterval;
  final int baseAmountMinor;
  final int studentUnitAmountMinor;

  factory BillingPlan.fromJson(Map<String, dynamic> json) => BillingPlan(
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? 'SchoolOS plan',
        description: json['description'] as String? ?? '',
        currency: json['currency'] as String? ?? 'NGN',
        billingInterval: json['billingInterval'] as String?,
        baseAmountMinor: (json['baseAmountMinor'] as num?)?.toInt() ?? 0,
        studentUnitAmountMinor:
            (json['studentUnitAmountMinor'] as num?)?.toInt() ?? 0,
      );
}

class BillingEntitlement {
  const BillingEntitlement({
    required this.code,
    required this.enabled,
    required this.available,
    this.limit,
  });

  final String code;
  final bool enabled;
  final bool available;
  final int? limit;

  factory BillingEntitlement.fromJson(
    String code,
    Map<String, dynamic> json,
  ) =>
      BillingEntitlement(
        code: code,
        enabled: json['enabled'] as bool? ?? false,
        available: json['available'] as bool? ?? false,
        limit: (json['limit'] as num?)?.toInt(),
      );
}

class BillingUsage {
  const BillingUsage({
    required this.activeSchools,
    this.billableStudents,
    this.capturedAt,
  });

  final int activeSchools;
  final int? billableStudents;
  final DateTime? capturedAt;

  factory BillingUsage.fromJson(Map<String, dynamic> json) => BillingUsage(
        activeSchools: (json['activeSchools'] as num?)?.toInt() ?? 0,
        billableStudents: (json['billableStudents'] as num?)?.toInt(),
        capturedAt: _date(json['capturedAt']),
      );
}

class OrganizationSubscriptionSummary {
  const OrganizationSubscriptionSummary({
    required this.organizationId,
    required this.status,
    required this.accessMode,
    required this.canManageBilling,
    required this.entitlements,
    required this.usage,
    this.plan,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.trialEndsAt,
    this.graceEndsAt,
    this.cancelAtPeriodEnd = false,
  });

  final String organizationId;
  final String status;
  final String accessMode;
  final BillingPlan? plan;
  final bool canManageBilling;
  final Map<String, BillingEntitlement> entitlements;
  final BillingUsage usage;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final DateTime? trialEndsAt;
  final DateTime? graceEndsAt;
  final bool cancelAtPeriodEnd;

  bool get accountChangesAvailable => accessMode == 'full';

  String get statusLabel => switch (status) {
        'trial' => 'Trial',
        'active' => 'Active',
        'past_due' => 'Past due',
        'grace' => 'Grace period',
        'restricted' => 'Restricted',
        'suspended' => 'Suspended',
        'cancelled' => 'Cancelled',
        _ => status.isEmpty ? 'Unknown' : status,
      };

  factory OrganizationSubscriptionSummary.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawEntitlements = json['entitlements'];
    final entitlements = <String, BillingEntitlement>{};
    if (rawEntitlements is Map) {
      for (final entry in rawEntitlements.entries) {
        if (entry.key is String && entry.value is Map) {
          entitlements[entry.key as String] = BillingEntitlement.fromJson(
            entry.key as String,
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }
    }

    return OrganizationSubscriptionSummary(
      organizationId: json['organizationId'] as String? ?? '',
      status: json['status'] as String? ?? '',
      accessMode: json['accessMode'] as String? ?? 'unknown',
      plan: json['plan'] is Map
          ? BillingPlan.fromJson(
              Map<String, dynamic>.from(json['plan'] as Map),
            )
          : null,
      canManageBilling: json['canManageBilling'] as bool? ?? false,
      entitlements: entitlements,
      usage: json['usage'] is Map
          ? BillingUsage.fromJson(
              Map<String, dynamic>.from(json['usage'] as Map),
            )
          : const BillingUsage(activeSchools: 0),
      currentPeriodStart: _date(json['currentPeriodStart']),
      currentPeriodEnd: _date(json['currentPeriodEnd']),
      trialEndsAt: _date(json['trialEndsAt']),
      graceEndsAt: _date(json['graceEndsAt']),
      cancelAtPeriodEnd: json['cancelAtPeriodEnd'] as bool? ?? false,
    );
  }
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
