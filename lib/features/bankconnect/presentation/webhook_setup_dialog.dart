import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/bank_labels.dart';
import '../domain/bank_models.dart';
import 'bank_widgets.dart';

/// Where the school gives the provider SchoolOS's address for payment notifications, and whether it is known to work.
///
/// SchoolOS never says the webhook is active because it was set up: only once a verified event has really arrived. Until then it
/// says it is waiting, so a school is not left believing payments are being heard when they are not.
Future<void> showWebhookSetupDialog(
  BuildContext context, {
  required ProviderConnection connection,
  required WebhookSetup setup,
  bool justConnected = false,
  Future<WebhookSetup?> Function()? onNewAddress,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _WebhookDialog(connection: connection, setup: setup, justConnected: justConnected, onNewAddress: onNewAddress),
    );

class _WebhookDialog extends StatefulWidget {
  const _WebhookDialog({required this.connection, required this.setup, required this.justConnected, this.onNewAddress});

  final ProviderConnection connection;
  final WebhookSetup setup;
  final bool justConnected;
  final Future<WebhookSetup?> Function()? onNewAddress;

  @override
  State<_WebhookDialog> createState() => _WebhookDialogState();
}

class _WebhookDialogState extends State<_WebhookDialog> {
  late WebhookSetup _setup = widget.setup;
  bool _busy = false;

  Future<void> _renew() async {
    final renew = widget.onNewAddress;
    if (renew == null) return;
    setState(() => _busy = true);
    try {
      final next = await renew();
      if (next != null && mounted) setState(() => _setup = next);
    } catch (error) {
      if (mounted) showBankMessage(context, describeBankError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final setup = _setup;
    return AlertDialog(
      title: Text(widget.justConnected ? '${widget.connection.providerName} is connected' : 'Webhook setup'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusChip(
              label: webhookStatusLabel(setup.status),
              color: setup.isActive ? const Color(0xFF1B7F3B) : const Color(0xFF8A6D00),
            ),
            const SizedBox(height: 12),
            Text(
              setup.mode == 'dashboard'
                  ? 'Give ${widget.connection.providerName} this address, so it can tell SchoolOS the moment a family pays.'
                  : 'SchoolOS gives ${widget.connection.providerName} this address for payment notifications.',
            ),
            const SizedBox(height: 8),
            SelectableText(setup.address, key: const ValueKey('webhook-address'), style: const TextStyle(fontFamily: 'monospace')),
            if (setup.url.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('Add your school server\'s public address in front of this.', style: TextStyle(color: Color(0xFF5F6B7A), fontSize: 12)),
              ),
            if (setup.where.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Where to put it', style: TextStyle(fontWeight: FontWeight.w700)),
              Text(setup.where),
            ],
            if (setup.events.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Events to send', style: TextStyle(fontWeight: FontWeight.w700)),
              Text(setup.events.join(', ')),
            ],
            if (setup.note.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(setup.note),
            ],
            const SizedBox(height: 12),
            Text(
              setup.isActive
                  ? 'A verified payment notification has arrived, so the webhook is working.'
                  : 'It is not active yet. It becomes active only when the first verified notification from ${widget.connection.providerName} arrives.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.onNewAddress != null) TextButton(onPressed: _busy ? null : _renew, child: const Text('New address')),
        TextButton(onPressed: () => Clipboard.setData(ClipboardData(text: setup.address)), child: const Text('Copy')),
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
      ],
    );
  }
}
