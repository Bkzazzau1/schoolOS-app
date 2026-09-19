enum FinanceFamilyAccountStatus { active, review }

class FinanceChildFeeLedger {
  const FinanceChildFeeLedger({
    required this.id,
    required this.student,
    required this.className,
    required this.billed,
    required this.paid,
  });

  final String id;
  final String student;
  final String className;
  final int billed;
  final int paid;

  int get balance => billed - paid;

  Map<String, Object?> toJson() => {
        'id': id,
        'student': student,
        'className': className,
        'billed': billed,
        'paid': paid,
      };

  factory FinanceChildFeeLedger.fromJson(Map<String, Object?> json) => FinanceChildFeeLedger(
        id: json['id'] as String,
        student: json['student'] as String,
        className: json['className'] as String,
        billed: json['billed'] as int,
        paid: json['paid'] as int,
      );
}

class FinanceFamilyAccount {
  const FinanceFamilyAccount({
    required this.id,
    required this.guardian,
    required this.accountNumber,
    required this.provider,
    required this.children,
    required this.status,
  });

  final String id;
  final String guardian;
  final String accountNumber;
  final String provider;
  final List<FinanceChildFeeLedger> children;
  final FinanceFamilyAccountStatus status;

  int get childCount => children.length;
  int get billed => children.fold<int>(0, (sum, child) => sum + child.billed);
  int get paid => children.fold<int>(0, (sum, child) => sum + child.paid);
  int get balance => children.fold<int>(0, (sum, child) => sum + child.balance);

  Map<String, Object?> toJson() => {
        'id': id,
        'guardian': guardian,
        'accountNumber': accountNumber,
        'provider': provider,
        'children': children.map((child) => child.toJson()).toList(),
        'status': status.name,
      };

  factory FinanceFamilyAccount.fromJson(Map<String, Object?> json) => FinanceFamilyAccount(
        id: json['id'] as String,
        guardian: json['guardian'] as String,
        accountNumber: json['accountNumber'] as String,
        provider: json['provider'] as String,
        children: (json['children'] as List<Object?>)
            .cast<Map<String, Object?>>()
            .map(FinanceChildFeeLedger.fromJson)
            .toList(growable: false),
        status: FinanceFamilyAccountStatus.values.byName(json['status'] as String),
      );
}

String financeFamilyAccountStatusLabel(FinanceFamilyAccountStatus status) => switch (status) {
      FinanceFamilyAccountStatus.active => 'Active',
      FinanceFamilyAccountStatus.review => 'Review',
    };

String financeFamilyMoney(int amount) {
  final raw = amount.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) buffer.write(',');
    buffer.write(raw[i]);
  }
  return '₦$buffer';
}
