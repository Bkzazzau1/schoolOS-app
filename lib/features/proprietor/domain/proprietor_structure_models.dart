enum LeadershipLevel {
  sectionHead,
  deputy,
  hod,
  coordinator;

  String get label => switch (this) {
        sectionHead => 'Section Head',
        deputy => 'Deputy',
        hod => 'HOD',
        coordinator => 'Coordinator',
      };
}

class AcademicSection {
  const AcademicSection({
    required this.id,
    required this.name,
    required this.stage,
    required this.campus,
    required this.leaderTitle,
    required this.leaderName,
    required this.classes,
  });

  final String id;
  final String name;
  final String stage;
  final String campus;
  final String leaderTitle;
  final String leaderName;
  final int classes;

  AcademicSection copyWith({
    String? leaderTitle,
    String? leaderName,
  }) {
    return AcademicSection(
      id: id,
      name: name,
      stage: stage,
      campus: campus,
      leaderTitle: leaderTitle ?? this.leaderTitle,
      leaderName: leaderName ?? this.leaderName,
      classes: classes,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'stage': stage,
        'campus': campus,
        'leaderTitle': leaderTitle,
        'leaderName': leaderName,
        'classes': classes,
      };

  factory AcademicSection.fromJson(Map<String, Object?> json) {
    return AcademicSection(
      id: json['id']! as String,
      name: json['name']! as String,
      stage: json['stage']! as String,
      campus: json['campus']! as String,
      leaderTitle: json['leaderTitle']! as String,
      leaderName: json['leaderName']! as String,
      classes: json['classes']! as int,
    );
  }
}

class LeadershipAppointment {
  const LeadershipAppointment({
    required this.id,
    required this.person,
    required this.title,
    required this.level,
    required this.sectionId,
    this.department,
    this.reportsTo,
  });

  final String id;
  final String person;
  final String title;
  final LeadershipLevel level;
  final String sectionId;
  final String? department;
  final String? reportsTo;

  LeadershipAppointment copyWith({
    String? person,
    String? title,
  }) {
    return LeadershipAppointment(
      id: id,
      person: person ?? this.person,
      title: title ?? this.title,
      level: level,
      sectionId: sectionId,
      department: department,
      reportsTo: reportsTo,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'person': person,
        'title': title,
        'level': level.name,
        'sectionId': sectionId,
        'department': department,
        'reportsTo': reportsTo,
      };

  factory LeadershipAppointment.fromJson(Map<String, Object?> json) {
    return LeadershipAppointment(
      id: json['id']! as String,
      person: json['person']! as String,
      title: json['title']! as String,
      level: LeadershipLevel.values.byName(json['level']! as String),
      sectionId: json['sectionId']! as String,
      department: json['department'] as String?,
      reportsTo: json['reportsTo'] as String?,
    );
  }
}

class AuthorityMatrixRow {
  const AuthorityMatrixRow({
    required this.role,
    required this.students,
    required this.teachers,
    required this.assignments,
    required this.results,
    required this.schoolIdentity,
  });

  final String role;
  final String students;
  final String teachers;
  final String assignments;
  final String results;
  final String schoolIdentity;
}
