import '../domain/lesson_plan_models.dart';

class OfflineLessonPlanGenerator {
  const OfflineLessonPlanGenerator();

  LessonPlanDraft generate(LessonPlanRequest request) {
    final objectives = request.learningObjectives.isNotEmpty
        ? request.learningObjectives
        : [
            'Explain the meaning of ${request.topic}.',
            'Identify the main ideas or components of ${request.topic}.',
            'Apply the lesson concept through a guided class activity.',
          ];

    final materials = request.availableResources.isNotEmpty
        ? request.availableResources
        : const ['Whiteboard', 'Marker', 'Relevant textbook or class notes'];

    return LessonPlanDraft(
      title:
          '${request.subject} · ${request.className} · ${request.topic} · Week ${request.week}',
      objectives: objectives,
      priorKnowledge:
          'Teacher briefly connects the topic to the most relevant concept students studied previously.',
      materials: materials,
      introduction: [
        'Begin with a short question or familiar example related to ${request.topic}.',
        'Invite two or three student responses and connect them to the lesson objective.',
      ],
      teacherActivities: [
        'Introduce ${request.topic} in clear steps using examples appropriate for ${request.className}.',
        'Explain the key terms and demonstrate one worked or practical example.',
        'Guide students through a short activity and correct misconceptions as they appear.',
      ],
      studentActivities: [
        'Respond to the opening question and share prior knowledge.',
        'Follow the explanation and record key points.',
        'Complete the guided activity individually or in small groups.',
      ],
      assessment: [
        'Ask at least three oral or written questions directly linked to the lesson objectives.',
        'Check whether students can explain the central idea of ${request.topic} without prompting.',
      ],
      homework:
          'Complete a short follow-up exercise on ${request.topic} and prepare one question for the next lesson.',
      mode: LessonPlanGenerationMode.offlineTemplate,
    );
  }
}
