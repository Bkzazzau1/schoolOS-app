import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/app/app_services.dart';
import 'package:schoolos_app/core/access/access_controller.dart';
import 'package:schoolos_app/core/appearance/school_appearance_controller.dart';
import 'package:schoolos_app/features/proprietor/data/owner_access_repository.dart';
import 'package:schoolos_app/features/proprietor/data/staff_server_api.dart';
import 'package:schoolos_app/core/notifications/notifications_controller.dart';
import 'package:schoolos_app/core/auth/auth_repository.dart';
import 'package:schoolos_app/core/network/api_config.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/sync/sync_coordinator.dart';
import 'package:schoolos_app/core/sync/sync_engine.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/core/tenancy/school_session_store.dart';
import 'package:schoolos_app/features/authentication/presentation/login_page.dart';
import 'package:schoolos_app/features/school_switcher/presentation/school_selection_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

class _DemoDatabase implements LocalDatabase {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getLocalRecord) {
      return Future<LocalRecord?>.value(null);
    }
    if (invocation.memberName == #getLocalRecords) {
      return Future<List<LocalRecord>>.value([]);
    }
    if (invocation.memberName == #pendingCount) return 0;
    return super.noSuchMethod(invocation);
  }
}

class _DemoServices implements AppServices {
  @override
  final apiConfig = const ApiConfig('');
  @override
  final AuthRepository? auth = null;
  @override
  final SyncEngine? syncEngine = null;
  @override
  final SyncCoordinator? syncCoordinator = null;
  @override
  final AccessController? access = null;
  @override
  final OwnerAccessRepository? ownerAccess = null;
  @override
  final StaffServerApi? staffServer = null;
  @override
  final NotificationsController? notifications = null;
  @override
  Future<void> beginSchool(SchoolMembership membership) async {}
  @override
  Future<void> endSession() async {}
  @override
  bool get usesBackend => false;
  @override
  final localDatabase = _DemoDatabase();
  @override
  final schoolSession = SchoolSessionController(store: SchoolSessionStore());
  @override
  late final schoolAppearance = SchoolAppearanceController(
    localDatabase: localDatabase,
    schoolSession: schoolSession,
  );
}

void main() {
  for (final entry in {
    'Proprietor': 'ProprietorWorkspacePage',
    'Administrator': 'AdministratorWorkspacePage',
    'Finance Officer': 'FinanceOfficeWorkspacePage',
    'Principal': 'PrincipalWorkspacePage',
    'Teacher': 'TeacherWorkspacePage',
    'Parent': 'ParentWorkspacePage',
  }.entries) {
    testWidgets('demo login opens ${entry.key} after login is disposed', (
      tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({});
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final services = _DemoServices();
      await tester.pumpWidget(MaterialApp(home: LoginPage(services: services)));
      await tester.enterText(find.byType(TextFormField).first, 'demo');
      await tester.enterText(find.byType(TextFormField).last, 'SchoolOS123!');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsNothing);
      expect(find.byType(SchoolSelectionPage), findsOneWidget);
      final role = find.text(entry.key);
      await tester.ensureVisible(role);
      await tester.tap(role);
      await tester.pumpAndSettle();
      expect(find.byType(SchoolSelectionPage), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == entry.value,
        ),
        findsOneWidget,
      );
      expect(services.schoolSession.activeMembership?.roleLabel, entry.key);
      if (entry.key == 'Proprietor') {
        await tester.tap(find.text('Owner Finance').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open Finance Office'));
        await tester.pumpAndSettle();
        expect(find.text('Term billed'), findsOneWidget);
        expect(
          services.schoolSession.activeMembership?.role,
          SchoolRole.proprietor,
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
      if (entry.key != 'Finance Officer') {
        await tester.tap(find.byTooltip('Switch school'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byWidgetPredicate(
            (widget) =>
                widget is PopupMenuItem<SchoolMembership> &&
                widget.value?.role == SchoolRole.accountant,
          ),
        );
        await tester.pumpAndSettle();
      }
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget.runtimeType.toString() == 'FinanceOfficeWorkspacePage',
        ),
        findsOneWidget,
      );
      expect(find.text('Fee Structure'), findsWidgets);
      expect(find.text('Term billed'), findsOneWidget);
      await tester.tap(find.text('Fee Structure').first);
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget.runtimeType.toString() == 'FinanceFeeStructurePage',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      services.schoolAppearance.dispose();
      services.schoolSession.dispose();
    });
  }
}
