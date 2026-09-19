class OwnerStaffKpi {
  const OwnerStaffKpi({
    required this.label,
    required this.value,
    required this.note,
  });

  final String label;
  final String value;
  final String note;
}

class OwnerLeaderRow {
  const OwnerLeaderRow({
    required this.name,
    required this.role,
    required this.scope,
    required this.team,
    required this.signal,
  });

  final String name;
  final String role;
  final String scope;
  final String team;
  final String signal;

  bool get needsReview => signal.toLowerCase() == 'review';
}

class OwnerPeopleAttentionItem {
  const OwnerPeopleAttentionItem({
    required this.title,
    required this.detail,
    required this.owner,
  });

  final String title;
  final String detail;
  final String owner;
}

class OwnerStaffMixItem {
  const OwnerStaffMixItem({
    required this.section,
    required this.count,
    required this.note,
  });

  final String section;
  final int count;
  final String note;
}
