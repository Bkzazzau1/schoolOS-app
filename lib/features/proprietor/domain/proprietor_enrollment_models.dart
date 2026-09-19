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

class OwnerEnrollmentPipelineRow {
  const OwnerEnrollmentPipelineRow({
    required this.section,
    required this.applications,
    required this.offers,
    required this.accepted,
    required this.activeStudents,
    required this.retentionPercent,
  });

  final String section;
  final int applications;
  final int offers;
  final int accepted;
  final int activeStudents;
  final int retentionPercent;

  double get offerRate => applications == 0 ? 0 : offers / applications;
  double get acceptanceRate => offers == 0 ? 0 : accepted / offers;
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

class OwnerEnrollmentSnapshot {
  const OwnerEnrollmentSnapshot({
    required this.kpis,
    required this.pipeline,
    required this.capacityWatch,
    required this.trend,
  });

  final List<OwnerEnrollmentKpi> kpis;
  final List<OwnerEnrollmentPipelineRow> pipeline;
  final List<OwnerCapacityWatchItem> capacityWatch;
  final List<int> trend;

  int get totalApplications =>
      pipeline.fold(0, (sum, row) => sum + row.applications);

  int get totalOffers => pipeline.fold(0, (sum, row) => sum + row.offers);

  int get totalAccepted =>
      pipeline.fold(0, (sum, row) => sum + row.accepted);

  int get activeStudents =>
      pipeline.fold(0, (sum, row) => sum + row.activeStudents);
}
