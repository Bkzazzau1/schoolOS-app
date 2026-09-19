import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/principal/data/principal_ai_demo_data.dart';
import 'package:schoolos_app/features/principal/domain/principal_ai_models.dart';

void main() {
  test('principal AI preserves exact website question and priority counts', () {
    expect(principalAISuggestedQuestions, hasLength(6));
    expect(principalAIResponses, hasLength(6));
    expect(principalAIPrioritySignals, hasLength(4));
    expect(principalAISuggestedQuestions.first, 'What needs my attention today?');
    expect(principalAIPrioritySignals.first.title, 'JSS 2B combined risk');
  });

  test('today insight preserves exact JSS 2B and approval evidence', () {
    final insight = resolvePrincipalAIInsight('What needs my attention today?');
    expect(insight.confidence, PrincipalAIConfidence.high);
    expect(insight.evidence, contains('JSS 2B average: 61%, trend: -6.8%'));
    expect(insight.evidence, contains('JSS 2B attendance: 85%, below other monitored classes'));
    expect(insight.evidence, contains('JSS 2B report batch: awaiting principal approval'));
    expect(insight.actions.map((e) => e.target), containsAll(['academics', 'attendance', 'approvals']));
  });

  test('teacher support and student risk evidence stay grounded', () {
    final teachers = resolvePrincipalAIInsight('Which teachers need support?');
    expect(teachers.evidence, contains('Mr. Peter James attendance: 89%'));
    expect(teachers.evidence, contains('Lesson plans: 72%'));
    expect(teachers.evidence, contains('Assessment completion: 69%'));

    final students = resolvePrincipalAIInsight('Which students are at risk?');
    expect(students.evidence, contains('Student Gamma: average 48%, attendance 79%, trend -8.4%'));
    expect(students.evidence, contains('Student Gamma: two incidents and two interventions'));
  });

  test('free-form routing maps to the correct grounded insight family', () {
    expect(resolvePrincipalAIInsight('Tell me about teacher workload').title, 'Teacher support priorities');
    expect(resolvePrincipalAIInsight('What is the syllabus coverage problem?').title, 'Syllabus coverage exceptions');
    expect(resolvePrincipalAIInsight('Compare our term performance').title, 'Term-on-term comparison');
    expect(resolvePrincipalAIInsight('Something completely different').confidence, PrincipalAIConfidence.medium);
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
