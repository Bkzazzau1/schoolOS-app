import '../domain/proprietor_ai_models.dart';
import 'owner_enrollment.dart';
import 'owner_reports.dart';

/// Answers the owner's questions from the school's real records (the same ones the reports use), on this device.
///
/// It only states what was recorded. When the school has no data for a question (fees, attendance, enrollment, results) it
/// says so and names what is missing, instead of inventing figures or causes.
class ProprietorAiService {
  const ProprietorAiService(this.facts);

  final OwnerReports facts;

  ProprietorAiResponse answer(String rawQuestion) {
    final question = rawQuestion.trim();
    final q = question.toLowerCase();

    if (_any(q, ['can not be reported', 'cannot be reported', 'not available', 'missing data', 'what is missing'])) {
      return _notAvailable(question);
    }
    if (_any(q, ['attendance', 'absent', 'absence'])) {
      return _noData(question, 'attendance', 'Teachers have not recorded attendance for the school yet.');
    }
    if (_any(q, ['fee', 'collection', 'arrears', 'outstanding', 'debt', 'receivable'])) {
      return _noData(question, 'fee collection', 'The Finance role has not recorded fees or payments yet.');
    }
    if (_any(q, ['enrol', 'retention', 'admission', 'applicant', 'intake'])) {
      final e = facts.enrollment;
      if (e == null || e.empty) {
        return _noData(question, 'enrollment', 'Admissions and student records are not in yet.');
      }
      return _enrollment(question, e);
    }
    if (_any(q, ['result', 'academic', 'performance', 'exam', 'grade'])) {
      return _noData(question, 'academic results', 'Teachers have not recorded results yet.');
    }
    if (_any(q, ['who leads', 'leader', 'leadership', 'head of', 'principal', 'section'])) return _leadership(question);
    if (_any(q, ['waiting', 'decision', 'approve', 'approval', 'pending'])) return _waiting(question);
    if (_any(q, ['scholarship', 'discount', 'concession', 'payroll', 'salary', 'salaries', 'money', 'finance'])) {
      return _money(question);
    }
    if (_any(q, ['staff', 'teacher', 'people', 'hr', 'file', 'document', 'contract', 'credential'])) return _staffing(question);
    if (_any(q, ['priorit', 'this week', 'action', 'attention', 'urgent'])) return _priorities(question);

    return ProprietorAiResponse(
      question: question,
      answer:
          'I can answer questions about what is waiting for your decision, staffing and staff files, scholarships, discounts and '
          'payroll, section leadership, and what the school cannot report yet.',
      evidence: const ['This question does not match anything recorded for the school on this device.'],
      interpretation:
          'A connected AI service may later answer more, but it must use the same authorization and decision boundaries. '
          'Nothing is guessed here.',
    );
  }

  ProprietorAiResponse defaultBriefQuestion() => _priorities('Which owner priorities need action this week?');

  ProprietorAiResponse _priorities(String question) {
    final items = facts.attention.items;
    if (items.isEmpty) {
      return ProprietorAiResponse(
        question: question,
        answer: 'Nothing is waiting on you right now.',
        evidence: const ['The owner attention queue is empty.'],
        interpretation: 'An empty queue means nothing has been recorded that needs you, not that everything is fine.',
      );
    }
    return ProprietorAiResponse(
      question: question,
      answer: '${items.length} ${items.length == 1 ? 'item is' : 'items are'} waiting on you. '
          'Start with: ${items.first.title}.',
      evidence: [for (final i in items.take(6)) '${i.title}. ${i.detail}'],
      interpretation:
          'These are items recorded in the school that need an owner or delegated action. They do not say what the right decision is.',
    );
  }

  ProprietorAiResponse _waiting(String question) {
    final decisions = facts.attention.items.where((i) => i.owner == 'Proprietor').toList();
    if (decisions.isEmpty) {
      return ProprietorAiResponse(
        question: question,
        answer: 'No approval or decision is waiting on you.',
        evidence: const ['No staff proposals, concessions or payroll batches are pending.'],
        interpretation: 'Other follow-ups may exist with other people; ask for the owner priorities to see them.',
      );
    }
    return ProprietorAiResponse(
      question: question,
      answer: '${decisions.length} ${decisions.length == 1 ? 'decision is' : 'decisions are'} waiting for you.',
      evidence: [for (final d in decisions) '${d.title}. ${d.detail}'],
      interpretation: 'Each one opens in its own screen where you can decide. The assistant does not decide for you.',
    );
  }

  ProprietorAiResponse _staffing(String question) {
    final s = facts.staff;
    if (s.empty) {
      return ProprietorAiResponse(
        question: question,
        answer: 'No staff are on record yet.',
        evidence: const ['Staff on record: 0.'],
        interpretation: 'Register staff in Staff Records before any people summary is possible.',
      );
    }
    return ProprietorAiResponse(
      question: question,
      answer: '${s.total} staff are on record. ${s.attention.isEmpty ? 'No staff file needs attention.' : '${s.attention.length} people issue(s) are open.'}',
      evidence: [
        for (final k in s.kpis) '${k.label}: ${k.value} (${k.note}).',
        for (final a in s.attention.take(4)) '${a.title}.',
      ],
      interpretation:
          'These are record checks (files, onboarding, expiring credentials). They are not performance scores and must not '
          'drive employment decisions by themselves.',
    );
  }

  ProprietorAiResponse _money(String question) {
    final f = facts.finance;
    return ProprietorAiResponse(
      question: question,
      answer: f.attention.isEmpty
          ? 'Nothing about scholarships, discounts or payroll is waiting on you.'
          : '${f.attention.length} scholarship, discount or payroll item(s) are waiting on you.',
      evidence: [
        for (final k in f.kpis) '${k.label}: ${k.value} (${k.note}).',
        for (final a in f.attention.take(4)) '${a.title}.',
      ],
      interpretation:
          'These come from concessions you decided and salaries recorded on this device. Fees billed and collected are not '
          'recorded yet, so nothing here says how much the school has earned.',
    );
  }

  ProprietorAiResponse _leadership(String question) {
    final leaders = facts.staff.leaders;
    if (leaders.isEmpty) {
      return ProprietorAiResponse(
        question: question,
        answer: 'No section leaders are appointed yet.',
        evidence: const ['Leadership appointments: 0.'],
        interpretation: 'Set up the structure and appoint leaders in Structure & Leadership.',
      );
    }
    return ProprietorAiResponse(
      question: question,
      answer: '${leaders.length} leaders are appointed.',
      evidence: [for (final l in leaders) '${l.name}, ${l.role} (${l.scope}): ${l.team}. ${l.signal}.'],
      interpretation: '"Review" only means a staff file in that section is incomplete. It is not a judgement of the leader.',
    );
  }

  ProprietorAiResponse _enrollment(String question, OwnerEnrollment e) => ProprietorAiResponse(
        question: question,
        answer: '${e.activeStudents} students are on the register and ${e.applications} applications are open, with ${e.accepted} offers accepted.',
        evidence: [
          for (final k in e.kpis) '${k.label}: ${k.value} (${k.note}).',
          for (final r in e.sections) '${r.section}: ${r.activeStudents} students, ${r.applications} applications, ${r.accepted} accepted.',
          for (final w in e.watch) '${w.title}.',
        ],
        interpretation:
            'These are counts from the register and the admissions pipeline. Retention and trends are not recorded, so nothing is said '
            'about them, and demand is a planning signal, not a reason to accept more places.',
      );

  ProprietorAiResponse _notAvailable(String question) {
    final missing = facts.unavailable.toList();
    return ProprietorAiResponse(
      question: question,
      answer: '${missing.length} areas cannot be reported yet.',
      evidence: [for (final d in missing) '${d.title}: ${d.unavailableReason}'],
      interpretation: 'Missing data is not poor performance. These fill in as the other roles record their work.',
    );
  }

  ProprietorAiResponse _noData(String question, String topic, String reason) => ProprietorAiResponse(
        question: question,
        answer: 'I cannot answer questions about $topic yet: nothing has been recorded.',
        evidence: [reason],
        interpretation:
            'Nothing is guessed. When the data is recorded this will be answered from it, without inferring causes for families, '
            'staff or students.',
      );

  bool _any(String value, List<String> needles) => needles.any(value.contains);

  /// The sections of the executive brief, from the same records.
  List<ExecutiveBriefSection> briefSections() => [
        ExecutiveBriefSection(
          title: 'Owner priorities',
          items: facts.attention.items.isEmpty
              ? const ['Nothing is waiting on the owner.']
              : [for (final i in facts.attention.items) '${i.title}. ${i.detail}'],
        ),
        ExecutiveBriefSection(
          title: 'People',
          items: [for (final k in facts.staff.kpis) '${k.label}: ${k.value} (${k.note})'],
        ),
        ExecutiveBriefSection(
          title: 'Scholarships, discounts & payroll',
          items: [for (final k in facts.finance.kpis) '${k.label}: ${k.value} (${k.note})'],
        ),
        ExecutiveBriefSection(
          title: 'Not available yet',
          items: [for (final d in facts.unavailable) '${d.title}: ${d.unavailableReason}'],
        ),
      ];
}
