class PrincipalAIAction {
  const PrincipalAIAction({required this.label, required this.target});
  final String label;
  final String target;
}

/// A response from the prototype Principal AI workspace. There is no real reasoning model
/// connected yet, so this never claims specific evidence or a confidence level — only an
/// honest answer and real navigation to the screen(s) that hold the actual figures.
class PrincipalAIInsight {
  const PrincipalAIInsight({
    required this.title,
    required this.answer,
    required this.actions,
    required this.scope,
  });

  final String title;
  final String answer;
  final List<PrincipalAIAction> actions;
  final String scope;
}

class PrincipalAIPermissions {
  const PrincipalAIPermissions({
    required this.canUsePrincipalAI,
    required this.canCrossSchoolRetrieve,
    required this.canAccessHiddenStaffConfidential,
    required this.canMakeAutomaticDisciplinaryDecisions,
    required this.canMakeAutonomousSafeguardingDecisions,
  });

  final bool canUsePrincipalAI;
  final bool canCrossSchoolRetrieve;
  final bool canAccessHiddenStaffConfidential;
  final bool canMakeAutomaticDisciplinaryDecisions;
  final bool canMakeAutonomousSafeguardingDecisions;
}
