import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/principal/data/principal_teachers_demo_data.dart';
import 'package:schoolos_app/features/principal/domain/principal_teachers_models.dart';

void main() {
  test('principal teachers seed preserves five exact website teachers', () {
    expect(principalTeachersWebsiteSeed.length, 5);
    expect(principalTeachersWebsiteSeed.map((e) => e.id).toList(), ['TCH-001', 'TCH-002', 'TCH-003', 'TCH-004', 'TCH-005']);
    expect(principalTeachersWebsiteSeed.first.name, 'Mrs. Amina Yusuf');
    expect(principalTeachersWebsiteSeed.last.name, 'Mrs. Hauwa Sani');
  });

  test('principal teacher headline KPIs preserve exact website values', () {
    expect(principalTeacherKpis['Secondary teaching staff'], '24');
    expect(principalTeacherKpis['Staff attendance'], '96%');
    expect(principalTeacherKpis['Needs support'], '1');
    expect(principalTeacherKpis['Pending teacher work'], '10');
    expect(principalTeacherKpis['Lesson-plan compliance'], '89%');
    expect(principalTeacherKpis['Assessment completion'], '85%');
  });

  test('teacher filters preserve department status and search behavior', () {
    final teachers = principalTeachersWebsiteSeed;
    expect(teachers.where((t) => t.matches(query: 'physics', departmentFilter: 'All departments', statusFilter: 'All statuses')).single.id, 'TCH-004');
    expect(teachers.where((t) => t.matches(query: '', departmentFilter: 'Mathematics', statusFilter: 'All statuses')).length, 2);
    expect(teachers.where((t) => t.matches(query: '', departmentFilter: 'All departments', statusFilter: 'Strong')).length, 2);
    expect(teachers.where((t) => t.matches(query: '', departmentFilter: 'Science', statusFilter: 'Needs support')).single.name, 'Mr. Bashir Musa');
  });

  test('selected teacher metrics preserve workload and support evidence', () {
    final bashir = principalTeachersWebsiteSeed.singleWhere((e) => e.id == 'TCH-004');
    expect(bashir.attendance, 89);
    expect(bashir.punctuality, 84);
    expect(bashir.lessonPlans, 72);
    expect(bashir.syllabus, 62);
    expect(bashir.assessments, 69);
    expect(bashir.pending, 4);
    expect(bashir.status, 'Needs support');
    expect(bashir.note, contains('support conversation'));
  });

  test('five full Secondary profiles and ten website tabs are preserved', () {
    expect(principalTeacherProfilesWebsiteSeed.length, 5);
    expect(principalStaffProfileTabs.length, 10);
    expect(principalStaffProfileTabs, ['Overview', 'Employment', 'Qualifications', 'Teaching Load', 'Attendance', 'Leave', 'Documents', 'Timeline', 'Leadership Notes', 'Payroll Access']);
    final amina = principalTeacherProfilesWebsiteSeed.first;
    expect(amina.staffId, 'TCH-2048');
    expect(amina.payrollId, 'PAY-BGA-2048');
    expect(amina.assignments.length, 4);
    expect(amina.documents.length, 3);
    expect(amina.timeline.length, 3);
  });

  test('teacher and full profile models serialize without losing evidence', () {
    final teacher = principalTeachersWebsiteSeed.first;
    final restoredTeacher = PrincipalTeacher.fromJson(teacher.toJson());
    expect(restoredTeacher.id, teacher.id);
    expect(restoredTeacher.lessonPlans, 92);
    expect(restoredTeacher.workload, 'Heavy');

    final profile = principalTeacherProfilesWebsiteSeed[3];
    final restoredProfile = PrincipalTeacherProfile.fromJson(profile.toJson());
    expect(restoredProfile.directoryId, 'TCH-004');
    expect(restoredProfile.weeklyPeriods, 24);
    expect(restoredProfile.assignments.length, 3);
    expect(restoredProfile.leave.single.type, 'Medical leave');
  });

  test('principal teacher scope remains Secondary only and payroll restricted', () {
    expect(principalTeacherPermissions.canReviewSecondaryTeachers, isTrue);
    expect(principalTeacherPermissions.canSavePrivateNotes, isTrue);
    expect(principalTeacherPermissions.canViewConfidentialPayroll, isFalse);
    expect(principalTeacherGuidance['SECTION SCOPE'], contains('Secondary teachers only'));
    expect(principalTeacherPayrollBoundary, contains('Salary amount'));
    expect(principalTeacherPayrollBoundary, contains('bank account'));
    expect(principalTeacherPayrollBoundary, contains('staff-loan'));
  });

  test('support guidance blocks single-score and automatic high-stakes decisions', () {
    expect(principalTeacherGuidance['SUPPORT FIRST'], contains('coaching'));
    expect(principalTeacherGuidance['SUPPORT FIRST'], contains('rather than reducing quality to one score'));
    expect(principalTeacherDecisionBoundary, contains('Do not use AI or a single metric'));
    expect(principalTeacherDecisionBoundary, contains('firing'));
    expect(principalTeacherDecisionBoundary, contains('disciplinary'));
  });
}
