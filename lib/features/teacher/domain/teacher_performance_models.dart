enum TeacherPerformancePeriod {
  thisTerm,
  last30Days,
  previousTerm,
}

extension TeacherPerformancePeriodLabel on TeacherPerformancePeriod {
  String get label => switch (this) {
        TeacherPerformancePeriod.thisTerm => 'This term',
        TeacherPerformancePeriod.last30Days => 'Last 30 days',
        TeacherPerformancePeriod.previousTerm => 'Previous term',
      };
}

class TeacherPerformanceMetric {
  const TeacherPerformanceMetric({
    required this.label,
    required this.value,
    required this.target,
    required this.note,
  });

  final String label;
  final int value;
  final int target;
  final String note;

  bool get isAtOrAboveTarget => value >= target;

  Map<String, Object?> toJson() => {
        'label': label,
        'value': value,
        'target': target,
        'note': note,
      };

  factory TeacherPerformanceMetric.fromJson(Map<String, Object?> json) =>
      TeacherPerformanceMetric(
        label: json['label'] as String,
        value: json['value'] as int,
        target: json['target'] as int,
        note: json['note'] as String,
      );
}

class TeacherClassPerformance {
  const TeacherClassPerformance({
    required this.name,
    required this.average,
    required this.change,
    required this.attendance,
    required this.syllabusPace,
  });

  final String name;
  final int average;
  final String change;
  final int attendance;
  final int syllabusPace;

  bool get isImproving => change.startsWith('+');

  Map<String, Object?> toJson() => {
        'name': name,
        'average': average,
        'change': change,
        'attendance': attendance,
        'syllabusPace': syllabusPace,
      };

  factory TeacherClassPerformance.fromJson(Map<String, Object?> json) =>
      TeacherClassPerformance(
        name: json['name'] as String,
        average: json['average'] as int,
        change: json['change'] as String,
        attendance: json['attendance'] as int,
        syllabusPace: json['syllabusPace'] as int,
      );
}

class TeacherDevelopmentLogItem {
  const TeacherDevelopmentLogItem({
    required this.title,
    required this.detail,
  });

  final String title;
  final String detail;

  Map<String, Object?> toJson() => {
        'title': title,
        'detail': detail,
      };

  factory TeacherDevelopmentLogItem.fromJson(Map<String, Object?> json) =>
      TeacherDevelopmentLogItem(
        title: json['title'] as String,
        detail: json['detail'] as String,
      );
}

class TeacherPrivateReflection {
  const TeacherPrivateReflection({
    required this.id,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String body;
  final String createdAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'body': body,
        'createdAt': createdAt,
      };

  factory TeacherPrivateReflection.fromJson(Map<String, Object?> json) =>
      TeacherPrivateReflection(
        id: json['id'] as String,
        body: json['body'] as String,
        createdAt: json['createdAt'] as String,
      );
}

class TeacherPerformancePermissions {
  const TeacherPerformancePermissions({
    required this.canViewOwnPerformance,
    required this.canAddPrivateReflection,
    required this.canViewOtherTeachersPerformance,
    required this.canAutomaticallyDiscipline,
    required this.canAutomaticallyReward,
    required this.canTreatClassOutcomesAsSoleCausation,
  });

  final bool canViewOwnPerformance;
  final bool canAddPrivateReflection;
  final bool canViewOtherTeachersPerformance;
  final bool canAutomaticallyDiscipline;
  final bool canAutomaticallyReward;
  final bool canTreatClassOutcomesAsSoleCausation;
}
