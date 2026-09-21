import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/proprietor/presentation/owner_dialogs.dart';

/// Closing a dialog while its text boxes are still on screen used to fail because they were disposed too early.
void main() {
  Future<void> openWith(WidgetTester tester, Future<Object?> Function(BuildContext) open, void Function(Object?) done) async {
    late BuildContext saved;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      saved = context;
      return const Scaffold();
    })));
    open(saved).then(done);
    await tester.pumpAndSettle();
  }

  testWidgets('the reason dialog returns what was typed and closes cleanly', (tester) async {
    Object? result = 'unset';
    await openWith(tester, (c) => askReason(c, title: 'Reject Amina', action: 'Reject'), (r) => result = r);
    await tester.enterText(find.byType(TextField), 'Not a fit');
    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();
    expect(result, 'Not a fit');
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling the reason dialog returns nothing and closes cleanly', (tester) async {
    Object? result = 'unset';
    await openWith(tester, (c) => askReason(c, title: 'Reject Amina', action: 'Reject'), (r) => result = r);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the salary dialog checks the numbers, then returns them and closes cleanly', (tester) async {
    Object? result;
    await openWith(tester, (c) => askSalary(c, personName: 'Grace Musa', gross: 100000, deductions: 0), (r) => result = r);
    await tester.enterText(find.byType(TextFormField).at(1), '200000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Deductions cannot exceed gross.'), findsOneWidget);
    expect(result, isNull);

    await tester.enterText(find.byType(TextFormField).at(1), '15000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final choice = result as SalaryChoice;
    expect((choice.gross, choice.deductions, choice.onPayroll), (100000, 15000, true));
    expect(tester.takeException(), isNull);
  });
}
