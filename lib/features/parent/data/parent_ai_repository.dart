import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../events/data/event_repository.dart';
import '../domain/parent_ai_models.dart';
import 'parent_ai_demo_data.dart';
import 'parent_ai_facts.dart';
import 'parent_attendance_repository.dart';
import 'parent_children_repository.dart';
import 'parent_finance_repository.dart';
import 'parent_learning_progress_repository.dart';
import 'parent_messages_repository.dart';

class ParentAIRepository {
  /// [localDatabase] is accepted for constructor consistency with every other Parent repository,
  /// even though this one only ever reads through the real repositories below and never touches the
  /// local database directly itself.
  ParentAIRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required ParentChildrenRepository children,
    required ParentAttendanceRepository attendance,
    required ParentFinanceRepository finance,
    required ParentLearningProgressRepository learning,
    required EventRepository events,
    required ParentMessagesRepository messages,
  })  : _schoolSession = schoolSession,
        _children = children,
        _attendance = attendance,
        _finance = finance,
        _learning = learning,
        _events = events,
        _messages = messages;

  final SchoolSessionController _schoolSession;
  final ParentChildrenRepository _children;
  final ParentAttendanceRepository _attendance;
  final ParentFinanceRepository _finance;
  final ParentLearningProgressRepository _learning;
  final EventRepository _events;
  final ParentMessagesRepository _messages;

  /// Reads the same real repositories every other Parent screen reads
  /// ([ParentAiFacts]/[loadParentAiFacts]) and answers every suggestion through the same
  /// keyword-matched, honest-refusal engine ([ParentAiService]) a free-text question would use —
  /// never a fixed canned answer that could drift from what My Children, Attendance, Finance,
  /// Learning Progress or Messages themselves show.
  Future<ParentAISnapshot> load() async {
    final membership = _requireParentMembership();
    final service = ParentAiService(await _facts());

    final suggestions = [
      for (final prompt in parentAiPrompts)
        ParentAISuggestion(prompt: prompt, answer: service.answer(prompt).answer),
    ];

    return ParentAISnapshot(
      familyAccountId: membership.id,
      assistantName: 'Family Assistant',
      description: 'Answers attendance, learning, payment, event and message questions from your real, '
          'family-visible SchoolOS records. It explains what is recorded, what is not, and when to '
          'contact the school.',
      defaultPrompt: parentAiPrompts.first,
      defaultAnswer: suggestions.first.answer,
      suggestions: suggestions,
      privacyBoundary: parentAIPrivacyBoundary,
      decisionBoundary: parentAIDecisionBoundary,
    );
  }

  Future<ParentAIResponse> answer(String question) async {
    final normalizedQuestion = question.trim();
    if (normalizedQuestion.isEmpty) {
      throw ArgumentError.value(question, 'question', 'A question is required.');
    }
    if (normalizedQuestion.length > 1000) {
      throw ArgumentError.value(
        question,
        'question',
        'Parent AI questions cannot exceed 1000 characters.',
      );
    }

    _requireParentMembership();
    final service = ParentAiService(await _facts());
    final result = service.answer(normalizedQuestion);
    return ParentAIResponse(
      question: result.question,
      answer: result.answer,
      isGroundedInCachedFamilyContext: result.isGroundedInCachedFamilyContext,
    );
  }

  Future<ParentAiFacts> _facts() => loadParentAiFacts(
        children: _children,
        attendance: _attendance,
        finance: _finance,
        learning: _learning,
        events: _events,
        messages: _messages,
      );

  SchoolMembership _requireParentMembership() {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.parent) {
      throw StateError('Parent AI requires an active Parent membership.');
    }
    return membership;
  }
}
