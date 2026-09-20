import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/parent_dashboard_models.dart';
import 'parent_dashboard_demo_data.dart';

abstract interface class ParentDashboardDataSource {
  Future<ParentDashboardSnapshot> loadDashboard();
  ParentDashboardPermissions get permissions;
}

class ParentDashboardRepository implements ParentDashboardDataSource {
  ParentDashboardRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _entityType = 'parent_family_dashboard';
  static const _entityId = 'family-dashboard';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  @override
  ParentDashboardPermissions get permissions => const ParentDashboardPermissions(
        canViewLinkedChildren: true,
        canViewFamilyFinance: true,
        canConfirmBankPayment: false,
        canEditChildLedger: false,
        canViewStaffPrivateNotes: false,
        canViewRestrictedSafeguarding: false,
      );

  @override
  Future<ParentDashboardSnapshot> loadDashboard() async {
    final membership = _requireParentMembership();
    final cached = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: _entityId,
    );

    if (cached != null) {
      return ParentDashboardSnapshot.fromJson(cached.payload);
    }

    // Foundation data is cached as a clean server-style snapshot so the
    // family dashboard remains available offline. This read path never
    // creates a sync mutation and therefore cannot fabricate a payment,
    // consent response, message delivery state or academic record change.
    parentDashboardDemoData.validate();
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: _entityId,
      payload: parentDashboardDemoData.toJson(),
      serverVersion: 1,
      isDirty: false,
    );
    return parentDashboardDemoData;
  }

  SchoolMembership _requireParentMembership() {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.parent) {
      throw StateError('Parent dashboard access requires an active parent membership.');
    }
    if (membership.schoolId.trim().isEmpty || membership.id.trim().isEmpty) {
      throw StateError('Parent dashboard access requires tenant and membership identity.');
    }
    return membership;
  }
}
