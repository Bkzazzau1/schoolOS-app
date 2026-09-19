enum FinanceMandateStatus { active, pendingConsent }

enum FinanceMandateAttempt { successful, failed, notStarted }

extension FinanceMandateStatusLabel on FinanceMandateStatus {
  String get label => switch (this) {
        FinanceMandateStatus.active => 'Active',
        FinanceMandateStatus.pendingConsent => 'Pending consent',
      };
}

extension FinanceMandateAttemptLabel on FinanceMandateAttempt {
  String get label => switch (this) {
        FinanceMandateAttempt.successful => 'Successful',
        FinanceMandateAttempt.failed => 'Failed',
        FinanceMandateAttempt.notStarted => 'Not started',
      };
}

class FinanceMandate {
  const FinanceMandate({
    required this.id,
    required this.guardian,
    required this.children,
    required this.method,
    required this.provider,
    required this.amount,
    required this.day,
    required this.nextAttempt,
    required this.status,
    required this.latestAttempt,
  });

  final String id;
  final String guardian;
  final String children;
  final String method;
  final String provider;
  final int amount;
  final String day;
  final String nextAttempt;
  final FinanceMandateStatus status;
  final FinanceMandateAttempt latestAttempt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'guardian': guardian,
        'children': children,
        'method': method,
        'provider': provider,
        'amount': amount,
        'day': day,
        'nextAttempt': nextAttempt,
        'status': status.name,
        'latestAttempt': latestAttempt.name,
      };

  factory FinanceMandate.fromJson(Map<String, dynamic> json) => FinanceMandate(
        id: json['id'] as String,
        guardian: json['guardian'] as String,
        children: json['children'] as String,
        method: json['method'] as String,
        provider: json['provider'] as String,
        amount: json['amount'] as int,
        day: json['day'] as String,
        nextAttempt: json['nextAttempt'] as String,
        status: FinanceMandateStatus.values.byName(json['status'] as String),
        latestAttempt:
            FinanceMandateAttempt.values.byName(json['latestAttempt'] as String),
      );
}

class FinanceMandateWorkflowStep {
  const FinanceMandateWorkflowStep(this.title, this.detail);

  final String title;
  final String detail;
}

String financeMandateMoney(int value) {
  final digits = value.toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return '₦$out';
}
