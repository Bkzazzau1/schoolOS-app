class AdministratorOperationTask {
  const AdministratorOperationTask({
    required this.title,
    required this.count,
    required this.note,
  });

  final String title;
  final String count;
  final String note;

  Map<String, dynamic> toJson() => {
        'title': title,
        'count': count,
        'note': note,
      };

  factory AdministratorOperationTask.fromJson(Map<String, dynamic> json) {
    return AdministratorOperationTask(
      title: json['title'] as String? ?? '',
      count: json['count'] as String? ?? '',
      note: json['note'] as String? ?? '',
    );
  }
}

class AdministratorOperationBoundary {
  const AdministratorOperationBoundary({
    required this.title,
    required this.detail,
  });

  final String title;
  final String detail;
}

class AdministratorOperationsPermissions {
  const AdministratorOperationsPermissions({required this.canView});

  final bool canView;
}
