import '../../../edge_ai/inference/edge_lesson_plan_engine.dart';
import '../domain/lesson_plan_models.dart';
import 'cloud_lesson_plan_client.dart';
import 'offline_lesson_plan_generator.dart';

class LessonPlanGenerationResult {
  const LessonPlanGenerationResult({
    required this.draft,
    required this.usedEdgeAi,
    required this.usedCloud,
    this.fallbackMessage,
  });

  final LessonPlanDraft draft;
  final bool usedEdgeAi;
  final bool usedCloud;
  final String? fallbackMessage;
}

class LessonPlanGenerationService {
  const LessonPlanGenerationService({
    this.offlineGenerator = const OfflineLessonPlanGenerator(),
    this.edgeEngine,
    this.cloudClient,
  });

  final OfflineLessonPlanGenerator offlineGenerator;
  final EdgeLessonPlanEngine? edgeEngine;
  final CloudLessonPlanClient? cloudClient;

  /// Always creates a valid offline draft first. Optional AI layers are
  /// enhancements only, so a teacher is never blocked by connectivity or a
  /// missing local model.
  Future<LessonPlanGenerationResult> generate(
    LessonPlanRequest request, {
    bool tryEdgeAi = true,
    bool tryCloud = false,
  }) async {
    var draft = offlineGenerator.generate(request);
    var usedEdgeAi = false;
    var usedCloud = false;
    String? fallbackMessage;

    if (tryEdgeAi) {
      final engine = edgeEngine;
      if (engine == null) {
        fallbackMessage =
            'Local AI runtime is not connected yet. Offline draft used.';
      } else {
        try {
          if (await engine.isAvailable()) {
            draft = await engine.improve(
              request: request,
              baseDraft: draft,
            );
            draft = draft.copyWith(mode: LessonPlanGenerationMode.edgeAi);
            usedEdgeAi = true;
          } else {
            fallbackMessage =
                'Local AI model is not installed yet. Offline draft used.';
          }
        } catch (_) {
          fallbackMessage =
              'Local AI could not run. Offline draft used safely.';
        }
      }
    }

    if (tryCloud) {
      final client = cloudClient;
      if (client == null) {
        fallbackMessage ??=
            'Cloud AI is not connected yet. The best local draft is ready.';
      } else {
        try {
          if (await client.isAvailable()) {
            draft = await client.enhance(
              request: request,
              baseDraft: draft,
            );
            draft = draft.copyWith(
              mode: LessonPlanGenerationMode.cloudEnhanced,
            );
            usedCloud = true;
          } else {
            fallbackMessage ??=
                'Cloud AI is unavailable. The best local draft is ready.';
          }
        } catch (_) {
          fallbackMessage ??=
              'Cloud enhancement failed. The best local draft is still ready.';
        }
      }
    }

    return LessonPlanGenerationResult(
      draft: draft,
      usedEdgeAi: usedEdgeAi,
      usedCloud: usedCloud,
      fallbackMessage: fallbackMessage,
    );
  }
}
