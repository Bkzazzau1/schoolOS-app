import 'finance_cashflow_demo_data.dart';
import 'finance_debt_aging_demo_data.dart';
import 'finance_office_dashboard_demo_data.dart';
import 'finance_reconciliation_demo_data.dart';
import 'finance_reports_demo_data.dart';
import '../domain/finance_ai_models.dart';

const financeAiPrompts = <String>[
  'Why is Secondary collection below target?',
  'Show unmatched payments needing review',
  "Summarize this month's expenses",
  'Which accounts have the largest balances?',
  'What changed in collections this week?',
];

const financeAiActionBoundary =
    'Finance AI may summarize, explain, compare authorized evidence and flag anomalies, but it cannot post payments, allocate money, issue receipts, approve refunds or reversals, approve financing, approve or pay payroll, alter balances, write off debt or change reconciliation state.';

const financeAiFairnessBoundary =
    'Payment history must remain factual. Finance AI must not infer why a family has not paid, create hidden family credit scores, judge or rank families by payment behavior, or use finance data to influence a child’s academic treatment.';

const financeAiDataBoundary =
    'Finance AI uses finance-authorized billing, transaction, reconciliation, aging, expense, payroll and reporting context only. Academic grades, private teacher notes, safeguarding records and unrelated sensitive data remain outside its context.';

const financeAiEvidenceBoundary =
    'AI answers must distinguish observed finance evidence from interpretation, show the source context used, and remain bounded when the available data does not support a conclusion.';

FinanceAiResponse financeAiAnswerFor(String rawQuestion) {
  final question = rawQuestion.trim();
  final q = question.toLowerCase();

  if (q.contains('secondary') || q.contains('below target')) {
    final secondary = financeManagementSnapshots.firstWhere(
      (item) => item.section == 'Secondary School',
    );
    return FinanceAiResponse(
      question: question,
      answer:
          'Secondary collection is currently ${secondary.collectionRate}%, below the 92% owner target. The visible drivers in this mock data are open balances and scheduled payment plans. I cannot infer why individual families have not paid, and I should not rank or judge families from payment behavior.',
      evidence: const [
        'Reports · Secondary School collection: 86% · Watch',
        'Outstanding & Aging · Open receivables include active mandates, payment plans, education financing and accounts with no active arrangement',
      ],
      boundary: financeAiFairnessBoundary,
    );
  }

  if (q.contains('unmatched') || q.contains('reconciliation')) {
    final unmatched = financeReconciliationKpis.firstWhere(
      (item) => item.label == 'Unmatched',
    );
    return FinanceAiResponse(
      question: question,
      answer:
          '${unmatched.value} payment events remain unmatched, representing ${unmatched.hint}. They require review using stronger evidence such as the family account or a verified payment reference. Sender name alone is not enough, and review must not post money or issue a receipt.',
      evidence: const [
        'Reconciliation · 7 unmatched · ₦386,000',
        'Matching rule · family account/reference evidence before child-ledger allocation',
      ],
      boundary: financeAiActionBoundary,
    );
  }

  if (q.contains('expense') || q.contains('spend')) {
    final expenses = financeCashflowKpis.firstWhere(
      (item) => item.label == 'Expenses this month',
    );
    final income = financeCashflowKpis.firstWhere(
      (item) => item.label == 'Income this month',
    );
    final net = financeCashflowKpis.firstWhere(
      (item) => item.label == 'Net operating inflow',
    );
    return FinanceAiResponse(
      question: question,
      answer:
          'This month shows ${income.value} in posted income, ${expenses.value} in expenses and ${net.value} net operating inflow in the prototype. Recent visible expense rows include fuel & transport operations, laboratory supplies and utilities. Approved expense is not the same as bank settlement.',
      evidence: const [
        'Income & Expenses · ₦18.6m posted income',
        'Income & Expenses · ₦6.4m monthly expenses',
        'Income & Expenses · ₦12.2m net operating inflow',
      ],
      boundary: financeAiEvidenceBoundary,
    );
  }

  if ((q.contains('largest') || q.contains('highest')) && q.contains('balance')) {
    final rows = [...financeFamilyReceivables]
      ..sort((a, b) => b.balance.compareTo(a.balance));
    final top = rows.take(3).toList();
    final summary = top
        .map((item) => '${item.family}: ₦${_formatPlain(item.balance)}')
        .join('; ');
    return FinanceAiResponse(
      question: question,
      answer:
          'In the visible sample receivables queue, the largest open balances are $summary. This is a factual sample queue, not a school-wide family ranking and not a credit score. Balance size must not be used to judge a family or affect a child academically.',
      evidence: [
        for (final item in top)
          'Outstanding & Aging · ${item.family} · ₦${_formatPlain(item.balance)} · ${item.plan}',
      ],
      boundary: financeAiFairnessBoundary,
    );
  }

  if (q.contains('this week') || q.contains('changed in collections') || q.contains('collection trend')) {
    final first = financeCollectionTrend.first.rate;
    final last = financeCollectionTrend.last.rate;
    final delta = last - first;
    return FinanceAiResponse(
      question: question,
      answer:
          'The visible seven-point collection trend rose from $first% in W1 to $last% in W7, an increase of $delta percentage points. The reporting snapshot separately shows a current-term collection rate of 94.1%; those values come from different displayed contexts and should not be silently treated as the same calculation.',
      evidence: const [
        'Dashboard trend · W1 72%, W2 78%, W3 81%, W4 84%, W5 88%, W6 91%, W7 94%',
        'Reports · Current-term collection rate: 94.1%',
      ],
      boundary: financeAiEvidenceBoundary,
    );
  }

  return FinanceAiResponse(
    question: question,
    answer:
        'I can answer questions using the authorized Finance Office evidence available in this prototype, but the current data does not support a grounded answer to that question yet. Try one of the suggested finance questions or open the relevant source module for review.',
    evidence: const [
      'Available context · billing, collections, reconciliation, aging, expenses, payroll and finance reports',
    ],
    boundary: financeAiDataBoundary,
  );
}

String _formatPlain(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
