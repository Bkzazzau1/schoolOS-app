enum CashflowType { income, expense }

enum CashflowStatus { posted, pendingApproval, approved, declined }

const cashflowCategories = <String>[
  'Utilities', 'Maintenance & Repairs', 'Supplies & Materials', 'Transport',
  'Staff Welfare', 'Professional Fees', 'Donation', 'Grant', 'Facility Rental', 'Other',
];

String cashflowTypeLabel(CashflowType type) => switch (type) {
      CashflowType.income => 'Income',
      CashflowType.expense => 'Expense',
    };

String cashflowStatusLabel(CashflowStatus status) => switch (status) {
      CashflowStatus.posted => 'Posted',
      CashflowStatus.pendingApproval => 'Pending approval',
      CashflowStatus.approved => 'Approved',
      CashflowStatus.declined => 'Declined',
    };

/// The school's own income and spending, outside the fee ledger entirely - a donation, a facility
/// rental, paying for repairs or supplies. Income posts the moment it is recorded; an expense needs a
/// billing authority's decision before it counts as spent.
class CashflowEntry {
  const CashflowEntry({
    required this.id,
    required this.date,
    required this.description,
    required this.type,
    required this.category,
    required this.amount,
    required this.status,
    this.recordedBy = '',
    this.createdAt = '',
    this.decidedBy,
    this.decidedAt,
    this.decisionNote,
  });

  final String id;

  /// yyyy-MM-dd
  final String date;
  final String description;
  final CashflowType type;
  final String category;
  final int amount;
  final CashflowStatus status;
  final String recordedBy;
  final String createdAt;
  final String? decidedBy;
  final String? decidedAt;
  final String? decisionNote;

  bool get isPending => status == CashflowStatus.pendingApproval;

  Map<String, Object?> toJson() => {
        'id': id, 'date': date, 'description': description, 'type': type.name, 'category': category,
        'amount': amount, 'status': status.name, 'recordedBy': recordedBy, 'createdAt': createdAt,
        'decidedBy': decidedBy, 'decidedAt': decidedAt, 'decisionNote': decisionNote,
      };

  factory CashflowEntry.fromJson(Map<String, Object?> json) => CashflowEntry(
        id: json['id'] as String? ?? '',
        date: json['date'] as String? ?? '',
        description: json['description'] as String? ?? '',
        type: CashflowType.values.firstWhere((t) => t.name == json['type'], orElse: () => CashflowType.expense),
        category: json['category'] as String? ?? 'Other',
        amount: json['amount'] as int? ?? 0,
        status: CashflowStatus.values.firstWhere((s) => s.name == json['status'], orElse: () => CashflowStatus.pendingApproval),
        recordedBy: json['recordedBy'] as String? ?? '',
        createdAt: json['createdAt'] as String? ?? '',
        decidedBy: json['decidedBy'] as String?,
        decidedAt: json['decidedAt'] as String?,
        decisionNote: json['decisionNote'] as String?,
      );
}
