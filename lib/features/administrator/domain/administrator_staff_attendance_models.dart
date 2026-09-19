enum StaffAttendanceReviewStatus {
  ready('Ready'),
  review('Review');

  const StaffAttendanceReviewStatus(this.label);
  final String label;

  static StaffAttendanceReviewStatus fromLabel(String? value) {
    return values.firstWhere(
      (item) => item.label == value,
      orElse: () => StaffAttendanceReviewStatus.review,
    );
  }
}

class StaffAttendanceRecord {
  const StaffAttendanceRecord({
    required this.id,
    required this.name,
    required this.role,
    required this.section,
    required this.expected,
    required this.present,
    required this.leave,
    required this.late,
    required this.unexplained,
    required this.status,
  });

  final String id;
  final String name;
  final String role;
  final String section;
  final int expected;
  final int present;
  final int leave;
  final int late;
  final int unexplained;
  final StaffAttendanceReviewStatus status;

  bool get payrollReady => status == StaffAttendanceReviewStatus.ready;
  String get payrollState => payrollReady ? 'Attendance verified' : 'Hold for review';

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'section': section,
        'expected': expected,
        'present': present,
        'leave': leave,
        'late': late,
        'unexplained': unexplained,
        'status': status.label,
      };

  factory StaffAttendanceRecord.fromJson(Map<String, Object?> json) {
    return StaffAttendanceRecord(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? '',
      section: json['section'] as String? ?? '',
      expected: json['expected'] as int? ?? 0,
      present: json['present'] as int? ?? 0,
      leave: json['leave'] as int? ?? 0,
      late: json['late'] as int? ?? 0,
      unexplained: json['unexplained'] as int? ?? 0,
      status: StaffAttendanceReviewStatus.fromLabel(json['status'] as String?),
    );
  }
}

class StaffAttendanceDevice {
  const StaffAttendanceDevice({
    required this.name,
    required this.location,
    required this.method,
    required this.state,
  });

  final String name;
  final String location;
  final String method;
  final String state;
}

class StaffAttendanceKpi {
  const StaffAttendanceKpi(this.label, this.value, this.note);
  final String label;
  final String value;
  final String note;
}

class StaffAttendancePermissions {
  const StaffAttendancePermissions({
    required this.canViewAttendance,
    required this.canSendPayrollSummary,
  });

  final bool canViewAttendance;
  final bool canSendPayrollSummary;
}

class PayrollAttendanceSummary {
  const PayrollAttendanceSummary({
    required this.id,
    required this.sent,
    required this.records,
  });

  final String id;
  final bool sent;
  final List<StaffAttendanceRecord> records;

  PayrollAttendanceSummary copyWith({bool? sent}) => PayrollAttendanceSummary(
        id: id,
        sent: sent ?? this.sent,
        records: records,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'sent': sent,
        'records': records.map((item) => item.toJson()).toList(),
      };

  factory PayrollAttendanceSummary.fromJson(Map<String, Object?> json) {
    final raw = json['records'] as List<Object?>? ?? const [];
    return PayrollAttendanceSummary(
      id: json['id'] as String? ?? 'PAYROLL-ATT-2026-09',
      sent: json['sent'] as bool? ?? false,
      records: raw
          .whereType<Map>()
          .map((item) => StaffAttendanceRecord.fromJson(
                item.map((key, value) => MapEntry('$key', value)),
              ))
          .toList(),
    );
  }
}

const staffAttendanceGovernanceRule =
    'Attendance records may support payroll preparation, but lateness, absence or device data must not automatically create salary deductions, disciplinary action or employment decisions. Those require the school’s authorized human workflow.';

const staffAttendanceSyncRule =
    'Queued scans should sync before an absence is finalized. Unknown or conflicting scans require human review rather than automatic payroll action.';
