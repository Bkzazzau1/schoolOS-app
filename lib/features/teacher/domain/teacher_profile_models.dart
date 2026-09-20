enum TeacherProfileTab {
  overview,
  employment,
  qualifications,
  teachingLoad,
  attendance,
  salary,
  payslips,
  deductions,
  loans,
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
        TeacherProfileTab.deductions => 'Deductions',
        TeacherProfileTab.loans => 'Loans & Advances',
        TeacherProfileTab.payments => 'Payment History',
        TeacherProfileTab.documents => 'Documents',
        TeacherProfileTab.timeline => 'Timeline',
        TeacherProfileTab.security => 'Security',
      };
}

class TeacherPayslip {
  const TeacherPayslip({
    required this.month,
    required this.reference,
    required this.basic,
    required this.housing,
    required this.transport,
    required this.responsibility,
    required this.pension,
    required this.tax,
    required this.loan,
    required this.other,
    required this.status,
  });

  final String month;
  final String reference;
  final int basic;
  final int housing;
  final int transport;
  final int responsibility;
  final int pension;
  final int tax;
  final int loan;
  final int other;
  final String status;

  int get gross => basic + housing + transport + responsibility;
  int get deductions => pension + tax + loan + other;
  int get net => gross - deductions;

  Map<String, dynamic> toJson() => {
        'month': month,
        'reference': reference,
        'basic': basic,
        'housing': housing,
        'transport': transport,
        'responsibility': responsibility,
        'pension': pension,
        'tax': tax,
        'loan': loan,
        'other': other,
        'status': status,
      };

  factory TeacherPayslip.fromJson(Map<String, dynamic> json) => TeacherPayslip(
        month: json['month'] as String,
        reference: json['reference'] as String,
        basic: json['basic'] as int,
        housing: json['housing'] as int,
        transport: json['transport'] as int,
        responsibility: json['responsibility'] as int,
        pension: json['pension'] as int,
        tax: json['tax'] as int,
        loan: json['loan'] as int,
        other: json['other'] as int,
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

class TeacherProfileSnapshotData {
  const TeacherProfileSnapshotData({
    required this.displayName,
    required this.staffId,
    required this.payrollId,
    required this.department,
    required this.jobTitle,
    required this.employmentType,
    required this.employmentStatus,
    required this.hireDate,
    required this.qualification,
    required this.campus,
    required this.bank,
    required this.account,
    required this.pensionId,
    required this.taxId,
    required this.contact,
    required this.payslips,
  });

  final String displayName;
  final String staffId;
  final String payrollId;
  final String department;
  final String jobTitle;
  final String employmentType;
  final String employmentStatus;
  final String hireDate;
  final String qualification;
  final String campus;
  final String bank;
  final String account;
  final String pensionId;
  final String taxId;
  final TeacherProfileContact contact;
  final List<TeacherPayslip> payslips;

  int get grossMonthly => payslips.first.gross;
  int get monthlyDeductions => payslips.first.deductions;
  int get netMonthly => payslips.first.net;
  int get annualGross => grossMonthly * 12;

  TeacherProfileSnapshotData copyWith({TeacherProfileContact? contact}) =>
      TeacherProfileSnapshotData(
        displayName: displayName,
        staffId: staffId,
        payrollId: payrollId,
        department: department,
        jobTitle: jobTitle,
        employmentType: employmentType,
        employmentStatus: employmentStatus,
        hireDate: hireDate,
        qualification: qualification,
        campus: campus,
        bank: bank,
        account: account,
        pensionId: pensionId,
        taxId: taxId,
        contact: contact ?? this.contact,
        payslips: payslips,
      );

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'staffId': staffId,
        'payrollId': payrollId,
        'department': department,
        'jobTitle': jobTitle,
        'employmentType': employmentType,
        'employmentStatus': employmentStatus,
        'hireDate': hireDate,
        'qualification': qualification,
        'campus': campus,
        'bank': bank,
        'account': account,
        'pensionId': pensionId,
        'taxId': taxId,
        'contact': contact.toJson(),
        'payslips': payslips.map((item) => item.toJson()).toList(),
      };

  factory TeacherProfileSnapshotData.fromJson(Map<String, dynamic> json) =>
      TeacherProfileSnapshotData(
        displayName: json['displayName'] as String,
        staffId: json['staffId'] as String,
        payrollId: json['payrollId'] as String,
        department: json['department'] as String,
        jobTitle: json['jobTitle'] as String,
        employmentType: json['employmentType'] as String,
        employmentStatus: json['employmentStatus'] as String,
        hireDate: json['hireDate'] as String,
        qualification: json['qualification'] as String,
        campus: json['campus'] as String,
        bank: json['bank'] as String,
        account: json['account'] as String,
        pensionId: json['pensionId'] as String,
        taxId: json['taxId'] as String,
        contact: TeacherProfileContact.fromJson(
          Map<String, dynamic>.from(json['contact'] as Map),
        ),
        payslips: (json['payslips'] as List)
            .map((item) => TeacherPayslip.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ))
            .toList(growable: false),
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
    'Salary, bank, loan and deduction information belongs to the staff member and specifically authorized HR, payroll, finance or leadership roles.';
const teacherProfileAuthorityBoundary =
    'Staff ID, payroll ID, employment status, contract, teaching load, approved leave and payroll records are authoritative school records and cannot be changed by teacher self-service.';
const teacherProfileSecurityBoundary =
    'Password, MFA and session changes require the authenticated account-security service. Offline UI must never claim those actions succeeded.';
