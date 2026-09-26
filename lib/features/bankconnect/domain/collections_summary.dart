import 'json_read.dart';

class AmountTotal {
  const AmountTotal({required this.amountMinor, required this.count});

  factory AmountTotal.fromJson(Map<String, dynamic> json) =>
      AmountTotal(amountMinor: json['amountMinor'] as int? ?? 0, count: json['count'] as int? ?? 0);

  final int amountMinor;
  final int count;
}

/// What one provider connection collected in the chosen period.
class ProviderTotal {
  const ProviderTotal({
    required this.connectionId,
    required this.provider,
    required this.merchantName,
    required this.label,
    required this.environment,
    required this.amountMinor,
    required this.count,
  });

  factory ProviderTotal.fromJson(Map<String, dynamic> json) => ProviderTotal(
        connectionId: json['connectionId'] as String? ?? '',
        provider: json['provider'] as String? ?? '',
        merchantName: json['merchantName'] as String? ?? '',
        label: json['label'] as String? ?? '',
        environment: json['environment'] as String? ?? '',
        amountMinor: json['amountMinor'] as int? ?? 0,
        count: json['count'] as int? ?? 0,
      );

  final String connectionId;
  final String provider;
  final String merchantName;
  final String label;
  final String environment;
  final int amountMinor;
  final int count;

  String get title => label.isNotEmpty ? label : (merchantName.isNotEmpty ? merchantName : provider);
}

class ReconciliationTotals {
  const ReconciliationTotals({required this.reconciledMinor, required this.unreconciledMinor, required this.pendingReviewCount});

  factory ReconciliationTotals.fromJson(Map<String, dynamic> json) => ReconciliationTotals(
        reconciledMinor: json['reconciledMinor'] as int? ?? 0,
        unreconciledMinor: json['unreconciledMinor'] as int? ?? 0,
        pendingReviewCount: json['pendingReviewCount'] as int? ?? 0,
      );

  final int reconciledMinor;
  final int unreconciledMinor;
  final int pendingReviewCount;

  int get totalMinor => reconciledMinor + unreconciledMinor;
}

/// How many provider connections work, and which one is the school's active collection provider.
class ProvidersBrief {
  const ProvidersBrief({required this.connected, required this.needAttention, required this.activeProvider, required this.activeMerchant});

  factory ProvidersBrief.fromJson(Map<String, dynamic> json) {
    final active = readMap(json['active']);
    return ProvidersBrief(
      connected: json['connected'] as int? ?? 0,
      needAttention: json['needAttention'] as int? ?? 0,
      activeProvider: active['provider'] as String? ?? '',
      activeMerchant: active['merchantName'] as String? ?? '',
    );
  }

  final int connected;
  final int needAttention;

  /// The active provider's code ("paystack", ...), or empty when none has been chosen.
  final String activeProvider;
  final String activeMerchant;
}

class RecentPayment {
  const RecentPayment({
    required this.id,
    required this.senderName,
    required this.amountMinor,
    required this.currency,
    required this.transactionDate,
    required this.provider,
    required this.status,
    required this.isSandbox,
  });

  factory RecentPayment.fromJson(Map<String, dynamic> json) => RecentPayment(
        id: json['id'] as String,
        senderName: json['senderName'] as String? ?? '',
        amountMinor: json['amountMinor'] as int? ?? 0,
        currency: json['currency'] as String? ?? 'NGN',
        transactionDate: readTime(json['transactionDate']),
        provider: json['provider'] as String? ?? '',
        status: json['reconciliationStatus'] as String? ?? '',
        isSandbox: json['isSandbox'] == true,
      );

  final String id;
  final String senderName;
  final int amountMinor;
  final String currency;
  final DateTime? transactionDate;
  final String provider;
  final String status;
  final bool isSandbox;
}

/// What is still owed for one session or term, as the school's fee ledger worked it out.
class OwedPeriod {
  const OwedPeriod({
    required this.label,
    required this.isPast,
    required this.isCurrent,
    required this.isClosed,
    required this.charges,
    required this.netMinor,
    required this.paidMinor,
    required this.outstandingMinor,
    required this.overdueMinor,
    required this.familiesOwing,
    required this.collectionRateBp,
  });

  factory OwedPeriod.fromJson(Map<String, dynamic> json) => OwedPeriod(
        label: json['label'] as String? ?? '',
        isPast: json['isPast'] == true,
        isCurrent: json['isCurrent'] == true,
        isClosed: json['isClosed'] == true,
        charges: json['charges'] as int? ?? 0,
        netMinor: json['netMinor'] as int? ?? 0,
        paidMinor: json['paidMinor'] as int? ?? 0,
        outstandingMinor: json['outstandingMinor'] as int? ?? 0,
        overdueMinor: json['overdueMinor'] as int? ?? 0,
        familiesOwing: json['familiesOwing'] as int? ?? 0,
        collectionRateBp: json['collectionRateBp'] as int?,
      );

  /// "2026/2027 · First Term" (or just the session, for a fee that covers all of it).
  final String label;

  /// The period has ended (or the school closed it), so what is left of it is arrears.
  final bool isPast;
  final bool isCurrent;
  final bool isClosed;
  final int charges;
  final int netMinor;
  final int paidMinor;
  final int outstandingMinor;
  final int overdueMinor;
  final int familiesOwing;

  /// Basis points of what was payable that has been paid (10000 = all of it); null when nothing was payable.
  final int? collectionRateBp;

  /// Whole percent collected, or null when nothing was payable.
  int? get collectedPercent => collectionRateBp == null ? null : (collectionRateBp! / 100).round();
}

/// What the school is owed, by session and term. Only real once the school has raised fees for its families:
/// until then [available] is false and there are no figures, not zeros.
class Owed {
  const Owed({
    required this.available,
    required this.outstandingMinor,
    required this.overdueMinor,
    required this.arrearsMinor,
    required this.currentMinor,
    required this.creditMinor,
    required this.familiesOwing,
    required this.periods,
  });

  factory Owed.fromJson(Map<String, dynamic> json) => Owed(
        available: json['available'] == true,
        outstandingMinor: json['outstandingMinor'] as int? ?? 0,
        overdueMinor: json['overdueMinor'] as int? ?? 0,
        arrearsMinor: json['arrearsMinor'] as int? ?? 0,
        currentMinor: json['currentMinor'] as int? ?? 0,
        creditMinor: json['creditMinor'] as int? ?? 0,
        familiesOwing: json['familiesOwing'] as int? ?? 0,
        periods: [for (final p in readMaps(json['periods'])) OwedPeriod.fromJson(p)],
      );

  static const none = Owed(
    available: false,
    outstandingMinor: 0,
    overdueMinor: 0,
    arrearsMinor: 0,
    currentMinor: 0,
    creditMinor: 0,
    familiesOwing: 0,
    periods: [],
  );

  final bool available;
  final int outstandingMinor;
  final int overdueMinor;

  /// Still owed for periods that have ended.
  final int arrearsMinor;

  /// Owed for the period that is running (or has not begun).
  final int currentMinor;

  /// Credit families hold, kept apart: it is not netted off what is owed.
  final int creditMinor;
  final int familiesOwing;
  final List<OwedPeriod> periods;
}

/// What the school has really collected, as the server worked it out. The app adds nothing to it:
/// where the server cannot know a number (what is still owed) it says so, and so does the screen.
class CollectionsSummary {
  const CollectionsSummary({
    required this.periodKey,
    required this.periodLabel,
    required this.available,
    required this.providers,
    required this.today,
    required this.thisWeek,
    required this.thisTerm,
    required this.selected,
    required this.byProvider,
    required this.reconciliation,
    required this.recent,
    required this.sandboxIncluded,
    required this.sandboxHidden,
    required this.otherCurrencyTransactions,
    required this.outstandingFeesAvailable,
    this.owed = Owed.none,
  });

  factory CollectionsSummary.fromJson(Map<String, dynamic> json) {
    final period = readMap(json['period']);
    return CollectionsSummary(
      periodKey: period['key'] as String? ?? 'all',
      periodLabel: period['label'] as String? ?? '',
      available: json['available'] == true,
      providers: ProvidersBrief.fromJson(readMap(json['providers'])),
      today: AmountTotal.fromJson(readMap(json['today'])),
      thisWeek: AmountTotal.fromJson(readMap(json['thisWeek'])),
      thisTerm: json['thisTerm'] is Map ? AmountTotal.fromJson(readMap(json['thisTerm'])) : null,
      selected: AmountTotal.fromJson(readMap(json['selected'])),
      byProvider: [for (final b in readMaps(json['byProvider'])) ProviderTotal.fromJson(b)],
      reconciliation: ReconciliationTotals.fromJson(readMap(json['reconciliation'])),
      recent: [for (final r in readMaps(json['recent'])) RecentPayment.fromJson(r)],
      sandboxIncluded: json['sandboxIncluded'] == true,
      sandboxHidden: json['sandboxHidden'] as int? ?? 0,
      otherCurrencyTransactions: json['otherCurrencyTransactions'] as int? ?? 0,
      outstandingFeesAvailable: json['outstandingFeesAvailable'] == true,
      owed: json['receivables'] is Map ? Owed.fromJson(readMap(json['receivables'])) : Owed.none,
    );
  }

  final String periodKey;
  final String periodLabel;

  /// False until a real collection provider is connected: the screen shows an honest empty state, not zeros.
  final bool available;
  final ProvidersBrief providers;
  final AmountTotal today;
  final AmountTotal thisWeek;

  /// Null when no academic term is open.
  final AmountTotal? thisTerm;
  final AmountTotal selected;
  final List<ProviderTotal> byProvider;
  final ReconciliationTotals reconciliation;
  final List<RecentPayment> recent;
  final bool sandboxIncluded;

  /// Test payments left out of every total above.
  final int sandboxHidden;
  final int otherCurrencyTransactions;

  /// False until the school has raised fees for its families: what is still owed cannot be worked out before that.
  final bool outstandingFeesAvailable;

  /// What the school is owed, by session and term (see [Owed.available]).
  final Owed owed;
}
