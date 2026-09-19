enum FinanceStoreOrderStatus {
  awaitingPayment('Awaiting payment'),
  paidReady('Paid · ready'),
  partiallyIssued('Partially issued'),
  completed('Completed');

  const FinanceStoreOrderStatus(this.label);
  final String label;

  static FinanceStoreOrderStatus fromLabel(String value) => values.firstWhere(
        (item) => item.label == value,
        orElse: () => FinanceStoreOrderStatus.awaitingPayment,
      );
}

class FinanceStoreOrder {
  const FinanceStoreOrder({
    required this.id,
    required this.student,
    required this.className,
    required this.guardian,
    required this.items,
    required this.amount,
    required this.account,
    required this.expires,
    required this.status,
    required this.issued,
  });

  final String id;
  final String student;
  final String className;
  final String guardian;
  final String items;
  final int amount;
  final String account;
  final String expires;
  final FinanceStoreOrderStatus status;
  final String issued;

  bool get isPaid => status != FinanceStoreOrderStatus.awaitingPayment;
  bool get isOpen => status != FinanceStoreOrderStatus.completed;
  bool get isPaidNotFullyIssued =>
      status == FinanceStoreOrderStatus.paidReady ||
      status == FinanceStoreOrderStatus.partiallyIssued;

  FinanceStoreOrder copyWith({
    FinanceStoreOrderStatus? status,
    String? issued,
  }) =>
      FinanceStoreOrder(
        id: id,
        student: student,
        className: className,
        guardian: guardian,
        items: items,
        amount: amount,
        account: account,
        expires: expires,
        status: status ?? this.status,
        issued: issued ?? this.issued,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'student': student,
        'className': className,
        'guardian': guardian,
        'items': items,
        'amount': amount,
        'account': account,
        'expires': expires,
        'status': status.label,
        'issued': issued,
      };

  factory FinanceStoreOrder.fromJson(Map<String, Object?> json) =>
      FinanceStoreOrder(
        id: json['id'] as String? ?? '',
        student: json['student'] as String? ?? '',
        className: json['className'] as String? ?? '',
        guardian: json['guardian'] as String? ?? '',
        items: json['items'] as String? ?? '',
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        account: json['account'] as String? ?? '',
        expires: json['expires'] as String? ?? '',
        status: FinanceStoreOrderStatus.fromLabel(json['status'] as String? ?? ''),
        issued: json['issued'] as String? ?? '',
      );
}

class FinanceStoreStockItem {
  const FinanceStoreStockItem({
    required this.item,
    required this.opening,
    required this.issued,
    required this.available,
    required this.price,
  });

  final String item;
  final int opening;
  final int issued;
  final int available;
  final int price;

  bool get reconciles => opening - issued == available;
}

class FinanceStoreTotals {
  const FinanceStoreTotals({
    required this.sales,
    required this.openOrders,
    required this.paidNotFullyIssued,
    required this.awaitingPayment,
    required this.lowStockItems,
  });

  final int sales;
  final int openOrders;
  final int paidNotFullyIssued;
  final int awaitingPayment;
  final int lowStockItems;
}

String financeStoreMoney(int value) {
  final text = value.abs().toString();
  final parts = <String>[];
  for (var end = text.length; end > 0; end -= 3) {
    final start = end - 3 < 0 ? 0 : end - 3;
    parts.insert(0, text.substring(start, end));
  }
  return '${value < 0 ? '-' : ''}₦${parts.join(',')}';
}
