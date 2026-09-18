import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/app/app.dart';

void main() {
  testWidgets('SchoolOS starts on the login screen', (tester) async {
    await tester.pumpWidget(const SchoolOsApp());

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.byIcon(Icons.school_rounded), findsOneWidget);
  });
}
