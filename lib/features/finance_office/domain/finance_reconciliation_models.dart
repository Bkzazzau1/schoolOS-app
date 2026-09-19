enum FinanceReconciliationStatus { matched, review }

class FinanceReconciliationRow {
  const FinanceReconciliationRow({
    required this.reference,
    required this.sender,
    required this.amount,
    required this.channel,
    required this.matchLabel,
    required this.status,
    this.familyAccountId,
    this.familyAccountNumber,
    this.childLedgerId,
  });

  final String reference;
  final String sender;
  final int amount;
  final String channel;
  final String matchLabel;
  final FinanceReconciliationStatus status;
  final String? familyAccountId;
  final String? familyAccountNumber;
  final String? childLedgerId;

  bool get isMatched => status == FinanceReconciliationStatus.matched;
  bool get needsReview => status == FinanceReconciliationStatus.review;
  bool get hasFamilyAllocation => familyAccountNumber != null && childLedgerId != null;

  Map<String, Object?> toJson() => {
        'reference': reference,
        'sender': sender,
        'amount': amount,
        'channel': channel,
        'matchLabel': matchLabel,
        'status': status.name,
        'familyAccountId': familyAccountId,
        'familyAccountNumber': familyAccountNumber,
        'childLedgerId': childLedgerId,
      };

  factory FinanceReconciliationRow.fromJson(Map<String, Object?> json) =>
      FinanceReconciliationRow(
        reference: json['reference'] as String,
        sender: json['sender'] as String,
        amount: json['amount'] as int,
        channel: json['channel'] as String,
        matchLabel: json['matchLabel'] as String,
        status: FinanceReconciliationStatus.values.byName(json['status'] as String),
        familyAccountId: json['familyAccountId'] as String?,
        familyAccountNumber: json['familyAccountNumber'] as String?,
        childLedgerId: json['childLedgerId'] as String?,
      );
}

class FinanceReconciliationKpi {
  const FinanceReconciliationKpi({
    required this.label,
    required this.value,
    required this.hint,
  });

  final String label;
  final String value;
  final String hint;
}

String financeReconciliationStatusLabel(FinanceReconciliationStatus status) => switch (status) {
      FinanceReconciliationStatus.matched => 'Matched',
      FinanceReconciliationStatus.review => 'Review',
    };

String financeReconciliationMoney(int amount) {
  final raw = amount.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) buffer.write(',');
    buffer.write(raw[i]);
  }
  return '₦$buffer';
}
