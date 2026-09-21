import '../../administrator/domain/administrator_students_models.dart';
import '../../proprietor/domain/concession_request.dart';
import '../domain/finance_ledger_models.dart';

/// The terms the school bills.
const financeTerms = ['2026/2027 · Term 1', '2026/2027 · Term 2', '2026/2027 · Term 3'];

/// The term fees are being collected for now.
const financeCurrentTerm = '2026/2027 · Term 1';

/// The sections fees are set for.
const financeSections = ['Early Years', 'Primary', 'Secondary'];

const paymentMethods = ['Cash', 'Bank transfer', 'POS'];

/// A section's charges when the school has not set its own yet (the demo school starts with these).
List<FeeItem> defaultFeeItems(String section) => switch (section) {
      'Early Years' => const [
          FeeItem(name: 'Tuition', amount: 95000),
          FeeItem(name: 'Development levy', amount: 10000),
          FeeItem(name: 'Activities', amount: 7500),
          FeeItem(name: 'Technology', amount: 5000),
        ],
      'Primary' => const [
          FeeItem(name: 'Tuition', amount: 115000),
          FeeItem(name: 'Development levy', amount: 12000),
          FeeItem(name: 'Activities', amount: 8000),
          FeeItem(name: 'Technology', amount: 10000),
        ],
      _ => const [
          FeeItem(name: 'Tuition', amount: 145000),
          FeeItem(name: 'Development levy', amount: 15000),
          FeeItem(name: 'Activities', amount: 10000),
          FeeItem(name: 'Technology', amount: 15000),
        ],
    };

String _key(String value) => value.trim().toLowerCase();

/// Every student's account for the term.
///
/// [students] are the students billed (those on the register). [structures] are the section fee structures for [term].
/// Only approved scholarships and discounts reduce a bill, and voided payments do not count as paid.
List<StudentAccount> buildAccounts({
  required List<AdministratorStudentRecord> students,
  required List<FeeStructure> structures,
  required List<ConcessionRequest> concessions,
  required List<Payment> payments,
  required String term,
  required String Function(String className) sectionOf,
}) {
  final byId = {for (final s in structures.where((s) => s.term == term)) s.section: s};
  final approved = concessions.where((c) => c.status == ConcessionStatus.approved);
  return [
    for (final s in students)
      () {
        final section = sectionOf(s.className);
        final gross = byId[section]?.total ?? 0;
        final concession = approved.where((c) => _key(c.student) == _key(s.name)).fold<int>(0, (n, c) => n + c.amount);
        final mine = [for (final p in payments) if (p.studentId == s.id && p.term == term) p];
        final paid = mine.where((p) => !p.isVoided).fold<int>(0, (n, p) => n + p.amount);
        return StudentAccount(student: s, section: section, gross: gross, concession: concession, paid: paid, payments: mine);
      }(),
  ];
}

/// Totals across the accounts.
class BillingTotals {
  const BillingTotals({required this.gross, required this.concession, required this.net, required this.paid, required this.balance});

  final int gross;
  final int concession;
  final int net;
  final int paid;
  final int balance;

  int get collectedPercent => net == 0 ? 0 : (paid * 100 / net).round();
}

BillingTotals totalsOf(Iterable<StudentAccount> accounts) {
  var gross = 0, concession = 0, net = 0, paid = 0, balance = 0;
  for (final a in accounts) {
    gross += a.gross;
    concession += a.gross == 0 ? 0 : a.gross - a.net;
    net += a.net;
    paid += a.paid;
    balance += a.balance > 0 ? a.balance : 0;
  }
  return BillingTotals(gross: gross, concession: concession, net: net, paid: paid, balance: balance);
}
