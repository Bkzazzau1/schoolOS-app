import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../../smartcollect/data/smart_collect_api.dart';
import '../../smartcollect/domain/collection_models.dart';
import '../../smartcollect/presentation/collection_words.dart';
import '../../smartcollect/presentation/provider_switch_card.dart';
import '../data/bank_connect_api.dart';
import '../domain/bank_labels.dart';
import '../domain/bank_models.dart';
import 'bank_widgets.dart';
import 'connect_provider_page.dart';
import 'provider_card.dart';
import 'replace_credentials_dialog.dart';
import 'webhook_setup_dialog.dart';

/// The school's collection providers: what is connected, which one is ACTIVE, and what can be done to each. Also a planned provider
/// switch, which is reviewed and applied by a person and never happens by itself.
class ProvidersTab extends StatefulWidget {
  const ProvidersTab({super.key, required this.api, required this.membership, required this.onViewPayments, this.smartApi, this.onChanged});

  final BankConnectApi api;
  final SmartCollectApi? smartApi;
  final SchoolMembership membership;
  final void Function(String connectionId) onViewPayments;
  final VoidCallback? onChanged;

  @override
  State<ProvidersTab> createState() => _ProvidersTabState();
}

class _ProvidersTabState extends State<ProvidersTab> {
  ProvidersInfo? _providers;
  ConnectionsInfo? _connections;
  SwitchesInfo? _switches;
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
      SwitchesInfo? switches;
      try {
        switches = await widget.smartApi?.switches(widget.membership);
      } catch (_) {
        switches = null; // the switch is extra: the providers still show without it
      }
      if (!mounted) return;
      setState(() {
        _providers = results[0] as ProvidersInfo;
        _connections = results[1] as ConnectionsInfo;
        _switches = switches;
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

  Future<bool> _ask(String title, String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(dialog).pop(true), child: Text(action)),
          ],
        ),
      ) ??
      false;

  Future<void> _connect() async {
    final info = _providers;
    if (info == null) return;
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ConnectProviderPage(
          api: widget.api,
          membership: widget.membership,
          info: info,
          alreadyConnected: [for (final c in _connections?.connections ?? const <ProviderConnection>[]) if (!c.isClosed) c.provider],
        ),
      ),
    );
    if (done == true) {
      _changed();
    } else {
      await _load();
    }
  }

  Future<void> _command(ProviderConnection connection, ProviderCommand command) async {
    if (command == ProviderCommand.payments) return widget.onViewPayments(connection.id);
    if (command == ProviderCommand.history) return _showHistory(connection);
    setState(() => _busyId = connection.id);
    try {
      await _run(connection, command);
    } catch (error) {
      if (mounted) showBankMessage(context, describeBankError(error));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _run(ProviderConnection connection, ProviderCommand command) async {
    final m = widget.membership;
    final api = widget.api;
    String? message;
    switch (command) {
      case ProviderCommand.activate:
        if (!await _ask(
          'Make ${connection.providerName} the active provider?',
          'New family collection accounts will be made with ${connection.providerName}. The school has one active provider at a time; changing it later is a reviewed switch.',
          'Make it active',
        )) {
          return;
        }
        await api.activate(m, connection.id);
        message = '${connection.providerName} is now the active collection provider.';
      case ProviderCommand.scheduleSwitch:
        final smart = widget.smartApi;
        if (smart == null) return;
        final plan = await showDialog<({DateTime when, String note})>(context: context, builder: (_) => _ScheduleSwitchDialog(target: connection));
        if (plan == null) return;
        await smart.scheduleSwitch(m, toConnectionId: connection.id, scheduledFor: plan.when, note: plan.note);
        message = 'Switch to ${connection.providerName} scheduled. It will wait for you when its date comes.';
      case ProviderCommand.test:
        final result = await api.test(m, connection.id);
        message = result.check?.ok == true ? 'The connection is working.' : (result.check?.message.isNotEmpty == true ? result.check!.message : bankErrorLabel(result.check?.code ?? ''));
      case ProviderCommand.enable:
        final result = await api.enable(m, connection.id);
        message = result.check?.ok == false ? 'Enabled, but the check failed: ${result.check!.message}' : '${connection.providerName} is enabled again.';
      case ProviderCommand.disable:
        if (!await _ask('Disable ${connection.providerName}?', 'SchoolOS will stop using it until you enable it again. Its history stays.', 'Disable')) return;
        await api.disable(m, connection.id);
        message = '${connection.providerName} is disabled.';
      case ProviderCommand.disconnect:
        if (!await _ask(
          'Disconnect ${connection.providerName}?',
          'SchoolOS will forget its credentials. Payments and accounts already made are kept. You can connect it again later.',
          'Disconnect',
        )) {
          return;
        }
        await api.disconnect(m, connection.id);
        message = '${connection.providerName} is disconnected.';
      case ProviderCommand.rename:
        final label = await showDialog<String>(context: context, builder: (_) => _RenameDialog(connection: connection));
        if (label == null) return;
        await api.rename(m, connection.id, label: label);
        message = 'Saved.';
      case ProviderCommand.replaceCredentials:
        final provider = _providers?.provider(connection.provider);
        if (provider == null) {
          message = 'This provider is not available on the server.';
          break;
        }
        final result = await showReplaceCredentialsDialog(context, api: api, membership: m, connection: connection, provider: provider);
        if (result == null) return;
        message = 'Credentials replaced.';
      case ProviderCommand.webhook:
        final setup = await api.webhookSetup(m, connection.id);
        if (!mounted) return;
        await showWebhookSetupDialog(
          context,
          connection: connection,
          setup: setup,
          onNewAddress: () async {
            if (!await _ask('New webhook address?', 'The provider must be given the new address. The old one stops working at once.', 'Issue new address')) return null;
            return api.newWebhookAddress(m, connection.id);
          },
        );
      case ProviderCommand.payments || ProviderCommand.history:
        return;
    }
    if (!mounted) return;
    if (message != null) showBankMessage(context, message);
    _changed();
  }

  Future<void> _showHistory(ProviderConnection connection) async {
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
              for (final e in events) ListTile(dense: true, title: Text(auditKindLabel(e.kind)), subtitle: Text(whenLabel(e.at))),
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
    final connections = [for (final c in _connections!.connections) if (!c.isClosed) c];
    final closed = [for (final c in _connections!.connections) if (c.isClosed) c];
    final canManage = _connections!.canManage;
    final hasActive = connections.any((c) => c.isActiveProvider);
    final open = _switches?.open;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'The school connects its own Paystack, Monnify or Remita account. One provider is active at a time and makes the families\' '
                  'accounts. Credentials are kept encrypted on the server and can never be read back.',
                ),
              ),
              if (canManage) FilledButton.icon(key: const ValueKey('connect-provider-button'), onPressed: _connect, icon: const Icon(Icons.add), label: const Text('Connect provider')),
            ],
          ),
          const SizedBox(height: 16),
          if (connections.isNotEmpty && !hasActive)
            const BankSection(
              title: 'Choose the active provider',
              child: Text('No provider is active yet, so no family accounts can be made. Make one of the connected providers active.'),
            ),
          if (open != null && widget.smartApi != null)
            ProviderSwitchCard(api: widget.smartApi!, membership: widget.membership, provider: open, canManage: canManage, onChanged: _changed),
          if (connections.isEmpty)
            const BankSection(
              title: 'No collection provider connected yet',
              child: Text(
                'Connect the school\'s own account at Paystack, Monnify or Remita. SchoolOS then makes each family a collection account there, '
                'and reads the provider\'s signed notifications to see what was paid. The money goes to the school through the provider.',
              ),
            ),
          for (final c in connections)
            ProviderCard(
              connection: c,
              canManage: canManage,
              hasActiveProvider: hasActive,
              busy: _busyId == c.id,
              onCommand: (command) => _command(c, command),
            ),
          if (closed.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Disconnected', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final c in closed)
              ProviderCard(connection: c, canManage: canManage, hasActiveProvider: hasActive, busy: false, onCommand: (command) => _command(c, command)),
          ],
        ],
      ),
    );
  }
}

/// Owns its own text box, so it is disposed by the framework once the dialog has finished closing.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.connection});

  final ProviderConnection connection;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _label = TextEditingController(text: widget.connection.label);

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(controller: _label, maxLength: 80, decoration: const InputDecoration(labelText: 'Name')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(_label.text), child: const Text('Save')),
        ],
      );
}

/// Plan a switch to another provider: a date and time, and an optional note. Nothing changes on that date by itself.
class _ScheduleSwitchDialog extends StatefulWidget {
  const _ScheduleSwitchDialog({required this.target});

  final ProviderConnection target;

  @override
  State<_ScheduleSwitchDialog> createState() => _ScheduleSwitchDialogState();
}

class _ScheduleSwitchDialogState extends State<_ScheduleSwitchDialog> {
  final _note = TextEditingController();
  DateTime _when = DateTime.now().add(const Duration(days: 7));

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final date = await showDatePicker(context: context, initialDate: _when, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 730)));
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_when));
    if (!mounted) return;
    setState(() => _when = DateTime(date.year, date.month, date.day, time?.hour ?? _when.hour, time?.minute ?? _when.minute));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Switch to ${widget.target.providerName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Plan the change for a date. When it comes, the switch becomes ready and waits for you to review and apply it. '
              'SchoolOS never switches the school\'s provider on its own.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('pick-switch-date'),
              onPressed: _pick,
              icon: const Icon(Icons.event),
              label: Text(dateTimeLabel(_when)),
            ),
            const SizedBox(height: 8),
            TextField(controller: _note, maxLength: 300, decoration: const InputDecoration(labelText: 'Note (optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(key: const ValueKey('schedule-switch'), onPressed: () => Navigator.of(context).pop((when: _when, note: _note.text)), child: const Text('Schedule')),
        ],
      );
}
