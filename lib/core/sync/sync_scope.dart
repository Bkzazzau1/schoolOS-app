import 'package:flutter/widgets.dart';

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
