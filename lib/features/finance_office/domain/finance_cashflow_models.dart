enum FinanceCashflowType { income, expense }

enum FinanceCashflowStatus { posted, approved }

class FinanceCashflowEntry {
  const FinanceCashflowEntry({
    required this.date,
    required this.description,
    required this.type,
    required this.category,
    required this.amount,
    required this.status,
  });

  final String date;
  final String description;
  final FinanceCashflowType type;
  final String category;
  final int amount;
  final FinanceCashflowStatus status;

  bool get isIncome => type == FinanceCashflowType.income;
  bool get isExpense => type == FinanceCashflowType.expense;
  bool get isPostedIncome => isIncome && status == FinanceCashflowStatus.posted;
  bool get isApprovedExpense => isExpense && status == FinanceCashflowStatus.approved;

  Map<String, Object?> toJson() => {
        'date': date,
        'description': description,
        'type': type.name,
        'category': category,
        'amount': amount,
        'status': status.name,
      };

  factory FinanceCashflowEntry.fromJson(Map<String, Object?> json) =>
      FinanceCashflowEntry(
        date: json['date'] as String,
        description: json['description'] as String,
        type: FinanceCashflowType.values.byName(json['type'] as String),
        category: json['category'] as String,
        amount: json['amount'] as int,
        status: FinanceCashflowStatus.values.byName(json['status'] as String),
      );
}

class FinanceCashflowKpi {
  const FinanceCashflowKpi({
    required this.label,
    required this.value,
    required this.hint,
  });

  final String label;
  final String value;
  final String hint;
}

class FinanceExpenseControl {
  const FinanceExpenseControl({required this.title, required this.detail});

  final String title;
  final String detail;
}

String financeCashflowTypeLabel(FinanceCashflowType type) => switch (type) {
      FinanceCashflowType.income => 'Income',
      FinanceCashflowType.expense => 'Expense',
    };

String financeCashflowStatusLabel(FinanceCashflowStatus status) => switch (status) {
      FinanceCashflowStatus.posted => 'Posted',
      FinanceCashflowStatus.approved => 'Approved',
    };

String financeCashflowMoney(int amount) {
  final raw = amount.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) buffer.write(',');
    buffer.write(raw[i]);
  }
  return '₦$buffer';
}
