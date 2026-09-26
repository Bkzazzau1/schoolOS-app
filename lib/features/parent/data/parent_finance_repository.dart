import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../finance_office/data/finance_aging.dart' show reminderLevelNames;
import '../../finance_office/data/finance_ledger_repository.dart';
import '../../finance_office/domain/finance_ledger_models.dart';
import '../../proprietor/domain/concession_request.dart' show formatNaira;
import '../domain/parent_finance_models.dart';
import 'parent_children_repository.dart';

const _notRecorded = 'Not recorded yet';

class ParentFinanceRepository {
  ParentFinanceRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required ParentChildrenRepository children,
    required FinanceLedgerRepository ledger,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _children = children,
        _ledger = ledger;

  static const _mandateEntityType = 'parent_finance_mandate_preference';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final ParentChildrenRepository _children;
  final FinanceLedgerRepository _ledger;

  /// Everything here is computed live from the same real ledger Finance Office uses
  /// (`FinanceLedgerRepository`), for the same real linked children `ParentChildrenRepository`
  /// reports — so a family's balance, receipts and reminders can never drift from what Finance
  /// actually sees, and can never disagree with what My Children shows for the same student.
  Future<ParentFinanceViewData> load() async {
    final membership = _requireParentMembership();
    final linked = (await _children.load()).children;
    final accounts = await _ledger.accounts();
    final reminders = await _ledger.reminders();

    final childAccounts = <ParentFinanceChildAccount>[];
    final ledgerEntries = <ParentFinanceLedgerEntry>[];
    final receipts = <ParentFinanceReceipt>[];
    final parentReminders = <ParentFeeReminder>[];

    for (final child in linked) {
      StudentAccount? account;
      for (final a in accounts) {
        if (a.student.id == child.id) {
          account = a;
          break;
        }
      }

      final discount = account?.gross == null ? 0 : (account!.gross - account.net);
      childAccounts.add(ParentFinanceChildAccount(
        id: child.id,
        name: child.name,
        className: child.className,
        grossFees: account?.gross ?? 0,
        discountAmount: discount,
        discountLabel: discount == 0 ? '₦0' : formatNaira(discount),
        paidAmount: account?.paid ?? 0,
        balance: account?.balance ?? 0,
      ));

      if (account != null) {
        final validPayments = [for (final p in account.payments) if (!p.isVoided) p]
          ..sort((a, b) => a.receivedAt.compareTo(b.receivedAt));
        var running = account.net;
        final withBalances = <(Payment, int, int)>[];
        for (final payment in validPayments) {
          final previous = running;
          running -= payment.amount;
          withBalances.add((payment, previous, running));
        }
        for (final (payment, previousBalance, newBalance) in withBalances.reversed) {
          final dateLabel = payment.receivedAt.split('T').first;
          ledgerEntries.add(ParentFinanceLedgerEntry(
            dateLabel: dateLabel,
            childId: child.id,
            childName: child.name,
            reference: payment.reference,
            channel: payment.method,
            amount: payment.amount,
            status: 'Confirmed',
          ));
          receipts.add(ParentFinanceReceipt(
            number: payment.receiptNumber,
            childId: child.id,
            student: child.name,
            className: child.className,
            admissionNumber: _notRecorded,
            amount: payment.amount,
            dateLabel: dateLabel,
            method: payment.method,
            reference: payment.reference,
            previousBalance: previousBalance,
            newBalance: newBalance,
          ));
        }
      }

      for (final reminder in reminders) {
        if (reminder.studentId != child.id) continue;
        parentReminders.add(ParentFeeReminder(
          childId: child.id,
          childName: child.name,
          className: child.className,
          balance: reminder.balance,
          nextAmount: reminder.balance,
          dateLabel: reminder.queuedAt.split('T').first,
          method: _notRecorded,
          status: reminderLevelNames[reminder.level] ?? _notRecorded,
          message: reminder.message.isEmpty ? _notRecorded : reminder.message,
        ));
      }
    }

    final mandateRecord = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _mandateEntityType,
      entityId: membership.id,
    );
    final mandate = mandateRecord == null
        ? const ParentPaymentMandatePreference(
            enabled: false,
            monthlyAmount: 0,
            debitDay: '25th',
            collectionMethod: _notRecorded,
          )
        : ParentPaymentMandatePreference.fromJson(
            Map<String, dynamic>.from(mandateRecord.payload['preference'] as Map? ?? const <String, dynamic>{}),
          );

    final snapshot = ParentFinanceSnapshot(
      familyAccountId: membership.id,
      academicPeriod: _notRecorded,
      children: childAccounts,
      ledger: ledgerEntries,
      mandate: mandate,
      reminders: parentReminders,
      // No real source tracks multiple delivery attempts/channels per reminder.
      reminderHistory: const [],
      receipts: receipts,
      // The school store has no real backend anywhere in the app (see the Finance Office
      // audit); there is nothing real to show here.
      storeOrders: const [],
    );

    return ParentFinanceViewData(
      snapshot: snapshot,
      mandateQueued: mandateRecord?.isDirty ?? false,
    );
  }

  Future<String> saveMandatePreference(
    ParentPaymentMandatePreference preference,
  ) async {
    final membership = _requireParentMembership();
    _validateMandate(preference);

    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _mandateEntityType,
      entityId: membership.id,
    );
    final payload = <String, Object?>{
      'membershipId': membership.id,
      'schoolId': membership.schoolId,
      'preference': preference.toJson(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'state': 'queued',
    };

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _mandateEntityType,
      entityId: membership.id,
      payload: payload,
      serverVersion: existing?.serverVersion,
      isDirty: true,
    );

    return _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _mandateEntityType,
      entityId: membership.id,
      operation: SyncOperation.update,
      payload: payload,
      baseVersion: existing?.serverVersion,
    );
  }

  void _validateMandate(ParentPaymentMandatePreference preference) {
    const allowedDays = {'5th', '10th', '15th', '20th', '25th', '28th'};
    if (preference.monthlyAmount < 0) {
      throw ArgumentError.value(
        preference.monthlyAmount,
        'monthlyAmount',
        'Monthly amount cannot be negative.',
      );
    }
    if (!allowedDays.contains(preference.debitDay)) {
      throw ArgumentError.value(
        preference.debitDay,
        'debitDay',
        'Unsupported preferred debit day.',
      );
    }
    if (preference.collectionMethod.trim().isEmpty) {
      throw ArgumentError.value(
        preference.collectionMethod,
        'collectionMethod',
        'Collection method is required.',
      );
    }
  }

  /// The signed-in parent's membership, for the screens that ask the school's server about their family.
  SchoolMembership get activeMembership => _requireParentMembership();

  SchoolMembership _requireParentMembership() {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.parent) {
      throw StateError('Family finance requires an active Parent membership.');
    }
    return membership;
  }
}
