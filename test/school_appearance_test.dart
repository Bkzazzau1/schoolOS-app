import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/appearance/logo_processor.dart';
import 'package:schoolos_app/core/appearance/school_appearance_controller.dart';
import 'package:schoolos_app/core/appearance/school_theme.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/proprietor/presentation/proprietor_appearance_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const owner = SchoolMembership(id: 'm-owner', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.proprietor);
const teacher = SchoolMembership(id: 'm-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

/// A real picture: a coloured rectangle of the given size, as PNG bytes.
Future<Uint8List> picture(int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const Color(0xFF2255AA),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;
  SchoolAppearanceController? started;
  late SchoolAppearanceController controller;

  Future<void> setUpSchool() async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([owner, teacher]);
    await session.selectSchool(owner);
    controller = SchoolAppearanceController(localDatabase: db, schoolSession: session);
    await controller.initialize();
    started = controller;
  }

  tearDown(() {
    started?.dispose();
    if (started != null) db.close();
    started = null;
  });

  Widget pageFor({LogoPicker? pick, VoidCallback? changed}) => MaterialApp(
        home: Scaffold(
          body: ProprietorAppearancePage(
            schoolName: 'BrightGate',
            controller: controller,
            onDashboard: () {},
            onAppearanceChanged: changed ?? () {},
            pickLogo: pick ?? pickLogoFromDevice,
          ),
        ),
      );

  /// Lets real work (the picture codec, the database) finish while the widgets keep being redrawn.
  Future<void> settle(WidgetTester tester, [int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  test('the owner own colours and logo are saved, queued for the school, and come back after a restart', () async {
    await setUpSchool();
    final logo = Uint8List.fromList([1, 2, 3, 4]);
    await controller.applyTheme(SchoolThemePreset.custom(darkArgb: 0xFF112233, accentArgb: 0xFFEEDDCC));
    await controller.applyLogo(logo);
    expect(controller.theme.isCustom, isTrue);
    expect(controller.logo, logo);
    expect(db.pendingCount(tenantId: owner.schoolId), 1);

    final again = SchoolAppearanceController(localDatabase: db, schoolSession: session);
    await again.initialize();
    expect(again.theme.darkArgb, 0xFF112233);
    expect(again.theme.accentArgb, 0xFFEEDDCC);
    expect(again.logo, logo);
    again.dispose();
  });

  test('changing the theme keeps the logo, and removing the logo keeps the theme', () async {
    await setUpSchool();
    await controller.applyLogo(Uint8List.fromList([9, 9]));
    await controller.applyTheme(schoolThemeById('royal'));
    expect(controller.logo, isNotNull);
    await controller.applyLogo(null);
    expect(controller.logo, isNull);
    expect(controller.theme.id, 'royal');
  });

  test('colours that are hard to read, and oversized logos, are refused with words for the owner', () async {
    await setUpSchool();
    await expectLater(
      controller.applyTheme(SchoolThemePreset.custom(darkArgb: 0xFFFFFF00, accentArgb: 0xFF000000)),
      throwsA(isA<StateError>().having((e) => e.message, 'message', contains('too light'))),
    );
    await expectLater(
      controller.applyLogo(Uint8List(SchoolAppearanceController.maxLogoBytes + 1)),
      throwsA(isA<StateError>()),
    );
    expect(controller.theme.id, 'forest');
  });

  test('only the owner may change the school look', () async {
    await setUpSchool();
    await session.selectSchool(teacher);
    await expectLater(controller.applyTheme(schoolThemeById('ocean')), throwsA(isA<StateError>()));
    await expectLater(controller.applyLogo(null), throwsA(isA<StateError>()));
  });

  testWidgets('a big picture is shrunk to a small PNG, and something that is not a picture is refused', (tester) async {
    await tester.runAsync(() async {
      final big = await picture(1200, 600);
      final small = await shrinkLogo(big);
      final codec = await ui.instantiateImageCodec(small);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 256);
      expect(frame.image.height, 128);
      expect(small.length, lessThan(SchoolAppearanceController.maxLogoBytes));
      await expectLater(shrinkLogo(Uint8List.fromList([1, 2, 3])), throwsA(isA<StateError>()));
    });
  });

  testWidgets('the owner picks a ready-made theme, then makes their own from a colour code, and applies it', (tester) async {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(setUpSchool);
    var changed = 0;
    await tester.pumpWidget(pageFor(changed: () => changed++));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('theme-navy-gold')), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('apply-theme'))).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('theme-navy-gold')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apply-theme')));
    await settle(tester);
    expect(controller.theme.id, 'navy-gold');
    expect(changed, 1);

    await tester.enterText(find.widgetWithText(TextField, '#0F2247').first, '#7A1F2B');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apply-theme')));
    await settle(tester);
    expect(controller.theme.isCustom, isTrue);
    expect(controller.theme.darkArgb, 0xFF7A1F2B);
  });

  testWidgets('a light main colour shows why it cannot be applied', (tester) async {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(setUpSchool);
    await tester.pumpWidget(pageFor());
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '#153D34').first, '#FFFF00');
    await tester.pumpAndSettle();
    expect(find.textContaining('too light'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('apply-theme'))).onPressed, isNull);
  });

  testWidgets('the owner chooses a logo, the school title shows it, and it can be removed', (tester) async {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late Uint8List png;
    await tester.runAsync(() async {
      await setUpSchool();
      png = await picture(600, 600);
    });
    await tester.pumpWidget(pageFor(pick: () async => png));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('school-logo-image')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('choose-logo')));
    await settle(tester, 15);
    expect(controller.logo, isNotNull);
    expect(find.byKey(const ValueKey('school-logo-image')), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('remove-logo')));
    await settle(tester);
    expect(controller.logo, isNull);
    expect(find.byKey(const ValueKey('school-logo-image')), findsNothing);
  });
}
