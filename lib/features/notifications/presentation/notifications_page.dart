import 'package:flutter/material.dart';

import '../../../core/notifications/notifications_controller.dart';
import '../../../core/sync/sync_scope.dart';
import '../../../shared/models/school_membership.dart';

/// The person's inbox: what the school's system has told them (a change to their
/// access, something waiting for their approval, an answer to a request).
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({
    super.key,
    required this.notifications,
    required this.membership,
  });

  final NotificationsController notifications;
  final SchoolMembership membership;

  Future<void> _refresh(BuildContext context) async {
    // A sync round reads the inbox as part of its follow-up; asking for one is
    // the same as pulling to refresh. Offline, the last messages stay.
    final coordinator = SyncScope.maybeOf(context);
    if (coordinator != null) {
      await coordinator.syncNow();
    } else {
      await notifications.refresh(membership).catchError((Object _) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: notifications,
      builder: (context, _) {
        final items = notifications.items;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Notifications'),
            actions: [
              if (notifications.unread > 0)
                TextButton(
                  onPressed: () => notifications.markAllRead(membership),
                  child: const Text('Mark all read'),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => _refresh(context),
            child: items.isEmpty
                ? ListView(
                    // A list, so pulling down to refresh works even when empty.
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [_EmptyInbox()],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) => _NotificationTile(
                      item: items[index],
                      onOpen: () => notifications.markRead(membership, items[index].id),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onOpen});

  final AppNotification item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onOpen,
      leading: CircleAvatar(
        backgroundColor: item.read
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.primaryContainer,
        child: Icon(_iconFor(item.kind), size: 20),
      ),
      title: Text(
        item.title,
        style: TextStyle(fontWeight: item.read ? FontWeight.w500 : FontWeight.w800),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.message),
            const SizedBox(height: 4),
            Text(
              _formatWhen(item.createdAt.toLocal()),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      trailing: item.read
          ? null
          : Icon(Icons.circle, size: 10, color: theme.colorScheme.primary, semanticLabel: 'Unread'),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Column(
        children: [
          Icon(Icons.notifications_none_rounded, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 14),
          Text(
            'No notifications',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Messages about your access, approvals and requests will appear here.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

IconData _iconFor(String kind) => switch (kind) {
      'access_changed' => Icons.lock_open_rounded,
      'staff_proposal' || 'staff_proposal_decided' => Icons.person_add_alt_1_rounded,
      'payroll_batch' => Icons.payments_outlined,
      'concession_request' || 'concession_decided' => Icons.volunteer_activism_outlined,
      'staff_invitation_accepted' => Icons.mark_email_read_outlined,
      'community_report' => Icons.flag_outlined,
      _ => Icons.notifications_outlined,
    };

String _formatWhen(DateTime value) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.day} ${months[value.month - 1]}, $hour:$minute';
}
