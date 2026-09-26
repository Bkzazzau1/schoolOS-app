import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/models/school_membership.dart';
import '../data/bank_connect_api.dart';
import '../domain/bank_labels.dart';
import '../domain/bank_models.dart';
import 'bank_widgets.dart';

/// The steps for connecting one of the school's own accounts. It ends with the bank's own name for the
/// account, so the school confirms it connected what it meant to before anything is read from it.
///
/// Credentials live only in the text boxes below: they are sent once, straight to the server, and the
/// boxes are cleared the moment the request finishes, whether it worked or not.
class ConnectBankPage extends StatefulWidget {
  const ConnectBankPage({super.key, required this.api, required this.membership, required this.info});

  final BankConnectApi api;
  final SchoolMembership membership;
  final ProvidersInfo info;

  @override
  State<ConnectBankPage> createState() => _ConnectBankPageState();
}

enum _Step { provider, details, secret, confirm, done }

class _ConnectBankPageState extends State<ConnectBankPage> {
  static const _returnAddress = 'schoolos://bank/return';

  _Step _step = _Step.provider;
  BankProvider? _provider;
  String _method = 'credentials';
  String _purpose = 'tuition';
  final _label = TextEditingController();
  final _code = TextEditingController();
  final _fields = <String, TextEditingController>{};
  AuthorizationStart? _authorization;
  BankConnection? _connection;
  String? _webhookPath;
  bool _busy = false;
  bool _created = false;
  String? _error;

  @override
  void dispose() {
    _wipe();
    _label.dispose();
    _code.dispose();
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _wipe() {
    _code.clear();
    for (final c in _fields.values) {
      c.clear();
    }
  }

  void _choose(BankProvider provider) {
    for (final c in _fields.values) {
      c.dispose();
    }
    _fields
      ..clear()
      ..addEntries([for (final f in provider.credentialFields) MapEntry(f.name, TextEditingController())]);
    setState(() {
      _provider = provider;
      _method = provider.usesCredentials ? 'credentials' : 'authorization';
      _step = _Step.details;
      _error = null;
    });
  }

  Future<void> _run(Future<void> Function() work) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await work();
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
    } finally {
      _wipe();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toSecret() async {
    final provider = _provider!;
    if (_method == 'authorization') {
      await _run(() async {
        _authorization = await widget.api.beginAuthorization(
          widget.membership,
          provider: provider.code,
          redirectUri: _returnAddress,
        );
        setState(() => _step = _Step.secret);
      });
    } else {
      setState(() => _step = _Step.secret);
    }
  }

  Future<void> _verify() async {
    final provider = _provider!;
    await _run(() async {
      final byCode = _method == 'authorization';
      final connection = await widget.api.connect(
        widget.membership,
        provider: provider.code,
        purpose: _purpose,
        label: _label.text,
        credentials: byCode ? null : {for (final e in _fields.entries) e.key: e.value.text},
        authorizationCode: byCode ? _code.text : null,
        state: byCode ? _authorization?.state : null,
      );
      _created = true;
      setState(() {
        _connection = connection;
        _step = _Step.confirm;
      });
    });
  }

  Future<void> _confirm() async {
    await _run(() async {
      final result = await widget.api.confirm(widget.membership, _connection!.id);
      setState(() {
        _connection = result.connection;
        _webhookPath = result.webhookPath;
        _step = _Step.done;
      });
    });
  }

  Future<void> _notMine() async {
    await _run(() async {
      await widget.api.disconnect(widget.membership, _connection!.id);
      setState(() {
        _connection = null;
        _step = _Step.provider;
      });
      if (mounted) showBankMessage(context, 'That account was not connected. Nothing was kept.');
    });
  }

  Future<void> _openApprovalPage() async {
    final uri = Uri.tryParse(_authorization?.url ?? '');
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) showBankMessage(context, 'The approval page could not be opened. Copy the link and open it in a browser.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocked = !widget.info.canManage
        ? 'Only the owner, or someone the owner has authorised, can connect a bank account.'
        : !widget.info.secureStorageReady
            ? 'This server has no secure storage set up for bank credentials, so no account can be connected yet.'
            : null;
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_created);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Connect a bank account')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (blocked != null) _Notice(blocked) else ..._body(),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: _Notice(_error!, error: true)),
            if (_busy) const Padding(padding: EdgeInsets.only(top: 16), child: LinearProgressIndicator()),
          ],
        ),
      ),
    );
  }

  List<Widget> _body() => switch (_step) {
        _Step.provider => _providerStep(),
        _Step.details => _detailsStep(),
        _Step.secret => _secretStep(),
        _Step.confirm => _confirmStep(),
        _Step.done => _doneStep(),
      };

  List<Widget> _providerStep() => [
        const Text('Which account?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Only accounts that belong to the school can be connected. Parents\' own bank accounts never are.'),
        const SizedBox(height: 12),
        for (final provider in widget.info.providers)
          Card(
            child: ListTile(
              enabled: provider.available,
              leading: Icon(provider.isCollectionProvider ? Icons.payments_outlined : Icons.account_balance_outlined),
              title: Text(provider.displayName),
              subtitle: Text(
                provider.available
                    ? provider.description
                    : 'Awaiting verified bank API documentation. ${provider.description}',
              ),
              trailing: provider.isSandbox ? const SandboxTag() : const Icon(Icons.chevron_right),
              onTap: provider.available ? () => _choose(provider) : null,
            ),
          ),
      ];

  List<Widget> _detailsStep() {
    final provider = _provider!;
    return [
      Text(provider.displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        initialValue: _purpose,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'What does this account collect money for?'),
        items: [for (final e in bankPurposes.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
        onChanged: (value) => setState(() => _purpose = value ?? _purpose),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _label,
        maxLength: 80,
        decoration: const InputDecoration(labelText: 'A name for it (optional)', hintText: 'Tuition Collection'),
      ),
      if (provider.usesCredentials && provider.usesAuthorization) ...[
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'credentials', label: Text('Enter credentials')),
            ButtonSegment(value: 'authorization', label: Text('Approve on the bank\'s page')),
          ],
          selected: {_method},
          onSelectionChanged: (value) => setState(() => _method = value.first),
        ),
      ],
      const SizedBox(height: 16),
      FilledButton(onPressed: _busy ? null : _toSecret, child: const Text('Continue')),
      TextButton(onPressed: _busy ? null : () => setState(() => _step = _Step.provider), child: const Text('Back')),
    ];
  }

  List<Widget> _secretStep() {
    final provider = _provider!;
    if (_method == 'authorization') {
      return [
        const Text('Approve access on the bank\'s own page', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text(
          'SchoolOS never asks for an internet-banking password. Approve access on the bank\'s page, then paste the '
          'approval code it gives you.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _openApprovalPage,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open the approval page'),
            ),
            TextButton.icon(
              onPressed: () => Clipboard.setData(ClipboardData(text: _authorization?.url ?? '')),
              icon: const Icon(Icons.copy),
              label: const Text('Copy link'),
            ),
          ],
        ),
        if (provider.isSandbox) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Test provider: the code is sandbox-approved.')),
        const SizedBox(height: 12),
        TextField(controller: _code, decoration: const InputDecoration(labelText: 'Approval code'), autocorrect: false),
        const SizedBox(height: 16),
        FilledButton(onPressed: _busy ? null : _verify, child: const Text('Check the account')),
        TextButton(onPressed: _busy ? null : () => setState(() => _step = _Step.details), child: const Text('Back')),
      ];
    }
    return [
      Text('Credentials for ${provider.displayName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      const Text(
        'These go straight to the SchoolOS server over a secure connection and are stored encrypted there. They are not '
        'kept on this device and can never be shown again.',
      ),
      const SizedBox(height: 12),
      for (final field in provider.credentialFields)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: _fields[field.name],
            obscureText: field.secret,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(labelText: field.label),
          ),
        ),
      FilledButton(onPressed: _busy ? null : _verify, child: const Text('Check the account')),
      TextButton(onPressed: _busy ? null : () => setState(() => _step = _Step.details), child: const Text('Back')),
    ];
  }

  List<Widget> _confirmStep() {
    final connection = _connection!;
    return [
      const Text('Is this your school\'s account?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      const Text('This is what the bank itself says the account is. Check it before going on.'),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(connection.bankName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(connection.accountName),
              Text('Account ${connection.accountMask}'),
              Text('Collects: ${purposeLabel(connection.purpose)}'),
              if (connection.isSandbox) const Padding(padding: EdgeInsets.only(top: 8), child: SandboxTag()),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      FilledButton(onPressed: _busy ? null : _confirm, child: const Text('Yes, this is our account')),
      TextButton(onPressed: _busy ? null : _notMine, child: const Text('No, this is not the right account')),
    ];
  }

  List<Widget> _doneStep() {
    final connection = _connection!;
    return [
      const Icon(Icons.check_circle_outline, size: 40, color: Color(0xFF1B7F3B)),
      const SizedBox(height: 8),
      Text('${connection.title} is connected', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      const Text('Payments it receives will appear under Payments and are matched to students automatically.'),
      if (_webhookPath != null) ...[
        const SizedBox(height: 16),
        const Text('Callback address', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Give this to the provider so it can tell SchoolOS about new payments straight away. It is shown only once.'),
        const SizedBox(height: 8),
        SelectableText(_webhookPath!, style: const TextStyle(fontFamily: 'monospace')),
        TextButton.icon(
          onPressed: () => Clipboard.setData(ClipboardData(text: _webhookPath!)),
          icon: const Icon(Icons.copy),
          label: const Text('Copy'),
        ),
      ],
      const SizedBox(height: 16),
      FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Done')),
    ];
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text, {this.error = false});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: (error ? const Color(0xFFB3261E) : const Color(0xFF8A6D00)).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text),
      );
}
