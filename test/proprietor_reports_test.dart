import 'package:flutter_test/flutter_test.dart';
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
}
