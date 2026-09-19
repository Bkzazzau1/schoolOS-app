import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/proprietor/data/proprietor_ai_demo_data.dart';
import 'package:schoolos_app/features/proprietor/data/proprietor_ai_service.dart';

void main() {
  const service = ProprietorAiService();

  test('owner priorities answer separates evidence from interpretation', () {
    final response = service.answer('Which owner priorities need action this week?');

    expect(response.isOffline, isTrue);
    expect(response.evidence, hasLength(4));
    expect(response.answer, contains('four items'));
    expect(response.interpretation, contains('do not establish'));
  });

  test('unsupported question is bounded instead of fabricated', () {
    final response = service.answer('Predict which parent will default next term');

    expect(response.answer, contains('proprietor-level questions'));
    expect(response.interpretation, contains('does not match a supported offline evidence pattern'));
  });

  test('proprietor AI exposes all five website suggested prompts', () {
    expect(proprietorAiPrompts, hasLength(5));
    expect(
      proprietorAiPrompts.map((item) => item.question),
      contains('Compare fee collection by section'),
    );
  });

  test('context and decision safeguards remain explicit', () {
    expect(proprietorAiContextBoundary, contains('tenant'));
    expect(proprietorAiContextBoundary, contains('record sensitivity'));
    expect(proprietorAiDecisionBoundary, contains('must not autonomously fire staff'));
    expect(proprietorAiDecisionBoundary, contains('financial action'));
  });

  test('executive brief contains the three owner sections', () {
    expect(proprietorExecutiveBriefSections, hasLength(3));
    expect(
      proprietorExecutiveBriefSections.map((section) => section.title),
      containsAll(['Owner priorities', 'Finance & enrollment', 'People & operations']),
    );
  });
}
