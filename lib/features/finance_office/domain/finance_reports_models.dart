class FinanceReportDefinition {
  const FinanceReportDefinition({
    required this.title,
    required this.period,
    required this.detail,
  });

  final String title;
  final String period;
  final String detail;

  Map<String, Object?> toJson() => {
        'title': title,
        'period': period,
        'detail': detail,
      };

  factory FinanceReportDefinition.fromJson(Map<String, Object?> json) =>
      FinanceReportDefinition(
        title: json['title'] as String,
        period: json['period'] as String,
        detail: json['detail'] as String,
      );
}

class FinanceReportKpi {
  const FinanceReportKpi({
    required this.label,
    required this.value,
    required this.hint,
  });

  final String label;
  final String value;
  final String hint;
}

class FinanceManagementSnapshot {
  const FinanceManagementSnapshot({
    required this.section,
    required this.collectionRate,
    required this.status,
  });

  final String section;
  final int collectionRate;
  final String status;

  Map<String, Object?> toJson() => {
        'section': section,
        'collectionRate': collectionRate,
        'status': status,
      };

  factory FinanceManagementSnapshot.fromJson(Map<String, Object?> json) =>
      FinanceManagementSnapshot(
        section: json['section'] as String,
        collectionRate: json['collectionRate'] as int,
        status: json['status'] as String,
      );
}
