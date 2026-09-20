enum TeacherStudentRisk { strong, stable, watch, atRisk }

class TeacherStudentSummary {
  const TeacherStudentSummary({
    required this.id,
    required this.name,
    required this.className,
    required this.average,
    required this.attendance,
    required this.trend,
    required this.risk,
    required this.intervention,
    required this.attention,
  });

  final String id;
  final String name;
  final String className;
  final int average;
  final int attendance;
  final double trend;
  final TeacherStudentRisk risk;
  final String intervention;
  final String attention;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return '$name $id $className'.toLowerCase().contains(q);
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'className': className,
        'average': average,
        'attendance': attendance,
        'trend': trend,
        'risk': risk.name,
        'intervention': intervention,
        'attention': attention,
      };

  factory TeacherStudentSummary.fromJson(Map<String, dynamic> json) =>
      TeacherStudentSummary(
        id: json['id'] as String,
        name: json['name'] as String,
        className: json['className'] as String,
        average: (json['average'] as num).toInt(),
        attendance: (json['attendance'] as num).toInt(),
        trend: (json['trend'] as num).toDouble(),
        risk: TeacherStudentRisk.values.byName(json['risk'] as String),
        intervention: json['intervention'] as String,
        attention: json['attention'] as String,
      );
}

class TeacherStudentSubjectEvidence {
  const TeacherStudentSubjectEvidence({
    required this.name,
    required this.score,
    required this.trend,
  });

  final String name;
  final int score;
  final double trend;

  Map<String, Object?> toJson() => {
        'name': name,
        'score': score,
        'trend': trend,
      };

  factory TeacherStudentSubjectEvidence.fromJson(Map<String, dynamic> json) =>
      TeacherStudentSubjectEvidence(
        name: json['name'] as String,
        score: (json['score'] as num).toInt(),
        trend: (json['trend'] as num).toDouble(),
      );
}

class TeacherStudentAttendanceEvidence {
  const TeacherStudentAttendanceEvidence({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  Map<String, Object?> toJson() => {'label': label, 'value': value};

  factory TeacherStudentAttendanceEvidence.fromJson(Map<String, dynamic> json) =>
      TeacherStudentAttendanceEvidence(
        label: json['label'] as String,
        value: json['value'] as String,
      );
}

class TeacherStudentTimelineItem {
  const TeacherStudentTimelineItem({
    required this.date,
    required this.title,
    required this.detail,
    required this.visibility,
  });

  final String date;
  final String title;
  final String detail;
  final String visibility;

  Map<String, Object?> toJson() => {
        'date': date,
        'title': title,
        'detail': detail,
        'visibility': visibility,
      };

  factory TeacherStudentTimelineItem.fromJson(Map<String, dynamic> json) =>
      TeacherStudentTimelineItem(
        date: json['date'] as String,
        title: json['title'] as String,
        detail: json['detail'] as String,
        visibility: json['visibility'] as String,
      );
}

class TeacherStudentProfile {
  const TeacherStudentProfile({
    required this.id,
    required this.admissionNo,
    required this.name,
    required this.className,
    required this.status,
    required this.average,
    required this.attendance,
    required this.trend,
    required this.classTeacher,
    required this.attention,
    required this.subjects,
    required this.attendanceSummary,
    required this.timeline,
  });

  final String id;
  final String admissionNo;
  final String name;
  final String className;
  final String status;
  final int average;
  final int attendance;
  final double trend;
  final String classTeacher;
  final String attention;
  final List<TeacherStudentSubjectEvidence> subjects;
  final List<TeacherStudentAttendanceEvidence> attendanceSummary;
  final List<TeacherStudentTimelineItem> timeline;

  Map<String, Object?> toJson() => {
        'id': id,
        'admissionNo': admissionNo,
        'name': name,
        'className': className,
        'status': status,
        'average': average,
        'attendance': attendance,
        'trend': trend,
        'classTeacher': classTeacher,
        'attention': attention,
        'subjects': subjects.map((item) => item.toJson()).toList(growable: false),
        'attendanceSummary': attendanceSummary
            .map((item) => item.toJson())
            .toList(growable: false),
        'timeline': timeline.map((item) => item.toJson()).toList(growable: false),
      };

  factory TeacherStudentProfile.fromJson(Map<String, dynamic> json) =>
      TeacherStudentProfile(
        id: json['id'] as String,
        admissionNo: json['admissionNo'] as String,
        name: json['name'] as String,
        className: json['className'] as String,
        status: json['status'] as String,
        average: (json['average'] as num).toInt(),
        attendance: (json['attendance'] as num).toInt(),
        trend: (json['trend'] as num).toDouble(),
        classTeacher: json['classTeacher'] as String,
        attention: json['attention'] as String,
        subjects: (json['subjects'] as List<dynamic>)
            .map((item) => TeacherStudentSubjectEvidence.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ))
            .toList(growable: false),
        attendanceSummary: (json['attendanceSummary'] as List<dynamic>)
            .map((item) => TeacherStudentAttendanceEvidence.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ))
            .toList(growable: false),
        timeline: (json['timeline'] as List<dynamic>)
            .map((item) => TeacherStudentTimelineItem.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ))
            .toList(growable: false),
      );
}

class TeacherStudentNote {
  const TeacherStudentNote({
    required this.studentId,
    required this.text,
    required this.version,
    required this.updatedAt,
  });

  final String studentId;
  final String text;
  final int version;
  final String updatedAt;

  TeacherStudentNote copyWith({
    String? text,
    int? version,
    String? updatedAt,
  }) =>
      TeacherStudentNote(
        studentId: studentId,
        text: text ?? this.text,
        version: version ?? this.version,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toJson() => {
        'studentId': studentId,
        'text': text,
        'version': version,
        'updatedAt': updatedAt,
      };

  factory TeacherStudentNote.fromJson(Map<String, dynamic> json) =>
      TeacherStudentNote(
        studentId: json['studentId'] as String,
        text: json['text'] as String,
        version: (json['version'] as num).toInt(),
        updatedAt: json['updatedAt'] as String,
      );
}

class TeacherStudentsPermissions {
  const TeacherStudentsPermissions({
    required this.canViewAssignedStudents,
    required this.canSaveProfessionalNote,
    required this.canUseSchoolContactChannel,
    required this.canViewFinance,
    required this.canViewMedical,
    required this.canViewLeadershipOnlyRecords,
    required this.canChangeStudentStatus,
  });

  final bool canViewAssignedStudents;
  final bool canSaveProfessionalNote;
  final bool canUseSchoolContactChannel;
  final bool canViewFinance;
  final bool canViewMedical;
  final bool canViewLeadershipOnlyRecords;
  final bool canChangeStudentStatus;
}

String teacherStudentRiskLabel(TeacherStudentRisk risk) => switch (risk) {
      TeacherStudentRisk.strong => 'Strong',
      TeacherStudentRisk.stable => 'Stable',
      TeacherStudentRisk.watch => 'Watch',
      TeacherStudentRisk.atRisk => 'At risk',
    };
