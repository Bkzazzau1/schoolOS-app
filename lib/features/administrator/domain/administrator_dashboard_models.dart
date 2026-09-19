class AdministratorKpi {
  const AdministratorKpi({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;
}

class AdministratorQueueItem {
  const AdministratorQueueItem({
    required this.title,
    required this.detail,
    required this.area,
  });

  final String title;
  final String detail;
  final String area;
}

class AdministratorDeskActivity {
  const AdministratorDeskActivity({
    required this.title,
    required this.detail,
  });

  final String title;
  final String detail;
}

class AdministratorQuickAction {
  const AdministratorQuickAction({
    required this.key,
    required this.title,
    required this.description,
  });

  final String key;
  final String title;
  final String description;
}

class AdministratorNavItem {
  const AdministratorNavItem({required this.key, required this.label});

  final String key;
  final String label;
}
