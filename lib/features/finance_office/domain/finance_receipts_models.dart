class FinanceReceipt {
  const FinanceReceipt({
    required this.number,
    required this.student,
    required this.className,
    required this.admissionNumber,
    required this.amount,
    required this.date,
    required this.method,
    required this.transactionReference,
    required this.previousBalance,
    required this.newBalance,
    required this.status,
  });

  final String number;
  final String student;
  final String className;
  final String admissionNumber;
  final int amount;
  final String date;
  final String method;
  final String transactionReference;
  final int previousBalance;
  final int newBalance;
  final FinanceReceiptStatus status;

  bool get balancesReconcile => previousBalance - amount == newBalance;

  Map<String, Object?> toJson() => {
        'number': number,
        'student': student,
        'className': className,
        'admissionNumber': admissionNumber,
        'amount': amount,
        'date': date,
        'method': method,
        'transactionReference': transactionReference,
        'previousBalance': previousBalance,
        'newBalance': newBalance,
        'status': status.name,
      };

  factory FinanceReceipt.fromJson(Map<String, Object?> json) => FinanceReceipt(
        number: json['number'] as String,
        student: json['student'] as String,
        className: json['className'] as String,
        admissionNumber: json['admissionNumber'] as String,
        amount: json['amount'] as int,
        date: json['date'] as String,
        method: json['method'] as String,
        transactionReference: json['transactionReference'] as String,
        previousBalance: json['previousBalance'] as int,
        newBalance: json['newBalance'] as int,
        status: FinanceReceiptStatus.values.firstWhere(
          (value) => value.name == json['status'],
        ),
      );
}

enum FinanceReceiptStatus { confirmed }

extension FinanceReceiptStatusLabel on FinanceReceiptStatus {
  String get label => switch (this) {
        FinanceReceiptStatus.confirmed => 'Confirmed',
      };
}

String financeReceiptMoney(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '₦$buffer';
}
