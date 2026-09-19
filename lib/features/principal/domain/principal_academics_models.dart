enum PrincipalAcademicStatus { strong, onTrack, watch, behind }

extension PrincipalAcademicStatusLabel on PrincipalAcademicStatus {
  String get label => switch (this) {
        PrincipalAcademicStatus.strong => 'Strong',
        PrincipalAcademicStatus.onTrack => 'On track',
        PrincipalAcademicStatus.watch => 'Watch',
        PrincipalAcademicStatus.behind => 'Behind',
      };

  static PrincipalAcademicStatus fromLabel(String value) => switch (value) {
        'Strong' => PrincipalAcademicStatus.strong,
        'On track' => PrincipalAcademicStatus.onTrack,
        'Watch' => PrincipalAcademicStatus.watch,
        'Behind' => PrincipalAcademicStatus.behind,
        _ => throw ArgumentError.value(value, 'value', 'Unknown academic status'),
      };
}

class PrincipalAcademicClass {
  const PrincipalAcademicClass({
    required this.name,
    required this.level,
    required this.students,
    required this.average,
    required this.attendance,
    required this.syllabus,
    required this.assessments,
    required this.teachers,
    required this.trend,
    required this.status,
    required this.concern,
  });

  final String name;
  final String level;
  final int students;
  final int average;
  final int attendance;
  final int syllabus;
  final int assessments;
  final int teachers;
  final double trend;
  final PrincipalAcademicStatus status;
  final String concern;

  bool matches({required String query, required String levelFilter, required String statusFilter}) {
    final normalized = query.trim().toLowerCase();
    final queryMatch = normalized.isEmpty || '$name $level ${status.label} $concern'.toLowerCase().contains(normalized);
    final levelMatch = levelFilter == 'All levels' || level == levelFilter;
    final statusMatch = statusFilter == 'All statuses' || status.label == statusFilter;
    return queryMatch && levelMatch && statusMatch;
  }

  Map<String, Object?> toJson() => {
        'name': name,
        'level': level,
        'students': students,
        'average': average,
        'attendance': attendance,
        'syllabus': syllabus,
        'assessments': assessments,
        'teachers': teachers,
        'trend': trend,
        'status': status.label,
        'concern': concern,
      };

  factory PrincipalAcademicClass.fromJson(Map<String, Object?> json) => PrincipalAcademicClass(
        name: json['name']! as String,
        level: json['level']! as String,
        students: json['students']! as int,
        average: json['average']! as int,
        attendance: json['attendance']! as int,
        syllabus: json['syllabus']! as int,
        assessments: json['assessments']! as int,
        teachers: json['teachers']! as int,
        trend: (json['trend']! as num).toDouble(),
        status: PrincipalAcademicStatusLabel.fromLabel(json['status']! as String),
        concern: json['concern']! as String,
      );
}

class PrincipalSubjectPerformance {
  const PrincipalSubjectPerformance({
    required this.name,
    required this.average,
    required this.target,
    required this.syllabus,
    required this.trend,
    required this.status,
  });

  final String name;
  final int average;
  final int target;
  final int syllabus;
  final double trend;
  final PrincipalAcademicStatus status;

  Map<String, Object?> toJson() => {
        'name': name,
        'average': average,
        'target': target,
        'syllabus': syllabus,
        'trend': trend,
        'status': status.label,
      };

  factory PrincipalSubjectPerformance.fromJson(Map<String, Object?> json) => PrincipalSubjectPerformance(
        name: json['name']! as String,
        average: json['average']! as int,
        target: json['target']! as int,
        syllabus: json['syllabus']! as int,
        trend: (json['trend']! as num).toDouble(),
        status: PrincipalAcademicStatusLabel.fromLabel(json['status']! as String),
      );
}

class PrincipalAcademicRisk {
  const PrincipalAcademicRisk({
    required this.title,
    required this.detail,
    required this.severity,
  });

  final String title;
  final String detail;
  final String severity;
}

class PrincipalAcademicsPermissions {
  const PrincipalAcademicsPermissions({
    required this.canViewSecondaryAcademics,
    required this.canLeadSecondaryInterventions,
    required this.canManagePrimary,
    required this.canManageEarlyYears,
  });

  final bool canViewSecondaryAcademics;
  final bool canLeadSecondaryInterventions;
  final bool canManagePrimary;
  final bool canManageEarlyYears;
}
