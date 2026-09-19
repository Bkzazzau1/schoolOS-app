enum FinanceTermAccountStatus { active, review }

enum FinanceCollectionStatus { confirmed }

class FinanceTermAccount {
  const FinanceTermAccount({
    required this.id,
    required this.student,
    required this.className,
    required this.guardian,
    required this.account,
    required this.provider,
    required this.gross,
    required this.scholarship,
    required this.discount,
    required this.paid,
    required this.limit,
    required this.status,
    required this.lastPayment,
  });

  final String id;
  final String student;
  final String className;
  final String guardian;
  final String account;
  final String provider;
  final int gross;
  final int scholarship;
  final int discount;
  final int paid;
  final int limit;
  final FinanceTermAccountStatus status;
  final String lastPayment;

  int get concessions => scholarship + discount;
  int get netCollectible => gross - concessions;
  int get outstanding => netCollectible - paid;

  Map<String, Object?> toJson() => {
        'id': id,
        'student': student,
        'className': className,
        'guardian': guardian,
        'account': account,
        'provider': provider,
        'gross': gross,
        'scholarship': scholarship,
        'discount': discount,
        'paid': paid,
        'limit': limit,
        'status': status.name,
        'lastPayment': lastPayment,
      };

  factory FinanceTermAccount.fromJson(Map<String, Object?> json) => FinanceTermAccount(
        id: json['id'] as String,
        student: json['student'] as String,
        className: json['className'] as String,
        guardian: json['guardian'] as String,
        account: json['account'] as String,
        provider: json['provider'] as String,
        gross: json['gross'] as int,
        scholarship: json['scholarship'] as int,
        discount: json['discount'] as int,
        paid: json['paid'] as int,
        limit: json['limit'] as int,
        status: FinanceTermAccountStatus.values.byName(json['status'] as String),
        lastPayment: json['lastPayment'] as String,
      );
}

class FinanceCollectionEvent {
  const FinanceCollectionEvent({
    required this.time,
    required this.student,
    required this.amount,
    required this.account,
    required this.status,
    required this.reference,
  });

  final String time;
  final String student;
  final int amount;
  final String account;
  final FinanceCollectionStatus status;
  final String reference;

  Map<String, Object?> toJson() => {
        'time': time,
        'student': student,
        'amount': amount,
        'account': account,
        'status': status.name,
        'reference': reference,
      };

  factory FinanceCollectionEvent.fromJson(Map<String, Object?> json) => FinanceCollectionEvent(
        time: json['time'] as String,
        student: json['student'] as String,
        amount: json['amount'] as int,
        account: json['account'] as String,
        status: FinanceCollectionStatus.values.byName(json['status'] as String),
        reference: json['reference'] as String,
      );
}

class FinanceCollectionsTotals {
  const FinanceCollectionsTotals({
    required this.gross,
    required this.concessions,
    required this.collected,
    required this.outstanding,
    required this.activeAccounts,
  });

  final int gross;
  final int concessions;
  final int collected;
  final int outstanding;
  final int activeAccounts;
}

FinanceCollectionsTotals financeCollectionsTotals(List<FinanceTermAccount> accounts) {
  final gross = accounts.fold<int>(0, (sum, item) => sum + item.gross);
  final concessions = accounts.fold<int>(0, (sum, item) => sum + item.concessions);
  final collected = accounts.fold<int>(0, (sum, item) => sum + item.paid);
  return FinanceCollectionsTotals(
    gross: gross,
    concessions: concessions,
    collected: collected,
    outstanding: gross - concessions - collected,
    activeAccounts: accounts.length,
  );
}

String financeTermAccountStatusLabel(FinanceTermAccountStatus status) => switch (status) {
      FinanceTermAccountStatus.active => 'Active',
      FinanceTermAccountStatus.review => 'Review',
    };

String financeCollectionStatusLabel(FinanceCollectionStatus status) => switch (status) {
      FinanceCollectionStatus.confirmed => 'Confirmed',
    };

String financeCollectionMoney(int amount) {
  final raw = amount.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) buffer.write(',');
    buffer.write(raw[i]);
  }
  return '₦$buffer';
}
