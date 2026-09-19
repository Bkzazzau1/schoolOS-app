enum FinanceReminderStatus { scheduled, sent, skipped, needsReview }

extension FinanceReminderStatusLabel on FinanceReminderStatus {
  String get label => switch (this) {
        FinanceReminderStatus.scheduled => 'Scheduled',
        FinanceReminderStatus.sent => 'Sent',
        FinanceReminderStatus.skipped => 'Skipped',
        FinanceReminderStatus.needsReview => 'Needs review',
      };

  static FinanceReminderStatus fromLabel(String value) => switch (value) {
        'Scheduled' => FinanceReminderStatus.scheduled,
        'Sent' => FinanceReminderStatus.sent,
        'Skipped' => FinanceReminderStatus.skipped,
        'Needs review' => FinanceReminderStatus.needsReview,
        _ => throw ArgumentError('Unknown reminder status: $value'),
      };
}

class FinanceReminderRow {
  const FinanceReminderRow({
    required this.id,
    required this.student,
    required this.guardian,
    required this.className,
    required this.balance,
    required this.arrangement,
    required this.nextAmount,
    required this.nextDate,
    required this.channels,
    required this.status,
    required this.reason,
  });

  final String id;
  final String student;
  final String guardian;
  final String className;
  final int balance;
  final String arrangement;
  final int nextAmount;
  final String nextDate;
  final String channels;
  final FinanceReminderStatus status;
  final String reason;

  FinanceReminderRow copyWith({FinanceReminderStatus? status}) => FinanceReminderRow(
        id: id,
        student: student,
        guardian: guardian,
        className: className,
        balance: balance,
        arrangement: arrangement,
        nextAmount: nextAmount,
        nextDate: nextDate,
        channels: channels,
        status: status ?? this.status,
        reason: reason,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'student': student,
        'guardian': guardian,
        'className': className,
        'balance': balance,
        'arrangement': arrangement,
        'nextAmount': nextAmount,
        'nextDate': nextDate,
        'channels': channels,
        'status': status.label,
        'reason': reason,
      };

  factory FinanceReminderRow.fromJson(Map<String, Object?> json) => FinanceReminderRow(
        id: json['id'] as String,
        student: json['student'] as String,
        guardian: json['guardian'] as String,
        className: json['className'] as String,
        balance: json['balance'] as int,
        arrangement: json['arrangement'] as String,
        nextAmount: json['nextAmount'] as int,
        nextDate: json['nextDate'] as String,
        channels: json['channels'] as String,
        status: FinanceReminderStatusLabel.fromLabel(json['status'] as String),
        reason: json['reason'] as String,
      );
}

class FinanceReminderStage {
  const FinanceReminderStage(this.when, this.message);
  final String when;
  final String message;
}

class FinanceSuppressionRule {
  const FinanceSuppressionRule({
    required this.title,
    required this.detail,
    required this.hint,
  });
  final String title;
  final String detail;
  final String hint;
}

class FinanceReminderHistoryEntry {
  const FinanceReminderHistoryEntry({
    required this.when,
    required this.recipient,
    required this.summary,
    required this.status,
  });
  final String when;
  final String recipient;
  final String summary;
  final String status;
}

String financeReminderMoney(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) buffer.write(',');
    buffer.write(raw[i]);
  }
  return '₦$buffer';
}

String financeReminderPreview(FinanceReminderRow row) {
  if (row.arrangement == 'Active mandate') {
    return 'A payment of ${financeReminderMoney(row.nextAmount)} for ${row.student} is scheduled for ${row.nextDate}. Current school-fee balance is ${financeReminderMoney(row.balance)}. No action is needed if your authorized deduction proceeds successfully.';
  }
  if (row.arrangement == 'No arrangement') {
    return '${row.student} has an outstanding school-fee balance of ${financeReminderMoney(row.balance)}. Please use the student term account or contact the Finance Office to arrange a payment plan.';
  }
  final amount = row.nextAmount > 0 ? financeReminderMoney(row.nextAmount) : 'your agreed amount';
  return 'A school-fee payment of $amount for ${row.student} is expected on ${row.nextDate}. Current outstanding balance is ${financeReminderMoney(row.balance)}.';
}
