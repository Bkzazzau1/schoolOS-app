import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/finance_office/data/finance_family_accounts_demo_data.dart';
import 'package:schoolos_app/features/finance_office/domain/finance_family_accounts_models.dart';

void main() {
  test('four sample students are grouped into three family accounts', () {
    expect(financeFamilyAccounts, hasLength(3));
    expect(
      financeFamilyAccounts.expand((account) => account.children).map((child) => child.student).toList(),
      ['Maryam Abdullahi', 'Hafsa Abdullahi', 'Ibrahim Sani', 'Yusuf Bello'],
    );
    expect(financeFamilyAccounts.map((account) => account.accountNumber).toSet(), hasLength(3));
  });

  test('Maryam and Hafsa share one parent account but keep separate ledgers', () {
    final family = financeFamilyAccounts.first;
    expect(family.guardian, 'Alhaji Abdullahi Yusuf');
    expect(family.accountNumber, '1047263815');
    expect(family.childCount, 2);
    expect(family.children.map((child) => child.student).toList(), [
      'Maryam Abdullahi',
      'Hafsa Abdullahi',
    ]);
    expect(family.children[0].id, 'STU-001');
    expect(family.children[1].id, 'PRI-003');
  });

  test('family totals aggregate child ledgers without merging child balances', () {
    final family = financeFamilyAccounts.first;
    expect(family.billed, 330000);
    expect(family.paid, 230000);
    expect(family.balance, 100000);
    expect(family.children[0].balance, 50000);
    expect(family.children[1].balance, 50000);
  });

  test('website school-wide KPIs are retained without inventing family count', () {
    expect(financeAccountsKpis.map((item) => item.value).toList(), [
      '648',
      '₦62.8m',
      '₦59.1m',
      '73',
      '118',
    ]);
    expect(financeAccountsKpis.first.label, 'Enrolled students');
    expect(financeAccountsKpis[3].hint, 'Family accounts');
  });

  test('family-account boundaries require child allocation and academic separation', () {
    expect(financeFamilyAccountBoundary, contains('one family collection account'));
    expect(financeFamilyAccountBoundary, contains('do not each need a separate bank account'));
    expect(financeFamilyAccountBoundary, contains('separate fee ledger'));
    expect(financeFamilyAllocationBoundary, contains('allocated to one or more linked child fee ledgers'));
    expect(financeFamilyAllocationBoundary, contains('wrong child'));
    expect(financeFamilyAcademicBoundary, contains('must not alter academic grades'));
  });

  test('family account serialization preserves linked child evidence', () {
    final source = financeFamilyAccounts.first;
    final copy = FinanceFamilyAccount.fromJson(source.toJson());
    expect(copy.id, source.id);
    expect(copy.guardian, source.guardian);
    expect(copy.accountNumber, source.accountNumber);
    expect(copy.childCount, 2);
    expect(copy.children[1].student, 'Hafsa Abdullahi');
    expect(copy.balance, 100000);
    expect(copy.status, FinanceFamilyAccountStatus.active);
  });

  test('family money formatter uses Nigerian grouping', () {
    expect(financeFamilyMoney(330000), '₦330,000');
    expect(financeFamilyMoney(100000), '₦100,000');
  });
}
