import '../domain/finance_ledger_models.dart';

/// A reasonable starting guess for when fees for [term] fall due, until the finance office sets
/// its own real date (see FinanceLedgerRepository.dueDate/setDueDate - this is never the stored,
/// authoritative date). Recognises the school year's own "YYYY/YYYY+1 · Term N" shape so a guess
/// is never tied to one fixed year: Term 1 starts late August, Term 2 mid-January of the second
/// year, Term 3 late April of the second year.
final _termPattern = RegExp(r'^(\d{4})/\d{4} · Term (\d)$');

DateTime defaultDueDate(String term) {
  final match = _termPattern.firstMatch(term);
  if (match == null) return DateTime.now();
  final firstYear = int.parse(match.group(1)!);
  return switch (match.group(2)) {
    '1' => DateTime(firstYear, 8, 25),
    '2' => DateTime(firstYear + 1, 1, 12),
    '3' => DateTime(firstYear + 1, 4, 27),
    _ => DateTime.now(),
  };
}

/// How long fees have been overdue.
enum AgingBand {
  notDue('Not yet due'),
  current('1-30 days'),
  followUp('31-60 days'),
  review('61-90 days'),
  priority('Over 90 days');

  const AgingBand(this.label);
  final String label;
}

/// The band for an amount that has been owed since [due], as of [today]. Dates are compared as calendar days.
AgingBand bandOf(DateTime due, DateTime today) {
  final days = DateTime(today.year, today.month, today.day).difference(DateTime(due.year, due.month, due.day)).inDays;
  if (days <= 0) return AgingBand.notDue;
  if (days <= 30) return AgingBand.current;
  if (days <= 60) return AgingBand.followUp;
  if (days <= 90) return AgingBand.review;
  return AgingBand.priority;
}

int daysOverdue(DateTime due, DateTime today) =>
    DateTime(today.year, today.month, today.day).difference(DateTime(due.year, due.month, due.day)).inDays;

class AgingBandSummary {
  const AgingBandSummary({required this.band, required this.accounts, required this.amount});

  final AgingBand band;
  final int accounts;
  final int amount;
}

/// Everyone who still owes, grouped by how overdue it is.
class AgingReport {
  const AgingReport({required this.due, required this.today, required this.owing, required this.bands});

  final DateTime due;
  final DateTime today;

  /// Accounts with a balance, largest first.
  final List<StudentAccount> owing;
  final List<AgingBandSummary> bands;

  int get outstanding => owing.fold(0, (n, a) => n + a.balance);
  int get days => daysOverdue(due, today);
  AgingBand get band => bandOf(due, today);
  bool get overdue => days > 0;
}

AgingReport buildAgingReport({required List<StudentAccount> accounts, required DateTime due, required DateTime today}) {
  final owing = [for (final a in accounts) if (a.balance > 0 && a.gross > 0) a]..sort((a, b) => b.balance.compareTo(a.balance));
  final band = bandOf(due, today);
  final bands = [
    for (final b in AgingBand.values)
      AgingBandSummary(
        band: b,
        accounts: b == band ? owing.length : 0,
        amount: b == band ? owing.fold(0, (n, a) => n + a.balance) : 0,
      ),
  ];
  return AgingReport(due: due, today: today, owing: owing, bands: bands);
}

/// A reminder queued for a family. Nothing is sent from the app: the school server sends queued reminders.
class FeeReminder {
  const FeeReminder({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.term,
    required this.level,
    required this.balance,
    required this.queuedAt,
    this.message = '',
    this.queuedBy = '',
  });

  final String id;
  final String studentId;
  final String studentName;
  final String term;

  /// 1 gentle, 2 firm, 3 final.
  final int level;
  final int balance;
  final String queuedAt;
  final String message;
  final String queuedBy;

  Map<String, Object?> toJson() => {
        'id': id,
        'studentId': studentId,
        'studentName': studentName,
        'term': term,
        'level': level,
        'balance': balance,
        'queuedAt': queuedAt,
        'message': message,
        'queuedBy': queuedBy,
      };

  factory FeeReminder.fromJson(Map<String, Object?> json) => FeeReminder(
        id: json['id'] as String? ?? '',
        studentId: json['studentId'] as String? ?? '',
        studentName: json['studentName'] as String? ?? '',
        term: json['term'] as String? ?? '',
        level: json['level'] as int? ?? 1,
        balance: json['balance'] as int? ?? 0,
        queuedAt: json['queuedAt'] as String? ?? '',
        message: json['message'] as String? ?? '',
        queuedBy: json['queuedBy'] as String? ?? '',
      );
}

const reminderLevelNames = {1: 'Friendly reminder', 2: 'Second notice', 3: 'Final notice'};

/// The words of a reminder. It states the amount and the term, and never guesses why a family has not paid.
String reminderMessage({required int level, required String guardian, required String student, required int balance, required String term, required String school}) {
  final amount = '₦${_grouped(balance)}';
  final greeting = 'Dear ${guardian.isEmpty ? 'Parent/Guardian' : guardian},';
  return switch (level) {
    1 => '$greeting this is a friendly reminder from $school that $student has $amount outstanding in school fees for $term. If you have already paid, please ignore this message.',
    2 => '$greeting $school is writing again about the $amount outstanding for $student ($term). Please pay, or contact the school office to agree a payment plan.',
    _ => '$greeting this is a final notice from $school: $amount for $student ($term) remains unpaid. Please contact the school office this week.',
  };
}

String _grouped(int amount) {
  final raw = amount.toString();
  final b = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) b.write(',');
    b.write(raw[i]);
  }
  return b.toString();
}
