class PrincipalNavItem {
  const PrincipalNavItem({required this.key, required this.label});

  final String key;
  final String label;
}

class PrincipalKpi {
  const PrincipalKpi({required this.label, required this.value, required this.hint});

  final String label;
  final String value;
  final String hint;
}

/// One real teaching submission or leadership action awaiting the Principal's review, from the
/// real Approvals queue.
class PrincipalDashboardApprovalItem {
  const PrincipalDashboardApprovalItem({
    required this.type,
    required this.title,
    required this.teacher,
    required this.age,
    required this.priority,
  });

  final String type;
  final String title;
  final String teacher;
  final String age;
  final String priority;
}

/// A real Secondary teacher's real, honestly-recorded oversight indicators (see the Teachers
/// screen: everything here is `0`/`'Not recorded yet'` until real teaching evidence exists).
class PrincipalTeacherIndicator {
  const PrincipalTeacherIndicator({
    required this.name,
    required this.subject,
    required this.compliance,
    required this.syllabus,
    required this.status,
  });

  final String name;
  final String subject;
  final int compliance;
  final int syllabus;
  final String status;

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return '$name $subject $status'.toLowerCase().contains(normalized);
  }
}

/// A real Secondary class's real academic/attendance/syllabus standing (see the Academics
/// screen).
class PrincipalClassIndicator {
  const PrincipalClassIndicator({
    required this.name,
    required this.average,
    required this.attendance,
    required this.syllabus,
    required this.status,
  });

  final String name;
  final int average;
  final int attendance;
  final int syllabus;
  final String status;
}

/// Always empty: flagging a genuine leadership alert needs human judgement over a pattern
/// nothing in the app infers automatically (the same reasoning already applied to Academics'
/// risk queue, Performance's priorities and Principal AI's priority signals).
class PrincipalAlert {
  const PrincipalAlert({required this.title, required this.detail, this.warning = false});

  final String title;
  final String detail;
  final bool warning;
}

class PrincipalPermissions {
  const PrincipalPermissions({
    required this.canLeadSecondary,
    required this.canApproveAcademicWork,
    required this.canGovernWholeSchool,
    required this.canLeadPrimary,
  });

  final bool canLeadSecondary;
  final bool canApproveAcademicWork;
  final bool canGovernWholeSchool;
  final bool canLeadPrimary;
}
