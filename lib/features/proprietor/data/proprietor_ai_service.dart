import '../domain/proprietor_ai_models.dart';

class ProprietorAiService {
  const ProprietorAiService();

  ProprietorAiResponse answer(String rawQuestion) {
    final question = rawQuestion.trim();
    final normalized = question.toLowerCase();

    if (_containsAny(normalized, ['attendance', 'secondary attendance'])) {
      return ProprietorAiResponse(
        question: question,
        answer:
            'Secondary attendance is below the current school target. The useful owner action is to ask the section leader for the attendance pattern and documented operational context before deciding on any intervention.',
        evidence: const [
          'Secondary attendance: 90%.',
          'Current proprietor target: 94%.',
          'Gap to target: 4 percentage points.',
        ],
        interpretation:
            'The available aggregate data shows the size of the gap, but does not establish its cause. Family, health, transport or staff explanations must not be invented from the metric alone.',
      );
    }

    if (_containsAny(normalized, ['fee', 'collection', 'arrears', 'outstanding'])) {
      return ProprietorAiResponse(
        question: question,
        answer:
            'Fee collection is strong overall, but the proprietor attention queue still contains a material receivable balance that needs structured follow-up rather than assumptions about individual families.',
        evidence: const [
          'Whole-school fee collection indicator: 94%.',
          'Outstanding fees: ₦3.7m.',
          'Affected family accounts: 73.',
        ],
        interpretation:
            'The aggregate figures support collections follow-up, but they do not justify ranking families or inferring ability or willingness to pay.',
      );
    }

    if (_containsAny(normalized, ['enrollment', 'retention', 'admission'])) {
      return ProprietorAiResponse(
        question: question,
        answer:
            'Enrollment remains healthy in the current prototype, with strong retention and the strongest current intake demand in Secondary. Capacity should be reviewed before accepting growth that exceeds staffing or facilities readiness.',
        evidence: const [
          'Active enrollment: 648 students.',
          'Current retention estimate: 96%.',
          'Secondary applications: 54 in the current intake cycle.',
        ],
        interpretation:
            'Demand is a planning signal, not an automatic reason to accept more places. Capacity, staffing and facilities remain human policy decisions.',
      );
    }

    if (_containsAny(normalized, ['staff', 'staffing', 'workload', 'vacancy', 'contract'])) {
      return ProprietorAiResponse(
        question: question,
        answer:
            'The main people issues are workload pressure, two open vacancies and seven contracts approaching renewal. The proprietor should ask HR and section leaders for documented role need and performance context before action.',
        evidence: const [
          'Teaching staff sample: 64.',
          'Heavy workload review: 5 staff.',
          'Open vacancies: 2.',
          'Contracts due within 60 days: 7.',
        ],
        interpretation:
            'These are review signals only. They are not employment scores and should not trigger automated renewal, non-renewal or disciplinary decisions.',
      );
    }

    if (_containsAny(normalized, ['priority', 'priorities', 'action this week', 'attention'])) {
      return _ownerPriorities(question);
    }

    return ProprietorAiResponse(
      question: question,
      answer:
          'I can answer proprietor-level questions about finance, enrollment, staffing, attendance, academics and operations using the cached owner-authorized context currently available on this device.',
      evidence: const [
        'The offline assistant only uses the bounded proprietor prototype dataset bundled or cached for this school.',
      ],
      interpretation:
          'This question does not match a supported offline evidence pattern yet. A connected Edge or Cloud AI runtime may provide a richer answer later, but it must use the same authorization and decision boundaries.',
    );
  }

  ProprietorAiResponse defaultBriefQuestion() {
    return _ownerPriorities('Which owner priorities need action this week?');
  }

  ProprietorAiResponse _ownerPriorities(String question) {
    return ProprietorAiResponse(
      question: question,
      answer:
          'The current owner attention queue has four items: Secondary attendance below target, outstanding fees, two Secondary curriculum pacing gaps, and one unfilled Primary 6 class-teacher responsibility. The strongest owner action is to assign follow-up owners and review the supporting context.',
      evidence: const [
        'Secondary attendance: 90% versus a 94% target.',
        'Outstanding fees: ₦3.7m across 73 family accounts.',
        'Secondary curriculum pacing gaps: 2.',
        'Primary 6 class-teacher responsibility gaps: 1.',
      ],
      interpretation:
          'These signals identify where attention is needed; they do not establish family causes, staff fault or the correct final decision.',
    );
  }

  bool _containsAny(String value, List<String> needles) {
    for (final needle in needles) {
      if (value.contains(needle)) return true;
    }
    return false;
  }
}
