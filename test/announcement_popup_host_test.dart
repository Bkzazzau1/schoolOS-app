import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/app/announcement_popup_host.dart';
import 'package:schoolos_app/core/announcements/announcements_controller.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';

import 'core/backend_test_support.dart';

Map<String, Object?> announcement(String id, {String title = 'Title', String body = 'Body'}) => {
      'id': id, 'title': title, 'body': body, 'startsAt': '2026-09-21T08:00:00Z',
    };

void main() {
  testWidgets('shows an unseen announcement as a dialog, once', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final controller = AnnouncementsController(
      api: apiFor(FakeServer((r) async => jsonResponse({
            'announcements': [announcement('a1', title: 'Annual plan sale', body: 'Save 10% before Dec 1.')],
          }))),
      store: MemorySyncStore(),
    );
    final schoolSession = SchoolSessionController(store: FakeSessionStore());
    await schoolSession.selectSchool(teacher);
    await controller.refresh(teacher);

    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: AnnouncementPopupHost(
        controller: controller,
        schoolSession: schoolSession,
        navigatorKey: navigatorKey,
        child: const Scaffold(body: Text('home')),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Annual plan sale'), findsOneWidget);
    expect(find.text('Save 10% before Dec 1.'), findsOneWidget);

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();

    expect(find.text('Annual plan sale'), findsNothing);
    expect(controller.toShow, isEmpty);
  });

  testWidgets('shows nothing when there is nothing to show', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final controller = AnnouncementsController(
      api: apiFor(FakeServer((r) async => jsonResponse({'announcements': const []}))),
      store: MemorySyncStore(),
    );
    final schoolSession = SchoolSessionController(store: FakeSessionStore());
    await schoolSession.selectSchool(teacher);
    await controller.refresh(teacher);

    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: AnnouncementPopupHost(
        controller: controller,
        schoolSession: schoolSession,
        navigatorKey: navigatorKey,
        child: const Scaffold(body: Text('home')),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('with no school chosen it never tries to show one', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final controller = AnnouncementsController(
      api: apiFor(FakeServer((r) async => jsonResponse({
            'announcements': [announcement('a1')],
          }))),
      store: MemorySyncStore(),
    );
    final schoolSession = SchoolSessionController(store: FakeSessionStore());
    // No selectSchool() call: activeMembership stays null.

    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: AnnouncementPopupHost(
        controller: controller,
        schoolSession: schoolSession,
        navigatorKey: navigatorKey,
        child: const Scaffold(body: Text('home')),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });
}
