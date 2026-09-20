class TeacherLearningTopicEvidence {
  const TeacherLearningTopicEvidence({
    required this.name,
    required this.classwork,
    required this.assignment,
    required this.assessment,
    required this.cbt,
    required this.trend,
  });

  final String name;
  final int classwork;
  final int assignment;
  final int assessment;
  final int cbt;
  final int trend;

  int get combined =>
      ((classwork + assignment + assessment + cbt) / 4).round();

  bool get isDeclining => trend < 0;

  Map<String, Object?> toJson() => {
        'name': name,
        'classwork': classwork,
        'assignment': assignment,
        'assessment': assessment,
        'cbt': cbt,
        'trend': trend,
      };

  factory TeacherLearningTopicEvidence.fromJson(Map<String, dynamic> json) =>
      TeacherLearningTopicEvidence(
        name: json['name'] as String,
        classwork: json['classwork'] as int,
        assignment: json['assignment'] as int,
        assessment: json['assessment'] as int,
        cbt: json['cbt'] as int,
        trend: json['trend'] as int,
      );
}

class TeacherLearningStudentEvidence {
  const TeacherLearningStudentEvidence({
    required this.id,
    required this.name,
    required this.className,
    required this.subject,
    required this.average,
    required this.attendance,
    required this.topics,
  });

  final String id;
  final String name;
  final String className;
  final String subject;
  final int average;
  final int attendance;
  final List<TeacherLearningTopicEvidence> topics;

  TeacherLearningTopicEvidence get weakestTopic {
    final ordered = [...topics]..sort((a, b) => a.combined.compareTo(b.combined));
    return ordered.first;
  }

  TeacherLearningTopicEvidence get strongestTopic {
    final ordered = [...topics]..sort((a, b) => b.combined.compareTo(a.combined));
    return ordered.first;
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'className': className,
        'subject': subject,
        'average': average,
        'attendance': attendance,
        'topics': topics.map((item) => item.toJson()).toList(),
      };

  factory TeacherLearningStudentEvidence.fromJson(Map<String, dynamic> json) =>
      TeacherLearningStudentEvidence(
        id: json['id'] as String,
        name: json['name'] as String,
        className: json['className'] as String,
        subject: json['subject'] as String,
        average: json['average'] as int,
        attendance: json['attendance'] as int,
        topics: (json['topics'] as List<dynamic>)
            .map((item) => TeacherLearningTopicEvidence.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ))
            .toList(growable: false),
      );
}

class TeacherLearningSupportAction {
  const TeacherLearningSupportAction({
    required this.student,
    required this.topic,
    required this.detail,
    required this.actionLabel,
    required this.destination,
  });

  final String student;
  final String topic;
  final String detail;
  final String actionLabel;
  final String destination;
}

class TeacherLearningProgressPermissions {
  const TeacherLearningProgressPermissions({
    required this.canViewAssignedLearners,
    required this.canViewMultiEvidence,
    required this.canSuggestSupport,
    required this.canPubliclyRankChildren,
    required this.canDiagnoseCondition,
    required this.canMakePromotionDecision,
    required this.canMakePunishmentDecision,
  });

  final bool canViewAssignedLearners;
  final bool canViewMultiEvidence;
  final bool canSuggestSupport;
  final bool canPubliclyRankChildren;
  final bool canDiagnoseCondition;
  final bool canMakePromotionDecision;
  final bool canMakePunishmentDecision;
}
