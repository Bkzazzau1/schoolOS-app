enum FinanceAgingBucket { zeroTo30, thirtyOneTo60, sixtyOneTo90, ninetyPlus }

extension FinanceAgingBucketX on FinanceAgingBucket {
  String get label => switch (this) {
        FinanceAgingBucket.zeroTo30 => '0–30 days',
        FinanceAgingBucket.thirtyOneTo60 => '31–60 days',
        FinanceAgingBucket.sixtyOneTo90 => '61–90 days',
        FinanceAgingBucket.ninetyPlus => '90+ days',
      };

  static FinanceAgingBucket fromLabel(String value) => switch (value) {
        '0–30 days' => FinanceAgingBucket.zeroTo30,
        '31–60 days' => FinanceAgingBucket.thirtyOneTo60,
        '61–90 days' => FinanceAgingBucket.sixtyOneTo90,
        '90+ days' => FinanceAgingBucket.ninetyPlus,
        _ => throw ArgumentError('Unknown aging bucket: $value'),
      };
}

enum FinanceReceivableStatus { scheduled, watch, structured, action, current }

extension FinanceReceivableStatusX on FinanceReceivableStatus {
  String get label => switch (this) {
        FinanceReceivableStatus.scheduled => 'Scheduled',
        FinanceReceivableStatus.watch => 'Watch',
        FinanceReceivableStatus.structured => 'Structured',
        FinanceReceivableStatus.action => 'Action',
        FinanceReceivableStatus.current => 'Current',
      };

  static FinanceReceivableStatus fromLabel(String value) => switch (value) {
        'Scheduled' => FinanceReceivableStatus.scheduled,
        'Watch' => FinanceReceivableStatus.watch,
        'Structured' => FinanceReceivableStatus.structured,
        'Action' => FinanceReceivableStatus.action,
        'Current' => FinanceReceivableStatus.current,
        _ => throw ArgumentError('Unknown receivable status: $value'),
      };
}

class FinanceFamilyReceivable {
  const FinanceFamilyReceivable({required this.family, required this.children, required this.balance, required this.age, required this.plan, required this.nextAction, required this.status});
  final String family;
  final String children;
  final int balance;
  final FinanceAgingBucket age;
  final String plan;
  final String nextAction;
  final FinanceReceivableStatus status;

  Map<String, Object?> toJson() => {'family': family, 'children': children, 'balance': balance, 'age': age.label, 'plan': plan, 'nextAction': nextAction, 'status': status.label};

  factory FinanceFamilyReceivable.fromJson(Map<String, Object?> json) => FinanceFamilyReceivable(
        family: json['family']! as String,
        children: json['children']! as String,
        balance: json['balance']! as int,
        age: FinanceAgingBucketX.fromLabel(json['age']! as String),
        plan: json['plan']! as String,
        nextAction: json['nextAction']! as String,
        status: FinanceReceivableStatusX.fromLabel(json['status']! as String),
      );
}

class FinanceAgingSummary {
  const FinanceAgingSummary({required this.bucket, required this.amount, required this.progressPercent, required this.hint});
  final FinanceAgingBucket bucket;
  final int amount;
  final int progressPercent;
  final String hint;
}

class FinanceArrangementSummary {
  const FinanceArrangementSummary({required this.label, required this.amount, required this.description, required this.guidance});
  final String label;
  final int amount;
  final String description;
  final String guidance;
}

String financeAgingMoney(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '₦$buffer';
}

List<FinanceFamilyReceivable> financeFilterReceivables(List<FinanceFamilyReceivable> rows, String bucket) {
  if (bucket == 'All') return List<FinanceFamilyReceivable>.from(rows);
  return rows.where((row) => row.age.label == bucket).toList();
}
