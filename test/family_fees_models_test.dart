import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/familyfees/domain/family_fees_models.dart';

import 'family_fees_fixtures.dart';

void main() {
  group('a family\'s payment account', () {
    test('it reads what the server gave without assuming a format', () {
      final a = FamilyPayAccount.fromJson(
        payAccountJson(
          provider: 'moniepoint', bankName: 'Moniepoint', accountNumber: 'MP-4471-2209', numberLabel: 'Payment code',
          details: [
            {'label': 'Payment reference', 'value': 'BG-0042'},
          ],
          note: 'Pay from any bank app.',
        ),
      );
      expect((a.numberLabel, a.accountNumber, a.bankLabel, a.note), ('Payment code', 'MP-4471-2209', 'Moniepoint', 'Pay from any bank app.'));
      expect(a.details.single.label, 'Payment reference');
      expect(a.canPay, isTrue);
    });

    test('a missing label falls back to "Account number" and a missing bank name to the provider', () {
      final a = FamilyPayAccount.fromJson({'id': 'x', 'provider': 'gtbank', 'accountNumber': '0123456789', 'status': 'active'});
      expect((a.numberLabel, a.bankLabel), ('Account number', 'gtbank'));
    });

    test('whether it can be paid follows the server, and a staff view (with no such field) follows its status', () {
      expect(FamilyPayAccount.fromJson(payAccountJson(status: 'provisioning')).canPay, isFalse);
      expect(FamilyPayAccount.fromJson(payAccountJson(status: 'suspended')).canPay, isFalse);
      expect(FamilyPayAccount.fromJson(payAccountJson(status: 'dormant')).canPay, isTrue);
      expect(FamilyPayAccount.fromJson(payAccountJson(status: 'active', staff: true)).canPay, isTrue);
      expect(FamilyPayAccount.fromJson(payAccountJson(status: 'suspended', staff: true)).canPay, isFalse);
    });

    test('a number the server withheld stays withheld', () {
      final a = FamilyPayAccount.fromJson(payAccountJson(status: 'suspended'));
      expect(a.accountNumber, '');
      expect(a.details, isEmpty);
      expect(a.isPaused, isTrue);
    });

    test('its state is put in words for a payer', () {
      String label(String status) => FamilyPayAccount.fromJson(payAccountJson(status: status)).statusLabel;
      expect(label('active'), 'Ready for payments');
      expect(label('dormant'), 'Nothing due right now');
      expect(label('provisioning'), 'Being set up by the school');
      expect(label('suspended'), 'Paused by the school');
    });

    test('a test account is marked', () {
      expect(FamilyPayAccount.fromJson(payAccountJson(isTest: true)).isTest, isTrue);
      expect(FamilyPayAccount.fromJson(payAccountJson()).isTest, isFalse);
    });
  });

  group('a parent\'s families', () {
    test('a family with several accounts lists the ones a payer can use', () {
      final f = MyFamily.fromJson(
        myFamilyJson(accounts: [
          payAccountJson(),
          payAccountJson(id: 'b', provider: 'uba', bankName: 'UBA', status: 'provisioning'),
        ]),
      );
      expect(f.accounts, hasLength(2));
      expect(f.payable.map((a) => a.id), ['acc-1']);
    });
  });

  group('the school\'s view of families', () {
    test('a merged family is flagged, and a closed account is history', () {
      final f = FamilyRow.fromJson(
        familyRowJson(status: 'inactive', mergedInto: 'fam-9', accounts: [payAccountJson(staff: true), payAccountJson(id: 'old', status: 'closed', staff: true)]),
      );
      expect((f.isMerged, f.isActive), (true, false));
      expect(f.liveAccounts.map((a) => a.id), ['acc-1']);
      expect(f.students, hasLength(3));
    });

    test('the page says whether this person may decide billing, and defaults to no', () {
      expect(FamilyPage.fromJson(familyPageJson([], canDecideBilling: true)).canDecideBilling, isTrue);
      expect(FamilyPage.fromJson(<String, dynamic>{}).canDecideBilling, isFalse);
      expect(FamilyPage.fromJson(familyPageJson([familyRowJson()], hasMore: true)).hasMore, isTrue);
    });
  });

  group('providers and shapes', () {
    test('each bank says what it calls its number and what else a payer must quote', () {
      final providers = [for (final p in (accountProvidersJson()['providers'] as List)) AccountProvider.fromJson(p as Map<String, dynamic>)];
      final moniepoint = providers.singleWhere((p) => p.code == 'moniepoint');
      expect((moniepoint.shape.numberLabel, moniepoint.shape.numberExample), ('Payment code', 'MP-4471-2209'));
      expect(moniepoint.shape.detailLabels, ['Payment reference']);
      expect(providers.singleWhere((p) => p.code == 'gtbank').canIssue, isFalse);
      expect(providers.singleWhere((p) => p.code == 'sandbox').canIssue, isTrue);
    });

    test('a provider with no shape gets the generic one', () {
      final p = AccountProvider.fromJson({'code': 'x', 'displayName': 'X'});
      expect((p.shape.numberLabel, p.canIssue), ('Account number', false));
      expect(p.shape.detailLabels, isEmpty);
    });
  });

  group('merging', () {
    test('a preview lists what moves, which banks\' accounts move and which stay', () {
      final p = MergePreview.fromJson(mergePreviewJson()['preview'] as Map<String, dynamic>);
      expect(p.canMerge, isTrue);
      expect((p.source.name, p.into.name), ('Sani family', 'Bello family'));
      expect(p.source.students, ['Yusuf Sani']);
      expect((p.moves['students'], p.moves['payments']), (1, 2));
      expect(p.accountsMoved, ['UBA']);
      expect(p.accountsKept, ['GTBank']);
      expect((p.source.outstandingMinor, p.into.creditMinor), (9000000, 500000));
    });

    test('a problem stops it', () {
      final p = MergePreview.fromJson(mergePreviewJson(problems: [
        {'code': 'same_family', 'message': 'A family cannot be merged into itself.'},
      ])['preview'] as Map<String, dynamic>);
      expect((p.canMerge, p.problems.single.code), (false, 'same_family'));
    });
  });

  test('the issue report counts what was made and names who could not be', () {
    final r = IssueReport.fromJson({
      'issued': 2,
      'failed': [
        {'familyName': 'Eze family', 'message': 'Nope'},
      ],
    });
    expect((r.issued, r.failed.single.familyName), (2, 'Eze family'));
  });
}
