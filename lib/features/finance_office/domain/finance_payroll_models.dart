enum FinancePayrollStatus { ready, attendanceReview }

class FinancePayrollRow {
  const FinancePayrollRow({
    required this.staffId,
    required this.name,
    required this.expectedDays,
    required this.presentDays,
    required this.leaveDays,
    required this.unexplainedDays,
    required this.gross,
    required this.deductions,
    required this.net,
    required this.status,
  });

  final String staffId;
  final String name;
  final int expectedDays;
  final int presentDays;
  final int leaveDays;
  final int unexplainedDays;
  final int gross;
  final int deductions;
  final int net;
  final FinancePayrollStatus status;

  bool get isReady => status == FinancePayrollStatus.ready;
  bool get needsAttendanceReview =>
      status == FinancePayrollStatus.attendanceReview;
  bool get arithmeticReconciles => gross - deductions == net;

  Map<String, Object?> toJson() => {
        'staffId': staffId,
        'name': name,
        'expectedDays': expectedDays,
        'presentDays': presentDays,
        'leaveDays': leaveDays,
        'unexplainedDays': unexplainedDays,
        'gross': gross,
        'deductions': deductions,
        'net': net,
        'status': status.name,
      };

  factory FinancePayrollRow.fromJson(Map<String, Object?> json) =>
      FinancePayrollRow(
        staffId: json['staffId'] as String,
        name: json['name'] as String,
        expectedDays: json['expectedDays'] as int,
        presentDays: json['presentDays'] as int,
        leaveDays: json['leaveDays'] as int,
        unexplainedDays: json['unexplainedDays'] as int,
        gross: json['gross'] as int,
        deductions: json['deductions'] as int,
        net: json['net'] as int,
        status: FinancePayrollStatus.values.byName(json['status'] as String),
      );
}

class FinancePayrollKpi {
  const FinancePayrollKpi(this.label, this.value, this.hint);

  final String label;
  final String value;
  final String hint;
}

String financePayrollStatusLabel(FinancePayrollStatus status) => switch (status) {
      FinancePayrollStatus.ready => 'Ready',
      FinancePayrollStatus.attendanceReview => 'Attendance review',
    };

String financePayrollMoney(int amount) {
  final raw = amount.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) buffer.write(',');
    buffer.write(raw[i]);
  }
  return '₦$buffer';
}
