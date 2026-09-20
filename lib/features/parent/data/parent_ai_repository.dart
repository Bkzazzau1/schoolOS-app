import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/parent_ai_models.dart';
import 'parent_ai_demo_data.dart';

class ParentAIRepository {
  ParentAIRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _entityType = 'parent_ai_snapshot';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  Future<ParentAISnapshot> load() async {
    final membership = _requireParentMembership();
    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: membership.id,
    );

    if (record != null) {
      final snapshot = ParentAISnapshot.fromJson(record.payload);
      _validateSnapshot(snapshot);
      return snapshot;
    }

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: membership.id,
      payload: parentDefaultAI.toJson(),
    );
    return parentDefaultAI;
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

    final snapshot = await load();
    final normalized = normalizedQuestion.toLowerCase();

    ParentAISuggestion? matched;
    for (final suggestion in snapshot.suggestions) {
      final prompt = suggestion.prompt.toLowerCase();
      if (normalized == prompt ||
          _keywords(prompt).where(normalized.contains).length >= 2) {
        matched = suggestion;
        break;
      }
    }

    if (matched != null) {
      return ParentAIResponse(
        question: normalizedQuestion,
        answer: matched.answer,
        isGroundedInCachedFamilyContext: true,
      );
    }

    final familyTopic = _looksLikeFamilyVisibleTopic(normalized);
    return ParentAIResponse(
      question: normalizedQuestion,
      answer: familyTopic
          ? 'I do not have enough family-visible cached evidence to answer that safely. I will not guess. Check the relevant SchoolOS family page or contact the school for clarification.'
          : 'I can help with guardian-visible SchoolOS information such as linked-child attendance, learning updates, payments, approved messages, events and school life. I cannot access private staff notes, other families, restricted safeguarding information or confidential health records.',
      isGroundedInCachedFamilyContext: false,
    );
  }

  Future<void> replaceFromServer({
    required ParentAISnapshot snapshot,
    required int serverVersion,
  }) async {
    final membership = _requireParentMembership();
    _validateSnapshot(snapshot);
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: membership.id,
      payload: snapshot.toJson(),
      serverVersion: serverVersion,
      isDirty: false,
    );
  }

  void _validateSnapshot(ParentAISnapshot snapshot) {
    if (snapshot.familyAccountId.trim().isEmpty ||
        snapshot.assistantName.trim().isEmpty ||
        snapshot.defaultPrompt.trim().isEmpty ||
        snapshot.defaultAnswer.trim().isEmpty) {
      throw StateError('Parent AI snapshot is missing required family context.');
    }

    final prompts = <String>{};
    for (final suggestion in snapshot.suggestions) {
      if (suggestion.prompt.trim().isEmpty ||
          suggestion.answer.trim().isEmpty ||
          !prompts.add(suggestion.prompt.trim().toLowerCase())) {
        throw StateError('Parent AI contains an invalid suggested question.');
      }
    }

    if (snapshot.privacyBoundary.trim().isEmpty ||
        snapshot.decisionBoundary.trim().isEmpty) {
      throw StateError('Parent AI governance boundaries are required.');
    }
  }

  SchoolMembership _requireParentMembership() {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.parent) {
      throw StateError('Parent AI requires an active Parent membership.');
    }
    return membership;
  }

  Set<String> _keywords(String value) {
    const ignored = <String>{
      'how',
      'is',
      'this',
      'the',
      'what',
      'are',
      'has',
      'why',
      'i',
      'may',
      'have',
      'up',
      'term',
    };
    return value
        .replaceAll(RegExp(r"[^a-z0-9 ]"), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.length >= 3 && !ignored.contains(word))
        .toSet();
  }

  bool _looksLikeFamilyVisibleTopic(String value) {
    const terms = <String>[
      'maryam',
      'hafsa',
      'attendance',
      'learning',
      'result',
      'assessment',
      'payment',
      'fee',
      'balance',
      'message',
      'event',
      'school',
      'activity',
      'transport',
      'meal',
      'document',
      'consent',
    ];
    return terms.any(value.contains);
  }
}
