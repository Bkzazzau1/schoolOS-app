/// One premium capability's availability for a specific school, and why - the same reason
/// text the backend would give if it actually refused the action, so this display can never
/// drift from the real gate (apps.billing.premium_access.resolve_school_entitlements).
///
/// Three separate signals, never collapsed into one boolean: [planEnabled] (the
/// organization's commercial plan includes this feature at all), [schoolPaid] (this specific
/// school's own current period is paid), and [available] (what the real gate would actually
/// decide right now). A fourth, orthogonal signal -
/// [SchoolEntitlementSummary.premiumEnforcementEnabled] - says whether any of this is
/// actually enforced yet.
class SchoolEntitlementCapability {
  const SchoolEntitlementCapability({
    required this.planEnabled,
    required this.schoolPaid,
    required this.available,
    required this.reason,
  });

  final bool planEnabled;
  final bool schoolPaid;
  final bool available;
  final String reason;

  static const unavailable = SchoolEntitlementCapability(
    planEnabled: false,
    schoolPaid: false,
    available: false,
    reason: '',
  );

  factory SchoolEntitlementCapability.fromJson(Map<String, dynamic> json) =>
      SchoolEntitlementCapability(
        planEnabled: json['planEnabled'] as bool? ?? false,
        schoolPaid: json['schoolPaid'] as bool? ?? false,
        available: json['available'] as bool? ?? false,
        reason: json['reason'] as String? ?? '',
      );
}

/// A school's own academic term or session - never an organization-wide period.
class SchoolAcademicPeriodBrief {
  const SchoolAcademicPeriodBrief({
    required this.id,
    required this.code,
    required this.name,
    this.startsOn,
    this.endsOn,
  });

  final String id;
  final String code;
  final String name;
  final DateTime? startsOn;
  final DateTime? endsOn;

  factory SchoolAcademicPeriodBrief.fromJson(Map<String, dynamic> json) =>
      SchoolAcademicPeriodBrief(
        id: json['id'] as String? ?? '',
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        startsOn: _date(json['startsOn']),
        endsOn: _date(json['endsOn']),
      );
}

/// The school's own applicable fixed-bracket price - never the retired per-student
/// calculation, and never a fabricated amount when the backend could not determine one
/// (zero enrollment, or enrollment above every configured bracket with no enterprise
/// agreement on file: see [undefinedReason]).
class SchoolEnrollmentPricing {
  const SchoolEnrollmentPricing({
    this.billableStudentCount,
    this.measuredAt,
    this.bracketMinStudents,
    this.bracketMaxStudents,
    this.pricingSource,
    this.undefinedReason,
  });

  final int? billableStudentCount;
  final DateTime? measuredAt;
  final int? bracketMinStudents;
  final int? bracketMaxStudents;
  final String? pricingSource;
  final String? undefinedReason;

  bool get isEnterprise => pricingSource == 'enterprise';
  bool get isPriceKnown => undefinedReason == null && pricingSource != null;

  /// A short label for the bracket/agreement, matching BillingInvoiceLine.pricingLabel's
  /// convention elsewhere in this feature.
  String get pricingLabel {
    if (isEnterprise) return 'Enterprise agreement';
    final max = bracketMaxStudents;
    final min = bracketMinStudents ?? 0;
    return max == null ? '$min+ students' : '$min–$max students';
  }

  factory SchoolEnrollmentPricing.fromJson(Map<String, dynamic> json) =>
      SchoolEnrollmentPricing(
        billableStudentCount: (json['billableStudentCount'] as num?)?.toInt(),
        measuredAt: _date(json['measuredAt']),
        bracketMinStudents: (json['bracketMinStudents'] as num?)?.toInt(),
        bracketMaxStudents: (json['bracketMaxStudents'] as num?)?.toInt(),
        pricingSource: json['pricingSource'] as String?,
        undefinedReason: json['undefinedReason'] as String?,
      );
}

/// The invoice's own latest payment attempt, exactly as the server recorded it - never
/// invented client-side, so a viewer who reopens this screen after abandoning checkout can
/// recover it from here instead of only from in-memory state that a dropped app would lose.
class SchoolPendingPaymentAttempt {
  const SchoolPendingPaymentAttempt({
    required this.reference,
    required this.status,
    required this.createdAt,
    this.checkoutUrl,
  });

  final String reference;
  final String status;
  final DateTime createdAt;
  final String? checkoutUrl;

  bool get succeeded => status == 'succeeded';
  bool get pending => status == 'pending' || status == 'initialized';
  bool get failed => status == 'failed' || status == 'cancelled';

  factory SchoolPendingPaymentAttempt.fromJson(Map<String, dynamic> json) =>
      SchoolPendingPaymentAttempt(
        reference: json['reference'] as String? ?? '',
        status: json['status'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        checkoutUrl: json['checkoutUrl'] as String?,
      );
}

/// Sensitive commercial detail (invoice id/number, due date, exact amounts) - present only
/// when the server decided this viewer has billing authority for this school's organization.
/// A null [SchoolEntitlementSummary.billing] means "not shown to you," never "nothing owed."
class SchoolBillingDetail {
  const SchoolBillingDetail({
    required this.organizationId,
    required this.invoiceId,
    required this.invoiceNumber,
    required this.status,
    required this.amountDueMinor,
    required this.amountPaidMinor,
    required this.currency,
    required this.issuedAt,
    required this.payable,
    this.dueAt,
    this.latestPaymentAttempt,
  });

  final String organizationId;
  final String invoiceId;
  final String invoiceNumber;
  final String status;
  final int amountDueMinor;
  final int amountPaidMinor;
  final String currency;
  final DateTime issuedAt;
  final DateTime? dueAt;
  final bool payable;
  final SchoolPendingPaymentAttempt? latestPaymentAttempt;

  int get outstandingMinor {
    final due = amountDueMinor < 0 ? 0 : amountDueMinor;
    return (due - amountPaidMinor).clamp(0, due).toInt();
  }

  bool get paid => status == 'paid';

  factory SchoolBillingDetail.fromJson(Map<String, dynamic> json) => SchoolBillingDetail(
        organizationId: json['organizationId'] as String? ?? '',
        invoiceId: json['invoiceId'] as String? ?? '',
        invoiceNumber: json['invoiceNumber'] as String? ?? '',
        status: json['status'] as String? ?? '',
        amountDueMinor: (json['amountDueMinor'] as num?)?.toInt() ?? 0,
        amountPaidMinor: (json['amountPaidMinor'] as num?)?.toInt() ?? 0,
        currency: json['currency'] as String? ?? 'NGN',
        issuedAt: DateTime.tryParse(json['issuedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        dueAt: _date(json['dueAt']),
        payable: json['payable'] as bool? ?? false,
        latestPaymentAttempt: json['latestPaymentAttempt'] is Map
            ? SchoolPendingPaymentAttempt.fromJson(
                Map<String, dynamic>.from(json['latestPaymentAttempt'] as Map),
              )
            : null,
      );
}

/// The school's own authoritative enrollment census for its current term (Phase D Stage 3,
/// Task 1/10) - never shown for MONTHLY/ANNUAL subscriptions, which have no per-school term
/// for a census to be scoped to. A null [SchoolEntitlementSummary.census] means nothing
/// about this has fired yet for this school, never an error.
class SchoolCensusStatus {
  const SchoolCensusStatus({
    required this.status,
    required this.isEarly,
    this.billableStudentCount,
    this.cutoffAt,
    this.frozenAt,
    this.exceptionReason,
  });

  final String status;
  final int? billableStudentCount;
  final DateTime? cutoffAt;
  final DateTime? frozenAt;
  final bool isEarly;
  final String? exceptionReason;

  bool get isFrozen => status == 'frozen';
  bool get needsReview => status == 'needs_review';

  factory SchoolCensusStatus.fromJson(Map<String, dynamic> json) => SchoolCensusStatus(
        status: json['status'] as String? ?? '',
        billableStudentCount: (json['billableStudentCount'] as num?)?.toInt(),
        cutoffAt: _date(json['cutoffAt']),
        frozenAt: _date(json['frozenAt']),
        isEarly: json['isEarly'] as bool? ?? false,
        exceptionReason: json['exceptionReason'] as String?,
      );
}

/// One school's own subscription and premium-entitlement status - never the organization-wide
/// accessMode, never a sibling school's payment (apps.billing.premium_access's own module
/// docstring: "do not rely solely on the organization-wide subscription status").
class SchoolEntitlementSummary {
  const SchoolEntitlementSummary({
    required this.schoolId,
    required this.schoolName,
    required this.canManageBilling,
    required this.premiumEnforcementEnabled,
    required this.paymentStatus,
    required this.entitlements,
    this.organizationId,
    this.viewerRole,
    this.academicTerm,
    this.academicSession,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.enrollment,
    this.billing,
    this.census,
  });

  final String schoolId;
  final String schoolName;
  final String? organizationId;
  final String? viewerRole;
  final bool canManageBilling;
  final bool premiumEnforcementEnabled;
  final String paymentStatus;
  final SchoolAcademicPeriodBrief? academicTerm;
  final SchoolAcademicPeriodBrief? academicSession;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final SchoolEnrollmentPricing? enrollment;
  final Map<String, SchoolEntitlementCapability> entitlements;
  final SchoolBillingDetail? billing;
  final SchoolCensusStatus? census;

  bool get isPaid => paymentStatus == 'paid';

  /// Whether SkulGen SaaS billing even applies to this school - false only for a legacy
  /// school with no organization, where every premium capability is simply always available.
  bool get subscriptionApplies => paymentStatus != 'not_applicable';

  SchoolEntitlementCapability capability(String code) =>
      entitlements[code] ?? SchoolEntitlementCapability.unavailable;

  String get paymentStatusLabel => switch (paymentStatus) {
        'paid' => 'Paid',
        'unpaid' => 'Unpaid',
        'no_invoice_yet' => 'No invoice yet',
        'not_applicable' => 'Not applicable',
        _ => paymentStatus.isEmpty ? 'Unknown' : paymentStatus,
      };

  factory SchoolEntitlementSummary.fromJson(Map<String, dynamic> json) {
    final rawEntitlements = json['entitlements'];
    final entitlements = <String, SchoolEntitlementCapability>{};
    if (rawEntitlements is Map) {
      for (final entry in rawEntitlements.entries) {
        if (entry.key is String && entry.value is Map) {
          entitlements[entry.key as String] = SchoolEntitlementCapability.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }
    }
    final currentPeriod = json['currentPeriod'];
    return SchoolEntitlementSummary(
      schoolId: json['schoolId'] as String? ?? '',
      schoolName: json['schoolName'] as String? ?? '',
      organizationId: json['organizationId'] as String?,
      viewerRole: json['viewerRole'] as String?,
      canManageBilling: json['canManageBilling'] as bool? ?? false,
      premiumEnforcementEnabled: json['premiumEnforcementEnabled'] as bool? ?? false,
      paymentStatus: json['paymentStatus'] as String? ?? '',
      academicTerm: json['academicTerm'] is Map
          ? SchoolAcademicPeriodBrief.fromJson(
              Map<String, dynamic>.from(json['academicTerm'] as Map),
            )
          : null,
      academicSession: json['academicSession'] is Map
          ? SchoolAcademicPeriodBrief.fromJson(
              Map<String, dynamic>.from(json['academicSession'] as Map),
            )
          : null,
      currentPeriodStart: currentPeriod is Map ? _date(currentPeriod['start']) : null,
      currentPeriodEnd: currentPeriod is Map ? _date(currentPeriod['end']) : null,
      enrollment: json['enrollment'] is Map
          ? SchoolEnrollmentPricing.fromJson(Map<String, dynamic>.from(json['enrollment'] as Map))
          : null,
      entitlements: entitlements,
      billing: json['billing'] is Map
          ? SchoolBillingDetail.fromJson(Map<String, dynamic>.from(json['billing'] as Map))
          : null,
      census: json['census'] is Map
          ? SchoolCensusStatus.fromJson(Map<String, dynamic>.from(json['census'] as Map))
          : null,
    );
  }
}

DateTime? _date(Object? value) => value is String ? DateTime.tryParse(value) : null;
