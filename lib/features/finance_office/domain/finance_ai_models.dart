class FinanceAiResponse {
  const FinanceAiResponse({
    required this.question,
    required this.answer,
    required this.evidence,
    required this.boundary,
  });

  final String question;
  final String answer;
  final List<String> evidence;
  final String boundary;

  Map<String, Object?> toJson() => {
        'question': question,
        'answer': answer,
        'evidence': evidence,
        'boundary': boundary,
      };

  factory FinanceAiResponse.fromJson(Map<String, Object?> json) {
    return FinanceAiResponse(
      question: json['question']! as String,
      answer: json['answer']! as String,
      evidence: (json['evidence']! as List<Object?>).cast<String>(),
      boundary: json['boundary']! as String,
    );
  }
}
