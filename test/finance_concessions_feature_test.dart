import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/finance_office/data/finance_concessions_demo_data.dart';
import 'package:schoolos_app/features/finance_office/data/finance_concessions_repository.dart';
import 'package:schoolos_app/features/finance_office/domain/finance_concessions_models.dart';
import 'package:schoolos_app/features/proprietor/data/concession_repository.dart';

void main() {
  test('website concession seed preserves exact four records', () {
    expect(financeConcessionSeed, hasLength(4));
    expect(financeConcessionSeed[0].id, 'CNC-2026-041');
    expect(financeConcessionSeed[0].student, 'Yusuf Bello');
    expect(financeConcessionSeed[0].grossFee, 185000);
    expect(financeConcessionSeed[0].amount, 75000);
    expect(financeConcessionSeed[0].status, FinanceConcessionStatus.approved);
    expect(financeConcessionSeed[1].student, 'Hafsa Abdullahi');
    expect(financeConcessionSeed[1].status, FinanceConcessionStatus.pendingApproval);
    expect(financeConcessionSeed[2].student, 'Muhammad Kabir');
    expect(financeConcessionSeed[3].requestedByRole, 'Administrator');
  });

  test('approved website records produce exact finance KPI values', () {
    const snapshot = FinanceConcessionsSnapshot(
      requests: financeConcessionSeed,
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
      requests: financeConcessionSeed,
      canSubmit: true,
      canApprove: false,
    );
    expect(snapshot.canSubmit, isTrue);
    expect(snapshot.canApprove, isFalse);
  });

  test('approved scholarship reduces net obligation instead of creating debt', () {
    final yusuf = financeConcessionSeed.first;
    expect(yusuf.netObligation, 110000);
    expect(financeConcessionControlPrinciple, contains('₦110,000'));
    expect(financeConcessionControlPrinciple, contains('not continue treating ₦75,000 as unpaid'));
  });

  test('funding source summary preserves exact website sample values', () {
    expect(financeConcessionFundingRows, hasLength(3));
    expect(financeConcessionFundingRows[0].label, 'Founder / school fund');
    expect(financeConcessionFundingRows[0].value, '₦125k');
    expect(financeConcessionFundingRows[0].percent, 72);
    expect(financeConcessionFundingRows[1].value, '₦33.5k');
    expect(financeConcessionFundingRows[2].value, '₦0 sample');
  });

  test('concession serialization preserves decision audit metadata', () {
    final restored = FinanceConcessionRequest.fromJson(financeConcessionSeed.first.toJson());
    expect(restored.id, 'CNC-2026-041');
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
