class PrincipalPerformanceMetric {
  const PrincipalPerformanceMetric({
    required this.label,
    required this.current,
    required this.previous,
    required this.target,
    required this.suffix,
    required this.routeKey,
  });

  final String label;
  final int current;
  final int previous;
  final int target;
  final String suffix;
  final String routeKey;

  int get delta => current - previous;
  bool get improving => current > previous;
  bool get belowTarget => current < target;
  double get targetProgress => (current / target).clamp(0, 1).toDouble();
}

class PrincipalPerformanceTrend {
  const PrincipalPerformanceTrend({
    required this.term,
    required this.academics,
    required this.attendance,
    required this.teacher,
    required this.operations,
  });

  final String term;
  final int academics;
  final int attendance;
  final int teacher;
  final int operations;
}

class PrincipalClassHealth {
  const PrincipalClassHealth({
    required this.className,
    required this.score,
    required this.trend,
    required this.status,
  });

  final String className;
  final int score;
  final int trend;
  final String status;
}

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
    required this.termTrend,
    required this.classHealth,
    required this.priorities,
  });

  final List<PrincipalPerformanceMetric> metrics;
  final List<PrincipalPerformanceTrend> termTrend;
  final List<PrincipalClassHealth> classHealth;
  final List<PrincipalPerformancePriority> priorities;

  int get overallHealth => (metrics.fold<double>(0, (sum, metric) => sum + (metric.current / metric.target).clamp(0, 1)) / metrics.length * 100).round();
  int get improvingIndicators => metrics.where((metric) => metric.improving).length;
  int get belowTargetIndicators => metrics.where((metric) => metric.belowTarget).length;
}
