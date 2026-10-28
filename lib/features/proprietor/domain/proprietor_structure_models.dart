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
    required this.campusId,
    required this.leaderTitle,
    required this.leaderName,
    required this.classes,
  });

  final String id;
  final String name;
  final String stage;

  /// A real [Campus.id], or '' when this section has not been assigned to one yet.
  final String campusId;
  final String leaderTitle;
  final String leaderName;
  final int classes;

  AcademicSection copyWith({
    String? leaderTitle,
    String? leaderName,
    String? campusId,
  }) {
    return AcademicSection(
      id: id,
      name: name,
      stage: stage,
      campusId: campusId ?? this.campusId,
      leaderTitle: leaderTitle ?? this.leaderTitle,
      leaderName: leaderName ?? this.leaderName,
      classes: classes,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'stage': stage,
        'campusId': campusId,
        'leaderTitle': leaderTitle,
        'leaderName': leaderName,
        'classes': classes,
      };

  factory AcademicSection.fromJson(Map<String, Object?> json) {
    return AcademicSection(
      id: json['id']! as String,
      name: json['name']! as String,
      stage: json['stage']! as String,
      campusId: json['campusId'] as String? ?? '',
      leaderTitle: json['leaderTitle']! as String,
      leaderName: json['leaderName']! as String,
      classes: json['classes']! as int,
    );
  }
}

/// One of the school's real physical sites. A section may be assigned to one (see
/// [AcademicSection.campusId]); staff belong to a campus only through their section.
class Campus {
  const Campus({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, Object?> toJson() => {'id': id, 'name': name};

  factory Campus.fromJson(Map<String, Object?> json) => Campus(
        id: json['id']! as String,
        name: json['name']! as String,
      );
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
