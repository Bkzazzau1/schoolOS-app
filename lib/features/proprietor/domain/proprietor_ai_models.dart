class ProprietorAiPrompt {
  const ProprietorAiPrompt({
    required this.id,
    required this.question,
    required this.category,
  });

  final String id;
  final String question;
  final String category;
}

class ProprietorAiResponse {
  const ProprietorAiResponse({
    required this.question,
    required this.answer,
    required this.evidence,
    required this.interpretation,
    this.isOffline = true,
  });

  final String question;
  final String answer;
  final List<String> evidence;
  final String interpretation;
  final bool isOffline;
}

class ExecutiveBriefSection {
  const ExecutiveBriefSection({
    required this.title,
    required this.items,
  });

  final String title;
  final List<String> items;
}
