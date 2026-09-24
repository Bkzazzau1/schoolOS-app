import '../../administrator/domain/report_card_models.dart';

enum ParentLearningStatus {
  strong('Strong'),
  stable('Stable'),
  watch('Watch'),
  needsSupport('Needs support');

  const ParentLearningStatus(this.label);

  final String label;

  static ParentLearningStatus fromJson(String value) {
    return ParentLearningStatus.values.firstWhere(
      (item) => item.label == value,
      orElse: () => ParentLearningStatus.stable,
    );
  }
}

class ParentLearningSubjectEvidence {
  const ParentLearningSubjectEvidence({
    required this.subject,
    required this.examPercent,
    required this.classworkPercent,
    required this.assignmentPercent,
    required this.trendLabel,
  });

  final String subject;
  final int examPercent;
  final int classworkPercent;
  final int assignmentPercent;
  final String trendLabel;

  Map<String, Object?> toJson() => {
        'subject': subject,
        'examPercent': examPercent,
        'classworkPercent': classworkPercent,
        'assignmentPercent': assignmentPercent,
        'trendLabel': trendLabel,
      };

  factory ParentLearningSubjectEvidence.fromJson(Map<String, dynamic> json) =>
      ParentLearningSubjectEvidence(
        subject: json['subject'] as String,
        examPercent: (json['examPercent'] as num).toInt(),
        classworkPercent: (json['classworkPercent'] as num).toInt(),
        assignmentPercent: (json['assignmentPercent'] as num).toInt(),
        trendLabel: json['trendLabel'] as String,
      );
}

class ParentLearningTopic {
  const ParentLearningTopic({
    required this.name,
    required this.scorePercent,
    required this.note,
  });

  final String name;
  final int scorePercent;
  final String note;

  Map<String, Object?> toJson() => {
        'name': name,
        'scorePercent': scorePercent,
        'note': note,
      };

  factory ParentLearningTopic.fromJson(Map<String, dynamic> json) =>
      ParentLearningTopic(
        name: json['name'] as String,
        scorePercent: (json['scorePercent'] as num).toInt(),
        note: json['note'] as String,
      );
}

class ParentLearningEvidenceItem {
  const ParentLearningEvidenceItem({
    required this.label,
    required this.value,
    required this.note,
  });

  final String label;
  final String value;
  final String note;

  Map<String, Object?> toJson() => {
        'label': label,
        'value': value,
        'note': note,
      };

  factory ParentLearningEvidenceItem.fromJson(Map<String, dynamic> json) =>
      ParentLearningEvidenceItem(
        label: json['label'] as String,
        value: json['value'] as String,
        note: json['note'] as String,
      );
}

class ParentLearningTimelineEvent {
  const ParentLearningTimelineEvent({
    required this.dateLabel,
    required this.title,
    required this.detail,
  });

  final String dateLabel;
  final String title;
  final String detail;

  Map<String, Object?> toJson() => {
        'dateLabel': dateLabel,
        'title': title,
        'detail': detail,
      };

  factory ParentLearningTimelineEvent.fromJson(Map<String, dynamic> json) =>
      ParentLearningTimelineEvent(
        dateLabel: json['dateLabel'] as String,
        title: json['title'] as String,
        detail: json['detail'] as String,
      );
}

class ParentLearningChild {
  const ParentLearningChild({
    required this.id,
    required this.name,
    required this.className,
    required this.section,
    required this.averagePercent,
    required this.attendancePercent,
    required this.trendPercent,
    required this.status,
    required this.history,
    required this.subjects,
    required this.topics,
    required this.evidence,
    required this.timeline,
    required this.insight,
    required this.actions,
    this.reportCard,
  });

  final String id;
  final String name;
  final String className;
  final String section;
  final int averagePercent;
  final int attendancePercent;
  final double trendPercent;
  final ParentLearningStatus status;
  final List<int> history;
  final List<ParentLearningSubjectEvidence> subjects;
  final List<ParentLearningTopic> topics;
  final List<ParentLearningEvidenceItem> evidence;
  final List<ParentLearningTimelineEvent> timeline;
  final String insight;
  final List<String> actions;

  /// This term's released report card, if the school has compiled and
  /// released one. Null otherwise - never fabricated from per-assessment
  /// evidence above.
  final ReportCard? reportCard;

  bool get improving => trendPercent > 0;

  String get trendLabel {
    final prefix = trendPercent > 0 ? '+' : '';
    return '$prefix${trendPercent.toStringAsFixed(1)}%';
  }

  ParentLearningTopic? get strongestTopic {
    if (topics.isEmpty) return null;
    return topics.reduce(
      (current, next) =>
          next.scorePercent > current.scorePercent ? next : current,
    );
  }

  ParentLearningTopic? get priorityTopic {
    if (topics.isEmpty) return null;
    return topics.reduce(
      (current, next) =>
          next.scorePercent < current.scorePercent ? next : current,
    );
  }

  ParentLearningEvidenceItem? get assignmentEvidence {
    for (final item in evidence) {
      if (item.label.toLowerCase() == 'assignments') return item;
    }
    return evidence.length > 2 ? evidence[2] : null;
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'className': className,
        'section': section,
        'averagePercent': averagePercent,
        'attendancePercent': attendancePercent,
        'trendPercent': trendPercent,
        'status': status.label,
        'history': history,
        'subjects': subjects.map((item) => item.toJson()).toList(),
        'topics': topics.map((item) => item.toJson()).toList(),
        'evidence': evidence.map((item) => item.toJson()).toList(),
        'timeline': timeline.map((item) => item.toJson()).toList(),
        'insight': insight,
        'actions': actions,
      };

  factory ParentLearningChild.fromJson(Map<String, dynamic> json) =>
      ParentLearningChild(
        id: json['id'] as String,
        name: json['name'] as String,
        className: json['className'] as String,
        section: json['section'] as String,
        averagePercent: (json['averagePercent'] as num).toInt(),
        attendancePercent: (json['attendancePercent'] as num).toInt(),
        trendPercent: (json['trendPercent'] as num).toDouble(),
        status: ParentLearningStatus.fromJson(json['status'] as String),
        history: (json['history'] as List<dynamic>)
            .map((item) => (item as num).toInt())
            .toList(growable: false),
        subjects: (json['subjects'] as List<dynamic>)
            .map(
              (item) => ParentLearningSubjectEvidence.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(growable: false),
        topics: (json['topics'] as List<dynamic>)
            .map(
              (item) => ParentLearningTopic.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(growable: false),
        evidence: (json['evidence'] as List<dynamic>)
            .map(
              (item) => ParentLearningEvidenceItem.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(growable: false),
        timeline: (json['timeline'] as List<dynamic>)
            .map(
              (item) => ParentLearningTimelineEvent.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(growable: false),
        insight: json['insight'] as String,
        actions: (json['actions'] as List<dynamic>)
            .map((item) => item as String)
            .toList(growable: false),
      );
}

class ParentLearningProgressSnapshot {
  const ParentLearningProgressSnapshot({
    required this.familyAccountId,
    required this.children,
  });

  final String familyAccountId;
  final List<ParentLearningChild> children;

  ParentLearningChild? childById(String childId) {
    for (final child in children) {
      if (child.id == childId) return child;
    }
    return null;
  }

  Map<String, Object?> toJson() => {
        'familyAccountId': familyAccountId,
        'children': children.map((child) => child.toJson()).toList(),
      };

  factory ParentLearningProgressSnapshot.fromJson(Map<String, dynamic> json) =>
      ParentLearningProgressSnapshot(
        familyAccountId: json['familyAccountId'] as String,
        children: (json['children'] as List<dynamic>)
            .map(
              (item) => ParentLearningChild.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(growable: false),
      );
}
