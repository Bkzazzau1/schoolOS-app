import 'package:flutter/material.dart';

import '../../../core/network/api_exceptions.dart';
import '../../../shared/models/school_membership.dart';
import '../data/staff_server_api.dart';

/// Where a staff member's invitation stands, with what the school can do about it:
/// send it again (the old link stops working), cancel it, or remove the login the
/// person made from it. Shown only when there is a server.
///
/// The owner, principal and administrator may see it and send it again. Cancelling
/// an invitation and removing a login are the owner's alone.
class InvitationStatusCard extends StatefulWidget {
  const InvitationStatusCard({
    super.key,
    required this.api,
    required this.membership,
    required this.staffId,
    this.onChanged,
  });

  final StaffServerApi api;
  final SchoolMembership membership;
  final String staffId;
  final VoidCallback? onChanged;

  @override
  State<InvitationStatusCard> createState() => _InvitationStatusCardState();
}

class _InvitationStatusCardState extends State<InvitationStatusCard> {
  InvitationStatus? _status;
  String? _error;
  bool _busy = true;

  bool get _isOwner => widget.membership.role == SchoolRole.proprietor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final status = await widget.api.invitation(widget.membership, widget.staffId);
      if (mounted) setState(() => _status = status);
    } catch (error) {
      if (mounted) setState(() => _error = _words(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _words(Object error) {
    if (error is ApiOfflineException) return 'You need a connection to see or change the invitation.';
    if (error is SessionExpiredException) return 'Your sign-in has ended. Sign in again to continue.';
    if (error is ApiException) return error.message;
    return 'Something went wrong. Please try again.';
  }

  /// Runs a change, tells the person how it went, and reads the status again.
  Future<void> _change(Future<Object?> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
      widget.onChanged?.call();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_words(error))));
    }
    await _load();
  }

  Future<void> _resend() async {
    final address = await showDialog<String>(
      context: context,
      builder: (context) => _ResendDialog(email: _status?.email ?? ''),
    );
    if (address == null) return;
    await _change(
      () => widget.api.resendInvitation(widget.membership, widget.staffId, email: address),
      'Invitation sent.',
    );
  }

  Future<bool> _confirm(String title, String message, String action) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Keep it')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(action)),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _cancel() async {
    final go = await _confirm(
      'Cancel this invitation?',
      'The link stops working. You can send a new invitation later.',
      'Cancel invitation',
    );
    if (go) await _change(() => widget.api.cancelInvitation(widget.membership, widget.staffId), 'Invitation cancelled.');
  }

  Future<void> _unlink() async {
    final go = await _confirm(
      'Remove their login?',
      'They can no longer sign in as this staff member, and any payroll or job authority you gave them stops. '
          'Their account is not deleted and anything else they are at the school is not changed. '
          'Use this if they have left, or the wrong person joined.',
      'Remove login',
    );
    if (go) await _change(() => widget.api.unlink(widget.membership, widget.staffId), 'Login removed.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _status;
    return Card(
      key: const ValueKey('invitation-card'),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Invitation and login', style: theme.textTheme.titleLarge)),
                if (_busy) const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 6),
            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              TextButton(onPressed: _busy ? null : _load, child: const Text('Try again')),
            ] else if (status != null) ...[
              Text(_describe(status)),
              if (status.linked) ...[
                const SizedBox(height: 4),
                const Text('This staff member has a login.', style: TextStyle(fontWeight: FontWeight.w700)),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (!status.linked)
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _resend,
                      icon: const Icon(Icons.forward_to_inbox_outlined, size: 18),
                      label: Text(status.status == 'none' ? 'Send invitation' : 'Send again'),
                    ),
                  if (_isOwner && status.isPending)
                    TextButton(onPressed: _busy ? null : _cancel, child: const Text('Cancel invitation')),
                  if (_isOwner && status.linked)
                    TextButton(
                      onPressed: _busy ? null : _unlink,
                      style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                      child: const Text('Remove login'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _date(DateTime? value) {
    if (value == null) return '';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final local = value.toLocal();
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  static String _describe(InvitationStatus s) {
    final to = s.email == null || s.email!.isEmpty ? 'the staff member' : s.email!;
    switch (s.status) {
      case 'pending':
        if (s.deliveryFailed || s.neverSent) {
          return 'The invitation to $to could not be delivered. Check the email address and send it again.';
        }
        return 'Sent to $to on ${_date(s.sentAt)}. Waiting for them to accept; the link works until ${_date(s.expiresAt)}.';
      case 'expired':
        return 'The invitation to $to expired on ${_date(s.expiresAt)}. Send it again.';
      case 'accepted':
        return 'Accepted on ${_date(s.acceptedAt)}.';
      case 'revoked':
        return 'The invitation was cancelled or replaced.';
      default:
        return s.linked ? 'They joined without an invitation record.' : 'No invitation has been sent.';
    }
  }
}

/// Owns its text field, so it is disposed only when the dialog has really gone.
class _ResendDialog extends StatefulWidget {
  const _ResendDialog({required this.email});

  final String email;

  @override
  State<_ResendDialog> createState() => _ResendDialogState();
}

class _ResendDialogState extends State<_ResendDialog> {
  late final _email = TextEditingController(text: widget.email);

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send the invitation again'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('The link they were sent before stops working. Correct the email address if it was wrong.'),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email address'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(context).pop(_email.text), child: const Text('Send')),
      ],
    );
  }
}
