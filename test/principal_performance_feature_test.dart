import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/principal/data/principal_performance_demo_data.dart';
import 'package:schoolos_app/features/principal/domain/principal_performance_models.dart';

void main() {
  test('performance snapshot preserves exact website scorecard', () {
    const snapshot = principalPerformanceSnapshot;
    expect(snapshot.metrics.length, 8);
    expect(snapshot.termTrend.length, 5);
    expect(snapshot.classHealth.length, 6);
    expect(snapshot.priorities.length, 4);
    expect(snapshot.overallHealth, 94);
    expect(snapshot.improvingIndicators, 8);
    expect(snapshot.belowTargetIndicators, 8);
  });

  test('core metric values and targets match website', () {
    final academic = principalPerformanceMetrics.firstWhere((item) => item.label == 'Academic average');
    final attendance = principalPerformanceMetrics.firstWhere((item) => item.label == 'Student attendance');
    final lessonPlans = principalPerformanceMetrics.firstWhere((item) => item.label == 'Lesson-plan compliance');
    final incidents = principalPerformanceMetrics.firstWhere((item) => item.label == 'Resolved incidents');

    expect((academic.current, academic.previous, academic.target), (72, 69, 75));
    expect((attendance.current, attendance.previous, attendance.target), (92, 90, 95));
    expect((lessonPlans.current, lessonPlans.previous, lessonPlans.target), (89, 84, 95));
    expect(lessonPlans.delta, 5);
    expect((incidents.current, incidents.previous, incidents.target), (81, 74, 90));
  });

  test('class health preserves strongest and weakest website rows', () {
    final jss3a = principalClassHealth.firstWhere((item) => item.className == 'JSS 3A');
    final jss2b = principalClassHealth.firstWhere((item) => item.className == 'JSS 2B');
    expect((jss3a.score, jss3a.trend, jss3a.status), (91, 7, 'Strong'));
    expect((jss2b.score, jss2b.trend, jss2b.status), (64, -7, 'Needs attention'));
  });

  test('term trend ends on current term exact values', () {
    final current = principalPerformanceTrend.last;
    expect(current.term, '1st Term 2026/27');
    expect((current.academics, current.attendance, current.teacher, current.operations), (72, 92, 94, 85));
  });

  test('principal priorities remain human-review links', () {
    expect(principalPerformancePriorities.map((item) => item.title), containsAll([
      'JSS 2B intervention',
      'Science staffing continuity',
      'Report release backlog',
      'Guardian engagement',
    ]));
    expect(principalPerformancePriorities.where((item) => item.severity == 'High').length, 2);
    expect(principalPerformancePriorities.every((item) => item.routeKey.isNotEmpty), isTrue);
  });

  test('period and comparison options preserve website order', () {
    expect(principalPerformancePeriods, ['1st Term 2026/27', '3rd Term 2025/26', '2nd Term 2025/26']);
    expect(principalPerformanceComparisons, ['Previous term', 'Same term last year', 'School target']);
  });

  test('target progress is bounded and scorecard remains descriptive', () {
    for (final PrincipalPerformanceMetric metric in principalPerformanceMetrics) {
      expect(metric.targetProgress, inInclusiveRange(0.0, 1.0));
      expect(metric.improving, isTrue);
      expect(metric.belowTarget, isTrue);
    }
    expect(principalPerformanceAiSummary, contains('targeted intervention'));
    expect(principalPerformanceAiSummary, isNot(contains('automatic')));
  });
}
