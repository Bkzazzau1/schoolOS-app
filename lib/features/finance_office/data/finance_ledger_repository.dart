import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/data/administrator_attendance_desk.dart' show sectionOfClass;
import '../../administrator/data/administrator_students_repository.dart';
import '../../administrator/domain/administrator_students_models.dart';
import '../../proprietor/data/concession_repository.dart';
import '../domain/finance_ledger_models.dart';
import 'finance_aging.dart';
import 'finance_authority.dart';
import 'finance_billing.dart';
import 'finance_reconciliation.dart';

class FinanceActionResult {
  const FinanceActionResult({required this.success, required this.message, this.payment});

  final bool success;
  final String message;
  final Payment? payment;
}

/// Fees, payments and receipts: the school's money ledger.
///
/// The finance officer and the owner can change it. Fee structures are per term and section; a payment is recorded against a
/// student and is never edited or deleted (a mistake is voided with a reason); every payment gets a numbered receipt.
class FinanceLedgerRepository {
  FinanceLedgerRepository({
    required this.database,
    required this.session,
    required this.students,
    required this.concessions,
  });

  final LocalDatabase database;
  final SchoolSessionController session;
  final AdministratorStudentsRepository students;
  final ConcessionRepository concessions;

  static const structureType = 'finance_fee_structure';
  static const paymentType = 'finance_payment';

  /// For deciding what families owe: fee schedules, due dates, discounts, scholarships, waivers.
  /// A job title never carries this on its own - not even Finance Office - only the owner, or
  /// someone the owner has specifically given billing authority to.
  Future<SchoolMembership> _billingAuthority() async {
    final m = session.requireActiveMembership();
    if (!await canManageBilling(database, m)) {
      throw StateError('Only the owner, or someone the owner has given billing authority, can decide what families owe.');
    }
    return m;
  }

  /// For working the ledger day to day: recording and correcting payments, the bank statement,
  /// reminders. Finance Office does this as part of their role; anyone else needs a duty for it.
  Future<SchoolMembership> _operator() async {
    final m = session.requireActiveMembership();
    if (!await canOperateReceivables(database, m)) {
      throw StateError('Only the owner or the Finance Office can do this.');
    }
    return m;
  }

  // ---------------------------------------------------------------- fee structures

  /// This term's fee structure, one row per section - honestly empty until the school sets its own
  /// (see [AccountStatus.noFees]), never a fabricated starting figure.
  Future<List<FeeStructure>> structures(String term) async {
    final m = session.requireActiveMembership();
    final records = await database.getLocalRecords(tenantId: m.schoolId, entityType: structureType);
    final found = [for (final r in records) FeeStructure.fromJson(r.payload)];
    final ofTerm = [for (final s in found) if (s.term == term) s];
    ofTerm.sort((a, b) => financeSections.indexOf(a.section).compareTo(financeSections.indexOf(b.section)));
    return ofTerm;
  }

  /// Sets what a section is charged for a term.
  Future<FinanceActionResult> saveStructure({required String term, required String section, required List<FeeItem> items}) async {
    final SchoolMembership m;
    try {
      m = await _billingAuthority();
    } on StateError catch (e) {
      return FinanceActionResult(success: false, message: e.message);
    }
    if (!financeSections.contains(section)) {
      return const FinanceActionResult(success: false, message: 'Choose a section.');
    }
    final cleaned = [for (final i in items) FeeItem(name: i.name.trim(), amount: i.amount)];
    if (cleaned.isEmpty) return const FinanceActionResult(success: false, message: 'Add at least one charge.');
    if (cleaned.any((i) => i.name.isEmpty)) return const FinanceActionResult(success: false, message: 'Every charge needs a name.');
    if (cleaned.any((i) => i.amount <= 0)) return const FinanceActionResult(success: false, message: 'Every charge needs an amount above zero.');
    final names = cleaned.map((i) => i.name.toLowerCase()).toList();
    if (names.toSet().length != names.length) return const FinanceActionResult(success: false, message: 'Two charges have the same name.');

    final structure = FeeStructure(term: term, section: section, items: cleaned, updatedAt: DateTime.now().toUtc().toIso8601String());
    await _put(m, structureType, structure.id, structure.toJson());
    return FinanceActionResult(success: true, message: '$section fees for $term saved.');
  }

  // ---------------------------------------------------------------- payments

  Future<List<Payment>> allPayments() async {
    final m = session.requireActiveMembership();
    final records = await database.getLocalRecords(tenantId: m.schoolId, entityType: paymentType);
    final list = [for (final r in records) Payment.fromJson(r.payload)];
    list.sort((a, b) => b.receiptNumber.compareTo(a.receiptNumber));
    return list;
  }

  /// Every student's account for the term.
  Future<List<StudentAccount>> accounts([String term = financeCurrentTerm]) async {
    final register = [
      for (final s in (await students.load()).students)
        if (s.status != AdministratorStudentStatus.transferredOut) s,
    ];
    final structs = await structures(term);
    final concessionList = await concessions.loadRequests();
    final payments = await allPayments();
    return buildAccounts(
      students: register,
      structures: structs,
      concessions: concessionList,
      payments: payments,
      term: term,
      sectionOf: sectionOfClass,
    );
  }

  static String _receipt(int n) => 'RCT-${n.toString().padLeft(6, '0')}';

  /// Records money received for a student. It cannot be more than what the student still owes, and needs a bank or POS
  /// reference when it did not arrive as cash. The receipt is numbered in order.
  Future<FinanceActionResult> recordPayment({
    required AdministratorStudentRecord student,
    required int amount,
    required String method,
    String reference = '',
    String note = '',
    String term = financeCurrentTerm,
    DateTime? now,
  }) async {
    final SchoolMembership m;
    try {
      m = await _operator();
    } on StateError catch (e) {
      return FinanceActionResult(success: false, message: e.message);
    }
    if (!paymentMethods.contains(method)) return const FinanceActionResult(success: false, message: 'Choose how it was paid.');
    if (amount <= 0) return const FinanceActionResult(success: false, message: 'Enter an amount above zero.');
    if (method != 'Cash' && reference.trim().isEmpty) {
      return FinanceActionResult(success: false, message: 'Enter the ${method == 'POS' ? 'POS' : 'bank'} reference so the payment can be reconciled.');
    }
    final account = (await accounts(term)).where((a) => a.student.id == student.id).firstOrNull;
    if (account == null) return FinanceActionResult(success: false, message: '${student.name} is not on the school register.');
    if (account.status == AccountStatus.noFees) {
      return FinanceActionResult(success: false, message: 'No fees are set for ${account.section} this term. Set them in Fee Structure first.');
    }
    if (account.balance <= 0) return FinanceActionResult(success: false, message: '${student.name} has nothing left to pay this term.');
    if (amount > account.balance) {
      return FinanceActionResult(
        success: false,
        message: '${_naira(amount)} is more than ${student.name} owes (${_naira(account.balance)}). Enter the amount actually received.',
      );
    }
    if (reference.trim().isNotEmpty) {
      final clash = (await allPayments()).any((p) => !p.isVoided && p.reference.trim().toLowerCase() == reference.trim().toLowerCase());
      if (clash) return const FinanceActionResult(success: false, message: 'That reference has already been recorded on another payment.');
    }

    final all = await allPayments();
    final at = now ?? DateTime.now();
    final payment = Payment(
      id: 'PAY-${at.microsecondsSinceEpoch}',
      receiptNumber: _receipt(all.length + 1),
      studentId: student.id,
      studentName: student.name,
      className: student.className,
      term: term,
      amount: amount,
      method: method,
      receivedAt: at.toUtc().toIso8601String(),
      reference: reference.trim(),
      recordedBy: m.id,
      note: note.trim(),
    );
    await _put(m, paymentType, payment.id, payment.toJson());
    return FinanceActionResult(
      success: true,
      message: 'Receipt ${payment.receiptNumber}: ${_naira(amount)} received for ${student.name}.',
      payment: payment,
    );
  }

  /// Cancels a payment that was recorded by mistake. It is kept, with the reason, and no longer counts as paid.
  Future<FinanceActionResult> voidPayment(Payment payment, String reason) async {
    final SchoolMembership m;
    try {
      m = await _operator();
    } on StateError catch (e) {
      return FinanceActionResult(success: false, message: e.message);
    }
    if (payment.isVoided) return const FinanceActionResult(success: false, message: 'This payment is already voided.');
    if (reason.trim().isEmpty) return const FinanceActionResult(success: false, message: 'Say why the payment is voided.');
    final updated = payment.voided(reason.trim());
    await _put(m, paymentType, updated.id, updated.toJson());
    return FinanceActionResult(success: true, message: 'Receipt ${payment.receiptNumber} voided.', payment: updated);
  }

  Future<void> _put(SchoolMembership m, String type, String id, Map<String, Object?> payload) async {
    final existing = await database.getLocalRecord(tenantId: m.schoolId, entityType: type, entityId: id);
    await database.upsertLocalRecord(
      tenantId: m.schoolId,
      entityType: type,
      entityId: id,
      payload: payload,
      serverVersion: existing?.serverVersion,
      isDirty: true,
    );
    await database.queueMutation(
      tenantId: m.schoolId,
      membershipId: m.id,
      entityType: type,
      entityId: id,
      operation: existing == null ? SyncOperation.create : SyncOperation.update,
      payload: payload,
      baseVersion: existing?.serverVersion,
    );
  }

  static String _naira(int amount) {
    final raw = amount.toString();
    final b = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) b.write(',');
      b.write(raw[i]);
    }
    return '₦$b';
  }

  // ---------------------------------------------------------------- due dates and reminders

  static const dueType = 'finance_term_due';
  static const reminderType = 'finance_reminder';

  /// When fees for the term fall due.
  Future<DateTime> dueDate(String term) async {
    final m = session.requireActiveMembership();
    final record = await database.getLocalRecord(tenantId: m.schoolId, entityType: dueType, entityId: term);
    final stored = record?.payload['date'] as String?;
    return stored == null ? defaultDueDate(term) : DateTime.parse(stored);
  }

  Future<FinanceActionResult> setDueDate(String term, DateTime date) async {
    final SchoolMembership m;
    try {
      m = await _billingAuthority();
    } on StateError catch (e) {
      return FinanceActionResult(success: false, message: e.message);
    }
    final day = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    await _put(m, dueType, term, {'term': term, 'date': day});
    return FinanceActionResult(success: true, message: 'Fees for $term are due on $day.');
  }

  Future<AgingReport> aging({String term = financeCurrentTerm, DateTime? today}) async => buildAgingReport(
        accounts: await accounts(term),
        due: await dueDate(term),
        today: today ?? DateTime.now(),
      );

  Future<List<FeeReminder>> reminders() async {
    final m = session.requireActiveMembership();
    final records = await database.getLocalRecords(tenantId: m.schoolId, entityType: reminderType);
    final list = [for (final r in records) FeeReminder.fromJson(r.payload)];
    list.sort((a, b) => b.queuedAt.compareTo(a.queuedAt));
    return list;
  }

  /// A family is not reminded again within this many days.
  static const reminderGapDays = 3;

  /// Queues a reminder for a student who owes and whose fees are overdue. Each one is firmer than the last (friendly, second,
  /// final), and a family is not reminded again within [reminderGapDays] days. Sending is done by the school server.
  Future<FinanceActionResult> queueReminder(
    StudentAccount account, {
    required String schoolName,
    String term = financeCurrentTerm,
    DateTime? now,
  }) async {
    final SchoolMembership m;
    try {
      m = await _operator();
    } on StateError catch (e) {
      return FinanceActionResult(success: false, message: e.message);
    }
    final at = now ?? DateTime.now();
    if (account.balance <= 0) {
      return FinanceActionResult(success: false, message: '${account.student.name} owes nothing this term.');
    }
    if (daysOverdue(await dueDate(term), at) <= 0) {
      return const FinanceActionResult(success: false, message: 'These fees are not overdue yet, so no reminder is queued.');
    }
    final mine = [for (final r in await reminders()) if (r.studentId == account.student.id && r.term == term) r];
    if (mine.isNotEmpty) {
      final last = DateTime.parse(mine.first.queuedAt);
      if (at.difference(last).inDays < reminderGapDays) {
        return FinanceActionResult(
          success: false,
          message: '${account.student.name}\'s family was reminded ${at.difference(last).inDays == 0 ? 'today' : '${at.difference(last).inDays} day(s) ago'}. Wait $reminderGapDays days between reminders.',
        );
      }
    }
    final level = (mine.length + 1).clamp(1, 3);
    final reminder = FeeReminder(
      id: 'REM-${account.student.id}-${at.microsecondsSinceEpoch}',
      studentId: account.student.id,
      studentName: account.student.name,
      term: term,
      level: level,
      balance: account.balance,
      queuedAt: at.toUtc().toIso8601String(),
      message: reminderMessage(
        level: level,
        guardian: account.student.primaryGuardian,
        student: account.student.name,
        balance: account.balance,
        term: term,
        school: schoolName,
      ),
      queuedBy: m.id,
    );
    await _put(m, reminderType, reminder.id, reminder.toJson());
    return FinanceActionResult(success: true, message: '${reminderLevelNames[level]} queued for ${account.student.name}\'s family.');
  }

  /// Queues a reminder for every overdue account that can be reminded now. Returns how many were queued.
  Future<int> queueAllReminders({required String schoolName, String term = financeCurrentTerm, DateTime? now}) async {
    var queued = 0;
    for (final a in await accounts(term)) {
      if ((await queueReminder(a, schoolName: schoolName, term: term, now: now)).success) queued++;
    }
    return queued;
  }

  // ---------------------------------------------------------------- bank statement and reconciliation

  static const bankLineType = 'finance_bank_line';

  Future<List<BankLine>> bankLines() async {
    final m = session.requireActiveMembership();
    final records = await database.getLocalRecords(tenantId: m.schoolId, entityType: bankLineType);
    final list = [for (final r in records) BankLine.fromJson(r.payload)];
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<ReconciliationReport> reconciliation() async =>
      reconcile(lines: await bankLines(), payments: await allPayments());

  /// Adds a line from the bank statement. A reference can only be entered once.
  Future<FinanceActionResult> addBankLine({
    required DateTime date,
    required int amount,
    required String reference,
    String narration = '',
  }) async {
    final SchoolMembership m;
    try {
      m = await _operator();
    } on StateError catch (e) {
      return FinanceActionResult(success: false, message: e.message);
    }
    if (amount <= 0) return const FinanceActionResult(success: false, message: 'Enter an amount above zero.');
    if (reference.trim().isEmpty) return const FinanceActionResult(success: false, message: 'Enter the reference on the statement.');
    final existing = await bankLines();
    if (existing.any((l) => l.reference.trim().toLowerCase() == reference.trim().toLowerCase())) {
      return const FinanceActionResult(success: false, message: 'That reference is already on the statement.');
    }
    final day = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final line = BankLine(
      id: 'BNK-${DateTime.now().microsecondsSinceEpoch}',
      date: day,
      amount: amount,
      reference: reference.trim(),
      narration: narration.trim(),
      addedBy: m.id,
    );
    await _put(m, bankLineType, line.id, line.toJson());
    return FinanceActionResult(success: true, message: 'Statement line ${line.reference} added.');
  }

  /// Turns a statement line nobody recorded into a payment for the student it belongs to. The receipt is recorded as a bank
  /// transfer with the statement's reference and amount, so it then matches the line.
  Future<FinanceActionResult> recordFromStatement(BankLine line, AdministratorStudentRecord student) => recordPayment(
        student: student,
        amount: line.amount,
        method: 'Bank transfer',
        reference: line.reference,
        note: line.narration.isEmpty ? 'From the bank statement' : 'From the bank statement: ${line.narration}',
      );

}
