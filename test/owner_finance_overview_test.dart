import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/proprietor/data/owner_finance_overview.dart';
import 'package:schoolos_app/features/proprietor/data/owner_payroll_repository.dart';
import 'package:schoolos_app/features/proprietor/data/payroll_batch_repository.dart';
import 'package:schoolos_app/features/proprietor/domain/concession_request.dart';

ConcessionRequest concession(String id, int amount, ConcessionStatus status) => ConcessionRequest(
      id: id,
      student: 'Student $id',
      className: 'Primary 3',
      type: ConcessionType.discount,
      grossFee: 100000,
      amount: amount,
      reason: 'Sibling',
      requestedBy: 'Finance Office',
      requestedByRole: 'Finance Office',
      requestedAt: '1 Sep 2026',
      status: status,
    );

void main() {
  test('with nothing recorded the page says so instead of inventing figures', () {
    final o = buildFinanceOverview(
      concessions: const [],
      payroll: const PayrollSnapshot(staff: [], profiles: {}, authorizers: []),
      batches: const [],
    );
    String kpi(String l) => o.kpis.firstWhere((k) => k.label == l).value;
    expect(kpi('Scholarships & discounts'), '₦0');
    expect(kpi('Monthly payroll (net)'), 'Not set up');
    expect(o.attention, isEmpty);
    expect(o.decidedRecently, isEmpty);
  });

  test('totals come from decided requests, and pending ones and waiting payroll need the owner', () {
    final o = buildFinanceOverview(
      concessions: [
        concession('1', 10000, ConcessionStatus.approved),
        concession('2', 5000, ConcessionStatus.approved),
        concession('3', 7000, ConcessionStatus.declined),
        concession('4', 20000, ConcessionStatus.pendingApproval),
      ],
      payroll: PayrollSnapshot(
        staff: const [],
        profiles: {
          'a': const PayrollProfile(staffId: 'a', name: 'A', role: 'Teacher', gross: 100000, deductions: 10000, onPayroll: true, history: []),
          'b': const PayrollProfile(staffId: 'b', name: 'B', role: 'Teacher', gross: 50000, deductions: 0, onPayroll: false, history: []),
        },
        authorizers: const [],
      ),
      batches: [
        const PayrollBatch(period: '2026-09', status: PayrollBatchStatus.prepared, lines: [{}], total: 90000, preparedBy: '', approvedBy: '', instructedBy: ''),
      ],
    );
    String kpi(String l) => o.kpis.firstWhere((k) => k.label == l).value;
    expect(kpi('Scholarships & discounts'), '₦15,000');
    expect(kpi('Awaiting your decision'), '1');
    expect(kpi('Monthly payroll (net)'), '₦90,000');
    expect(o.attention.length, 2);
    expect(o.decidedRecently.length, 3);
  });
}
