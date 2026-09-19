import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/finance_office/data/finance_reminders_demo_data.dart';
import 'package:schoolos_app/features/finance_office/domain/finance_reminders_models.dart';
import 'package:schoolos_app/features/finance_office/presentation/finance_reminders_page.dart';

void main() {
  test('fee reminders preserve exact five website family rows', () {
    expect(financeReminderSeed, hasLength(5));
    expect(financeReminderSeed.map((row) => row.id).toList(), [
      'REM-26091',
      'REM-26092',
      'REM-26093',
      'REM-26094',
      'REM-26095',
    ]);
    expect(financeReminderSeed.first.student, 'Maryam Abdullahi');
    expect(financeReminderSeed.last.student, 'Muhammad Kabir');
  });

  test('website reminder status mix and arrangements remain exact', () {
    expect(financeReminderSeed[0].status, FinanceReminderStatus.scheduled);
    expect(financeReminderSeed[1].arrangement, 'Manual partial payment');
    expect(financeReminderSeed[2].status, FinanceReminderStatus.sent);
    expect(financeReminderSeed[3].status, FinanceReminderStatus.needsReview);
    expect(financeReminderSeed[4].status, FinanceReminderStatus.skipped);
    expect(financeReminderSeed[4].arrangement, 'Education financing');
  });

  test('website Fee Reminder KPI snapshot is preserved', () {
    expect(financeReminderDueIn7Days, 84);
    expect(financeReminderMandateBacked, 39);
    expect(financeReminderPaymentPlanFamilies, 21);
    expect(financeReminderNoArrangement, 17);
    expect(financeReminderSuppressedToday, 11);
  });

  test('mandate reminder uses scheduled debit wording without double-pay request', () {
    final preview = financeReminderPreview(financeReminderSeed[0]);
    expect(preview, contains('₦30,000'));
    expect(preview, contains('scheduled for 25 Sep 2026'));
    expect(preview, contains('No action is needed'));
  });

  test('no-arrangement reminder routes family toward payment or Finance plan', () {
    final preview = financeReminderPreview(financeReminderSeed[3]);
    expect(preview, contains('₦120,000'));
    expect(preview, contains('student term account'));
    expect(preview, contains('contact the Finance Office to arrange a payment plan'));
  });

  test('ordinary agreed-payment reminder only asks for the next instalment', () {
    final preview = financeReminderPreview(financeReminderSeed[1]);
    expect(preview, contains('₦20,000'));
    expect(preview, contains('20 Sep 2026'));
    expect(preview, contains('₦55,000'));
  });

  test('reminder escalation and suppression rules match website', () {
    expect(financeReminderStages, hasLength(5));
    expect(financeReminderStages.first.when, '7 days before');
    expect(financeReminderStages.last.when, '7 days overdue');
    expect(financeReminderStages.last.message, 'Finance Office review queue');

    expect(financeReminderSuppressionRules, hasLength(4));
    expect(financeReminderSuppressionRules[0].title, 'Recent payment received');
    expect(financeReminderSuppressionRules[1].hint, 'Mandate-aware wording');
    expect(financeReminderSuppressionRules[2].hint, 'Separate repayment workflow');
    expect(financeReminderSuppressionRules[3].hint, 'Reason should remain visible in audit history');
  });

  test('communication history preserves acknowledged Delivered and Viewed outcomes', () {
    expect(financeReminderHistory, hasLength(3));
    expect(financeReminderHistory[0].status, 'Delivered');
    expect(financeReminderHistory[1].status, 'Viewed');
    expect(financeReminderHistory[2].status, 'Delivered');
    expect(financeReminderHistory[0].summary, '₦25,000 due 18 Sep');
  });

  test('reminder serialization preserves finance evidence and local status transition', () {
    final source = financeReminderSeed.first;
    final decoded = FinanceReminderRow.fromJson(source.toJson());
    expect(decoded.id, 'REM-26091');
    expect(decoded.channels, 'Portal · WhatsApp');
    expect(decoded.balance, 125000);
    expect(decoded.status, FinanceReminderStatus.scheduled);

    final sent = source.copyWith(status: FinanceReminderStatus.sent);
    expect(sent.status, FinanceReminderStatus.sent);
    expect(sent.balance, source.balance);
    expect(sent.nextAmount, source.nextAmount);
  });

  test('reminder governance blocks academic leakage and false delivery claims', () {
    expect(financeReminderAcademicBoundary, contains('must never affect a pupil’s grades'));
    expect(financeReminderAcademicBoundary, contains('finance communication tool only'));
    expect(financeReminderDeliveryBoundary, contains('provider/server acknowledgement'));
    expect(financeReminderDeliveryBoundary, contains('not the same as delivered'));
    expect(financeReminderPrototypeBoundary, contains('Do not invent delivery or account mutations'));
  });

  testWidgets('Fee Reminder Center renders on a phone-sized viewport without exceptions', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: FinanceRemindersPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fee Reminder Center'), findsOneWidget);
    expect(find.text('Reminder rules'), findsOneWidget);
    expect(find.text('Create campaign'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
