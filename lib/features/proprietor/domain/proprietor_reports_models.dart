class OwnerReportKpi {
  const OwnerReportKpi({
    required this.label,
    required this.value,
    required this.note,
  });

  final String label;
  final String value;
  final String note;
}

class OwnerExecutiveReport {
  const OwnerExecutiveReport({
    required this.title,
    required this.coverage,
    required this.updated,
    required this.status,
  });

  final String title;
  final String coverage;
  final String updated;
  final String status;
}

class OwnerReportPackSection {
  const OwnerReportPackSection({
    required this.number,
    required this.title,
    required this.description,
  });

  final int number;
  final String title;
  final String description;
}

class OwnerReportCadence {
  const OwnerReportCadence({
    required this.frequency,
    required this.reportType,
    required this.purpose,
  });

  final String frequency;
  final String reportType;
  final String purpose;
}
