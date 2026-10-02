import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/finance_office/data/finance_concessions_policy_copy.dart';
import 'package:schoolos_app/features/finance_office/data/finance_concessions_repository.dart';
import 'package:schoolos_app/features/finance_office/domain/finance_concessions_models.dart';
import 'package:schoolos_app/features/proprietor/data/concession_repository.dart';

const _fixtureRequests = <FinanceConcessionRequest>[
  FinanceConcessionRequest(
    id: 'CNC-FIX-041',
    student: 'Yusuf Bello',
    className: 'JSS 2B',
    type: FinanceConcessionType.scholarship,
    grossFee: 185000,
    amount: 75000,
    reason: 'Founder Scholarship · BrightGate Founder Fund',
    requestedBy: 'Finance Office',
    requestedByRole: 'Finance Office',
    requestedAt: '02 Sep 2026',
    status: FinanceConcessionStatus.approved,
    decidedBy: 'Proprietor',
    decidedAt: '03 Sep 2026',
    decisionNote: 'Approved per founder fund allocation.',
  ),
  FinanceConcessionRequest(
    id: 'CNC-FIX-042',
    student: 'Hafsa Abdullahi',
    className: 'Primary 3',
    type: FinanceConcessionType.discount,
    grossFee: 145000,
    amount: 10000,
    reason: 'Sibling Discount · school policy',
    requestedBy: 'Finance Office',
    requestedByRole: 'Finance Office',
    requestedAt: '10 Sep 2026',
    status: FinanceConcessionStatus.pendingApproval,
  ),
  FinanceConcessionRequest(
    id: 'CNC-FIX-043',
    student: 'Muhammad Kabir',
    className: 'Primary 5',
    type: FinanceConcessionType.scholarship,
    grossFee: 145000,
    amount: 50000,
    reason: 'Academic Scholarship · BrightGate Scholarship Fund',
    requestedBy: 'Finance Office',
    requestedByRole: 'Finance Office',
    requestedAt: '05 Sep 2026',
    status: FinanceConcessionStatus.approved,
    decidedBy: 'Proprietor',
    decidedAt: '06 Sep 2026',
    decisionNote: 'Approved based on academic performance review.',
  ),
  FinanceConcessionRequest(
    id: 'CNC-FIX-044',
    student: 'Aisha Ibrahim',
    className: 'Nursery 2',
    type: FinanceConcessionType.discount,
    grossFee: 117500,
    amount: 23500,
    reason: 'Staff Child Discount · staff benefit policy',
    requestedBy: 'Administrator',
    requestedByRole: 'Administrator',
    requestedAt: '12 Sep 2026',
    status: FinanceConcessionStatus.pendingApproval,
  ),
];

void main() {
  test('a fixture request carries exact student, fee and decision fields', () {
    expect(_fixtureRequests, hasLength(4));
    expect(_fixtureRequests[0].student, 'Yusuf Bello');
    expect(_fixtureRequests[0].grossFee, 185000);
    expect(_fixtureRequests[0].amount, 75000);
    expect(_fixtureRequests[0].status, FinanceConcessionStatus.approved);
    expect(_fixtureRequests[1].student, 'Hafsa Abdullahi');
    expect(_fixtureRequests[1].status, FinanceConcessionStatus.pendingApproval);
    expect(_fixtureRequests[2].student, 'Muhammad Kabir');
    expect(_fixtureRequests[3].requestedByRole, 'Administrator');
  });

  test('a fixture snapshot produces exact finance KPI values', () {
    const snapshot = FinanceConcessionsSnapshot(
      requests: _fixtureRequests,
      canSubmit: true,
      canApprove: false,
    );
    expect(snapshot.approvedGrossTotal, 330000);
    expect(snapshot.approvedConcessionTotal, 125000);
    expect(snapshot.netParentObligation, 205000);
    expect(snapshot.studentsSupported, 2);
    expect(snapshot.pendingCount, 2);
  });

  test('finance membership can submit but cannot approve concessions', () {
    const snapshot = FinanceConcessionsSnapshot(
      requests: _fixtureRequests,
      canSubmit: true,
      canApprove: false,
    );
    expect(snapshot.canSubmit, isTrue);
    expect(snapshot.canApprove, isFalse);
  });

  test('approved scholarship reduces net obligation instead of creating debt', () {
    final yusuf = _fixtureRequests.first;
    expect(yusuf.netObligation, 110000);
    expect(financeConcessionControlPrinciple, contains('₦110,000'));
    expect(financeConcessionControlPrinciple, contains('not continue treating ₦75,000 as unpaid'));
  });

  test('concession serialization preserves decision audit metadata', () {
    final restored = FinanceConcessionRequest.fromJson(_fixtureRequests.first.toJson());
    expect(restored.id, 'CNC-FIX-041');
    expect(restored.decidedBy, 'Proprietor');
    expect(restored.decidedAt, '03 Sep 2026');
    expect(restored.decisionNote, 'Approved per founder fund allocation.');
    expect(restored.status, FinanceConcessionStatus.approved);
  });

  test('finance money formatter matches Nigerian fee display', () {
    expect(financeMoney(185000), '₦185,000');
    expect(financeMoney(125000), '₦125,000');
    expect(financeMoney(0), '₦0');
  });

  test('finance requests and proprietor approvals share one offline entity type', () {
    expect(FinanceConcessionsRepository.entityType, ConcessionRepository.entityType);
    expect(FinanceConcessionsRepository.entityType, 'concession_request');
  });
}
