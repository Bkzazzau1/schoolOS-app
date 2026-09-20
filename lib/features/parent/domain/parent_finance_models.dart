class ParentFinanceChildAccount {
  const ParentFinanceChildAccount({
    required this.id,
    required this.name,
    required this.className,
    required this.accountNumber,
    required this.bank,
    required this.grossFees,
    required this.discountAmount,
    required this.discountLabel,
    required this.paidAmount,
    required this.balance,
  });

  final String id;
  final String name;
  final String className;
  final String accountNumber;
  final String bank;
  final int grossFees;
  final int discountAmount;
  final String discountLabel;
  final int paidAmount;
  final int balance;

  int get netFees => grossFees - discountAmount;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'className': className,
        'accountNumber': accountNumber,
        'bank': bank,
        'grossFees': grossFees,
        'discountAmount': discountAmount,
        'discountLabel': discountLabel,
        'paidAmount': paidAmount,
        'balance': balance,
      };

  factory ParentFinanceChildAccount.fromJson(Map<String, dynamic> json) =>
      ParentFinanceChildAccount(
        id: json['id'] as String,
        name: json['name'] as String,
        className: json['className'] as String,
        accountNumber: json['accountNumber'] as String,
        bank: json['bank'] as String,
        grossFees: (json['grossFees'] as num).toInt(),
        discountAmount: (json['discountAmount'] as num).toInt(),
        discountLabel: json['discountLabel'] as String,
        paidAmount: (json['paidAmount'] as num).toInt(),
        balance: (json['balance'] as num).toInt(),
      );
}

class ParentFinanceLedgerEntry {
  const ParentFinanceLedgerEntry({
    required this.dateLabel,
    required this.childId,
    required this.childName,
    required this.reference,
    required this.channel,
    required this.amount,
    required this.status,
  });

  final String dateLabel;
  final String childId;
  final String childName;
  final String reference;
  final String channel;
  final int amount;
  final String status;

  Map<String, Object?> toJson() => {
        'dateLabel': dateLabel,
        'childId': childId,
        'childName': childName,
        'reference': reference,
        'channel': channel,
        'amount': amount,
        'status': status,
      };

  factory ParentFinanceLedgerEntry.fromJson(Map<String, dynamic> json) =>
      ParentFinanceLedgerEntry(
        dateLabel: json['dateLabel'] as String,
        childId: json['childId'] as String,
        childName: json['childName'] as String,
        reference: json['reference'] as String,
        channel: json['channel'] as String,
        amount: (json['amount'] as num).toInt(),
        status: json['status'] as String,
      );
}

class ParentPaymentMandatePreference {
  const ParentPaymentMandatePreference({
    required this.enabled,
    required this.monthlyAmount,
    required this.debitDay,
    required this.collectionMethod,
  });

  final bool enabled;
  final int monthlyAmount;
  final String debitDay;
  final String collectionMethod;

  Map<String, Object?> toJson() => {
        'enabled': enabled,
        'monthlyAmount': monthlyAmount,
        'debitDay': debitDay,
        'collectionMethod': collectionMethod,
      };

  factory ParentPaymentMandatePreference.fromJson(Map<String, dynamic> json) =>
      ParentPaymentMandatePreference(
        enabled: json['enabled'] as bool? ?? false,
        monthlyAmount: (json['monthlyAmount'] as num? ?? 0).toInt(),
        debitDay: json['debitDay'] as String? ?? '25th',
        collectionMethod:
            json['collectionMethod'] as String? ?? 'Bank direct debit · prototype',
      );
}

class ParentFeeReminder {
  const ParentFeeReminder({
    required this.childId,
    required this.childName,
    required this.className,
    required this.balance,
    required this.nextAmount,
    required this.dateLabel,
    required this.method,
    required this.status,
    required this.message,
  });

  final String childId;
  final String childName;
  final String className;
  final int balance;
  final int nextAmount;
  final String dateLabel;
  final String method;
  final String status;
  final String message;

  Map<String, Object?> toJson() => {
        'childId': childId,
        'childName': childName,
        'className': className,
        'balance': balance,
        'nextAmount': nextAmount,
        'dateLabel': dateLabel,
        'method': method,
        'status': status,
        'message': message,
      };

  factory ParentFeeReminder.fromJson(Map<String, dynamic> json) =>
      ParentFeeReminder(
        childId: json['childId'] as String,
        childName: json['childName'] as String,
        className: json['className'] as String,
        balance: (json['balance'] as num).toInt(),
        nextAmount: (json['nextAmount'] as num).toInt(),
        dateLabel: json['dateLabel'] as String,
        method: json['method'] as String,
        status: json['status'] as String,
        message: json['message'] as String,
      );
}

class ParentFeeReminderHistoryEntry {
  const ParentFeeReminderHistoryEntry({
    required this.dateLabel,
    required this.childName,
    required this.channel,
    required this.message,
    required this.status,
  });

  final String dateLabel;
  final String childName;
  final String channel;
  final String message;
  final String status;

  Map<String, Object?> toJson() => {
        'dateLabel': dateLabel,
        'childName': childName,
        'channel': channel,
        'message': message,
        'status': status,
      };

  factory ParentFeeReminderHistoryEntry.fromJson(Map<String, dynamic> json) =>
      ParentFeeReminderHistoryEntry(
        dateLabel: json['dateLabel'] as String,
        childName: json['childName'] as String,
        channel: json['channel'] as String,
        message: json['message'] as String,
        status: json['status'] as String,
      );
}

class ParentFinanceReceipt {
  const ParentFinanceReceipt({
    required this.number,
    required this.childId,
    required this.student,
    required this.className,
    required this.admissionNumber,
    required this.amount,
    required this.dateLabel,
    required this.method,
    required this.reference,
    required this.previousBalance,
    required this.newBalance,
  });

  final String number;
  final String childId;
  final String student;
  final String className;
  final String admissionNumber;
  final int amount;
  final String dateLabel;
  final String method;
  final String reference;
  final int previousBalance;
  final int newBalance;

  Map<String, Object?> toJson() => {
        'number': number,
        'childId': childId,
        'student': student,
        'className': className,
        'admissionNumber': admissionNumber,
        'amount': amount,
        'dateLabel': dateLabel,
        'method': method,
        'reference': reference,
        'previousBalance': previousBalance,
        'newBalance': newBalance,
      };

  factory ParentFinanceReceipt.fromJson(Map<String, dynamic> json) =>
      ParentFinanceReceipt(
        number: json['number'] as String,
        childId: json['childId'] as String,
        student: json['student'] as String,
        className: json['className'] as String,
        admissionNumber: json['admissionNumber'] as String,
        amount: (json['amount'] as num).toInt(),
        dateLabel: json['dateLabel'] as String,
        method: json['method'] as String,
        reference: json['reference'] as String,
        previousBalance: (json['previousBalance'] as num).toInt(),
        newBalance: (json['newBalance'] as num).toInt(),
      );
}

class ParentStoreOrder {
  const ParentStoreOrder({
    required this.id,
    required this.childId,
    required this.childName,
    required this.className,
    required this.items,
    required this.amount,
    required this.accountNumber,
    required this.bank,
    required this.status,
    required this.issueStatus,
    required this.receiptNumber,
    required this.expiresLabel,
  });

  final String id;
  final String childId;
  final String childName;
  final String className;
  final List<String> items;
  final int amount;
  final String accountNumber;
  final String bank;
  final String status;
  final String issueStatus;
  final String receiptNumber;
  final String expiresLabel;

  Map<String, Object?> toJson() => {
        'id': id,
        'childId': childId,
        'childName': childName,
        'className': className,
        'items': items,
        'amount': amount,
        'accountNumber': accountNumber,
        'bank': bank,
        'status': status,
        'issueStatus': issueStatus,
        'receiptNumber': receiptNumber,
        'expiresLabel': expiresLabel,
      };

  factory ParentStoreOrder.fromJson(Map<String, dynamic> json) => ParentStoreOrder(
        id: json['id'] as String,
        childId: json['childId'] as String,
        childName: json['childName'] as String,
        className: json['className'] as String,
        items: (json['items'] as List<dynamic>).cast<String>(),
        amount: (json['amount'] as num).toInt(),
        accountNumber: json['accountNumber'] as String,
        bank: json['bank'] as String,
        status: json['status'] as String,
        issueStatus: json['issueStatus'] as String,
        receiptNumber: json['receiptNumber'] as String,
        expiresLabel: json['expiresLabel'] as String,
      );
}

class ParentCombinedPaymentAllocation {
  const ParentCombinedPaymentAllocation({
    required this.childId,
    required this.childName,
    required this.accountNumber,
    required this.amount,
  });

  final String childId;
  final String childName;
  final String accountNumber;
  final int amount;

  Map<String, Object?> toJson() => {
        'childId': childId,
        'childName': childName,
        'accountNumber': accountNumber,
        'amount': amount,
      };

  factory ParentCombinedPaymentAllocation.fromJson(Map<String, dynamic> json) =>
      ParentCombinedPaymentAllocation(
        childId: json['childId'] as String,
        childName: json['childName'] as String,
        accountNumber: json['accountNumber'] as String,
        amount: (json['amount'] as num).toInt(),
      );
}

class ParentCombinedPaymentRequest {
  const ParentCombinedPaymentRequest({
    required this.id,
    required this.membershipId,
    required this.familyAccountId,
    required this.allocations,
    required this.queuedAt,
    this.status = 'Queued',
  });

  final String id;
  final String membershipId;
  final String familyAccountId;
  final List<ParentCombinedPaymentAllocation> allocations;
  final DateTime queuedAt;
  final String status;

  int get total => allocations.fold(0, (sum, item) => sum + item.amount);

  Map<String, Object?> toJson() => {
        'id': id,
        'membershipId': membershipId,
        'familyAccountId': familyAccountId,
        'allocations': allocations.map((item) => item.toJson()).toList(),
        'queuedAt': queuedAt.toUtc().toIso8601String(),
        'status': status,
      };

  factory ParentCombinedPaymentRequest.fromJson(Map<String, dynamic> json) =>
      ParentCombinedPaymentRequest(
        id: json['id'] as String,
        membershipId: json['membershipId'] as String,
        familyAccountId: json['familyAccountId'] as String,
        allocations: (json['allocations'] as List<dynamic>)
            .map(
              (item) => ParentCombinedPaymentAllocation.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(growable: false),
        queuedAt: DateTime.parse(json['queuedAt'] as String),
        status: json['status'] as String? ?? 'Queued',
      );
}

class ParentFinanceSnapshot {
  const ParentFinanceSnapshot({
    required this.familyAccountId,
    required this.academicPeriod,
    required this.children,
    required this.ledger,
    required this.mandate,
    required this.reminders,
    required this.reminderHistory,
    required this.receipts,
    required this.storeOrders,
  });

  final String familyAccountId;
  final String academicPeriod;
  final List<ParentFinanceChildAccount> children;
  final List<ParentFinanceLedgerEntry> ledger;
  final ParentPaymentMandatePreference mandate;
  final List<ParentFeeReminder> reminders;
  final List<ParentFeeReminderHistoryEntry> reminderHistory;
  final List<ParentFinanceReceipt> receipts;
  final List<ParentStoreOrder> storeOrders;

  int get grossTotal => children.fold(0, (sum, child) => sum + child.grossFees);
  int get discountTotal => children.fold(0, (sum, child) => sum + child.discountAmount);
  int get paidTotal => children.fold(0, (sum, child) => sum + child.paidAmount);
  int get outstandingTotal => children.fold(0, (sum, child) => sum + child.balance);

  ParentFinanceSnapshot copyWith({
    ParentPaymentMandatePreference? mandate,
  }) {
    return ParentFinanceSnapshot(
      familyAccountId: familyAccountId,
      academicPeriod: academicPeriod,
      children: children,
      ledger: ledger,
      mandate: mandate ?? this.mandate,
      reminders: reminders,
      reminderHistory: reminderHistory,
      receipts: receipts,
      storeOrders: storeOrders,
    );
  }

  Map<String, Object?> toJson() => {
        'familyAccountId': familyAccountId,
        'academicPeriod': academicPeriod,
        'children': children.map((item) => item.toJson()).toList(),
        'ledger': ledger.map((item) => item.toJson()).toList(),
        'mandate': mandate.toJson(),
        'reminders': reminders.map((item) => item.toJson()).toList(),
        'reminderHistory': reminderHistory.map((item) => item.toJson()).toList(),
        'receipts': receipts.map((item) => item.toJson()).toList(),
        'storeOrders': storeOrders.map((item) => item.toJson()).toList(),
      };

  factory ParentFinanceSnapshot.fromJson(Map<String, dynamic> json) =>
      ParentFinanceSnapshot(
        familyAccountId: json['familyAccountId'] as String,
        academicPeriod: json['academicPeriod'] as String,
        children: _list(json['children'], ParentFinanceChildAccount.fromJson),
        ledger: _list(json['ledger'], ParentFinanceLedgerEntry.fromJson),
        mandate: ParentPaymentMandatePreference.fromJson(
          Map<String, dynamic>.from(json['mandate'] as Map),
        ),
        reminders: _list(json['reminders'], ParentFeeReminder.fromJson),
        reminderHistory: _list(
          json['reminderHistory'],
          ParentFeeReminderHistoryEntry.fromJson,
        ),
        receipts: _list(json['receipts'], ParentFinanceReceipt.fromJson),
        storeOrders: _list(json['storeOrders'], ParentStoreOrder.fromJson),
      );
}

class ParentFinanceViewData {
  const ParentFinanceViewData({
    required this.snapshot,
    required this.pendingCombinedRequests,
    required this.mandateQueued,
  });

  final ParentFinanceSnapshot snapshot;
  final List<ParentCombinedPaymentRequest> pendingCombinedRequests;
  final bool mandateQueued;
}

List<T> _list<T>(
  Object? value,
  T Function(Map<String, dynamic>) fromJson,
) {
  return (value as List<dynamic>? ?? const <dynamic>[])
      .map((item) => fromJson(Map<String, dynamic>.from(item as Map)))
      .toList(growable: false);
}
