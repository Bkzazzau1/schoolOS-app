enum TeacherProfileTab {
  overview,
  employment,
  qualifications,
  teachingLoad,
  attendance,
  salary,
  payslips,
  payments,
  documents,
  timeline,
  security,
}

extension TeacherProfileTabLabel on TeacherProfileTab {
  String get label => switch (this) {
        TeacherProfileTab.overview => 'Overview',
        TeacherProfileTab.employment => 'Employment',
        TeacherProfileTab.qualifications => 'Qualifications',
        TeacherProfileTab.teachingLoad => 'Teaching Load',
        TeacherProfileTab.attendance => 'Attendance & Leave',
        TeacherProfileTab.salary => 'Salary',
        TeacherProfileTab.payslips => 'Payslips',
        TeacherProfileTab.payments => 'Payment History',
        TeacherProfileTab.documents => 'Documents',
        TeacherProfileTab.timeline => 'Timeline',
        TeacherProfileTab.security => 'Security',
      };
}

/// A real payroll period this teacher was actually included in, read from the
/// school's own [PayrollBatch] records. A prepared batch's line only ever
/// keeps the net figure (see payroll_batch_repository.dart's `prepare()`) -
/// no real gross/deductions/allowance breakdown survives anywhere in the app,
/// so none is invented here. `status` never claims "Paid": the real payroll
/// workflow stops at "disbursement instructed" because that is the last state
/// backed by real evidence.
class TeacherPayslip {
  const TeacherPayslip({
    required this.period,
    required this.reference,
    required this.net,
    required this.status,
  });

  final String period;
  final String reference;
  final int net;
  final String status;

  Map<String, dynamic> toJson() => {
        'period': period,
        'reference': reference,
        'net': net,
        'status': status,
      };

  factory TeacherPayslip.fromJson(Map<String, dynamic> json) => TeacherPayslip(
        period: json['period'] as String,
        reference: json['reference'] as String,
        net: json['net'] as int,
        status: json['status'] as String,
      );
}

class TeacherProfileContact {
  const TeacherProfileContact({
    required this.phone,
    required this.email,
    required this.address,
    required this.nextOfKin,
    required this.emergencyPhone,
    this.version = 0,
    this.pendingSync = false,
  });

  final String phone;
  final String email;
  final String address;
  final String nextOfKin;
  final String emergencyPhone;
  final int version;
  final bool pendingSync;

  TeacherProfileContact copyWith({
    String? phone,
    String? email,
    String? address,
    String? nextOfKin,
    String? emergencyPhone,
    int? version,
    bool? pendingSync,
  }) =>
      TeacherProfileContact(
        phone: phone ?? this.phone,
        email: email ?? this.email,
        address: address ?? this.address,
        nextOfKin: nextOfKin ?? this.nextOfKin,
        emergencyPhone: emergencyPhone ?? this.emergencyPhone,
        version: version ?? this.version,
        pendingSync: pendingSync ?? this.pendingSync,
      );

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'email': email,
        'address': address,
        'nextOfKin': nextOfKin,
        'emergencyPhone': emergencyPhone,
        'version': version,
        'pendingSync': pendingSync,
      };

  factory TeacherProfileContact.fromJson(Map<String, dynamic> json) =>
      TeacherProfileContact(
        phone: json['phone'] as String,
        email: json['email'] as String,
        address: json['address'] as String,
        nextOfKin: json['nextOfKin'] as String,
        emergencyPhone: json['emergencyPhone'] as String,
        version: (json['version'] as int?) ?? 0,
        pendingSync: (json['pendingSync'] as bool?) ?? false,
      );
}

/// Attendance/leave day counts for the current term, read from the real
/// [StaffAttendanceRecord] the Administrator's Staff Attendance desk already
/// keeps for this teacher's own staffId - honestly all zero when no record
/// exists yet, never a fabricated percentage.
class TeacherAttendanceSummary {
  const TeacherAttendanceSummary({
    this.presentPercent = 0,
    this.lateArrivals = 0,
    this.approvedLeaveDays = 0,
    this.unapprovedAbsence = 0,
  });

  final int presentPercent;
  final int lateArrivals;
  final int approvedLeaveDays;
  final int unapprovedAbsence;
}

class TeacherProfileSnapshotData {
  const TeacherProfileSnapshotData({
    required this.hasLinkedStaffRecord,
    required this.displayName,
    required this.staffId,
    required this.department,
    required this.jobTitle,
    required this.employmentType,
    required this.hireDate,
    required this.campus,
    required this.bank,
    required this.account,
    required this.contact,
    required this.qualifications,
    required this.teachingLoad,
    required this.documents,
    required this.attendance,
    required this.payslips,
    required this.profileCompleteness,
    required this.timeline,
  });

  /// False until this teacher's membership has really been linked to a staff
  /// record (see StaffProfile.linkedMembershipId) - every identity/payroll/HR
  /// field below is honestly blank/zero until then, never a placeholder person.
  final bool hasLinkedStaffRecord;

  final String displayName;
  final String staffId;
  final String department;
  final String jobTitle;
  final String employmentType;
  final String hireDate;
  final String campus;
  final String bank;
  final String account;
  final TeacherProfileContact contact;

  /// Each row: (title, detail, category) - built from the real
  /// StaffProfile.academics and .credentials records.
  final List<(String, String, String)> qualifications;

  /// Each row: (class · subject, periods/week · room, scope) - built from the
  /// real TeacherClassesRepository assignment list.
  final List<(String, String, String)> teachingLoad;

  /// Each row: (document name, status, where it's kept) - built from the real
  /// StaffProfile.documents records.
  final List<(String, String, String)> documents;

  final TeacherAttendanceSummary attendance;
  final List<TeacherPayslip> payslips;

  /// Real percentage of this teacher's required staff documents marked
  /// verified - 0 when there are none, never a fixed placeholder.
  final int profileCompleteness;

  /// Each row: (date, title, detail) - the only real staff-record events this
  /// app can derive (payroll periods that actually reached disbursement).
  final List<(String, String, String)> timeline;

  int get netMonthly => payslips.isEmpty ? 0 : payslips.first.net;
  int get annualNet => netMonthly * 12;

  TeacherProfileSnapshotData copyWith({TeacherProfileContact? contact}) =>
      TeacherProfileSnapshotData(
        hasLinkedStaffRecord: hasLinkedStaffRecord,
        displayName: displayName,
        staffId: staffId,
        department: department,
        jobTitle: jobTitle,
        employmentType: employmentType,
        hireDate: hireDate,
        campus: campus,
        bank: bank,
        account: account,
        contact: contact ?? this.contact,
        qualifications: qualifications,
        teachingLoad: teachingLoad,
        documents: documents,
        attendance: attendance,
        payslips: payslips,
        profileCompleteness: profileCompleteness,
        timeline: timeline,
      );
}

class TeacherProfilePermissions {
  const TeacherProfilePermissions({
    required this.canViewOwnProfile,
    required this.canUpdateOwnContact,
    required this.canEditEmploymentAuthority,
    required this.canEditPayroll,
    required this.canEditTeachingAssignments,
    required this.canViewOtherStaffPayroll,
    required this.canSelfApproveSecurityChanges,
  });

  final bool canViewOwnProfile;
  final bool canUpdateOwnContact;
  final bool canEditEmploymentAuthority;
  final bool canEditPayroll;
  final bool canEditTeachingAssignments;
  final bool canViewOtherStaffPayroll;
  final bool canSelfApproveSecurityChanges;
}

const teacherProfilePayrollBoundary =
    'Salary, bank and deduction information belongs to the staff member and specifically authorized HR, payroll, finance or leadership roles.';
const teacherProfileAuthorityBoundary =
    'Staff ID, employment status, contract, teaching load, approved leave and payroll records are authoritative school records and cannot be changed by teacher self-service.';
const teacherProfileSecurityBoundary =
    'Password, multi-factor authentication and session management are not implemented in this app yet. Offline UI must never claim those actions succeeded.';
