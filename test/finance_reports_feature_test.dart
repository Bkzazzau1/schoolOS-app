import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/finance_office/data/finance_cashflow_demo_data.dart';
import 'package:schoolos_app/features/finance_office/data/finance_office_dashboard_demo_data.dart';
import 'package:schoolos_app/features/finance_office/data/finance_reconciliation_demo_data.dart';
import 'package:schoolos_app/features/finance_office/data/finance_reports_demo_data.dart';
import 'package:schoolos_app/features/finance_office/domain/finance_reports_models.dart';

void main() {
  test('report library preserves exact six website reports', () {
    expect(financeReportLibrary, hasLength(6));
    expect(financeReportLibrary[0].title, 'Collection Summary');
    expect(financeReportLibrary[0].period, 'Current term');
    expect(
      financeReportLibrary[0].detail,
      'Fees billed, received, balances, collection rate',
    );
    expect(financeReportLibrary[1].title, 'Outstanding Accounts');
    expect(financeReportLibrary[2].title, 'Bank Reconciliation');
    expect(financeReportLibrary[3].title, 'Income & Expense Statement');
    expect(financeReportLibrary[4].title, 'Education Financing Ledger');
    expect(financeReportLibrary[5].title, 'Payroll Payment Register');
    expect(financeReportLibrary[5].period, 'Monthly');
  });

  test('website report KPI snapshot is preserved exactly', () {
    expect(financeReportKpis, hasLength(5));
    expect(financeReportKpis[0].value, '94.1%');
    expect(financeReportKpis[1].value, '₦3.7m');
    expect(financeReportKpis[1].hint, '73 family accounts');
    expect(financeReportKpis[2].value, '₦6.4m');
    expect(financeReportKpis[3].value, '7');
    expect(financeReportKpis[4].value, '6');
  });

  test('report KPIs stay consistent with source finance workspaces', () {
    expect(financeOfficeKpis[1].hint, contains(financeReportKpis[0].value));
    expect(financeReportKpis[1].value, financeOfficeKpis[2].value);
    expect(financeReportKpis[1].hint, financeOfficeKpis[2].hint);
    expect(financeReportKpis[2].value, financeCashflowKpis[1].value);
    expect(financeReportKpis[3].value, financeReconciliationKpis[2].value);
    expect(financeReportLibrary.length.toString(), financeReportKpis[4].value);
  });

  test('management snapshot preserves exact website section indicators', () {
    expect(financeManagementSnapshots, hasLength(3));
    expect(financeManagementSnapshots[0].section, 'Nursery / Early Years');
    expect(financeManagementSnapshots[0].collectionRate, 96);
    expect(financeManagementSnapshots[0].status, 'Healthy');
    expect(financeManagementSnapshots[1].section, 'Primary School');
    expect(financeManagementSnapshots[1].collectionRate, 91);
    expect(financeManagementSnapshots[1].status, 'Healthy');
    expect(financeManagementSnapshots[2].section, 'Secondary School');
    expect(financeManagementSnapshots[2].collectionRate, 86);
    expect(financeManagementSnapshots[2].status, 'Watch');
  });

  test('reporting boundaries keep export read-only and minimum necessary', () {
    expect(financeReportsReadOnlyBoundary, contains('read-only'));
    expect(financeReportsReadOnlyBoundary, contains('must not post money'));
    expect(financeReportsReadOnlyBoundary, contains('approve payroll'));
    expect(financeReportsReadOnlyBoundary, contains('issue a receipt'));
    expect(financeReportsMinimumNecessaryBoundary, contains('minimum necessary'));
    expect(financeReportsMinimumNecessaryBoundary, contains('parent bank credentials'));
    expect(financeReportsSourceBoundary, contains('authoritative finance ledgers'));
    expect(financeReportsSourceBoundary, contains('second accounting truth'));
    expect(financeReportsSectionRateBoundary, contains('must not be averaged'));
  });

  test('report definitions and section snapshots serialize cleanly', () {
    final report = FinanceReportDefinition.fromJson(financeReportLibrary[2].toJson());
    expect(report.title, 'Bank Reconciliation');
    expect(report.period, 'Daily / monthly');

    final snapshot = FinanceManagementSnapshot.fromJson(
      financeManagementSnapshots[2].toJson(),
    );
    expect(snapshot.section, 'Secondary School');
    expect(snapshot.collectionRate, 86);
    expect(snapshot.status, 'Watch');
  });
}
