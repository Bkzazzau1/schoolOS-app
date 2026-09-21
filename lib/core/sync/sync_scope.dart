import 'package:flutter/widgets.dart';

import '../access/access_controller.dart';
import '../notifications/notifications_controller.dart';
import 'sync_coordinator.dart';

/// Makes the [SyncCoordinator] available to every screen, so none of them has
/// to be handed it. Absent when the app runs on demo data.
class SyncScope extends InheritedWidget {
  const SyncScope({super.key, required this.coordinator, required super.child});

  final SyncCoordinator coordinator;

  /// The coordinator, or null on demo data. Does not rebuild the caller; to
  /// react to new data use [SyncRefresh], or listen to the coordinator.
  static SyncCoordinator? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SyncScope>()?.coordinator;

  @override
  bool updateShouldNotify(SyncScope oldWidget) =>
      coordinator != oldWidget.coordinator;
}

/// Lets a screen react when a sync round changed what is on the device:
///
///     class _MyPageState extends State<MyPage> with SyncRefresh<MyPage> {
///       @override
///       void onSynced() => _load();
///     }
///
/// [onSynced] runs after a round that sent changes or brought in changes made by
/// others (not after an idle round). It is never called while the screen is
/// gone. Do not use it to rebuild a form someone may be typing in: reload only
/// what is safe to replace.
mixin SyncRefresh<T extends StatefulWidget> on State<T> {
  SyncCoordinator? _syncCoordinator;
  int _seenChanges = 0;

  /// What to do when there is new data on the device.
  void onSynced();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final coordinator = SyncScope.maybeOf(context);
    if (coordinator == _syncCoordinator) return;
    _syncCoordinator?.removeListener(_heardFromCoordinator);
    _syncCoordinator = coordinator;
    _seenChanges = coordinator?.changes ?? 0;
    coordinator?.addListener(_heardFromCoordinator);
  }

  void _heardFromCoordinator() {
    final coordinator = _syncCoordinator;
    if (coordinator == null || !mounted) return;
    if (coordinator.changes == _seenChanges) return;
    _seenChanges = coordinator.changes;
    onSynced();
  }

  @override
  void dispose() {
    _syncCoordinator?.removeListener(_heardFromCoordinator);
    super.dispose();
  }
}

/// Makes the person's access (which screens they may use) available to every screen.
class AccessScope extends InheritedWidget {
  const AccessScope({super.key, required this.access, required super.child});

  final AccessController access;

  static AccessController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AccessScope>()?.access;

  @override
  bool updateShouldNotify(AccessScope oldWidget) => access != oldWidget.access;
}

/// Makes the person's inbox available to every screen.
class NotificationsScope extends InheritedWidget {
  const NotificationsScope({super.key, required this.notifications, required super.child});

  final NotificationsController notifications;

  static NotificationsController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<NotificationsScope>()?.notifications;

  @override
  bool updateShouldNotify(NotificationsScope oldWidget) => notifications != oldWidget.notifications;
}

/// Lets a workspace show only the screens the owner allows the person:
///
///     class _MyWorkspaceState extends State<MyWorkspace> with AccessAware<MyWorkspace> {
///       List<NavItem> get _navigation => visibleScreens('teacher', _allNavigation, (item) => item.key);
///     }
///
/// The screen list is redrawn whenever the person's access changes. While access
/// is not known (demo data, or before the first answer) every screen is shown.
mixin AccessAware<T extends StatefulWidget> on State<T> {
  AccessController? _accessController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final access = AccessScope.maybeOf(context);
    if (access == _accessController) return;
    _accessController?.removeListener(_accessChanged);
    _accessController = access;
    access?.addListener(_accessChanged);
  }

  void _accessChanged() {
    if (mounted) setState(() {});
  }

  /// [items] filtered to what the person may use in [workspace] (`owner`,
  /// `principal`, `administrator`, `finance`, `teacher`, `driver` or `parent`).
  /// The screen key is the one the workspace already uses for the item.
  List<I> visibleScreens<I>(String workspace, List<I> items, String Function(I item) keyOf) {
    final access = _accessController ?? AccessScope.maybeOf(context);
    if (access == null || !access.known) return items;
    final visible = [for (final item in items) if (access.allows('$workspace.${keyOf(item)}')) item];
    // Never leave the person with an empty menu: the server guarantees a landing screen, but be safe.
    return visible.isEmpty ? items : visible;
  }

  @override
  void dispose() {
    _accessController?.removeListener(_accessChanged);
    super.dispose();
  }
}
