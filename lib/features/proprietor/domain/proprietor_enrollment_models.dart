class OwnerEnrollmentKpi {
  const OwnerEnrollmentKpi({
    required this.label,
    required this.value,
    required this.note,
  });

  final String label;
  final String value;
  final String note;
}

class OwnerCapacityWatchItem {
  const OwnerCapacityWatchItem({
    required this.title,
    required this.detail,
    required this.action,
  });

  final String title;
  final String detail;
  final String action;
}
