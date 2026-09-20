class TeacherClassAssignment {
  const TeacherClassAssignment({
    required this.id,
    required this.name,
    required this.subject,
    required this.students,
    required this.room,
    required this.progress,
    required this.attendance,
    required this.classAverage,
    required this.nextLesson,
    required this.topic,
    required this.pendingMarking,
  });

  final String id;
  final String name;
  final String subject;
  final int students;
  final String room;
  final int progress;
  final int attendance;
  final int classAverage;
  final String nextLesson;
  final String topic;
  final int pendingMarking;

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return '$name $subject $topic'.toLowerCase().contains(normalized);
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'subject': subject,
        'students': students,
        'room': room,
        'progress': progress,
        'attendance': attendance,
        'classAverage': classAverage,
        'nextLesson': nextLesson,
        'topic': topic,
        'pendingMarking': pendingMarking,
      };

  factory TeacherClassAssignment.fromJson(Map<String, dynamic> json) {
    return TeacherClassAssignment(
      id: json['id'] as String,
      name: json['name'] as String,
      subject: json['subject'] as String,
      students: json['students'] as int,
      room: json['room'] as String,
      progress: json['progress'] as int,
      attendance: json['attendance'] as int,
      classAverage: json['classAverage'] as int,
      nextLesson: json['nextLesson'] as String,
      topic: json['topic'] as String,
      pendingMarking: json['pendingMarking'] as int,
    );
  }
}

class TeacherClassPermissions {
  const TeacherClassPermissions({
    required this.canViewAssignedClasses,
    required this.canOpenAuthorizedRoster,
    required this.canChangeClassMembership,
    required this.canChangeAcademicMarksFromClassesPage,
    required this.canAccessFinance,
    required this.canAccessSafeguardingDetails,
  });

  final bool canViewAssignedClasses;
  final bool canOpenAuthorizedRoster;
  final bool canChangeClassMembership;
  final bool canChangeAcademicMarksFromClassesPage;
  final bool canAccessFinance;
  final bool canAccessSafeguardingDetails;
}

class TeacherClassesSnapshot {
  const TeacherClassesSnapshot({
    required this.assignments,
    required this.permissions,
  });

  final List<TeacherClassAssignment> assignments;
  final TeacherClassPermissions permissions;

  int get totalStudents => assignments.fold(0, (sum, item) => sum + item.students);
}
