enum ConcessionType { scholarship, discount }

enum ConcessionStatus { pendingApproval, approved, declined }

class ConcessionRequest {
  const ConcessionRequest({
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
    this.serverVersion,
  });

  final String id;
  final String student;
  final String className;
  final ConcessionType type;
  final int grossFee;
  final int amount;
  final String reason;
  final String requestedBy;
  final String requestedByRole;
  final String requestedAt;
  final ConcessionStatus status;
  final String? decidedBy;
  final String? decidedAt;
  final String? decisionNote;
  final int? serverVersion;

  int get netObligation => grossFee - amount;

  String get typeLabel => type == ConcessionType.scholarship ? 'Scholarship' : 'Discount';

  String get statusLabel => switch (status) {
        ConcessionStatus.pendingApproval => 'Pending Approval',
        ConcessionStatus.approved => 'Approved',
        ConcessionStatus.declined => 'Declined',
      };

  ConcessionRequest copyWith({
    ConcessionStatus? status,
    String? decidedBy,
    String? decidedAt,
    String? decisionNote,
    int? serverVersion,
  }) {
    return ConcessionRequest(
      id: id,
      student: student,
      className: className,
      type: type,
      grossFee: grossFee,
      amount: amount,
      reason: reason,
      requestedBy: requestedBy,
      requestedByRole: requestedByRole,
      requestedAt: requestedAt,
      status: status ?? this.status,
      decidedBy: decidedBy ?? this.decidedBy,
      decidedAt: decidedAt ?? this.decidedAt,
      decisionNote: decisionNote ?? this.decisionNote,
      serverVersion: serverVersion ?? this.serverVersion,
    );
  }

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

  factory ConcessionRequest.fromJson(Map<String, Object?> json, {int? serverVersion}) {
    return ConcessionRequest(
      id: json['id'] as String,
      student: json['student'] as String,
      className: json['className'] as String,
      type: ConcessionType.values.byName(json['type'] as String),
      grossFee: json['grossFee'] as int,
      amount: json['amount'] as int,
      reason: json['reason'] as String,
      requestedBy: json['requestedBy'] as String,
      requestedByRole: json['requestedByRole'] as String,
      requestedAt: json['requestedAt'] as String,
      status: ConcessionStatus.values.byName(json['status'] as String),
      decidedBy: json['decidedBy'] as String?,
      decidedAt: json['decidedAt'] as String?,
      decisionNote: json['decisionNote'] as String?,
      serverVersion: serverVersion,
    );
  }
}

String formatNaira(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) buffer.write(',');
    buffer.write(raw[i]);
  }
  return '₦$buffer';
}
