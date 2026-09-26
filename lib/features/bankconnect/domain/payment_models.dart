import 'json_read.dart';

/// One clue the matching engine found, in words.
class MatchSignal {
  const MatchSignal({required this.signal, required this.points, required this.detail});

  factory MatchSignal.fromJson(Map<String, dynamic> json) => MatchSignal(
        signal: json['signal'] as String? ?? '',
        points: json['points'] as int? ?? 0,
        detail: json['detail'] as String? ?? '',
      );

  final String signal;
  final int points;
  final String detail;
}

/// A student the engine thinks a payment might be for, and why.
class MatchCandidate {
  const MatchCandidate({
    required this.studentId,
    required this.studentName,
    required this.studentCode,
    required this.className,
    required this.studentStatus,
    required this.score,
    required this.signals,
  });

  factory MatchCandidate.fromJson(Map<String, dynamic> json) => MatchCandidate(
        studentId: json['studentId'] as String,
        studentName: json['studentName'] as String? ?? '',
        studentCode: json['studentCode'] as String? ?? '',
        className: json['className'] as String? ?? '',
        studentStatus: json['studentStatus'] as String? ?? '',
        score: json['score'] as int? ?? 0,
        signals: [for (final s in readMaps(json['signals'])) MatchSignal.fromJson(s)],
      );

  final String studentId;
  final String studentName;
  final String studentCode;
  final String className;
  final String studentStatus;
  final int score;
  final List<MatchSignal> signals;
}

class PaymentAllocation {
  const PaymentAllocation({
    required this.studentId,
    required this.studentName,
    required this.studentCode,
    required this.purpose,
    required this.amountMinor,
    required this.source,
    required this.superseded,
  });

  factory PaymentAllocation.fromJson(Map<String, dynamic> json) => PaymentAllocation(
        studentId: json['studentId'] as String,
        studentName: json['studentName'] as String? ?? '',
        studentCode: json['studentCode'] as String? ?? '',
        purpose: json['purpose'] as String? ?? '',
        amountMinor: json['amountMinor'] as int? ?? 0,
        source: json['source'] as String? ?? '',
        superseded: json['superseded'] == true,
      );

  final String studentId;
  final String studentName;
  final String studentCode;
  final String purpose;
  final int amountMinor;

  /// `auto` (the engine) or `manual` (a person).
  final String source;

  /// Replaced by a later decision. Kept for the history, never counted.
  final bool superseded;
}

/// Something the engine or a person decided about a payment.
class PaymentDecision {
  const PaymentDecision({
    required this.action,
    required this.note,
    required this.actorName,
    required this.at,
    required this.fromStatus,
    required this.toStatus,
  });

  factory PaymentDecision.fromJson(Map<String, dynamic> json) => PaymentDecision(
        action: json['action'] as String? ?? '',
        note: json['note'] as String? ?? '',
        actorName: json['actorName'] as String? ?? '',
        at: readTime(json['at']),
        fromStatus: readMap(json['before'])['status'] as String? ?? '',
        toStatus: readMap(json['after'])['status'] as String? ?? '',
      );

  final String action;
  final String note;
  final String actorName;
  final DateTime? at;
  final String fromStatus;
  final String toStatus;
}

/// A payment into a family's collection account, in SchoolOS's own shape whichever provider reported it.
class BankPayment {
  const BankPayment({
    required this.id,
    required this.connectionId,
    required this.provider,
    required this.receivingAccountRef,
    required this.transactionReference,
    required this.direction,
    required this.amountMinor,
    required this.currency,
    required this.senderName,
    required this.senderAccountMask,
    required this.senderBank,
    required this.narration,
    required this.transactionDate,
    required this.isSandbox,
    required this.status,
    required this.confidence,
    required this.candidates,
    required this.notes,
    required this.duplicateOf,
    required this.allocations,
    required this.decisions,
  });

  factory BankPayment.fromJson(Map<String, dynamic> json) {
    final reasons = readMaps(json['matchReasons']);
    return BankPayment(
      id: json['id'] as String,
      connectionId: json['connectionId'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      receivingAccountRef: json['receivingAccountRef'] as String? ?? '',
      transactionReference: json['transactionReference'] as String? ?? '',
      direction: json['direction'] as String? ?? 'credit',
      amountMinor: json['amountMinor'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'NGN',
      senderName: json['senderName'] as String? ?? '',
      senderAccountMask: json['senderAccountMask'] as String? ?? '',
      senderBank: json['senderBank'] as String? ?? '',
      narration: json['narration'] as String? ?? '',
      transactionDate: readTime(json['transactionDate']),
      isSandbox: json['isSandbox'] == true,
      status: json['reconciliationStatus'] as String? ?? 'unmatched',
      confidence: json['confidence'] as int? ?? 0,
      candidates: [for (final r in reasons.where((r) => r['kind'] == 'candidate')) MatchCandidate.fromJson(r)],
      notes: [for (final r in reasons.where((r) => r['kind'] == 'note')) r['text'] as String? ?? ''],
      duplicateOf: json['duplicateOf'] as String?,
      allocations: [for (final a in readMaps(json['allocations'])) PaymentAllocation.fromJson(a)],
      decisions: [for (final d in readMaps(json['decisions'])) PaymentDecision.fromJson(d)],
    );
  }

  final String id;
  final String connectionId;
  final String provider;

  /// The family's collection account the money was paid into, as the provider reported it.
  final String receivingAccountRef;
  final String transactionReference;
  final String direction;
  final int amountMinor;
  final String currency;
  final String senderName;
  final String senderAccountMask;
  final String senderBank;
  final String narration;
  final DateTime? transactionDate;
  final bool isSandbox;
  final String status;
  final int confidence;
  final List<MatchCandidate> candidates;
  final List<String> notes;
  final String? duplicateOf;
  final List<PaymentAllocation> allocations;

  /// Only present when the payment was opened on its own (not in a list).
  final List<PaymentDecision> decisions;

  bool get isCredit => direction == 'credit';
  List<PaymentAllocation> get activeAllocations => [for (final a in allocations) if (!a.superseded) a];
  int get allocatedMinor => activeAllocations.fold(0, (sum, a) => sum + a.amountMinor);
  String get senderTitle => senderName.isNotEmpty ? senderName : 'Unnamed sender';
}

class PaymentPage {
  const PaymentPage({required this.payments, required this.total, required this.hasMore, required this.counts});

  factory PaymentPage.fromJson(Map<String, dynamic> json) => PaymentPage(
        payments: [for (final t in readMaps(json['transactions'])) BankPayment.fromJson(t)],
        total: json['total'] as int? ?? 0,
        hasMore: json['hasMore'] == true,
        counts: {for (final e in readMap(json['counts']).entries) e.key: e.value as int},
      );

  final List<BankPayment> payments;
  final int total;
  final bool hasMore;

  /// Review queue only: how many payments are in each status.
  final Map<String, int> counts;
}

class StudentHit {
  const StudentHit({
    required this.id,
    required this.name,
    required this.studentCode,
    required this.admissionNumber,
    required this.className,
    required this.status,
  });

  factory StudentHit.fromJson(Map<String, dynamic> json) => StudentHit(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        studentCode: json['studentCode'] as String? ?? '',
        admissionNumber: json['admissionNumber'] as String? ?? '',
        className: json['className'] as String? ?? '',
        status: json['status'] as String? ?? '',
      );

  final String id;
  final String name;
  final String studentCode;
  final String admissionNumber;
  final String className;
  final String status;

  String get subtitle => [studentCode, if (className.isNotEmpty) className].join(' · ');
}
