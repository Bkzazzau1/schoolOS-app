enum PrincipalAIConfidence { high, medium }

extension PrincipalAIConfidenceLabel on PrincipalAIConfidence {
  String get label => switch (this) {
        PrincipalAIConfidence.high => 'High',
        PrincipalAIConfidence.medium => 'Medium',
      };
}

class PrincipalAIAction {
  const PrincipalAIAction({required this.label, required this.target});
  final String label;
  final String target;
}

class PrincipalAIInsight {
  const PrincipalAIInsight({
    required this.title,
    required this.answer,
    required this.evidence,
    required this.actions,
    required this.confidence,
    required this.scope,
  });

  final String title;
  final String answer;
  final List<String> evidence;
  final List<PrincipalAIAction> actions;
  final PrincipalAIConfidence confidence;
  final String scope;
}

class PrincipalAIPrioritySignal {
  const PrincipalAIPrioritySignal({
    required this.rank,
    required this.title,
    required this.detail,
    required this.priority,
    required this.target,
  });

  final int rank;
  final String title;
  final String detail;
  final String priority;
  final String target;
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
