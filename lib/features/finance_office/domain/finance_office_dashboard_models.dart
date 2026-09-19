class FinanceOfficeNavItem {
  const FinanceOfficeNavItem({required this.key, required this.label});

  final String key;
  final String label;
}

class FinanceKpi {
  const FinanceKpi({
    required this.label,
    required this.value,
    required this.hint,
  });

  final String label;
  final String value;
  final String hint;
}

class FinanceCollectionActivity {
  const FinanceCollectionActivity({
    required this.reference,
    required this.account,
    required this.channel,
    required this.amount,
    required this.status,
  });

  final String reference;
  final String account;
  final String channel;
  final String amount;
  final String status;
}

class FinanceAttentionItem {
  const FinanceAttentionItem({
    required this.title,
    required this.detail,
    this.caption,
  });

  final String title;
  final String detail;
  final String? caption;
}

class FinanceTrendPoint {
  const FinanceTrendPoint({required this.week, required this.rate});

  final String week;
  final int rate;
}

class FinanceOfficePermissions {
  const FinanceOfficePermissions({
    required this.canAccessFeeData,
    required this.canAccessTransactions,
    required this.canProcessApprovedPayroll,
    required this.canAccessAcademicGrades,
    required this.canAccessPrivateTeacherNotes,
    required this.canAccessSafeguardingRecords,
  });

  final bool canAccessFeeData;
  final bool canAccessTransactions;
  final bool canProcessApprovedPayroll;
  final bool canAccessAcademicGrades;
  final bool canAccessPrivateTeacherNotes;
  final bool canAccessSafeguardingRecords;
}
