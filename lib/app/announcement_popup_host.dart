import 'package:flutter/material.dart';

import '../core/announcements/announcements_controller.dart';
import '../core/tenancy/school_session_controller.dart';

/// Shows each still-unseen platform announcement as a dismissible pop-up, one at a
/// time, as soon as it becomes known (restored from cache, or fetched after a sync
/// round). Dismissing is remembered on this device (AnnouncementsController), so the
/// same message is never shown again once closed.
///
/// Uses [navigatorKey] rather than the ambient BuildContext: this widget sits above
/// the app's Navigator in the widget tree (in MaterialApp.builder), so its own
/// context has no Navigator ancestor to find. The Navigator's overlay context does.
class AnnouncementPopupHost extends StatefulWidget {
  const AnnouncementPopupHost({
    super.key,
    required this.controller,
    required this.schoolSession,
    required this.navigatorKey,
    required this.child,
  });

  final AnnouncementsController controller;
  final SchoolSessionController schoolSession;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<AnnouncementPopupHost> createState() => _AnnouncementPopupHostState();
}

class _AnnouncementPopupHostState extends State<AnnouncementPopupHost> {
  bool _showingDialog = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_maybeShow);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_maybeShow);
    super.dispose();
  }

  void _maybeShow() {
    if (_showingDialog) return;
    final toShow = widget.controller.toShow;
    if (toShow.isEmpty) return;
    final membership = widget.schoolSession.activeMembership;
    if (membership == null) return;
    final dialogContext = widget.navigatorKey.currentState?.overlay?.context;
    if (dialogContext == null) return;

    final announcement = toShow.first;
    _showingDialog = true;
    showDialog<void>(
      context: dialogContext,
      builder: (context) => AlertDialog(
        title: Text(announcement.title),
        content: Text(announcement.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    ).then((_) async {
      await widget.controller.dismiss(membership, announcement.id);
      _showingDialog = false;
      if (mounted) _maybeShow();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
