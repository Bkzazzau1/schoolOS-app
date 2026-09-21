import 'package:flutter/material.dart';

import '../../../core/sync/sync_scope.dart';
import '../../../shared/models/school_membership.dart';
import 'notifications_page.dart';

/// A bell with the unread count that opens the inbox. It shows nothing when the
/// app has no backend (demo data has no inbox).
class NotificationsBell extends StatelessWidget {
  const NotificationsBell({super.key, required this.membership});

  final SchoolMembership membership;

  @override
  Widget build(BuildContext context) {
    final notifications = NotificationsScope.maybeOf(context);
    if (notifications == null) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: notifications,
      builder: (context, _) {
        final unread = notifications.unread;
        return IconButton(
          tooltip: unread == 0 ? 'Notifications' : 'Notifications · $unread unread',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => NotificationsPage(notifications: notifications, membership: membership),
            ),
          ),
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text(unread > 99 ? '99+' : '$unread'),
            child: const Icon(Icons.notifications_outlined),
          ),
        );
      },
    );
  }
}
