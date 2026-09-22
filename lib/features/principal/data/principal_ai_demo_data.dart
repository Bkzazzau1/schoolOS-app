import '../domain/principal_ai_models.dart';

const principalAISuggestedQuestions = <String>[
  'What needs my attention today?',
  'Why is a class declining?',
  'Which teachers need support?',
  'Which students are at risk?',
  'Compare this term with the previous term',
  'Which classes are behind on syllabus coverage?',
];

const principalAIDefaultQuestion = 'What needs my attention today?';

/// Real screens that can answer the question with real data, keyed by a keyword found in the
/// question. Routing to the right real screen is genuinely useful; asserting a specific
/// invented number or naming a specific person before the model is actually connected is not.
const _routesByKeyword = <String, List<PrincipalAIAction>>{
  'attend': [PrincipalAIAction(label: 'Open Attendance', target: 'attendance')],
  'teacher': [PrincipalAIAction(label: 'Open Teachers', target: 'teachers')],
  'staff': [PrincipalAIAction(label: 'Open Teachers', target: 'teachers')],
  'student': [PrincipalAIAction(label: 'Open Students', target: 'students')],
  'risk': [PrincipalAIAction(label: 'Open Students', target: 'students'), PrincipalAIAction(label: 'Open Incidents', target: 'incidents')],
  'incident': [PrincipalAIAction(label: 'Open Incidents', target: 'incidents')],
  'syllabus': [PrincipalAIAction(label: 'Open Academics', target: 'academics')],
  'coverage': [PrincipalAIAction(label: 'Open Academics', target: 'academics')],
  'term': [PrincipalAIAction(label: 'Open Performance', target: 'performance')],
  'compare': [PrincipalAIAction(label: 'Open Performance', target: 'performance')],
  'approv': [PrincipalAIAction(label: 'Open Approvals', target: 'approvals')],
  'result': [PrincipalAIAction(label: 'Open Results', target: 'results')],
  'academic': [PrincipalAIAction(label: 'Open Academics', target: 'academics')],
};

const _defaultActions = <PrincipalAIAction>[
  PrincipalAIAction(label: 'Open Performance', target: 'performance'),
  PrincipalAIAction(label: 'Open Academics', target: 'academics'),
];

/// A prototype response: honest about not being connected to a real reasoning model yet,
/// rather than asserting invented statistics about specific classes, teachers or students.
/// It still routes to the real screen(s) most likely to hold the answer.
PrincipalAIInsight resolvePrincipalAIInsight(String question) {
  final normalized = question.toLowerCase();
  final actions = <PrincipalAIAction>[];
  for (final entry in _routesByKeyword.entries) {
    if (normalized.contains(entry.key)) actions.addAll(entry.value);
  }
  final resolvedActions = actions.isEmpty ? _defaultActions : actions.toSet().toList(growable: false);

  return PrincipalAIInsight(
    title: 'Not available yet',
    answer:
        'Principal AI is not connected to a real reasoning model or the school\'s live records yet, so it cannot '
        'give you a grounded answer to "$question". Open the real screen below for the current figures, or ask '
        'again once Principal AI is connected to a model.',
    actions: resolvedActions,
    scope: resolvedActions.map((a) => a.label.replaceFirst('Open ', '')).join(' · '),
  );
}

const principalAIGuardrail =
    'Principal AI must resolve the active school, membership and principal permissions before retrieving data. It must never search another school, expose finance or staff-confidential records outside the principal’s permission set, or make automatic safeguarding/disciplinary decisions.';

const principalAIProductionPrinciple =
    'The model should never receive an unrestricted database dump. SchoolOS should retrieve the smallest authorized context first, then ask the model to reason over that context. That keeps tenant isolation and role permissions outside the model rather than trusting the model to enforce them.';

const principalAIDataPath = <String>['Principal', 'Active school', 'Role & permissions', 'Allowed records', 'Context builder', 'AI answer'];
