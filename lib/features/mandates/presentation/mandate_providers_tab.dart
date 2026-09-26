import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/models/school_membership.dart';
import '../../bankconnect/domain/bank_labels.dart';
import '../../bankconnect/presentation/bank_widgets.dart';
import '../data/mandates_api.dart';
import '../domain/mandate_labels.dart';
import '../domain/mandate_models.dart';
import 'connect_mandate_provider_page.dart';
import 'mandate_widgets.dart';

/// The school's direct-debit providers. A school may connect BOTH Remita and Lendsqr and there is no "active provider": each mandate
/// records the connection it was made under for good, so different families can use different providers.
class MandateProvidersTab extends StatefulWidget {
  const MandateProvidersTab({super.key, required this.api, required this.membership, this.onChanged});

  final MandatesApi api;
  final SchoolMembership membership;
  final VoidCallback? onChanged;

  @override
  State<MandateProvidersTab> createState() => _MandateProvidersTabState();
}

class _MandateProvidersTabState extends State<MandateProvidersTab> {
  MandateProvidersInfo? _providers;
  MandateConnectionsInfo? _connections;
  String? _error;
  bool _loading = true;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final providers = await widget.api.providers(widget.membership);
      final connections = await widget.api.connections(widget.membership);
      if (!mounted) return;
      setState(() {
        _providers = providers;
        _connections = connections;
      });
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changed() {
    widget.onChanged?.call();
    _load();
  }

  Future<void> _run(MandateConnection c, Future<MandateActionResult> Function() action, {String? done}) async {
    setState(() => _busyId = c.id);
    try {
      final result = await action();
      if (!mounted) return;
      final message = result.testOk == null ? done : (result.testOk! ? 'The connection works.' : result.testMessage);
      if (message != null && message.isNotEmpty) showBankMessage(context, message);
      _changed();
    } catch (error) {
      if (mounted) showBankMessage(context, describeBankError(error));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _connect() async {
    final providers = _providers;
    final connections = _connections;
    if (providers == null || connections == null) return;
    final made = await Navigator.of(context).push<MandateConnection>(
      MaterialPageRoute(
        builder: (_) => ConnectMandateProviderPage(
          api: widget.api,
          membership: widget.membership,
          providers: providers,
          connected: {for (final c in connections.connections) if (c.status != 'revoked') c.provider},
        ),
      ),
    );
    if (made == null || !mounted) return;
    _changed();
    if (made.capabilitiesHaveWebhooks) await _showWebhook(made, justConnected: true);
  }

  Future<void> _showWebhook(MandateConnection c, {bool justConnected = false}) async {
    try {
      final hook = await widget.api.webhook(widget.membership, c.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _WebhookDialog(
          connection: c,
          hook: hook,
          justConnected: justConnected,
          onNewAddress: () => widget.api.newWebhookAddress(widget.membership, c.id),
        ),
      );
    } catch (error) {
      if (mounted) showBankMessage(context, describeBankError(error));
    }
  }

  Future<void> _replace(MandateConnection c) async {
    final provider = _providers?.provider(c.provider);
    if (provider == null) return;
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => FieldsDialog(
        title: 'Replace ${c.providerName} credentials',
        intro: 'Enter the new credentials. They must be for the same merchant account: mandates already made belong to it.',
        fields: [for (final f in provider.credentialFields) DialogField(name: f.name, label: f.label, fieldKey: ValueKey('replace-${f.name}'), secret: f.secret)],
        action: 'Replace',
        confirmKey: const ValueKey('replace-confirm'),
      ),
    );
    if (values == null || !mounted) return;
    await _run(c, () => widget.api.replaceCredentials(widget.membership, c.id, credentials: values), done: 'The credentials were replaced.');
    values.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _providers == null) return const Center(child: CircularProgressIndicator());
    if (_error != null && _providers == null) return ErrorRetry(message: _error!, onRetry: _load);
    final providers = _providers!;
    final connections = _connections!;
    final can = connections.permissions.canManageProviders;
    final live = [for (final c in connections.connections) if (c.status != 'revoked') c];
    final left = [for (final p in providers.providers) if (p.available && !live.any((c) => c.provider == p.code)) p];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Remita and Lendsqr connect to your school with your own credentials. Both can be connected at once; there is no "active provider". '
            'Each family\'s mandate stays with the provider it was made under.',
          ),
          const SizedBox(height: 12),
          if (can && left.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(key: const ValueKey('connect-provider'), onPressed: _connect, icon: const Icon(Icons.add_link), label: const Text('Connect a provider')),
            ),
          const SizedBox(height: 12),
          if (live.isEmpty)
            const BankSection(title: 'No direct-debit provider connected yet', child: Text('Connect Remita or Lendsqr to make mandates for payers. Nothing is shown here until a school server has one.')),
          for (final c in live) _card(c, can),
        ],
      ),
    );
  }

  Widget _card(MandateConnection c, bool can) {
    final busy = _busyId == c.id;
    return Card(
      key: ValueKey('connection-${c.provider}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(c.providerName.toUpperCase(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.5))),
              if (c.isSandbox) const SandboxTag(),
            ]),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 4, children: [
              ConnectionStatusChip(c.status),
              StatusChip(label: mandateEnvironmentLabel(c.environment), color: c.environment == 'live' ? const Color(0xFF1B7F3B) : const Color(0xFF3B5BA5)),
              if (c.capabilitiesHaveWebhooks) StatusChip(label: webhookStatusLabel(c.webhookStatus), color: c.webhookStatus == 'active' ? const Color(0xFF1B7F3B) : const Color(0xFF8A6D00)),
            ]),
            const SizedBox(height: 8),
            Text('Mandates: ${c.activeMandates} active${c.liveMandates > c.activeMandates ? ', ${c.liveMandates - c.activeMandates} not yet active' : ''}', key: ValueKey('active-${c.provider}')),
            if (c.merchantReference.isNotEmpty) Text('Merchant ${c.merchantReference}', style: const TextStyle(color: Color(0xFF5F6B7A))),
            if (!c.capabilities.supportsManualDebit)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('SchoolOS can make, activate and watch mandates here, but cannot send a debit through this provider yet.', style: TextStyle(color: Color(0xFF8A6D00))),
              ),
            if (c.lastErrorCode.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(bankErrorLabel(c.lastErrorCode), style: const TextStyle(color: Color(0xFFB3261E)))),
            if (can) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 4, children: [
                OutlinedButton(key: ValueKey('test-${c.provider}'), onPressed: busy ? null : () => _run(c, () => widget.api.test(widget.membership, c.id)), child: const Text('Test')),
                OutlinedButton(key: ValueKey('replace-${c.provider}'), onPressed: busy ? null : () => _replace(c), child: const Text('Replace credentials')),
                if (c.capabilitiesHaveWebhooks) OutlinedButton(key: ValueKey('webhook-${c.provider}'), onPressed: busy ? null : () => _showWebhook(c), child: const Text('Callback setup')),
                if (c.status == 'disabled')
                  OutlinedButton(key: ValueKey('enable-${c.provider}'), onPressed: busy ? null : () => _run(c, () => widget.api.enable(widget.membership, c.id)), child: const Text('Enable'))
                else
                  OutlinedButton(
                    key: ValueKey('disable-${c.provider}'),
                    onPressed: busy
                        ? null
                        : () async {
                            if (await confirmAction(context, title: 'Disable ${c.providerName}?', message: 'No new mandates or debits go through it while it is disabled. Mandates that are still live stop it being disabled.', action: 'Disable')) {
                              await _run(c, () => widget.api.disable(widget.membership, c.id), done: '${c.providerName} was disabled.');
                            }
                          },
                    child: const Text('Disable'),
                  ),
                TextButton(
                  key: ValueKey('disconnect-${c.provider}'),
                  onPressed: busy
                      ? null
                      : () async {
                          if (await confirmAction(
                            context,
                            title: 'Disconnect ${c.providerName}?',
                            message: 'The stored credentials are wiped. Mandates, debits and payments already recorded are kept. This is refused while any mandate on it is still live.',
                            action: 'Disconnect',
                            danger: true,
                          )) {
                            await _run(c, () => widget.api.disconnect(widget.membership, c.id), done: '${c.providerName} was disconnected.');
                          }
                        },
                  child: const Text('Disconnect', style: TextStyle(color: Color(0xFFB3261E))),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

extension on MandateConnection {
  bool get capabilitiesHaveWebhooks => capabilities.supportsWebhooks;
}

/// Where the school gives the provider SchoolOS's address for notifications. It is not called active until a notification the provider
/// confirmed has really arrived.
class _WebhookDialog extends StatefulWidget {
  const _WebhookDialog({required this.connection, required this.hook, required this.justConnected, required this.onNewAddress});

  final MandateConnection connection;
  final MandateWebhook hook;
  final bool justConnected;
  final Future<MandateWebhook> Function() onNewAddress;

  @override
  State<_WebhookDialog> createState() => _WebhookDialogState();
}

class _WebhookDialogState extends State<_WebhookDialog> {
  late MandateWebhook _hook = widget.hook;
  bool _busy = false;

  Future<void> _renew() async {
    setState(() => _busy = true);
    try {
      final next = await widget.onNewAddress();
      if (mounted) setState(() => _hook = next);
    } catch (error) {
      if (mounted) showBankMessage(context, describeBankError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final address = _hook.url.isNotEmpty ? _hook.url : _hook.path;
    return AlertDialog(
      title: Text(widget.justConnected ? '${widget.connection.providerName} is connected' : 'Callback setup'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_hook.where),
            const SizedBox(height: 8),
            SelectableText(address, key: const ValueKey('callback-address'), style: const TextStyle(fontFamily: 'monospace')),
            if (_hook.url.isEmpty) const Text('Add this to your server\'s public address.', style: TextStyle(color: Color(0xFF5F6B7A))),
            const SizedBox(height: 8),
            if (_hook.note.isNotEmpty) Text(_hook.note),
            const SizedBox(height: 8),
            Text(_hook.status == 'active' ? 'A confirmed notification has arrived, so the callback is active.' : 'It is not active yet: it is called active only after a real notification has arrived and the provider has confirmed it.'),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Clipboard.setData(ClipboardData(text: address)), child: const Text('Copy address')),
        TextButton(key: const ValueKey('callback-renew'), onPressed: _busy ? null : _renew, child: const Text('New address')),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
      ],
    );
  }
}
