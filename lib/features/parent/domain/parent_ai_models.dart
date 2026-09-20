class ParentAISuggestion {
  const ParentAISuggestion({
    required this.prompt,
    required this.answer,
  });

  final String prompt;
  final String answer;

  Map<String, Object?> toJson() => {
        'prompt': prompt,
        'answer': answer,
      };

  factory ParentAISuggestion.fromJson(Map<String, dynamic> json) =>
      ParentAISuggestion(
        prompt: json['prompt'] as String? ?? '',
        answer: json['answer'] as String? ?? '',
      );
}

class ParentAISnapshot {
  const ParentAISnapshot({
    required this.familyAccountId,
    required this.assistantName,
    required this.description,
    required this.defaultPrompt,
    required this.defaultAnswer,
    required this.suggestions,
    required this.privacyBoundary,
    required this.decisionBoundary,
  });

  final String familyAccountId;
  final String assistantName;
  final String description;
  final String defaultPrompt;
  final String defaultAnswer;
  final List<ParentAISuggestion> suggestions;
  final String privacyBoundary;
  final String decisionBoundary;

  Map<String, Object?> toJson() => {
        'familyAccountId': familyAccountId,
        'assistantName': assistantName,
        'description': description,
        'defaultPrompt': defaultPrompt,
        'defaultAnswer': defaultAnswer,
        'suggestions': suggestions.map((item) => item.toJson()).toList(),
        'privacyBoundary': privacyBoundary,
        'decisionBoundary': decisionBoundary,
      };

  factory ParentAISnapshot.fromJson(Map<String, dynamic> json) =>
      ParentAISnapshot(
        familyAccountId: json['familyAccountId'] as String? ?? '',
        assistantName: json['assistantName'] as String? ?? '',
        description: json['description'] as String? ?? '',
        defaultPrompt: json['defaultPrompt'] as String? ?? '',
        defaultAnswer: json['defaultAnswer'] as String? ?? '',
        suggestions: _maps(json['suggestions'])
            .map(ParentAISuggestion.fromJson)
            .toList(growable: false),
        privacyBoundary: json['privacyBoundary'] as String? ?? '',
        decisionBoundary: json['decisionBoundary'] as String? ?? '',
      );
}

class ParentAIResponse {
  const ParentAIResponse({
    required this.question,
    required this.answer,
    required this.isGroundedInCachedFamilyContext,
  });

  final String question;
  final String answer;
  final bool isGroundedInCachedFamilyContext;
}

List<Map<String, dynamic>> _maps(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}
