import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/principal/data/principal_ai_demo_data.dart';

void main() {
  test('suggested question list preserves exact website count and order', () {
    expect(principalAISuggestedQuestions, hasLength(6));
    expect(principalAISuggestedQuestions.first, 'What needs my attention today?');
    expect(principalAIDefaultQuestion, principalAISuggestedQuestions.first);
  });

  test('a response never claims specific evidence about a real or invented person', () {
    for (final question in principalAISuggestedQuestions) {
      final insight = resolvePrincipalAIInsight(question);
      // No fabricated per-person or per-class statistic should ever appear in an answer.
      expect(insight.answer, isNot(contains('%')));
      expect(insight.title, isNot(contains('%')));
    }
  });

  test('a response is honest that no real reasoning model is connected yet', () {
    final insight = resolvePrincipalAIInsight('What needs my attention today?');
    expect(insight.answer, contains('not connected'));
    expect(insight.title, 'Not available yet');
  });

  test('routing sends attendance questions toward the real Attendance screen', () {
    final insight = resolvePrincipalAIInsight('How is attendance today?');
    expect(insight.actions.map((a) => a.target), contains('attendance'));
  });

  test('routing sends teacher questions toward the real Teachers screen', () {
    final insight = resolvePrincipalAIInsight('Which teachers need support?');
    expect(insight.actions.map((a) => a.target), contains('teachers'));
  });

  test('routing sends student and risk questions toward Students and Incidents', () {
    final insight = resolvePrincipalAIInsight('Which students are at risk?');
    expect(insight.actions.map((a) => a.target), containsAll(['students', 'incidents']));
  });

  test('routing sends syllabus questions toward the real Academics screen', () {
    final insight = resolvePrincipalAIInsight('Which classes are behind on syllabus coverage?');
    expect(insight.actions.map((a) => a.target), contains('academics'));
  });

  test('an unrecognised question still returns a real, non-empty set of navigation actions', () {
    final insight = resolvePrincipalAIInsight('Something completely unrelated to any keyword');
    expect(insight.actions, isNotEmpty);
  });

  test('guardrails keep permission enforcement outside the model', () {
    expect(principalAIGuardrail, contains('active school'));
    expect(principalAIGuardrail, contains('principal permissions'));
    expect(principalAIGuardrail, contains('never search another school'));
    expect(principalAIGuardrail, contains('automatic safeguarding/disciplinary decisions'));
    expect(principalAIProductionPrinciple, contains('smallest authorized context'));
    expect(principalAIProductionPrinciple, contains('rather than trusting the model to enforce them'));
  });

  test('AI data path applies tenancy and role checks before context', () {
    expect(principalAIDataPath, [
      'Principal',
      'Active school',
      'Role & permissions',
      'Allowed records',
      'Context builder',
      'AI answer',
    ]);
  });
}
