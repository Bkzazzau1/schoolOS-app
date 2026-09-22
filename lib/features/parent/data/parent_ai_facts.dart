import '../../events/data/event_repository.dart';
import '../../events/domain/event_models.dart';
import '../../proprietor/domain/concession_request.dart' show formatNaira;
import '../domain/parent_attendance_models.dart';
import '../domain/parent_children_models.dart';
import '../domain/parent_finance_models.dart';
import '../domain/parent_learning_progress_models.dart';
import '../domain/parent_messages_models.dart';
import 'parent_attendance_repository.dart';
import 'parent_children_repository.dart';
import 'parent_finance_repository.dart';
import 'parent_learning_progress_repository.dart';
import 'parent_messages_repository.dart';

/// Everything Parent AI says, read once from the same real repositories every other Parent screen
/// already reads — so its answers can never disagree with what My Children, Attendance, Finance,
/// Learning Progress or Messages themselves show for the same real family.
class ParentAiFacts {
  const ParentAiFacts({
    required this.children,
    required this.attendance,
    required this.finance,
    required this.learning,
    required this.upcomingEvents,
    required this.messages,
  });

  final List<ParentLinkedChild> children;
  final ParentAttendanceSnapshot attendance;
  final ParentFinanceSnapshot finance;
  final ParentLearningProgressSnapshot learning;
  final List<SchoolEvent> upcomingEvents;
  final ParentMessagesSnapshot messages;

  /// The linked child, if any, whose first name is mentioned in [question] (already lower-cased).
  ParentLinkedChild? childMentionedIn(String question) {
    for (final child in children) {
      final firstName = child.name.split(' ').first.toLowerCase();
      if (firstName.isNotEmpty && question.contains(firstName)) return child;
    }
    return null;
  }

  ParentAttendanceChildSummary? attendanceFor(String childId) {
    for (final summary in attendance.children) {
      if (summary.childId == childId) return summary;
    }
    return null;
  }

  ParentFinanceChildAccount? financeFor(String childId) {
    for (final account in finance.children) {
      if (account.id == childId) return account;
    }
    return null;
  }
}

Future<ParentAiFacts> loadParentAiFacts({
  required ParentChildrenRepository children,
  required ParentAttendanceRepository attendance,
  required ParentFinanceRepository finance,
  required ParentLearningProgressRepository learning,
  required EventRepository events,
  required ParentMessagesRepository messages,
}) async {
  final eventSnapshot = await events.load();
  return ParentAiFacts(
    children: (await children.load()).children,
    attendance: await attendance.load(),
    finance: (await finance.load()).snapshot,
    learning: await learning.load(),
    upcomingEvents: [for (final event in eventSnapshot.events) if (event.isUpcoming) event],
    messages: await messages.load(),
  );
}

class ParentAiAnswer {
  const ParentAiAnswer({
    required this.question,
    required this.answer,
    required this.isGroundedInCachedFamilyContext,
  });

  final String question;
  final String answer;
  final bool isGroundedInCachedFamilyContext;
}

const parentAiPrompts = [
  'How is Maryam doing this term?',
  "What is Hafsa's attendance?",
  'What payments are due?',
  'What school events are coming up?',
  'Do I have any unread messages?',
];

/// Answers family questions from real, already family-visible SchoolOS records, and honestly refuses
/// when it cannot answer safely — the same design already used for `FinanceAiService`, never a fixed
/// canned reply that could drift from what the family's other real screens show.
class ParentAiService {
  const ParentAiService(this.facts);

  final ParentAiFacts facts;

  ParentAiAnswer answer(String raw) {
    final question = raw.trim();
    final q = question.toLowerCase();
    bool any(List<String> words) => words.any(q.contains);

    if (any(['why', 'diagnos', 'predict', 'forecast', 'rank', 'compare', 'best', 'worst', 'ability', 'iq'])) {
      return _cannotInfer(question);
    }
    if (any(['attend', 'present', 'absent', 'late'])) return _attendance(question);
    if (any(['learn', 'academic', 'result', 'assess', 'grade', 'score', 'average', 'progress'])) {
      return _learning(question);
    }
    if (any(['pay', 'fee', 'balance', 'owe', 'receipt', 'mandate'])) return _finance(question);
    if (any(['event', 'calendar', 'upcoming', 'happening'])) return _events(question);
    if (any(['message', 'unread', 'conversation', 'reply'])) return _messages(question);

    return _fallback(question);
  }

  ParentAiAnswer _attendance(String q) {
    final child = facts.childMentionedIn(q);
    if (facts.attendance.children.isEmpty) {
      return _noFamilyRecord(q);
    }
    if (child == null) {
      final lines = [
        for (final summary in facts.attendance.children)
          '${summary.name}: ${summary.attendancePercent}% today (${summary.presentDaysLabel}).',
      ];
      return ParentAiAnswer(question: q, answer: lines.join(' '), isGroundedInCachedFamilyContext: true);
    }
    final summary = facts.attendanceFor(child.id);
    if (summary == null) return _noRecordFor(q, child.name);
    return ParentAiAnswer(
      question: q,
      answer: '${child.name} is ${summary.checkedInToday ? 'marked present' : 'not marked present'} today '
          '(${summary.attendancePercent}%)${summary.lateArrivals > 0 ? ', with a late arrival flagged' : ''}. '
          'Only today\'s real gate-scan record is available; a day-by-day history is not recorded yet.',
      isGroundedInCachedFamilyContext: true,
    );
  }

  ParentAiAnswer _learning(String q) {
    final child = facts.childMentionedIn(q);
    if (facts.learning.children.isEmpty) return _noFamilyRecord(q);
    if (child == null) {
      final lines = [
        for (final entry in facts.learning.children)
          entry.averagePercent == 0
              ? '${entry.name}: no recorded assessment yet.'
              : '${entry.name}: ${entry.averagePercent}% average.',
      ];
      return ParentAiAnswer(question: q, answer: lines.join(' '), isGroundedInCachedFamilyContext: true);
    }
    final entry = facts.learning.childById(child.id);
    if (entry == null || entry.averagePercent == 0) {
      return ParentAiAnswer(
        question: q,
        answer: '${child.name} has no recorded assessment score yet.',
        isGroundedInCachedFamilyContext: true,
      );
    }
    return ParentAiAnswer(
      question: q,
      answer: '${child.name} has a ${entry.averagePercent}% average across ${entry.evidence.length} recorded '
          'assessment${entry.evidence.length == 1 ? '' : 's'} this term (status: ${entry.status.label}).',
      isGroundedInCachedFamilyContext: true,
    );
  }

  ParentAiAnswer _finance(String q) {
    final child = facts.childMentionedIn(q);
    if (facts.finance.children.isEmpty) return _noFamilyRecord(q);
    if (child == null) {
      final lines = [
        for (final account in facts.finance.children)
          account.balance == 0
              ? '${account.name}: fully paid.'
              : '${account.name}: ${formatNaira(account.balance)} outstanding.',
      ];
      return ParentAiAnswer(question: q, answer: lines.join(' '), isGroundedInCachedFamilyContext: true);
    }
    final account = facts.financeFor(child.id);
    if (account == null) return _noRecordFor(q, child.name);
    return ParentAiAnswer(
      question: q,
      answer: account.balance == 0
          ? '${child.name}\'s account is fully paid (${formatNaira(account.paidAmount)} of ${formatNaira(account.netFees)}).'
          : '${child.name} has ${formatNaira(account.balance)} outstanding of ${formatNaira(account.netFees)} net fees.',
      isGroundedInCachedFamilyContext: true,
    );
  }

  ParentAiAnswer _events(String q) {
    if (facts.upcomingEvents.isEmpty) {
      return ParentAiAnswer(
        question: q,
        answer: 'No upcoming school-wide events are recorded right now.',
        isGroundedInCachedFamilyContext: true,
      );
    }
    final lines = [for (final event in facts.upcomingEvents.take(3)) '${event.title} (${event.date}, ${event.audience}).'];
    return ParentAiAnswer(question: q, answer: lines.join(' '), isGroundedInCachedFamilyContext: true);
  }

  ParentAiAnswer _messages(String q) {
    final unread = facts.messages.unreadCount;
    return ParentAiAnswer(
      question: q,
      answer: unread == 0
          ? 'No unread school-to-guardian messages right now. Open Messages for the full approved conversation history.'
          : '$unread conversation${unread == 1 ? '' : 's'} marked unread. Open Messages to read the full conversation.',
      isGroundedInCachedFamilyContext: true,
    );
  }

  ParentAiAnswer _cannotInfer(String q) => ParentAiAnswer(
        question: q,
        answer: 'I cannot answer that: I read family-visible records, I do not diagnose, rank, compare siblings '
            'or predict outcomes. I will not guess a reason behind a pattern either — contact the school for that.',
        isGroundedInCachedFamilyContext: false,
      );

  ParentAiAnswer _noFamilyRecord(String q) => ParentAiAnswer(
        question: q,
        answer: 'There is no family-visible record for that yet.',
        isGroundedInCachedFamilyContext: false,
      );

  ParentAiAnswer _noRecordFor(String q, String name) => ParentAiAnswer(
        question: q,
        answer: 'There is no family-visible record for $name yet.',
        isGroundedInCachedFamilyContext: false,
      );

  ParentAiAnswer _fallback(String q) => ParentAiAnswer(
        question: q,
        answer: 'I can help with guardian-visible SchoolOS information such as linked-child attendance, '
            'learning updates, payments, approved messages and school events. I cannot access private staff '
            'notes, other families, restricted safeguarding information or confidential health records.',
        isGroundedInCachedFamilyContext: false,
      );
}
