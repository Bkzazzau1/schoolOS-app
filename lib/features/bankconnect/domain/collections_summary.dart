import 'json_read.dart';

class AmountTotal {
  const AmountTotal({required this.amountMinor, required this.count});

  factory AmountTotal.fromJson(Map<String, dynamic> json) =>
      AmountTotal(amountMinor: json['amountMinor'] as int? ?? 0, count: json['count'] as int? ?? 0);

  final int amountMinor;
  final int count;
}

class PurposeTotal {
  const PurposeTotal({required this.purpose, required this.amountMinor, required this.count});

  factory PurposeTotal.fromJson(Map<String, dynamic> json) => PurposeTotal(
        purpose: json['purpose'] as String? ?? '',
        amountMinor: json['amountMinor'] as int? ?? 0,
        count: json['count'] as int? ?? 0,
      );

  final String purpose;
  final int amountMinor;
  final int count;
}

class BankTotal {
  const BankTotal({
    required this.connectionId,
    required this.bankName,
    required this.accountMask,
    required this.label,
    required this.amountMinor,
    required this.count,
  });

  factory BankTotal.fromJson(Map<String, dynamic> json) => BankTotal(
        connectionId: json['connectionId'] as String? ?? '',
        bankName: json['bankName'] as String? ?? '',
        accountMask: json['accountMask'] as String? ?? '',
        label: json['label'] as String? ?? '',
        amountMinor: json['amountMinor'] as int? ?? 0,
        count: json['count'] as int? ?? 0,
      );

  final String connectionId;
  final String bankName;
  final String accountMask;
  final String label;
  final int amountMinor;
  final int count;
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

class AccountsInfo {
  const AccountsInfo({required this.connected, required this.needAttention, required this.lastSyncedAt});

  factory AccountsInfo.fromJson(Map<String, dynamic> json) => AccountsInfo(
        connected: json['connected'] as int? ?? 0,
        needAttention: json['needAttention'] as int? ?? 0,
        lastSyncedAt: readTime(json['lastSyncedAt']),
      );

  final int connected;
  final int needAttention;
  final DateTime? lastSyncedAt;
}

class RecentPayment {
  const RecentPayment({
    required this.id,
    required this.senderName,
    required this.amountMinor,
    required this.currency,
    required this.transactionDate,
    required this.bankName,
    required this.status,
    required this.isSandbox,
  });

  factory RecentPayment.fromJson(Map<String, dynamic> json) => RecentPayment(
        id: json['id'] as String,
        senderName: json['senderName'] as String? ?? '',
        amountMinor: json['amountMinor'] as int? ?? 0,
        currency: json['currency'] as String? ?? 'NGN',
        transactionDate: readTime(json['transactionDate']),
        bankName: json['bankName'] as String? ?? '',
        status: json['reconciliationStatus'] as String? ?? '',
        isSandbox: json['isSandbox'] == true,
      );

  final String id;
  final String senderName;
  final int amountMinor;
  final String currency;
  final DateTime? transactionDate;
  final String bankName;
  final String status;
  final bool isSandbox;
}

/// What the school has really collected, as the server worked it out. The app adds nothing to it:
/// where the server cannot know a number (what is still owed) it says so, and so does the screen.
class CollectionsSummary {
  const CollectionsSummary({
    required this.periodKey,
    required this.periodLabel,
    required this.available,
    required this.accounts,
    required this.today,
    required this.thisWeek,
    required this.thisTerm,
    required this.selected,
    required this.byPurpose,
    required this.byBank,
    required this.reconciliation,
    required this.recent,
    required this.sandboxIncluded,
    required this.sandboxHidden,
    required this.otherCurrencyTransactions,
    required this.outstandingFeesAvailable,
  });

  factory CollectionsSummary.fromJson(Map<String, dynamic> json) {
    final period = readMap(json['period']);
    return CollectionsSummary(
      periodKey: period['key'] as String? ?? 'all',
      periodLabel: period['label'] as String? ?? '',
      available: json['available'] == true,
      accounts: AccountsInfo.fromJson(readMap(json['accounts'])),
      today: AmountTotal.fromJson(readMap(json['today'])),
      thisWeek: AmountTotal.fromJson(readMap(json['thisWeek'])),
      thisTerm: json['thisTerm'] is Map ? AmountTotal.fromJson(readMap(json['thisTerm'])) : null,
      selected: AmountTotal.fromJson(readMap(json['selected'])),
      byPurpose: [for (final p in readMaps(json['byPurpose'])) PurposeTotal.fromJson(p)],
      byBank: [for (final b in readMaps(json['byBank'])) BankTotal.fromJson(b)],
      reconciliation: ReconciliationTotals.fromJson(readMap(json['reconciliation'])),
      recent: [for (final r in readMaps(json['recent'])) RecentPayment.fromJson(r)],
      sandboxIncluded: json['sandboxIncluded'] == true,
      sandboxHidden: json['sandboxHidden'] as int? ?? 0,
      otherCurrencyTransactions: json['otherCurrencyTransactions'] as int? ?? 0,
      outstandingFeesAvailable: json['outstandingFeesAvailable'] == true,
    );
  }

  final String periodKey;
  final String periodLabel;

  /// False until a real bank account is connected: the screen shows an honest empty state, not zeros.
  final bool available;
  final AccountsInfo accounts;
  final AmountTotal today;
  final AmountTotal thisWeek;

  /// Null when no academic term is open.
  final AmountTotal? thisTerm;
  final AmountTotal selected;
  final List<PurposeTotal> byPurpose;
  final List<BankTotal> byBank;
  final ReconciliationTotals reconciliation;
  final List<RecentPayment> recent;
  final bool sandboxIncluded;

  /// Test payments left out of every total above.
  final int sandboxHidden;
  final int otherCurrencyTransactions;

  /// Always false until the server has a fee ledger: what is still owed cannot be worked out.
  final bool outstandingFeesAvailable;
}
