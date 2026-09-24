class BillingPaymentAttempt {
  const BillingPaymentAttempt({
    required this.id,
    required this.provider,
    required this.reference,
    required this.status,
    required this.amountMinor,
    required this.currency,
    required this.createdAt,
    this.checkoutUrl,
    this.accessCode,
    this.succeededAt,
  });

  final String id;
  final String provider;
  final String reference;
  final String status;
  final int amountMinor;
  final String currency;
  final String? checkoutUrl;
  final String? accessCode;
  final DateTime createdAt;
  final DateTime? succeededAt;

  bool get succeeded => status == 'succeeded';
  bool get pending => status == 'pending' || status == 'initialized';

  factory BillingPaymentAttempt.fromJson(Map<String, dynamic> json) =>
      BillingPaymentAttempt(
        id: json['id'] as String? ?? '',
        provider: json['provider'] as String? ?? '',
        reference: json['reference'] as String? ?? '',
        status: json['status'] as String? ?? '',
        amountMinor: (json['amountMinor'] as num?)?.toInt() ?? 0,
        currency: json['currency'] as String? ?? 'NGN',
        checkoutUrl: json['checkoutUrl'] as String?,
        accessCode: json['accessCode'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        succeededAt: json['succeededAt'] is String
            ? DateTime.tryParse(json['succeededAt'] as String)
            : null,
      );
}

class BillingInvoice {
  const BillingInvoice({
    required this.id,
    required this.number,
    required this.organizationId,
    required this.status,
    required this.currency,
    required this.baseAmountMinor,
    required this.studentUnitAmountMinor,
    required this.billableStudentCount,
    required this.amountDueMinor,
    required this.amountPaidMinor,
    required this.issuedAt,
    this.periodStart,
    this.periodEnd,
    this.dueAt,
    this.paidAt,
    this.paymentAttempts = const [],
  });

  final String id;
  final String number;
  final String organizationId;
  final String status;
  final String currency;
  final int baseAmountMinor;
  final int studentUnitAmountMinor;
  final int billableStudentCount;
  final int amountDueMinor;
  final int amountPaidMinor;
  final DateTime issuedAt;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final DateTime? dueAt;
  final DateTime? paidAt;
  final List<BillingPaymentAttempt> paymentAttempts;

  int get outstandingMinor {
    // amountDueMinor is trusted server data, but nothing upstream guarantees it
    // is non-negative (a credit-note invoice, a refund adjustment, or simply a
    // bad value during backend development). clamp(lower, upper) throws if
    // lower > upper, so a negative amountDueMinor would crash this getter -
    // guard it to a safe floor first.
    final due = amountDueMinor < 0 ? 0 : amountDueMinor;
    return (due - amountPaidMinor).clamp(0, due).toInt();
  }

  bool get paid => status == 'paid';
  bool get payable => status == 'open' && outstandingMinor > 0;

  factory BillingInvoice.fromJson(Map<String, dynamic> json) => BillingInvoice(
        id: json['id'] as String? ?? '',
        number: json['number'] as String? ?? '',
        organizationId: json['organizationId'] as String? ?? '',
        status: json['status'] as String? ?? '',
        currency: json['currency'] as String? ?? 'NGN',
        baseAmountMinor: (json['baseAmountMinor'] as num?)?.toInt() ?? 0,
        studentUnitAmountMinor:
            (json['studentUnitAmountMinor'] as num?)?.toInt() ?? 0,
        billableStudentCount:
            (json['billableStudentCount'] as num?)?.toInt() ?? 0,
        amountDueMinor: (json['amountDueMinor'] as num?)?.toInt() ?? 0,
        amountPaidMinor: (json['amountPaidMinor'] as num?)?.toInt() ?? 0,
        issuedAt: DateTime.tryParse(json['issuedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        periodStart: json['periodStart'] is String
            ? DateTime.tryParse(json['periodStart'] as String)
            : null,
        periodEnd: json['periodEnd'] is String
            ? DateTime.tryParse(json['periodEnd'] as String)
            : null,
        dueAt: json['dueAt'] is String
            ? DateTime.tryParse(json['dueAt'] as String)
            : null,
        paidAt: json['paidAt'] is String
            ? DateTime.tryParse(json['paidAt'] as String)
            : null,
        paymentAttempts: [
          for (final item in (json['paymentAttempts'] as List? ?? const []))
            if (item is Map)
              BillingPaymentAttempt.fromJson(
                Map<String, dynamic>.from(item),
              ),
        ],
      );
}

class BillingCheckout {
  const BillingCheckout({required this.invoice, required this.payment});

  final BillingInvoice invoice;
  final BillingPaymentAttempt payment;

  factory BillingCheckout.fromJson(Map<String, dynamic> json) {
    final invoice = json['invoice'];
    final payment = json['payment'];
    if (invoice is! Map || payment is! Map) {
      throw const FormatException('Invalid checkout response.');
    }
    return BillingCheckout(
      invoice: BillingInvoice.fromJson(Map<String, dynamic>.from(invoice)),
      payment: BillingPaymentAttempt.fromJson(
        Map<String, dynamic>.from(payment),
      ),
    );
  }
}
