class AdministratorSubject {
  const AdministratorSubject({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.isActive,
    this.pendingSync = false,
  });

  final String id;
  final String code;
  final String name;
  final String description;
  final bool isActive;
  final bool pendingSync;

  Map<String, Object?> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'description': description,
        'isActive': isActive,
      };

  factory AdministratorSubject.fromJson(
    Map<String, Object?> json, {
    bool pendingSync = false,
  }) =>
      AdministratorSubject(
        id: json['id'] as String? ?? '',
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        isActive: json['isActive'] as bool? ?? true,
        pendingSync: pendingSync,
      );
}

class AdministratorClassSubject {
  const AdministratorClassSubject({
    required this.id,
    required this.sessionId,
    required this.classId,
    required this.className,
    required this.subjectId,
    required this.subjectCode,
    required this.subjectName,
    required this.requirement,
    required this.periodsPerWeek,
    required this.isActive,
    this.pendingSync = false,
  });

  final String id;
  final String sessionId;
  final String classId;
  final String className;
  final String subjectId;
  final String subjectCode;
  final String subjectName;
  final String requirement;
  final int periodsPerWeek;
  final bool isActive;
  final bool pendingSync;

  bool get compulsory => requirement == 'compulsory';
  bool get elective => requirement == 'elective';

  Map<String, Object?> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'classId': classId,
        'subjectId': subjectId,
        'requirement': requirement,
        'periodsPerWeek': periodsPerWeek,
        'isActive': isActive,
      };

  factory AdministratorClassSubject.fromJson(
    Map<String, Object?> json, {
    bool pendingSync = false,
  }) =>
      AdministratorClassSubject(
        id: json['id'] as String? ?? '',
        sessionId: json['sessionId'] as String? ?? '',
        classId: json['classId'] as String? ?? '',
        className: json['className'] as String? ?? '',
        subjectId: json['subjectId'] as String? ?? '',
        subjectCode: json['subjectCode'] as String? ?? '',
        subjectName: json['subjectName'] as String? ?? '',
        requirement: json['requirement'] as String? ?? 'compulsory',
        periodsPerWeek: json['periodsPerWeek'] as int? ?? 1,
        isActive: json['isActive'] as bool? ?? true,
        pendingSync: pendingSync,
      );
}

class AdministratorStudentSubjectSelection {
  const AdministratorStudentSubjectSelection({
    required this.id,
    required this.studentId,
    required this.classSubjectId,
    required this.selected,
    this.pendingSync = false,
  });

  final String id;
  final String studentId;
  final String classSubjectId;
  final bool selected;
  final bool pendingSync;

  Map<String, Object?> toJson() => {
        'id': id,
        'studentId': studentId,
        'classSubjectId': classSubjectId,
        'selected': selected,
      };

  factory AdministratorStudentSubjectSelection.fromJson(
    Map<String, Object?> json, {
    bool pendingSync = false,
  }) =>
      AdministratorStudentSubjectSelection(
        id: json['id'] as String? ?? '',
        studentId: json['studentId'] as String? ?? '',
        classSubjectId: json['classSubjectId'] as String? ?? '',
        selected: json['selected'] as bool? ?? false,
        pendingSync: pendingSync,
      );
}

class AdministratorCurriculumSnapshot {
  const AdministratorCurriculumSnapshot({
    required this.subjects,
    required this.classSubjects,
    required this.selections,
  });

  final List<AdministratorSubject> subjects;
  final List<AdministratorClassSubject> classSubjects;
  final List<AdministratorStudentSubjectSelection> selections;

  bool isSelected(String studentId, String classSubjectId) => selections.any(
        (item) =>
            item.studentId == studentId &&
            item.classSubjectId == classSubjectId &&
            item.selected,
      );
}
