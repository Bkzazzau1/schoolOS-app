import '../domain/lesson_plan_models.dart';

/// Cloud boundary implemented later by the SchoolOS Django/AI API client.
///
/// The cloud receives an already-valid draft plus authorized school context.
/// This keeps lesson planning usable even when the network or cloud AI is
/// unavailable.
abstract interface class CloudLessonPlanClient {
  Future<bool> isAvailable();

  Future<LessonPlanDraft> enhance({
    required LessonPlanRequest request,
    required LessonPlanDraft baseDraft,
  });
}

class CloudLessonPlanUnavailableException implements Exception {
  const CloudLessonPlanUnavailableException([
    this.message = 'Cloud lesson-plan enhancement is unavailable.',
  ]);

  final String message;

  @override
  String toString() => message;
}
