import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/finance_office/data/finance_billing.dart';
import 'package:schoolos_app/features/proprietor/data/owner_attention_repository.dart';
import 'package:schoolos_app/features/proprietor/data/owner_finance_overview.dart';
import 'package:schoolos_app/features/proprietor/data/owner_payroll_repository.dart';
import 'package:schoolos_app/features/proprietor/data/owner_reports.dart';
import 'package:schoolos_app/features/proprietor/data/owner_staff_overview.dart';
import 'package:schoolos_app/features/proprietor/domain/proprietor_overview_models.dart';

void main() {
  final staff = buildStaffOverview(people: const [], sections: const [], leaders: const [], now: DateTime(2026, 9, 21));
  final finance = buildFinanceOverview(
    concessions: const [],
    payroll: const PayrollSnapshot(staff: [], profiles: {}, authorizers: []),
    batches: const [],
  );
  const attention = OwnerAttention(
    items: [
      ProprietorAttentionItem(
        title: 'Approve new staff: Amina',
        detail: 'Teacher.',
        owner: 'Proprietor',
        tone: ProprietorAttentionTone.high,
      ),
    ],
    leadership: [],
  );
  final reports = buildOwnerReports(staff: staff, finance: finance, attention: attention, now: DateTime(2026, 9, 21));

  test('three reports are built from records and four say plainly that they are not available yet', () {
    expect(reports.available.map((d) => d.title), ['Executive summary', 'Staff & leadership', 'Scholarships, discounts & payroll']);
    expect(reports.unavailable.length, 4);
    expect(reports.unavailable.every((d) => d.unavailableReason!.isNotEmpty), isTrue);
  });

  test('the executive summary carries what is waiting on the owner', () {
    final lines = reports.docs.first.sections.first.lines;
    expect(lines.single, contains('Approve new staff: Amina'));
  });

  test('the pack lists ready reports in full and the others as not available, with no invented figures', () {
    final text = renderReportPack(schoolName: 'BrightGate Academy', reports: reports);
    expect(text, contains('Generated: 2026-09-21'));
    expect(text, contains('Executive summary'));
    expect(text, contains('NOT AVAILABLE YET'));
    expect(text, contains('Fee collection: The Finance role has not recorded fees or payments yet.'));
    expect(text, isNot(contains('₦102')));
  });

  test('the reporting principle keeps source context and forbids made-up figures', () {
    expect(reportingPrinciple, contains('source'));
    expect(reportingPrinciple, contains('made up'));
  });

  test('once the ledger is connected, Fee collection reports the real figures instead of "not recorded yet"', () {
    final financeWithFees = buildFinanceOverview(
      concessions: const [],
      payroll: const PayrollSnapshot(staff: [], profiles: {}, authorizers: []),
      batches: const [],
      fees: OwnerFeeSummary(
        term: '2026 Term 1',
        totals: BillingTotals(gross: 100000, concession: 0, net: 100000, paid: 60000, balance: 40000),
        sections: [
          OwnerFeeSection(section: 'Primary', students: 2, net: 100000, paid: 60000, balance: 40000),
        ],
        byMethod: {},
        due: DateTime(2026, 10, 1),
        daysOverdue: 5,
        band: '1-30 days',
        owingAccounts: 1,
        topOwing: [('Maryam Abdullahi', 'JSS 2A', 40000)],
      ),
    );
    final withFees = buildOwnerReports(staff: staff, finance: financeWithFees, attention: attention, now: DateTime(2026, 9, 21));
    final feeDoc = withFees.docs.firstWhere((d) => d.title == 'Fee collection');

    expect(feeDoc.available, isTrue);
    final text = renderReportPack(schoolName: 'A Real School', reports: withFees);
    expect(text, contains('Billed: ₦100,000'));
    expect(text, contains('Collected: ₦60,000 (60%)'));
    expect(text, contains('Outstanding: ₦40,000'));
    expect(text, contains('Maryam Abdullahi'));
    expect(text, isNot(contains('Fee collection: The Finance role has not recorded fees or payments yet.')));
  });
}
