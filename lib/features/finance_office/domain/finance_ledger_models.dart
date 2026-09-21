import '../../administrator/domain/administrator_students_models.dart';

/// One charge in a section's fee structure for a term (tuition, development levy...).
class FeeItem {
  const FeeItem({required this.name, required this.amount});

  final String name;
  final int amount;

  Map<String, Object?> toJson() => {'name': name, 'amount': amount};

  factory FeeItem.fromJson(Map<String, Object?> json) =>
      FeeItem(name: json['name'] as String? ?? '', amount: json['amount'] as int? ?? 0);
}

/// What a section is charged for a term.
class FeeStructure {
  const FeeStructure({required this.term, required this.section, required this.items, this.updatedAt = ''});

  final String term;
  final String section;
  final List<FeeItem> items;
  final String updatedAt;

  int get total => items.fold(0, (sum, i) => sum + i.amount);

  String get id => '$term|$section';

  Map<String, Object?> toJson() => {
        'term': term,
        'section': section,
        'items': [for (final i in items) i.toJson()],
        'updatedAt': updatedAt,
      };

  factory FeeStructure.fromJson(Map<String, Object?> json) => FeeStructure(
        term: json['term'] as String? ?? '',
        section: json['section'] as String? ?? '',
        items: [
          for (final i in (json['items'] as List? ?? const [])) FeeItem.fromJson(Map<String, Object?>.from(i as Map)),
        ],
        updatedAt: json['updatedAt'] as String? ?? '',
      );
}

/// Money received from a family for one student. Payments are never edited or deleted: a mistake is voided, with a reason.
class Payment {
  const Payment({
    required this.id,
    required this.receiptNumber,
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.term,
    required this.amount,
    required this.method,
    required this.receivedAt,
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
  final String term;
  final int amount;

  /// Cash, Bank transfer or POS.
  final String method;

  /// When it was received (ISO 8601).
  final String receivedAt;

  /// The bank or POS reference, when there is one.
  final String reference;
  final String recordedBy;
  final String note;
  final String voidedReason;

  bool get isVoided => voidedReason.isNotEmpty;

  Payment voided(String reason) => Payment(
        id: id,
        receiptNumber: receiptNumber,
        studentId: studentId,
        studentName: studentName,
        className: className,
        term: term,
        amount: amount,
        method: method,
        receivedAt: receivedAt,
        reference: reference,
        recordedBy: recordedBy,
        note: note,
        voidedReason: reason,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'receiptNumber': receiptNumber,
        'studentId': studentId,
        'studentName': studentName,
        'className': className,
        'term': term,
        'amount': amount,
        'method': method,
        'receivedAt': receivedAt,
        'reference': reference,
        'recordedBy': recordedBy,
        'note': note,
        'voidedReason': voidedReason,
      };

  factory Payment.fromJson(Map<String, Object?> json) => Payment(
        id: json['id'] as String? ?? '',
        receiptNumber: json['receiptNumber'] as String? ?? '',
        studentId: json['studentId'] as String? ?? '',
        studentName: json['studentName'] as String? ?? '',
        className: json['className'] as String? ?? '',
        term: json['term'] as String? ?? '',
        amount: json['amount'] as int? ?? 0,
        method: json['method'] as String? ?? 'Cash',
        receivedAt: json['receivedAt'] as String? ?? '',
        reference: json['reference'] as String? ?? '',
        recordedBy: json['recordedBy'] as String? ?? '',
        note: json['note'] as String? ?? '',
        voidedReason: json['voidedReason'] as String? ?? '',
      );
}

enum AccountStatus { noFees, unpaid, partPaid, paid }

/// A student's fees for a term: what the section charges, less approved scholarships and discounts, less what has been paid.
class StudentAccount {
  const StudentAccount({
    required this.student,
    required this.section,
    required this.gross,
    required this.concession,
    required this.paid,
    required this.payments,
  });

  final AdministratorStudentRecord student;
  final String section;
  final int gross;
  final int concession;
  final int paid;
  final List<Payment> payments;

  int get net => (gross - concession).clamp(0, gross);
  int get balance => net - paid;

  AccountStatus get status {
    if (gross == 0) return AccountStatus.noFees;
    if (balance <= 0) return AccountStatus.paid;
    return paid == 0 ? AccountStatus.unpaid : AccountStatus.partPaid;
  }

  String get statusLabel => switch (status) {
        AccountStatus.noFees => 'No fees set',
        AccountStatus.unpaid => 'Unpaid',
        AccountStatus.partPaid => 'Part paid',
        AccountStatus.paid => 'Paid',
      };
}
