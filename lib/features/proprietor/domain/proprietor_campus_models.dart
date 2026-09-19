class OwnerCampusKpi {
  const OwnerCampusKpi({
    required this.label,
    required this.value,
    required this.note,
  });

  final String label;
  final String value;
  final String note;
}

enum CampusStatus { active, planned }

class OwnerCampusSummary {
  const OwnerCampusSummary({
    required this.name,
    required this.status,
    required this.students,
    required this.staff,
    required this.attendancePercent,
    required this.feeCollectionPercent,
    required this.academicPercent,
    required this.leader,
    required this.description,
    required this.readinessNote,
  });

  final String name;
  final CampusStatus status;
  final int students;
  final int staff;
  final int attendancePercent;
  final int feeCollectionPercent;
  final int academicPercent;
  final String leader;
  final String description;
  final String readinessNote;

  bool get isActive => status == CampusStatus.active;

  String get statusLabel => switch (status) {
        CampusStatus.active => 'Active',
        CampusStatus.planned => 'Planned',
      };
}

class OwnerCampusChecklistItem {
  const OwnerCampusChecklistItem({
    required this.title,
    required this.detail,
  });

  final String title;
  final String detail;
}
