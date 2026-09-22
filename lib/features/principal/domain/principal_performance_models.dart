/// A school-wide indicator. [current] is `null` when nothing real has been recorded for it
/// yet. [target] is a fixed school policy goal, not a measurement, so it is always present.
class PrincipalPerformanceMetric {
  const PrincipalPerformanceMetric({
    required this.label,
    required this.current,
    required this.target,
    required this.suffix,
    required this.routeKey,
  });

  final String label;
  final int? current;
  final int target;
  final String suffix;
  final String routeKey;

  bool get hasEvidence => current != null;
  bool get belowTarget => hasEvidence && current! < target;
  double get targetProgress => hasEvidence ? (current! / target).clamp(0, 1).toDouble() : 0;
}

/// A real Secondary class's academic and attendance standing. [average] is `null` when the
/// class has no recorded assessment evidence yet (see PrincipalAcademicStatus.notEvaluated).
class PrincipalClassHealth {
  const PrincipalClassHealth({
    required this.className,
    required this.average,
    required this.attendance,
  });

  final String className;
  final int? average;
  final int attendance;
}

/// Always empty: identifying a genuine leadership priority needs human judgement over a
/// pattern, which nothing in the app infers automatically. The type is kept so the UI can
/// show a real (currently empty) list rather than deleting the section outright.
class PrincipalPerformancePriority {
  const PrincipalPerformancePriority({
    required this.title,
    required this.area,
    required this.detail,
    required this.routeKey,
    required this.severity,
  });

  final String title;
  final String area;
  final String detail;
  final String routeKey;
  final String severity;
}

class PrincipalPerformanceSnapshot {
  const PrincipalPerformanceSnapshot({
    required this.metrics,
    required this.classHealth,
    required this.priorities,
  });

  final List<PrincipalPerformanceMetric> metrics;
  final List<PrincipalClassHealth> classHealth;
  final List<PrincipalPerformancePriority> priorities;

  /// The mean target-progress across metrics that actually have real evidence, as a whole
  /// percentage. `null` when no metric has any evidence yet.
  int? get overallHealth {
    final evaluated = metrics.where((metric) => metric.hasEvidence).toList();
    if (evaluated.isEmpty) return null;
    return (evaluated.fold<double>(0, (sum, metric) => sum + metric.targetProgress) / evaluated.length * 100).round();
  }

  int get evaluatedIndicators => metrics.where((metric) => metric.hasEvidence).length;
  int get belowTargetIndicators => metrics.where((metric) => metric.belowTarget).length;
}
