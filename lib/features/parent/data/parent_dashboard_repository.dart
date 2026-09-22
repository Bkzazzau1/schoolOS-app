import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../events/data/event_repository.dart';
import '../../proprietor/domain/concession_request.dart' show formatNaira;
import '../domain/parent_dashboard_models.dart';
import 'parent_children_repository.dart';
import 'parent_finance_repository.dart';
import 'parent_learning_progress_repository.dart';
import 'parent_messages_repository.dart';

const _notRecorded = 'Not recorded yet';

class ParentDashboardRepository {
  /// [localDatabase] is accepted for constructor consistency with every other Parent repository,
  /// even though this one only ever reads through the real repositories below and never touches the
  /// local database directly itself.
  ParentDashboardRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required ParentChildrenRepository children,
    required ParentLearningProgressRepository learning,
    required ParentFinanceRepository finance,
    required ParentMessagesRepository messages,
    required EventRepository events,
  })  : _schoolSession = schoolSession,
        _children = children,
        _learning = learning,
        _finance = finance,
        _messages = messages,
        _events = events;

  final SchoolSessionController _schoolSession;
  final ParentChildrenRepository _children;
  final ParentLearningProgressRepository _learning;
  final ParentFinanceRepository _finance;
  final ParentMessagesRepository _messages;
  final EventRepository _events;

  /// A roll-up of every other now-real Parent screen, built last and only from repositories that are
  /// themselves already real — mirroring how Principal's own Dashboard was rebuilt last in that
  /// role's audit — so it can never show a child, a figure or an item that disagrees with what
  /// actually opening that specific screen shows.
  Future<ParentDashboardSnapshot> load() async {
    final membership = _requireParentMembership();

    final linked = (await _children.load()).children;
    final learningSnapshot = await _learning.load();
    final financeView = await _finance.load();
    final financeSnapshot = financeView.snapshot;
    final messagesSnapshot = await _messages.load();
    final eventSnapshot = await _events.load();

    final financeByChildId = {for (final account in financeSnapshot.children) account.id: account};

    final children = <ParentChildSummary>[
      for (final child in linked)
        ParentChildSummary(
          id: child.id,
          name: child.name,
          className: child.className,
          section: child.section,
          // The real gate-scan record only ever keeps today's attendance (see Parent Attendance);
          // there is no real second attendance source to compute a running percentage from.
          attendancePercent: child.presentToday ? 100 : 0,
          academicPercent: learningSnapshot.childById(child.id)?.averagePercent ?? 0,
          feeBalance: financeByChildId[child.id]?.balance ?? 0,
          initials: _initials(child.name),
          presentToday: child.presentToday,
        ),
    ];

    final attentionItems = <ParentAttentionItem>[
      for (final child in children)
        if (!child.presentToday)
          ParentAttentionItem(
            title: '${child.name} is not marked present today',
            detail: 'Check today\'s real attendance record and contact the school if context is missing.',
            area: 'Attendance · ${child.className}',
            destinationKey: 'attendance',
          ),
      for (final child in children)
        if (child.feeBalance > 0)
          ParentAttentionItem(
            title: '${child.name} has an outstanding balance',
            detail: '${formatNaira(child.feeBalance)} outstanding this term.',
            area: 'Finance · ${child.className}',
            destinationKey: 'finance',
          ),
    ];

    final mandate = financeSnapshot.mandate;
    final finance = ParentFinanceSnapshot(
      totalBilled: financeSnapshot.children.fold<int>(0, (sum, account) => sum + account.grossFees),
      totalPaid: financeSnapshot.children.fold<int>(0, (sum, account) => sum + account.paidAmount),
      accounts: [
        for (final account in financeSnapshot.children)
          ParentPaymentAccount(
            childName: account.name,
            // The real ledger has no separate bank account number; the real, already unique
            // system id stands in for it, the same as Parent Finance's own account view.
            accountNumber: account.id,
            description: _notRecorded,
            balance: account.balance,
          ),
      ],
      nextScheduledDebit: mandate.enabled ? mandate.monthlyAmount : 0,
      nextScheduledDebitLabel:
          mandate.enabled ? '${mandate.debitDay} · ${mandate.collectionMethod}' : _notRecorded,
    );

    final messages = <ParentMessagePreview>[
      for (final thread in messagesSnapshot.threads)
        if (thread.messages.isNotEmpty)
          ParentMessagePreview(
            sender: thread.participantName,
            message: thread.messages.last.body,
            timeLabel: thread.messages.last.timeLabel,
            unread: thread.unread,
          ),
    ];

    final notices = <ParentNoticePreview>[
      for (final event in eventSnapshot.events)
        if (event.isUpcoming)
          ParentNoticePreview(
            title: event.title,
            detail: '${event.date} · ${event.venue}',
            category: event.type.label,
          ),
    ];

    return ParentDashboardSnapshot(
      // No real per-membership guardian display-name directory exists yet (the same reason My
      // Children's classTeacher field is honestly "Not recorded yet"); "Guardian" is a role label,
      // the same convention used for Finance Office's own shell identity, not an invented name.
      guardianName: 'Guardian',
      familyAccountId: membership.id,
      children: children,
      attentionItems: attentionItems,
      finance: finance,
      messages: messages,
      notices: notices,
    );
  }

  SchoolMembership _requireParentMembership() {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.parent) {
      throw StateError('Parent family records require an active Parent membership.');
    }
    return membership;
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
}
