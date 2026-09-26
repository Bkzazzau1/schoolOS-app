import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/models/school_membership.dart';
import '../data/bank_connect_api.dart';
import '../domain/bank_labels.dart';
import '../domain/bank_models.dart';
import 'bank_widgets.dart';
import 'connect_bank_page.dart';
import 'connection_card.dart';
import 'renew_credentials_dialog.dart';

/// The school's bank accounts: what is connected, in what state, and what can be done to each.
class BankAccountsTab extends StatefulWidget {
  const BankAccountsTab({super.key, required this.api, required this.membership, required this.onViewPayments, this.onChanged});

  final BankConnectApi api;
  final SchoolMembership membership;
  final void Function(String connectionId) onViewPayments;
  final VoidCallback? onChanged;

  @override
  State<BankAccountsTab> createState() => _BankAccountsTabState();
}

class _BankAccountsTabState extends State<BankAccountsTab> {
  ProvidersInfo? _providers;
  ConnectionsInfo? _connections;
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
      final results = await Future.wait([widget.api.providers(widget.membership), widget.api.connections(widget.membership)]);
      if (!mounted) return;
      setState(() {
        _providers = results[0] as ProvidersInfo;
        _connections = results[1] as ConnectionsInfo;
      });
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  BankProvider? _providerFor(BankConnection connection) {
    for (final p in _providers?.providers ?? const <BankProvider>[]) {
      if (p.code == connection.provider) return p;
    }
    return null;
  }

  Future<bool> _ask(String title, String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(action)),
          ],
        ),
      ) ??
      false;

  Future<void> _connect() async {
    final info = _providers;
    if (info == null) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ConnectBankPage(api: widget.api, membership: widget.membership, info: info)),
    );
    await _load();
    widget.onChanged?.call();
  }

  Future<void> _command(BankConnection connection, ConnectionCommand command) async {
    if (command == ConnectionCommand.payments) return widget.onViewPayments(connection.id);
    if (command == ConnectionCommand.history) return _showHistory(connection);
    setState(() => _busyId = connection.id);
    try {
      await _run(connection, command);
    } catch (error) {
      if (mounted) showBankMessage(context, describeBankError(error));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _run(BankConnection connection, ConnectionCommand command) async {
    final m = widget.membership;
    final api = widget.api;
    ConnectionActionResult? result;
    String? message;
    switch (command) {
      case ConnectionCommand.confirm:
        result = await api.confirm(m, connection.id);
        message = '${connection.title} is connected.';
      case ConnectionCommand.cancel:
        if (!await _ask('Not the right account?', 'Nothing will be kept and no payments will be read from it.', 'Remove it')) return;
        result = await api.disconnect(m, connection.id);
        message = 'That account was not connected.';
      case ConnectionCommand.sync:
        result = await api.sync(m, connection.id);
        final s = result.sync!;
        message = !s.ok ? (s.message.isNotEmpty ? s.message : bankErrorLabel(s.code)) : s.created == 0 ? 'No new payments.' : '${s.created} new payment${s.created == 1 ? '' : 's'}.';
      case ConnectionCommand.test:
        result = await api.test(m, connection.id);
        message = result.check!.ok ? 'The connection is working.' : (result.check!.message.isNotEmpty ? result.check!.message : bankErrorLabel(result.check!.code));
      case ConnectionCommand.enable:
        result = await api.enable(m, connection.id);
        message = result.check?.ok == false ? 'Enabled, but the check failed: ${result.check!.message}' : '${connection.title} is being read again.';
      case ConnectionCommand.disable:
        if (!await _ask('Disable ${connection.title}?', 'No new payments will be read from it until you enable it again. Its history stays.', 'Disable')) return;
        result = await api.disable(m, connection.id);
        message = '${connection.title} is disabled.';
      case ConnectionCommand.disconnect:
        if (!await _ask('Disconnect ${connection.title}?', 'SchoolOS will forget its credentials and stop reading it. Payments already received are kept. You can connect it again later.', 'Disconnect')) return;
        result = await api.disconnect(m, connection.id);
        message = '${connection.title} is disconnected.';
      case ConnectionCommand.rename:
        final change = await _askRename(connection);
        if (change == null) return;
        result = await api.rename(m, connection.id, purpose: change.$1, label: change.$2);
        message = 'Saved.';
      case ConnectionCommand.reconnect || ConnectionCommand.rotate:
        final provider = _providerFor(connection);
        if (provider == null) {
          message = 'This provider is not available on the server.';
          break;
        }
        result = await showRenewCredentialsDialog(
          context, api: api, membership: m, connection: connection, provider: provider,
          reconnect: command == ConnectionCommand.reconnect,
        );
        if (result == null) return;
        message = 'Credentials saved.';
      case ConnectionCommand.webhook:
        if (!await _ask('New callback address?', 'The provider must be given the new address. The old one stops working at once.', 'Issue new address')) return;
        result = await api.newWebhookAddress(m, connection.id);
      case ConnectionCommand.payments || ConnectionCommand.history:
        return;
    }
    if (!mounted) return;
    if (result?.webhookPath != null) await _showWebhook(result!.webhookPath!);
    if (message != null && mounted) showBankMessage(context, message);
    await _load();
    widget.onChanged?.call();
  }

  Future<(String, String)?> _askRename(BankConnection connection) =>
      showDialog<(String, String)>(context: context, builder: (_) => _RenameDialog(connection: connection));

  Future<void> _showWebhook(String path) => showDialog<void>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Callback address'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Give this to the provider so it can tell SchoolOS about new payments straight away. It is shown only once.'),
              const SizedBox(height: 8),
              SelectableText(path, style: const TextStyle(fontFamily: 'monospace')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Clipboard.setData(ClipboardData(text: path)), child: const Text('Copy')),
            FilledButton(onPressed: () => Navigator.of(dialog).pop(), child: const Text('Done')),
          ],
        ),
      );

  Future<void> _showHistory(BankConnection connection) async {
    try {
      final events = await widget.api.audit(widget.membership, connection.id);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          builder: (_, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.all(16),
            children: [
              Text('Activity: ${connection.title}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (events.isEmpty) const Text('Nothing yet.'),
              for (final e in events)
                ListTile(dense: true, title: Text(auditKindLabel(e.kind)), subtitle: Text(whenLabel(e.at))),
            ],
          ),
        ),
      );
    } catch (error) {
      if (mounted) showBankMessage(context, describeBankError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _connections == null) return const Center(child: CircularProgressIndicator());
    if (_error != null && _connections == null) return ErrorRetry(message: _error!, onRetry: _load);
    final connections = _connections!.connections;
    final canManage = _connections!.canManage;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Only the last four digits of an account are ever shown. Credentials are stored encrypted on the server and can never be read back.'),
              ),
              if (canManage) FilledButton.icon(onPressed: _connect, icon: const Icon(Icons.add), label: const Text('Connect bank')),
            ],
          ),
          const SizedBox(height: 16),
          if (connections.isEmpty)
            const BankSection(
              title: 'No bank accounts connected yet',
              child: Text(
                'Connect the school\'s own account and SchoolOS will read the payments it receives and match them to students automatically. '
                'Parents keep paying the school\'s accounts as they do now.',
              ),
            ),
          for (final c in connections)
            ConnectionCard(connection: c, canManage: canManage, busy: _busyId == c.id, onCommand: (command) => _command(c, command)),
        ],
      ),
    );
  }
}

/// Owns its own text box, so it is disposed by the framework once the dialog has finished closing.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.connection});

  final BankConnection connection;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _label = TextEditingController(text: widget.connection.label);
  late String _purpose = widget.connection.purpose;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Rename or change purpose'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _label, maxLength: 80, decoration: const InputDecoration(labelText: 'Name')),
            DropdownButtonFormField<String>(
              initialValue: _purpose,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Collects money for'),
              items: [for (final e in bankPurposes.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: (value) => setState(() => _purpose = value ?? _purpose),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop((_purpose, _label.text)), child: const Text('Save')),
        ],
      );
}
