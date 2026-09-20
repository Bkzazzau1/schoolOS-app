class ParentWeeklySubjectUpdate {
  const ParentWeeklySubjectUpdate({
    required this.subject,
    required this.thisWeek,
    required this.learningEvidence,
    required this.nextTopic,
    required this.practiceNote,
  });

  final String subject;
  final String thisWeek;
  final String learningEvidence;
  final String nextTopic;
  final String practiceNote;

  Map<String, Object?> toJson() => {
        'subject': subject,
        'thisWeek': thisWeek,
        'learningEvidence': learningEvidence,
        'nextTopic': nextTopic,
        'practiceNote': practiceNote,
      };

  factory ParentWeeklySubjectUpdate.fromJson(Map<String, dynamic> json) =>
      ParentWeeklySubjectUpdate(
        subject: json['subject'] as String,
        thisWeek: json['thisWeek'] as String,
        learningEvidence: json['learningEvidence'] as String,
        nextTopic: json['nextTopic'] as String,
        practiceNote: json['practiceNote'] as String,
      );
}

class ParentWeeklyLearningUpdate {
  const ParentWeeklyLearningUpdate({
    required this.id,
    required this.weekLabel,
    required this.dateLabel,
    required this.childId,
    required this.childName,
    required this.className,
    required this.teacher,
    required this.teacherNote,
    required this.subjects,
    this.published = true,
  });

  final String id;
  final String weekLabel;
  final String dateLabel;
  final String childId;
  final String childName;
  final String className;
  final String teacher;
  final String teacherNote;
  final List<ParentWeeklySubjectUpdate> subjects;
  final bool published;

  Map<String, Object?> toJson() => {
        'id': id,
        'weekLabel': weekLabel,
        'dateLabel': dateLabel,
        'childId': childId,
        'childName': childName,
        'className': className,
        'teacher': teacher,
        'teacherNote': teacherNote,
        'subjects': subjects.map((item) => item.toJson()).toList(),
        'published': published,
      };

  factory ParentWeeklyLearningUpdate.fromJson(Map<String, dynamic> json) =>
      ParentWeeklyLearningUpdate(
        id: json['id'] as String,
        weekLabel: json['weekLabel'] as String,
        dateLabel: json['dateLabel'] as String,
        childId: json['childId'] as String,
        childName: json['childName'] as String,
        className: json['className'] as String,
        teacher: json['teacher'] as String,
        teacherNote: json['teacherNote'] as String,
        subjects: (json['subjects'] as List<dynamic>)
            .map(
              (item) => ParentWeeklySubjectUpdate.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(growable: false),
        published: json['published'] as bool? ?? true,
      );
}

class ParentWeeklyLearningChild {
  const ParentWeeklyLearningChild({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}

class ParentWeeklyLearningSnapshot {
  const ParentWeeklyLearningSnapshot({
    required this.familyAccountId,
    required this.updates,
  });

  final String familyAccountId;
  final List<ParentWeeklyLearningUpdate> updates;

  List<ParentWeeklyLearningChild> get children {
    final seen = <String>{};
    final result = <ParentWeeklyLearningChild>[];
    for (final update in updates) {
      if (seen.add(update.childId)) {
        result.add(
          ParentWeeklyLearningChild(id: update.childId, name: update.childName),
        );
      }
    }
    return List.unmodifiable(result);
  }

  List<ParentWeeklyLearningUpdate> updatesForChild(String childId) => updates
      .where((update) => update.childId == childId && update.published)
      .toList(growable: false);

  ParentWeeklyLearningUpdate? updateById(String id) {
    for (final update in updates) {
      if (update.id == id && update.published) return update;
    }
    return null;
  }

  Map<String, Object?> toJson() => {
        'familyAccountId': familyAccountId,
        'updates': updates.map((update) => update.toJson()).toList(),
      };

  factory ParentWeeklyLearningSnapshot.fromJson(Map<String, dynamic> json) =>
      ParentWeeklyLearningSnapshot(
        familyAccountId: json['familyAccountId'] as String,
        updates: (json['updates'] as List<dynamic>)
            .map(
              (item) => ParentWeeklyLearningUpdate.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(growable: false),
      );
}
