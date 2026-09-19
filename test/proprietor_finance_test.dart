import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/proprietor/domain/concession_request.dart';

void main() {
  test('concession calculates net obligation and round-trips safely', () {
    const request = ConcessionRequest(
      id: 'CNC-TEST-001',
      student: 'Hafsa Abdullahi',
      className: 'Primary 3',
      type: ConcessionType.discount,
      grossFee: 145000,
      amount: 10000,
      reason: 'Sibling Discount',
      requestedBy: 'Finance Office',
      requestedByRole: 'Finance Office',
      requestedAt: '10 Sep 2026',
      status: ConcessionStatus.pendingApproval,
    );

    expect(request.netObligation, 135000);
    expect(formatNaira(request.netObligation), '₦135,000');

    final approved = request.copyWith(
      status: ConcessionStatus.approved,
      decidedBy: 'Proprietor',
      decidedAt: '19 Sep 2026',
      decisionNote: 'Approved within policy.',
    );
    final restored = ConcessionRequest.fromJson(approved.toJson());

    expect(restored.status, ConcessionStatus.approved);
    expect(restored.netObligation, 135000);
    expect(restored.decidedBy, 'Proprietor');
    expect(restored.decisionNote, 'Approved within policy.');
  });
}
