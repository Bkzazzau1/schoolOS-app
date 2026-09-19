enum LessonPlanGenerationMode {
  offlineTemplate,
  edgeAi,
  cloudEnhanced,
}

class LessonPlanRequest {
  const LessonPlanRequest({
    required this.schoolId,
    required this.className,
    required this.subject,
    required this.topic,
    required this.durationMinutes,
    required this.term,
    required this.week,
    this.learningObjectives = const [],
    this.availableResources = const [],
    this.schemeOfWorkContext,
    this.schoolTemplateName,
  });

  final String schoolId;
  final String className;
  final String subject;
  final String topic;
  final int durationMinutes;
  final String term;
  final int week;
  final List<String> learningObjectives;
  final List<String> availableResources;
  final String? schemeOfWorkContext;
  final String? schoolTemplateName;

  Map<String, Object?> toJson() {
    return {
      'schoolId': schoolId,
      'className': className,
      'subject': subject,
      'topic': topic,
      'durationMinutes': durationMinutes,
      'term': term,
      'week': week,
      'learningObjectives': learningObjectives,
      'availableResources': availableResources,
      'schemeOfWorkContext': schemeOfWorkContext,
      'schoolTemplateName': schoolTemplateName,
    };
  }
}

class LessonPlanDraft {
  const LessonPlanDraft({
    required this.title,
    required this.objectives,
    required this.priorKnowledge,
    required this.materials,
    required this.introduction,
    required this.teacherActivities,
    required this.studentActivities,
    required this.assessment,
    required this.homework,
    required this.mode,
  });

  final String title;
  final List<String> objectives;
  final String priorKnowledge;
  final List<String> materials;
  final List<String> introduction;
  final List<String> teacherActivities;
  final List<String> studentActivities;
  final List<String> assessment;
  final String homework;
  final LessonPlanGenerationMode mode;

  LessonPlanDraft copyWith({
    String? title,
    List<String>? objectives,
    String? priorKnowledge,
    List<String>? materials,
    List<String>? introduction,
    List<String>? teacherActivities,
    List<String>? studentActivities,
    List<String>? assessment,
    String? homework,
    LessonPlanGenerationMode? mode,
  }) {
    return LessonPlanDraft(
      title: title ?? this.title,
      objectives: objectives ?? this.objectives,
      priorKnowledge: priorKnowledge ?? this.priorKnowledge,
      materials: materials ?? this.materials,
      introduction: introduction ?? this.introduction,
      teacherActivities: teacherActivities ?? this.teacherActivities,
      studentActivities: studentActivities ?? this.studentActivities,
      assessment: assessment ?? this.assessment,
      homework: homework ?? this.homework,
      mode: mode ?? this.mode,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'title': title,
      'objectives': objectives,
      'priorKnowledge': priorKnowledge,
      'materials': materials,
      'introduction': introduction,
      'teacherActivities': teacherActivities,
      'studentActivities': studentActivities,
      'assessment': assessment,
      'homework': homework,
      'mode': mode.name,
    };
  }

  factory LessonPlanDraft.fromJson(Map<String, dynamic> json) {
    List<String> stringList(String key) {
      final value = json[key];
      if (value is! List) return const [];
      return value.whereType<String>().toList(growable: false);
    }

    return LessonPlanDraft(
      title: json['title'] as String? ?? '',
      objectives: stringList('objectives'),
      priorKnowledge: json['priorKnowledge'] as String? ?? '',
      materials: stringList('materials'),
      introduction: stringList('introduction'),
      teacherActivities: stringList('teacherActivities'),
      studentActivities: stringList('studentActivities'),
      assessment: stringList('assessment'),
      homework: json['homework'] as String? ?? '',
      mode: LessonPlanGenerationMode.values.byName(
        json['mode'] as String? ?? LessonPlanGenerationMode.offlineTemplate.name,
      ),
    );
  }
}
