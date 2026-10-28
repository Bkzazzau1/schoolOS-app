/// A thing the School Store sells (a uniform, a book, stationery) and how many are left.
class StoreItem {
  const StoreItem({required this.id, required this.name, required this.price, required this.stock});

  final String id;
  final String name;
  final int price;
  final int stock;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'price': price, 'stock': stock};

  factory StoreItem.fromJson(Map<String, Object?> json) => StoreItem(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        price: json['price'] as int? ?? 0,
        stock: json['stock'] as int? ?? 0,
      );
}

/// One line of a sale: how many of one item, at the price the store charged at the time.
class StoreSaleLine {
  const StoreSaleLine({required this.itemId, required this.itemName, required this.quantity, required this.unitPrice});

  final String itemId;
  final String itemName;
  final int quantity;
  final int unitPrice;

  int get total => quantity * unitPrice;

  Map<String, Object?> toJson() => {'itemId': itemId, 'itemName': itemName, 'quantity': quantity, 'unitPrice': unitPrice};

  factory StoreSaleLine.fromJson(Map<String, Object?> json) => StoreSaleLine(
        itemId: json['itemId'] as String? ?? '',
        itemName: json['itemName'] as String? ?? '',
        quantity: json['quantity'] as int? ?? 0,
        unitPrice: json['unitPrice'] as int? ?? 0,
      );
}

/// Items sold to a student, paid for at the point of sale - never "on account". Never edited once
/// stored except to void it, with a reason.
class StoreSale {
  const StoreSale({
    required this.id,
    required this.receiptNumber,
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.items,
    required this.amount,
    required this.method,
    required this.soldAt,
    this.reference = '',
    this.recordedBy = '',
    this.note = '',
    this.voidedReason = '',
  });

  final String id;
  final String receiptNumber;
  final String studentId;
  final String studentName;
  final String className;
  final List<StoreSaleLine> items;
  final int amount;
  final String method;
  final String soldAt;
  final String reference;
  final String recordedBy;
  final String note;
  final String voidedReason;

  bool get isVoided => voidedReason.isNotEmpty;

  StoreSale voided(String reason) => StoreSale(
        id: id, receiptNumber: receiptNumber, studentId: studentId, studentName: studentName,
        className: className, items: items, amount: amount, method: method, soldAt: soldAt,
        reference: reference, recordedBy: recordedBy, note: note, voidedReason: reason,
      );

  Map<String, Object?> toJson() => {
        'id': id, 'receiptNumber': receiptNumber, 'studentId': studentId, 'studentName': studentName,
        'className': className, 'items': [for (final i in items) i.toJson()], 'amount': amount,
        'method': method, 'soldAt': soldAt, 'reference': reference, 'recordedBy': recordedBy,
        'note': note, 'voidedReason': voidedReason,
      };

  factory StoreSale.fromJson(Map<String, Object?> json) => StoreSale(
        id: json['id'] as String? ?? '',
        receiptNumber: json['receiptNumber'] as String? ?? '',
        studentId: json['studentId'] as String? ?? '',
        studentName: json['studentName'] as String? ?? '',
        className: json['className'] as String? ?? '',
        items: [
          for (final i in (json['items'] as List? ?? const [])) StoreSaleLine.fromJson(Map<String, Object?>.from(i as Map)),
        ],
        amount: json['amount'] as int? ?? 0,
        method: json['method'] as String? ?? 'Cash',
        soldAt: json['soldAt'] as String? ?? '',
        reference: json['reference'] as String? ?? '',
        recordedBy: json['recordedBy'] as String? ?? '',
        note: json['note'] as String? ?? '',
        voidedReason: json['voidedReason'] as String? ?? '',
      );
}
