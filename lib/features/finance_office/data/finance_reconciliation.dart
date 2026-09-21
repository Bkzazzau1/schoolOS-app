import '../domain/finance_ledger_models.dart';

/// One line on the school's bank (or POS) statement.
class BankLine {
  const BankLine({
    required this.id,
    required this.date,
    required this.amount,
    required this.reference,
    this.narration = '',
    this.addedBy = '',
  });

  final String id;

  /// yyyy-MM-dd
  final String date;
  final int amount;
  final String reference;
  final String narration;
  final String addedBy;

  Map<String, Object?> toJson() => {
        'id': id,
        'date': date,
        'amount': amount,
        'reference': reference,
        'narration': narration,
        'addedBy': addedBy,
      };

  factory BankLine.fromJson(Map<String, Object?> json) => BankLine(
        id: json['id'] as String? ?? '',
        date: json['date'] as String? ?? '',
        amount: json['amount'] as int? ?? 0,
        reference: json['reference'] as String? ?? '',
        narration: json['narration'] as String? ?? '',
        addedBy: json['addedBy'] as String? ?? '',
      );
}

/// A statement line and the receipt it matches.
class ReconciledPair {
  const ReconciledPair({required this.line, required this.payment});

  final BankLine line;
  final Payment payment;
}

/// Statement lines set against the receipts recorded for bank transfers and POS payments.
class ReconciliationReport {
  const ReconciliationReport({
    required this.matched,
    required this.amountMismatches,
    required this.unmatchedLines,
    required this.unmatchedPayments,
  });

  /// Same reference and same amount.
  final List<ReconciledPair> matched;

  /// Same reference, different amount: the receipt and the bank disagree.
  final List<ReconciledPair> amountMismatches;

  /// Money on the statement with no receipt: someone paid and it was not recorded.
  final List<BankLine> unmatchedLines;

  /// Transfer or POS receipts with no statement line yet: recorded, but not seen in the bank.
  final List<Payment> unmatchedPayments;

  int get matchedAmount => matched.fold(0, (n, p) => n + p.payment.amount);
  int get unmatchedLineAmount => unmatchedLines.fold(0, (n, l) => n + l.amount);
  int get unmatchedPaymentAmount => unmatchedPayments.fold(0, (n, p) => n + p.amount);

  /// Nothing is left to look at.
  bool get clear => amountMismatches.isEmpty && unmatchedLines.isEmpty && unmatchedPayments.isEmpty;
}

String _ref(String value) => value.trim().toLowerCase();

/// Cash never appears on a bank statement, so only transfers and POS payments are matched. A voided receipt is not matched.
ReconciliationReport reconcile({required List<BankLine> lines, required List<Payment> payments}) {
  final candidates = [for (final p in payments) if (!p.isVoided && p.method != 'Cash' && p.reference.trim().isNotEmpty) p];
  final byRef = {for (final p in candidates) _ref(p.reference): p};
  final matched = <ReconciledPair>[];
  final mismatches = <ReconciledPair>[];
  final unmatchedLines = <BankLine>[];
  final seen = <String>{};
  for (final l in lines) {
    final p = byRef[_ref(l.reference)];
    if (p == null) {
      unmatchedLines.add(l);
      continue;
    }
    seen.add(p.id);
    (p.amount == l.amount ? matched : mismatches).add(ReconciledPair(line: l, payment: p));
  }
  return ReconciliationReport(
    matched: matched,
    amountMismatches: mismatches,
    unmatchedLines: unmatchedLines,
    unmatchedPayments: [for (final p in candidates) if (!seen.contains(p.id)) p],
  );
}
