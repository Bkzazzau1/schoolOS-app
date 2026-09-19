class FinanceFeeSection {
  const FinanceFeeSection({
    required this.section,
    required this.students,
    required this.tuition,
    required this.development,
    required this.activities,
    required this.technology,
    required this.total,
  });

  final String section;
  final int students;
  final int tuition;
  final int development;
  final int activities;
  final int technology;
  final int total;
}

class FinanceOptionalCharge {
  const FinanceOptionalCharge({
    required this.charge,
    required this.amount,
    required this.mode,
    required this.rule,
  });

  final String charge;
  final String amount;
  final String mode;
  final String rule;
}

class FinanceBillingStep {
  const FinanceBillingStep({
    required this.number,
    required this.title,
    required this.detail,
  });

  final int number;
  final String title;
  final String detail;
}
