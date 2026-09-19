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

class PrincipalApprovalItem {
  const PrincipalApprovalItem({
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
