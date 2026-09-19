enum FinanceConcessionType { scholarship, discount }

enum FinanceConcessionStatus { pendingApproval, approved, declined }

class FinanceConcessionRequest {
  const FinanceConcessionRequest({
    required this.id,
    required this.student,
    required this.className,
    required this.type,
    required this.grossFee,
    required this.amount,
    required this.reason,
    required this.requestedBy,
    required this.requestedByRole,
    required this.requestedAt,
    required this.status,
    this.decidedBy,
    this.decidedAt,
    this.decisionNote,
  });

  final String id;
  final String student;
  final String className;
  final FinanceConcessionType type;
  final int grossFee;
  final int amount;
  final String reason;
  final String requestedBy;
  final String requestedByRole;
  final String requestedAt;
  final FinanceConcessionStatus status;
  final String? decidedBy;
  final String? decidedAt;
  final String? decisionNote;

  int get netObligation => grossFee - amount;

  Map<String, Object?> toJson() => {
        'id': id,
        'student': student,
        'className': className,
        'type': type.name,
        'grossFee': grossFee,
        'amount': amount,
        'reason': reason,
        'requestedBy': requestedBy,
        'requestedByRole': requestedByRole,
        'requestedAt': requestedAt,
        'status': status.name,
        'decidedBy': decidedBy,
        'decidedAt': decidedAt,
        'decisionNote': decisionNote,
      };

  factory FinanceConcessionRequest.fromJson(Map<String, dynamic> json) =>
      FinanceConcessionRequest(
        id: json['id'] as String,
        student: json['student'] as String,
        className: json['className'] as String,
        type: FinanceConcessionType.values.byName(json['type'] as String),
        grossFee: json['grossFee'] as int,
        amount: json['amount'] as int,
        reason: json['reason'] as String,
        requestedBy: json['requestedBy'] as String,
        requestedByRole: json['requestedByRole'] as String,
        requestedAt: json['requestedAt'] as String,
        status: FinanceConcessionStatus.values.byName(json['status'] as String),
        decidedBy: json['decidedBy'] as String?,
        decidedAt: json['decidedAt'] as String?,
        decisionNote: json['decisionNote'] as String?,
      );
}

class FinanceConcessionsSnapshot {
  const FinanceConcessionsSnapshot({
    required this.requests,
    required this.canSubmit,
    required this.canApprove,
  });

  final List<FinanceConcessionRequest> requests;
  final bool canSubmit;
  final bool canApprove;

  List<FinanceConcessionRequest> get approved => requests
      .where((item) => item.status == FinanceConcessionStatus.approved)
      .toList(growable: false);

  int get approvedGrossTotal => approved.fold(0, (sum, item) => sum + item.grossFee);
  int get approvedConcessionTotal => approved.fold(0, (sum, item) => sum + item.amount);
  int get netParentObligation => approvedGrossTotal - approvedConcessionTotal;
  int get studentsSupported => approved.map((item) => item.student).toSet().length;
  int get pendingCount => requests
      .where((item) => item.status == FinanceConcessionStatus.pendingApproval)
      .length;
}

String financeMoney(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '₦$buffer';
}

String financeConcessionTypeLabel(FinanceConcessionType type) => switch (type) {
      FinanceConcessionType.scholarship => 'Scholarship',
      FinanceConcessionType.discount => 'Discount',
    };

String financeConcessionStatusLabel(FinanceConcessionStatus status) => switch (status) {
      FinanceConcessionStatus.pendingApproval => 'Pending Approval',
      FinanceConcessionStatus.approved => 'Approved',
      FinanceConcessionStatus.declined => 'Declined',
    };
