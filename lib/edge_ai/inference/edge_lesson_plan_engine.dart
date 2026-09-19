import '../../features/lesson_plans/domain/lesson_plan_models.dart';

abstract interface class EdgeLessonPlanEngine {
  /// True when a compatible local model is installed and the current device
  /// has enough resources to run it safely.
  Future<bool> isAvailable();

  /// Improves an already-valid offline draft. Edge AI is never required to
  /// produce a basic lesson plan, so model absence cannot block the teacher.
  Future<LessonPlanDraft> improve({
    required LessonPlanRequest request,
    required LessonPlanDraft baseDraft,
  });
}

class EdgeAiUnavailableException implements Exception {
  const EdgeAiUnavailableException([this.message = 'Edge AI is unavailable.']);

  final String message;

  @override
  String toString() => message;
}
