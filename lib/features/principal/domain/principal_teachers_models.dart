class PrincipalTeacher {
  const PrincipalTeacher({
    required this.id,
    required this.name,
    required this.initials,
    required this.department,
    required this.subjects,
    required this.classes,
    required this.students,
    required this.attendance,
    required this.punctuality,
    required this.lessonPlans,
    required this.syllabus,
    required this.assessments,
    required this.workload,
    required this.status,
    required this.pending,
    required this.note,
  });

  final String id;
  final String name;
  final String initials;
  final String department;
  final String subjects;
  final int classes;
  final int students;
  final int attendance;
  final int punctuality;
  final int lessonPlans;
  final int syllabus;
  final int assessments;
  final String workload;
  final String status;
  final int pending;
  final String note;

  bool matches({required String query, required String departmentFilter, required String statusFilter}) {
    final normalized = query.trim().toLowerCase();
    final queryMatches = normalized.isEmpty || '$name $department $subjects'.toLowerCase().contains(normalized);
    final departmentMatches = departmentFilter == 'All departments' || department == departmentFilter;
    final statusMatches = statusFilter == 'All statuses' || status == statusFilter;
    return queryMatches && departmentMatches && statusMatches;
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'initials': initials,
        'department': department,
        'subjects': subjects,
        'classes': classes,
        'students': students,
        'attendance': attendance,
        'punctuality': punctuality,
        'lessonPlans': lessonPlans,
        'syllabus': syllabus,
        'assessments': assessments,
        'workload': workload,
        'status': status,
        'pending': pending,
        'note': note,
      };

  factory PrincipalTeacher.fromJson(Map<String, dynamic> json) => PrincipalTeacher(
        id: json['id'] as String,
        name: json['name'] as String,
        initials: json['initials'] as String,
        department: json['department'] as String,
        subjects: json['subjects'] as String,
        classes: json['classes'] as int,
        students: json['students'] as int,
        attendance: json['attendance'] as int,
        punctuality: json['punctuality'] as int,
        lessonPlans: json['lessonPlans'] as int,
        syllabus: json['syllabus'] as int,
        assessments: json['assessments'] as int,
        workload: json['workload'] as String,
        status: json['status'] as String,
        pending: json['pending'] as int,
        note: json['note'] as String,
      );
}

class PrincipalTeacherAssignment {
  const PrincipalTeacherAssignment({required this.className, required this.subject, required this.periods, required this.role});
  final String className;
  final String subject;
  final int periods;
  final String role;
  Map<String, Object?> toJson() => {'className': className, 'subject': subject, 'periods': periods, 'role': role};
  factory PrincipalTeacherAssignment.fromJson(Map<String, dynamic> json) => PrincipalTeacherAssignment(className: json['className'] as String, subject: json['subject'] as String, periods: json['periods'] as int, role: json['role'] as String);
}

class PrincipalTeacherLeave {
  const PrincipalTeacherLeave({required this.type, required this.dates, required this.days, required this.status});
  final String type;
  final String dates;
  final int days;
  final String status;
  Map<String, Object?> toJson() => {'type': type, 'dates': dates, 'days': days, 'status': status};
  factory PrincipalTeacherLeave.fromJson(Map<String, dynamic> json) => PrincipalTeacherLeave(type: json['type'] as String, dates: json['dates'] as String, days: json['days'] as int, status: json['status'] as String);
}

class PrincipalTeacherDocument {
  const PrincipalTeacherDocument({required this.name, required this.status, required this.visibility});
  final String name;
  final String status;
  final String visibility;
  Map<String, Object?> toJson() => {'name': name, 'status': status, 'visibility': visibility};
  factory PrincipalTeacherDocument.fromJson(Map<String, dynamic> json) => PrincipalTeacherDocument(name: json['name'] as String, status: json['status'] as String, visibility: json['visibility'] as String);
}

class PrincipalTeacherTimelineItem {
  const PrincipalTeacherTimelineItem({required this.date, required this.title, required this.detail});
  final String date;
  final String title;
  final String detail;
  Map<String, Object?> toJson() => {'date': date, 'title': title, 'detail': detail};
  factory PrincipalTeacherTimelineItem.fromJson(Map<String, dynamic> json) => PrincipalTeacherTimelineItem(date: json['date'] as String, title: json['title'] as String, detail: json['detail'] as String);
}

class PrincipalTeacherProfile {
  const PrincipalTeacherProfile({
    required this.directoryId,
    required this.staffId,
    required this.payrollId,
    required this.name,
    required this.section,
    required this.campus,
    required this.jobTitle,
    required this.department,
    required this.employmentType,
    required this.employmentStatus,
    required this.hireDate,
    required this.qualification,
    required this.professionalId,
    required this.phone,
    required this.email,
    required this.nextOfKin,
    required this.emergencyPhone,
    required this.attendance,
    required this.punctuality,
    required this.weeklyPeriods,
    required this.workload,
    required this.classResponsibility,
    required this.subjects,
    required this.assignments,
    required this.leave,
    required this.documents,
    required this.timeline,
    required this.supportNote,
  });

  final String directoryId;
  final String staffId;
  final String payrollId;
  final String name;
  final String section;
  final String campus;
  final String jobTitle;
  final String department;
  final String employmentType;
  final String employmentStatus;
  final String hireDate;
  final String qualification;
  final String professionalId;
  final String phone;
  final String email;
  final String nextOfKin;
  final String emergencyPhone;
  final int attendance;
  final int punctuality;
  final int weeklyPeriods;
  final String workload;
  final String classResponsibility;
  final List<String> subjects;
  final List<PrincipalTeacherAssignment> assignments;
  final List<PrincipalTeacherLeave> leave;
  final List<PrincipalTeacherDocument> documents;
  final List<PrincipalTeacherTimelineItem> timeline;
  final String supportNote;

  Map<String, Object?> toJson() => {
        'directoryId': directoryId,
        'staffId': staffId,
        'payrollId': payrollId,
        'name': name,
        'section': section,
        'campus': campus,
        'jobTitle': jobTitle,
        'department': department,
        'employmentType': employmentType,
        'employmentStatus': employmentStatus,
        'hireDate': hireDate,
        'qualification': qualification,
        'professionalId': professionalId,
        'phone': phone,
        'email': email,
        'nextOfKin': nextOfKin,
        'emergencyPhone': emergencyPhone,
        'attendance': attendance,
        'punctuality': punctuality,
        'weeklyPeriods': weeklyPeriods,
        'workload': workload,
        'classResponsibility': classResponsibility,
        'subjects': subjects,
        'assignments': assignments.map((e) => e.toJson()).toList(),
        'leave': leave.map((e) => e.toJson()).toList(),
        'documents': documents.map((e) => e.toJson()).toList(),
        'timeline': timeline.map((e) => e.toJson()).toList(),
        'supportNote': supportNote,
      };

  factory PrincipalTeacherProfile.fromJson(Map<String, dynamic> json) => PrincipalTeacherProfile(
        directoryId: json['directoryId'] as String,
        staffId: json['staffId'] as String,
        payrollId: json['payrollId'] as String,
        name: json['name'] as String,
        section: json['section'] as String,
        campus: json['campus'] as String,
        jobTitle: json['jobTitle'] as String,
        department: json['department'] as String,
        employmentType: json['employmentType'] as String,
        employmentStatus: json['employmentStatus'] as String,
        hireDate: json['hireDate'] as String,
        qualification: json['qualification'] as String,
        professionalId: json['professionalId'] as String,
        phone: json['phone'] as String,
        email: json['email'] as String,
        nextOfKin: json['nextOfKin'] as String,
        emergencyPhone: json['emergencyPhone'] as String,
        attendance: json['attendance'] as int,
        punctuality: json['punctuality'] as int,
        weeklyPeriods: json['weeklyPeriods'] as int,
        workload: json['workload'] as String,
        classResponsibility: json['classResponsibility'] as String,
        subjects: (json['subjects'] as List).cast<String>(),
        assignments: (json['assignments'] as List).map((e) => PrincipalTeacherAssignment.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        leave: (json['leave'] as List).map((e) => PrincipalTeacherLeave.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        documents: (json['documents'] as List).map((e) => PrincipalTeacherDocument.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        timeline: (json['timeline'] as List).map((e) => PrincipalTeacherTimelineItem.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        supportNote: json['supportNote'] as String,
      );
}

class PrincipalTeacherNote {
  const PrincipalTeacherNote({required this.teacherId, required this.text});
  final String teacherId;
  final String text;
  Map<String, Object?> toJson() => {'teacherId': teacherId, 'text': text};
  factory PrincipalTeacherNote.fromJson(Map<String, dynamic> json) => PrincipalTeacherNote(teacherId: json['teacherId'] as String, text: json['text'] as String);
}

class PrincipalTeacherPermissions {
  const PrincipalTeacherPermissions({required this.canReviewSecondaryTeachers, required this.canSavePrivateNotes, required this.canViewConfidentialPayroll});
  final bool canReviewSecondaryTeachers;
  final bool canSavePrivateNotes;
  final bool canViewConfidentialPayroll;
}
