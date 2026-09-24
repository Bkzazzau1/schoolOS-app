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

class BillingAutomation {
  const BillingAutomation({
    required this.enabled,
    required this.state,
    required this.message,
    required this.activeSchools,
    required this.meteredSchools,
    this.periodStart,
    this.periodEnd,
    this.nextInvoiceAt,
    this.invoiceDueDays,
    this.pastDueDays,
    this.graceDays,
  });

  static const unavailable = BillingAutomation(
    enabled: false,
    state: 'unknown',
    message: '',
    activeSchools: 0,
    meteredSchools: 0,
  );

  final bool enabled;
  final String state;
  final String message;
  final int activeSchools;
  final int meteredSchools;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final DateTime? nextInvoiceAt;
  final int? invoiceDueDays;
  final int? pastDueDays;
  final int? graceDays;

  bool get meterReady => meteredSchools >= activeSchools;

  String get stateLabel => switch (state) {
        'cadence_not_configured' => 'Cadence not configured',
        'automatic_invoicing_off' => 'Automatic invoicing off',
        'policy_incomplete' => 'Policy incomplete',
        'period_required' => 'Billing period required',
        'awaiting_meter' => 'Waiting for roster meter',
        'ready_to_initialize' => 'Ready to initialize',
        'ready_to_invoice' => 'Ready to invoice',
        'scheduled' => 'Scheduled',
        'invoice_outstanding' => 'Invoice outstanding',
        _ => state.isEmpty || state == 'unknown' ? 'Not available' : state,
      };

  factory BillingAutomation.fromJson(Map<String, dynamic> json) =>
      BillingAutomation(
        enabled: json['enabled'] as bool? ?? false,
        state: json['state'] as String? ?? 'unknown',
        message: json['message'] as String? ?? '',
        activeSchools: (json['activeSchools'] as num?)?.toInt() ?? 0,
        meteredSchools: (json['meteredSchools'] as num?)?.toInt() ?? 0,
        periodStart: _date(json['periodStart']),
        periodEnd: _date(json['periodEnd']),
        nextInvoiceAt: _date(json['nextInvoiceAt']),
        invoiceDueDays: (json['invoiceDueDays'] as num?)?.toInt(),
        pastDueDays: (json['pastDueDays'] as num?)?.toInt(),
        graceDays: (json['graceDays'] as num?)?.toInt(),
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
    this.automation = BillingAutomation.unavailable,
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
  final BillingAutomation automation;

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
      automation: json['automation'] is Map
          ? BillingAutomation.fromJson(
              Map<String, dynamic>.from(json['automation'] as Map),
            )
          : BillingAutomation.unavailable,
    );
  }
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
