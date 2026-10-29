import '../../bankconnect/domain/json_read.dart';

/// One extra fact a payer needs with an account, such as a payment reference. Which ones exist depends on the bank.
class PayDetail {
  const PayDetail({required this.label, required this.value});

  factory PayDetail.fromJson(Map<String, dynamic> json) =>
      PayDetail(label: json['label'] as String? ?? '', value: json['value'] as String? ?? '');

  final String label;
  final String value;
}

/// The place a FAMILY pays into. It belongs to the family, never to one child: every child shares it, and the
/// school shares what arrives across whichever of them owe.
///
/// What it looks like depends on the bank that issued it, so nothing here assumes ten digits: [numberLabel] is
/// what that bank calls the number, [details] are extra facts the payer must be told, and [note] is how to pay it.
/// The number is the school's own account. SkulGen does not receive or hold the money.
class FamilyPayAccount {
  const FamilyPayAccount({
    required this.id,
    required this.provider,
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
    required this.numberLabel,
    required this.details,
    required this.note,
    required this.status,
    required this.canPay,
    required this.isTest,
    this.connectionId,
  });

  factory FamilyPayAccount.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as String? ?? '';
    return FamilyPayAccount(
      id: json['id'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      bankName: json['bankName'] as String? ?? '',
      accountName: json['accountName'] as String? ?? '',
      accountNumber: json['accountNumber'] as String? ?? '',
      numberLabel: (json['numberLabel'] as String?)?.trim().isNotEmpty == true ? json['numberLabel'] as String : 'Account number',
      details: [for (final d in readMaps(json['details'])) PayDetail.fromJson(d)],
      note: json['note'] as String? ?? '',
      status: status,
      // A parent's view says so; a staff view has no such field, and an account they can read is theirs to manage.
      canPay: json['canPay'] is bool ? json['canPay'] as bool : const {'active', 'dormant', 'settled', 'grace'}.contains(status),
      isTest: json['isTest'] == true,
      connectionId: json['connectionId'] as String?,
    );
  }

  final String id;
  final String provider;
  final String bankName;
  final String accountName;
  final String accountNumber;
  final String numberLabel;
  final List<PayDetail> details;
  final String note;
  final String status;
  final bool canPay;
  final bool isTest;
  final String? connectionId;

  bool get isSettingUp => status == 'provisioning';
  bool get isPaused => status == 'suspended';
  bool get isResting => status == 'dormant' || status == 'settled' || status == 'grace';

  /// Words for a payer, never a raw status code.
  String get statusLabel => switch (status) {
        'active' => 'Ready for payments',
        'dormant' || 'settled' || 'grace' => 'Nothing due right now',
        'provisioning' => 'Being set up by the school',
        'suspended' => 'Paused by the school',
        'closing' => 'Being closed by the school',
        'closed' => 'Closed',
        _ => status,
      };

  /// What to call the bank: its name, or the provider's code when the school did not record one.
  String get bankLabel => bankName.isNotEmpty ? bankName : provider;
}

/// A family's real, verified financial position - worked out live from Smart Money Collection and the
/// school's fee ledger, never remembered. The same figures Finance Office's own tools read.
class FamilyPosition {
  const FamilyPosition({
    required this.grossMinor,
    required this.adjustmentsMinor,
    required this.netMinor,
    required this.paidMinor,
    required this.outstandingMinor,
    required this.overdueMinor,
    required this.arrearsMinor,
    required this.currentMinor,
    required this.creditMinor,
    required this.collectibleMinor,
    required this.charges,
    required this.currency,
  });

  factory FamilyPosition.fromJson(Map<String, dynamic> json) => FamilyPosition(
        grossMinor: (json['grossMinor'] as num?)?.toInt() ?? 0,
        adjustmentsMinor: (json['adjustmentsMinor'] as num?)?.toInt() ?? 0,
        netMinor: (json['netMinor'] as num?)?.toInt() ?? 0,
        paidMinor: (json['paidMinor'] as num?)?.toInt() ?? 0,
        outstandingMinor: (json['outstandingMinor'] as num?)?.toInt() ?? 0,
        overdueMinor: (json['overdueMinor'] as num?)?.toInt() ?? 0,
        arrearsMinor: (json['arrearsMinor'] as num?)?.toInt() ?? 0,
        currentMinor: (json['currentMinor'] as num?)?.toInt() ?? 0,
        creditMinor: (json['creditMinor'] as num?)?.toInt() ?? 0,
        collectibleMinor: (json['collectibleMinor'] as num?)?.toInt() ?? 0,
        charges: (json['charges'] as num?)?.toInt() ?? 0,
        currency: json['currency'] as String? ?? 'NGN',
      );

  final int grossMinor;
  final int adjustmentsMinor;
  final int netMinor;
  final int paidMinor;
  final int outstandingMinor;
  final int overdueMinor;
  final int arrearsMinor;
  final int currentMinor;
  final int creditMinor;
  final int collectibleMinor;
  final int charges;
  final String currency;
}

/// A family the signed-in parent's children belong to, and where it pays.
class MyFamily {
  const MyFamily({required this.id, required this.code, required this.displayName, required this.accounts, required this.position});

  factory MyFamily.fromJson(Map<String, dynamic> json) => MyFamily(
        id: json['id'] as String? ?? '',
        code: json['code'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
        accounts: [for (final a in readMaps(json['collectionAccounts'])) FamilyPayAccount.fromJson(a)],
        position: FamilyPosition.fromJson(readMap(json['position'])),
      );

  final String id;
  final String code;
  final String displayName;
  final List<FamilyPayAccount> accounts;
  final FamilyPosition position;

  /// The accounts a payer can use right now.
  List<FamilyPayAccount> get payable => [for (final a in accounts) if (a.canPay) a];
}

/// One real allocation within a verified payment: where (some of) it went.
class FamilyVerifiedAllocation {
  const FamilyVerifiedAllocation({
    required this.studentId,
    required this.studentName,
    required this.purpose,
    required this.amountMinor,
    required this.item,
  });

  factory FamilyVerifiedAllocation.fromJson(Map<String, dynamic> json) => FamilyVerifiedAllocation(
        studentId: json['studentId'] as String? ?? '',
        studentName: json['studentName'] as String? ?? '',
        purpose: json['purpose'] as String? ?? '',
        amountMinor: (json['amountMinor'] as num?)?.toInt() ?? 0,
        item: json['item'] as String? ?? '',
      );

  final String studentId;
  final String studentName;
  final String purpose;
  final int amountMinor;
  final String item;
}

/// One real payment that is, or was, part of a family's Smart Money Collection history - the same payments
/// Finance Office's own Collections screen shows, read through the family's own ledger. A payment that was
/// reversed, refunded or found to be a duplicate still appears here: [countsTowardBalance] says whether it
/// does, never its absence.
class FamilyVerifiedPayment {
  const FamilyVerifiedPayment({
    required this.transactionId,
    required this.date,
    required this.provider,
    required this.reference,
    required this.amountMinor,
    required this.status,
    required this.countsTowardBalance,
    required this.allocations,
    required this.allocatedMinor,
    required this.creditMinor,
    required this.unappliedMinor,
  });

  factory FamilyVerifiedPayment.fromJson(Map<String, dynamic> json) => FamilyVerifiedPayment(
        transactionId: json['transactionId'] as String? ?? '',
        date: json['date'] as String? ?? '',
        provider: json['provider'] as String? ?? '',
        reference: json['reference'] as String? ?? '',
        amountMinor: (json['amountMinor'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? '',
        countsTowardBalance: json['countsTowardBalance'] == true,
        allocations: [for (final a in readMaps(json['allocations'])) FamilyVerifiedAllocation.fromJson(a)],
        allocatedMinor: (json['allocatedMinor'] as num?)?.toInt() ?? 0,
        creditMinor: (json['creditMinor'] as num?)?.toInt() ?? 0,
        unappliedMinor: (json['unappliedMinor'] as num?)?.toInt() ?? 0,
      );

  final String transactionId;
  final String date;
  final String provider;
  final String reference;
  final int amountMinor;
  final String status;
  final bool countsTowardBalance;
  final List<FamilyVerifiedAllocation> allocations;
  final int allocatedMinor;
  final int creditMinor;
  final int unappliedMinor;

  String get dateLabel => date.split('T').first;

  /// Words for a parent, never a raw status code.
  String get statusLabel => switch (status) {
        'matched' || 'partially_matched' => 'Confirmed',
        'reversed' => 'Reversed',
        'refunded' => 'Refunded',
        'duplicate' => 'Held as a possible duplicate',
        _ => 'Under review',
      };
}

// -- the school's side -------------------------------------------------------------------------------------------

class FamilyStudentBrief {
  const FamilyStudentBrief({required this.id, required this.name});

  factory FamilyStudentBrief.fromJson(Map<String, dynamic> json) =>
      FamilyStudentBrief(id: json['id'] as String? ?? '', name: json['name'] as String? ?? '');

  final String id;
  final String name;
}

/// A family as the school's finance side sees it: its children and its payment accounts.
class FamilyRow {
  const FamilyRow({
    required this.id,
    required this.code,
    required this.displayName,
    required this.status,
    required this.mergedInto,
    required this.students,
    required this.accounts,
  });

  factory FamilyRow.fromJson(Map<String, dynamic> json) => FamilyRow(
        id: json['id'] as String? ?? '',
        code: json['code'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
        status: json['status'] as String? ?? 'active',
        mergedInto: json['mergedInto'] as String?,
        students: [for (final s in readMaps(json['students'])) FamilyStudentBrief.fromJson(s)],
        accounts: [for (final a in readMaps(json['collectionAccounts'])) FamilyPayAccount.fromJson(a)],
      );

  final String id;
  final String code;
  final String displayName;
  final String status;
  final String? mergedInto;
  final List<FamilyStudentBrief> students;
  final List<FamilyPayAccount> accounts;

  bool get isActive => status == 'active' && mergedInto == null;
  bool get isMerged => mergedInto != null;

  /// Accounts still in use (a closed one is history).
  List<FamilyPayAccount> get liveAccounts => [for (final a in accounts) if (a.status != 'closed') a];
}

class FamilyPage {
  const FamilyPage({required this.families, required this.hasMore, required this.canDecideBilling});

  factory FamilyPage.fromJson(Map<String, dynamic> json) => FamilyPage(
        families: [for (final f in readMaps(json['families'])) FamilyRow.fromJson(f)],
        hasMore: json['hasMore'] == true,
        canDecideBilling: readMap(json['permissions'])['canDecideBilling'] == true,
      );

  final List<FamilyRow> families;
  final bool hasMore;

  /// Whether this person may decide what families owe - the authority merging two families needs.
  final bool canDecideBilling;
}

class MergeProblem {
  const MergeProblem({required this.code, required this.message});

  factory MergeProblem.fromJson(Map<String, dynamic> json) =>
      MergeProblem(code: json['code'] as String? ?? '', message: json['message'] as String? ?? '');

  final String code;
  final String message;
}

class MergeSide {
  const MergeSide({required this.id, required this.name, required this.students, required this.outstandingMinor, required this.creditMinor});

  factory MergeSide.fromJson(Map<String, dynamic> json) => MergeSide(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        students: [for (final s in (json['students'] as List? ?? const [])) '$s'],
        outstandingMinor: json['outstandingMinor'] as int? ?? 0,
        creditMinor: json['creditMinor'] as int? ?? 0,
      );

  final String id;
  final String name;
  final List<String> students;
  final int outstandingMinor;
  final int creditMinor;
}

/// What merging one family into another would do, worked out by the server without doing it.
class MergePreview {
  const MergePreview({
    required this.problems,
    required this.source,
    required this.into,
    required this.moves,
    required this.accountsMoved,
    required this.accountsKept,
  });

  factory MergePreview.fromJson(Map<String, dynamic> json) {
    List<String> banks(Object? value) => [
          for (final a in readMaps(value)) (a['bankName'] as String?)?.isNotEmpty == true ? a['bankName'] as String : (a['provider'] as String? ?? ''),
        ];
    return MergePreview(
      problems: [for (final p in readMaps(json['problems'])) MergeProblem.fromJson(p)],
      source: MergeSide.fromJson(readMap(json['source'])),
      into: MergeSide.fromJson(readMap(json['into'])),
      moves: {for (final e in readMap(json['moves']).entries) e.key: e.value is int ? e.value as int : 0},
      accountsMoved: banks(json['accountsMoved']),
      accountsKept: banks(json['accountsKeptAsIs']),
    );
  }

  final List<MergeProblem> problems;
  final MergeSide source;
  final MergeSide into;
  final Map<String, int> moves;

  /// Banks whose account moves to the surviving family.
  final List<String> accountsMoved;

  /// Banks where the survivor already has one: the other account stays put and still credits the survivor.
  final List<String> accountsKept;

  bool get canMerge => problems.isEmpty;
}
