import '../../proprietor/data/owner_reports.dart' show ReportDoc, ReportSection;
import '../../proprietor/domain/concession_request.dart';
import '../domain/finance_ledger_models.dart';
import 'finance_aging.dart';
import 'finance_billing.dart';
import 'finance_ledger_repository.dart';
import 'finance_reconciliation.dart';

/// Everything the finance reports and the finance assistant say, read from the ledger once.
class FinanceFacts {
  const FinanceFacts({
    required this.term,
    required this.accounts,
    required this.payments,
    required this.concessions,
    required this.reminders,
    required this.aging,
    required this.reconciliation,
    required this.generatedOn,
  });

  final String term;
  final List<StudentAccount> accounts;
  final List<Payment> payments;
  final List<ConcessionRequest> concessions;
  final List<FeeReminder> reminders;
  final AgingReport aging;
  final ReconciliationReport reconciliation;
  final DateTime generatedOn;

  BillingTotals get totals => totalsOf(accounts);
  List<Payment> get validPayments => [for (final p in payments) if (!p.isVoided && p.term == term) p];
  List<Payment> get voidedPayments => [for (final p in payments) if (p.isVoided) p];

  Map<String, int> get byMethod {
    final m = <String, int>{};
    for (final p in validPayments) {
      m[p.method] = (m[p.method] ?? 0) + p.amount;
    }
    return m;
  }

  List<(String, BillingTotals, int)> get bySection => [
        for (final s in financeSections)
          (s, totalsOf(accounts.where((a) => a.section == s)), accounts.where((a) => a.section == s).length),
      ];
}

Future<FinanceFacts> loadFinanceFacts(FinanceLedgerRepository ledger, {DateTime? now}) async {
  final at = now ?? DateTime.now();
  return FinanceFacts(
    term: financeCurrentTerm,
    accounts: await ledger.accounts(),
    payments: await ledger.allPayments(),
    concessions: await ledger.concessions.loadRequests(),
    reminders: await ledger.reminders(),
    aging: await ledger.aging(today: at),
    reconciliation: await ledger.reconciliation(),
    generatedOn: at,
  );
}

String _pct(int part, int whole) => whole == 0 ? '0%' : '${(part * 100 / whole).round()}%';

/// The reports the finance office can produce from the ledger. Ones it has no records for say so.
List<ReportDoc> buildFinanceReports(FinanceFacts f) {
  final t = f.totals;
  return [
    ReportDoc(
      title: 'Collection summary',
      coverage: '${f.term}: what was billed, collected and is still owed',
      sections: [
        ReportSection('Totals', [
          'Gross fees: ${formatNaira(t.gross)}',
          'Scholarships and discounts: ${formatNaira(t.gross - t.net)}',
          'Net collectible: ${formatNaira(t.net)}',
          'Collected: ${formatNaira(t.paid)} (${t.collectedPercent}%)',
          'Still owed: ${formatNaira(t.balance)}',
        ]),
        ReportSection('By section', [
          for (final (name, totals, students) in f.bySection)
            '$name: $students students, net ${formatNaira(totals.net)}, collected ${formatNaira(totals.paid)} (${totals.collectedPercent}%), owed ${formatNaira(totals.balance)}',
        ]),
        ReportSection('How families paid', [
          if (f.byMethod.isEmpty) 'No payments yet.',
          for (final e in f.byMethod.entries) '${e.key}: ${formatNaira(e.value)}',
        ]),
      ],
    ),
    ReportDoc(
      title: 'Outstanding fees',
      coverage: 'Everyone who owes, largest first, and how overdue it is',
      sections: [
        ReportSection('Position', [
          'Due ${f.aging.due.toIso8601String().split('T').first}; ${f.aging.overdue ? '${f.aging.days} days overdue (${f.aging.band.label})' : 'not yet due'}.',
          '${f.aging.owing.length} accounts owe ${formatNaira(f.aging.outstanding)}.',
        ]),
        ReportSection('Who owes', [
          if (f.aging.owing.isEmpty) 'Nobody owes anything.',
          for (final a in f.aging.owing) '${a.student.name} (${a.student.className}): ${formatNaira(a.balance)}, guardian ${a.student.primaryGuardian}',
        ]),
      ],
    ),
    ReportDoc(
      title: 'Receipts register',
      coverage: 'Every receipt issued, and every one voided',
      sections: [
        ReportSection('Receipts', [
          if (f.validPayments.isEmpty) 'None yet.',
          for (final p in f.validPayments)
            '${p.receiptNumber} · ${p.receivedAt.split('T').first} · ${p.studentName} · ${formatNaira(p.amount)} · ${p.method}${p.reference.isEmpty ? '' : ' (${p.reference})'}',
        ]),
        ReportSection('Voided', [
          if (f.voidedPayments.isEmpty) 'None.',
          for (final p in f.voidedPayments) '${p.receiptNumber} · ${p.studentName} · ${formatNaira(p.amount)} · ${p.voidedReason}',
        ]),
      ],
    ),
    ReportDoc(
      title: 'Scholarships & discounts',
      coverage: 'What the owner approved, and what is waiting',
      sections: [
        ReportSection('Approved', [
          if (f.concessions.where((c) => c.status == ConcessionStatus.approved).isEmpty) 'None yet.',
          for (final c in f.concessions.where((c) => c.status == ConcessionStatus.approved)) '${c.student} (${c.className}): ${formatNaira(c.amount)}, ${c.reason}',
        ]),
        ReportSection('Waiting for the owner', [
          if (f.concessions.where((c) => c.status == ConcessionStatus.pendingApproval).isEmpty) 'None.',
          for (final c in f.concessions.where((c) => c.status == ConcessionStatus.pendingApproval)) '${c.student} (${c.className}): ${formatNaira(c.amount)}, ${c.reason}',
        ]),
      ],
    ),
    ReportDoc(
      title: 'Bank reconciliation',
      coverage: 'Bank transfers and POS receipts set against the statement',
      sections: [
        ReportSection('Position', [
          '${f.reconciliation.matched.length} matched (${formatNaira(f.reconciliation.matchedAmount)}).',
          '${f.reconciliation.amountMismatches.length} where the bank and the receipt disagree.',
          '${f.reconciliation.unmatchedLines.length} statement lines with no receipt (${formatNaira(f.reconciliation.unmatchedLineAmount)}).',
          '${f.reconciliation.unmatchedPayments.length} receipts not yet on the statement (${formatNaira(f.reconciliation.unmatchedPaymentAmount)}).',
        ]),
      ],
    ),
    const ReportDoc(
      title: 'School store',
      coverage: 'Orders, payments and stock issued',
      unavailableReason: 'The school store is not recorded yet.',
    ),
    const ReportDoc(
      title: 'Expenses & income',
      coverage: 'Operating costs, other income and cash position',
      unavailableReason: 'Expenses and other income are not recorded yet.',
    ),
    const ReportDoc(
      title: 'Payment mandates',
      coverage: 'Standing instructions and scheduled deductions',
      unavailableReason: 'Payment mandates are not set up yet.',
    ),
  ];
}

String renderFinanceReport(ReportDoc doc) {
  final b = StringBuffer()..writeln(doc.title)..writeln(doc.coverage)..writeln();
  if (!doc.available) {
    b.writeln('Not available yet: ${doc.unavailableReason}');
    return b.toString();
  }
  for (final s in doc.sections) {
    b.writeln(s.heading.toUpperCase());
    for (final l in s.lines) {
      b.writeln('- $l');
    }
    b.writeln();
  }
  return b.toString();
}

String renderFinancePack({required String schoolName, required List<ReportDoc> docs, required DateTime date}) {
  final day = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  final b = StringBuffer()
    ..writeln('SchoolOS Finance Report Pack')
    ..writeln(schoolName)
    ..writeln('Generated: $day')
    ..writeln();
  for (final d in docs.where((d) => d.available)) {
    b.writeln('=' * 40);
    b.write(renderFinanceReport(d));
  }
  final missing = docs.where((d) => !d.available).toList();
  if (missing.isNotEmpty) {
    b.writeln('=' * 40);
    b.writeln('NOT AVAILABLE YET');
    for (final d in missing) {
      b.writeln('- ${d.title}: ${d.unavailableReason}');
    }
  }
  return b.toString();
}

/// One answer from the finance assistant.
class FinanceAnswer {
  const FinanceAnswer({required this.question, required this.answer, required this.evidence, required this.boundary});

  final String question;
  final String answer;
  final List<String> evidence;
  final String boundary;
}

const financeAiBoundary =
    'The assistant reads the ledger and reports what is recorded. It does not contact families, record or change payments, decide '
    'scholarships, or judge a family\'s ability or willingness to pay.';

const financeAiPrompts = [
  'Who owes the most?',
  'How much have we collected this term?',
  'Compare collection by section',
  'How overdue are fees?',
  'How did families pay?',
  'What is waiting for the owner?',
  'Is the bank statement reconciled?',
  'What can the finance office not report yet?',
];

/// Answers finance questions from the ledger, and says so when nothing is recorded (store, expenses, mandates, forecasts).
class FinanceAiService {
  const FinanceAiService(this.facts);

  final FinanceFacts facts;

  FinanceAnswer answer(String raw) {
    final question = raw.trim();
    final q = question.toLowerCase();
    bool any(List<String> words) => words.any(q.contains);

    if (any(['store', 'uniform', 'book shop', 'expense', 'profit', 'cash flow', 'cashflow', 'income', 'mandate', 'forecast', 'predict', 'next term'])) {
      return _notRecorded(question);
    }
    if (any(['cannot report', 'can not report', 'not report', 'missing', 'not available'])) return _cannotReport(question);
    if (any(['reconcil', 'statement', 'bank'])) return _reconciliation(question);
    if (any(['owner', 'waiting', 'approve', 'scholarship', 'discount', 'concession'])) return _concessions(question);
    if (any(['compare', 'section', 'nursery', 'primary', 'secondary'])) return _sections(question);
    if (any(['overdue', 'aging', 'ageing', 'late', 'due'])) return _overdue(question);
    if (any(['method', 'cash', 'pos', 'transfer', 'how did', 'how do families pay'])) return _methods(question);
    if (any(['remind'])) return _reminders(question);
    if (any(['void', 'receipt'])) return _receipts(question);
    if (any(['owe', 'owes', 'balance', 'outstanding', 'debt', 'arrears'])) return _owing(question);
    if (any(['collect', 'paid', 'revenue', 'rate', 'how much'])) return _collected(question);

    return FinanceAnswer(
      question: question,
      answer: 'I can answer questions about who owes, collection, sections, how overdue fees are, payment methods, reminders, '
          'scholarships and the bank statement.',
      evidence: const ['This question does not match anything recorded in the ledger.'],
      boundary: financeAiBoundary,
    );
  }

  FinanceAnswer _owing(String q) {
    final owing = facts.aging.owing;
    if (owing.isEmpty) {
      return FinanceAnswer(question: q, answer: 'Nobody owes anything this term.', evidence: const ['Every account is paid.'], boundary: financeAiBoundary);
    }
    return FinanceAnswer(
      question: q,
      answer: '${owing.length} accounts owe ${formatNaira(facts.aging.outstanding)}. The largest balance is ${formatNaira(owing.first.balance)} (${owing.first.student.name}).',
      evidence: [for (final a in owing.take(5)) '${a.student.name} (${a.student.className}): ${formatNaira(a.balance)} of ${formatNaira(a.net)}.'],
      boundary: '$financeAiBoundary A balance says what is owed, not why.',
    );
  }

  FinanceAnswer _collected(String q) {
    final t = facts.totals;
    return FinanceAnswer(
      question: q,
      answer: '${formatNaira(t.paid)} has been collected of ${formatNaira(t.net)} net collectible (${t.collectedPercent}%).',
      evidence: [
        'Gross fees: ${formatNaira(t.gross)}.',
        'Scholarships and discounts: ${formatNaira(t.gross - t.net)}.',
        'Still owed: ${formatNaira(t.balance)}.',
        '${facts.validPayments.length} receipts issued.',
      ],
      boundary: financeAiBoundary,
    );
  }

  FinanceAnswer _sections(String q) {
    final rows = facts.bySection;
    final best = [...rows]..sort((a, b) => b.$2.collectedPercent.compareTo(a.$2.collectedPercent));
    return FinanceAnswer(
      question: q,
      answer: '${best.first.$1} has collected the most of what it owes (${best.first.$2.collectedPercent}%); ${best.last.$1} the least (${best.last.$2.collectedPercent}%).',
      evidence: [for (final r in rows) '${r.$1}: ${r.$3} students, collected ${formatNaira(r.$2.paid)} of ${formatNaira(r.$2.net)} (${r.$2.collectedPercent}%).'],
      boundary: '$financeAiBoundary Differences between sections may reflect fee levels and timing, not effort.',
    );
  }

  FinanceAnswer _overdue(String q) {
    final a = facts.aging;
    return FinanceAnswer(
      question: q,
      answer: a.overdue
          ? 'Fees were due ${a.due.toIso8601String().split('T').first} and are ${a.days} days overdue (${a.band.label}), with ${formatNaira(a.outstanding)} outstanding.'
          : 'Fees are not overdue yet.',
      evidence: [
        '${a.owing.length} accounts owe money.',
        'Reminders queued this term: ${facts.reminders.where((r) => r.term == facts.term).length}.',
      ],
      boundary: financeAiBoundary,
    );
  }

  FinanceAnswer _methods(String q) {
    final m = facts.byMethod;
    if (m.isEmpty) {
      return FinanceAnswer(question: q, answer: 'No payments have been recorded yet.', evidence: const [], boundary: financeAiBoundary);
    }
    final total = m.values.fold<int>(0, (n, v) => n + v);
    final top = m.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return FinanceAnswer(
      question: q,
      answer: '${top.key} brought in the most (${formatNaira(top.value)}, ${_pct(top.value, total)} of receipts).',
      evidence: [for (final e in m.entries) '${e.key}: ${formatNaira(e.value)} (${_pct(e.value, total)}).'],
      boundary: financeAiBoundary,
    );
  }

  FinanceAnswer _reminders(String q) {
    final list = facts.reminders.where((r) => r.term == facts.term).toList();
    return FinanceAnswer(
      question: q,
      answer: list.isEmpty ? 'No reminders have been queued this term.' : '${list.length} reminders are queued this term.',
      evidence: [
        for (final level in [1, 2, 3]) '${reminderLevelNames[level]}: ${list.where((r) => r.level == level).length}.',
        'Reminders are queued by the app and sent by the school server.',
      ],
      boundary: financeAiBoundary,
    );
  }

  FinanceAnswer _receipts(String q) => FinanceAnswer(
        question: q,
        answer: '${facts.validPayments.length} receipts are in force and ${facts.voidedPayments.length} have been voided.',
        evidence: [
          for (final p in facts.voidedPayments.take(5)) '${p.receiptNumber} voided: ${p.voidedReason}.',
          if (facts.voidedPayments.isEmpty) 'No receipt has been voided.',
        ],
        boundary: financeAiBoundary,
      );

  FinanceAnswer _concessions(String q) {
    final pending = facts.concessions.where((c) => c.status == ConcessionStatus.pendingApproval).toList();
    final approved = facts.concessions.where((c) => c.status == ConcessionStatus.approved).toList();
    return FinanceAnswer(
      question: q,
      answer: pending.isEmpty ? 'Nothing is waiting for the owner.' : '${pending.length} scholarships or discounts are waiting for the owner.',
      evidence: [
        for (final c in pending) '${c.student}: ${formatNaira(c.amount)} requested. It does not lower the bill until approved.',
        '${approved.length} approved, worth ${formatNaira(approved.fold(0, (n, c) => n + c.amount))}.',
      ],
      boundary: financeAiBoundary,
    );
  }

  FinanceAnswer _reconciliation(String q) {
    final r = facts.reconciliation;
    return FinanceAnswer(
      question: q,
      answer: r.clear ? 'The statement is fully reconciled.' : 'The statement is not fully reconciled: ${r.unmatchedLines.length} lines have no receipt, ${r.unmatchedPayments.length} receipts are not on the statement, ${r.amountMismatches.length} amounts disagree.',
      evidence: [
        '${r.matched.length} lines match a receipt (${formatNaira(r.matchedAmount)}).',
        'Cash is not on a bank statement, so it is not matched.',
      ],
      boundary: financeAiBoundary,
    );
  }

  FinanceAnswer _cannotReport(String q) => FinanceAnswer(
        question: q,
        answer: 'Three areas are not recorded yet.',
        evidence: const [
          'School store: orders, payments and stock issued.',
          'Expenses and other income, so no cash position or profit.',
          'Payment mandates and scheduled deductions.',
        ],
        boundary: financeAiBoundary,
      );

  FinanceAnswer _notRecorded(String q) => FinanceAnswer(
        question: q,
        answer: 'I cannot answer that: it is not recorded yet.',
        evidence: const ['The school store, expenses, other income and payment mandates are not recorded, and I do not forecast.'],
        boundary: financeAiBoundary,
      );
}
