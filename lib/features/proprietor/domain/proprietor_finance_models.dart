class OwnerFinanceKpi {
  const OwnerFinanceKpi({
    required this.label,
    required this.value,
    required this.note,
  });

  final String label;
  final String value;
  final String note;
}

class OwnerFinanceSectionRow {
  const OwnerFinanceSectionRow({
    required this.section,
    required this.grossFees,
    required this.concessions,
    required this.netCollectible,
    required this.collected,
    required this.rate,
  });

  final String section;
  final String grossFees;
  final String concessions;
  final String netCollectible;
  final String collected;
  final int rate;
}

class OwnerFinanceListItem {
  const OwnerFinanceListItem({
    required this.title,
    required this.detail,
    required this.note,
    this.isWarning = false,
  });

  final String title;
  final String detail;
  final String note;
  final bool isWarning;
}

class OwnerFinanceAgingRow {
  const OwnerFinanceAgingRow({
    required this.band,
    required this.amount,
    required this.status,
  });

  final String band;
  final String amount;
  final String status;
}

class OwnerFinanceQuickAction {
  const OwnerFinanceQuickAction({
    required this.key,
    required this.title,
    required this.description,
  });

  final String key;
  final String title;
  final String description;
}
