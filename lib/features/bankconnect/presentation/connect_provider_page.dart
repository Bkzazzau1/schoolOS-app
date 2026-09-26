import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../data/bank_connect_api.dart';
import '../domain/bank_labels.dart';
import '../domain/bank_models.dart';
import 'bank_widgets.dart';
import 'webhook_setup_dialog.dart';

/// Connect Collection Provider: the school connects its OWN Paystack, Monnify or Remita account with the credentials that
/// provider issued to it. There is no bank account to enter and nothing to confirm: SchoolOS never receives or holds fee money.
///
/// What the school is asked for depends on the provider (the fields come from the server), and a secret is masked while typed,
/// sent once over HTTPS, and never shown or kept again.
class ConnectProviderPage extends StatefulWidget {
  const ConnectProviderPage({super.key, required this.api, required this.membership, required this.info, this.alreadyConnected = const []});

  final BankConnectApi api;
  final SchoolMembership membership;
  final ProvidersInfo info;

  /// Provider codes the school has already connected (each provider can be connected once; replace its credentials instead).
  final List<String> alreadyConnected;

  @override
  State<ConnectProviderPage> createState() => _ConnectProviderPageState();
}

class _ConnectProviderPageState extends State<ConnectProviderPage> {
  final _label = TextEditingController();
  final Map<String, TextEditingController> _fields = {};
  CollectionProvider? _provider;
  String _environment = 'live';
  bool _busy = false;
  String? _error;

  List<CollectionProvider> get _choices => [
        for (final p in widget.info.providers)
          if (p.available && !widget.alreadyConnected.contains(p.code)) p,
      ];

  @override
  void initState() {
    super.initState();
    final choices = _choices;
    if (choices.isNotEmpty) _choose(choices.first);
  }

  @override
  void dispose() {
    _label.dispose();
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _choose(CollectionProvider provider) {
    for (final c in _fields.values) {
      c.dispose();
    }
    _fields.clear();
    for (final f in provider.credentialFields) {
      _fields['credential:${f.name}'] = TextEditingController();
    }
    for (final f in provider.settingFields) {
      _fields['setting:${f.name}'] = TextEditingController(text: f.defaultValue);
    }
    setState(() {
      _provider = provider;
      _environment = provider.environments.contains('live') ? 'live' : (provider.environments.isEmpty ? 'test' : provider.environments.first);
      _error = null;
    });
  }

  Future<void> _connect() async {
    final provider = _provider;
    if (provider == null || _busy) return;
    final credentials = <String, String>{};
    for (final f in provider.credentialFields) {
      final value = _fields['credential:${f.name}']!.text.trim();
      if (f.required && value.isEmpty) {
        setState(() => _error = 'Enter ${f.label}.');
        return;
      }
      if (value.isNotEmpty) credentials[f.name] = value;
    }
    final settings = <String, String>{};
    for (final f in provider.settingFields) {
      final value = _fields['setting:${f.name}']!.text.trim();
      if (value.isNotEmpty) settings[f.name] = value;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ProviderConnection connection;
    try {
      connection = await widget.api.connect(
        widget.membership,
        provider: provider.code,
        environment: _environment,
        label: _label.text,
        credentials: credentials,
        settings: settings,
      );
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
      return;
    } finally {
      // The credentials have gone to the server, whatever it answered: they are cleared from the screen at once, so a refused key
      // does not sit in a box, and a person types it again.
      for (final f in provider.credentialFields) {
        _fields['credential:${f.name}']?.clear();
      }
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    await _showWebhook(connection);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _showWebhook(ProviderConnection connection) async {
    try {
      final setup = await widget.api.webhookSetup(widget.membership, connection.id);
      if (!mounted) return;
      await showWebhookSetupDialog(context, connection: connection, setup: setup, justConnected: true);
    } catch (_) {
      // The provider is connected; the address can be opened again from its card.
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final provider = _provider;
    return Scaffold(
      appBar: AppBar(title: const Text('Connect Collection Provider')),
      body: !info.secureStorageReady
          ? const _Notice(
              icon: Icons.lock_outline,
              title: 'Secure storage is not set up',
              message: 'This server has no key to keep provider credentials safely, so no provider can be connected yet. Ask whoever runs the school\'s server to set it up.',
            )
          : _choices.isEmpty
              ? const _Notice(
                  icon: Icons.check_circle_outline,
                  title: 'Every provider is connected',
                  message: 'Paystack, Monnify and Remita are all connected. To use new credentials for one of them, replace its credentials from its card.',
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Connect the school\'s own account at one of these providers. Parents pay into accounts the provider makes for each family, '
                      'and the money goes to the school through the provider: SchoolOS never receives or holds it.',
                    ),
                    const SizedBox(height: 16),
                    const Text('Choose the school\'s provider', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final p in _choices)
                          ChoiceChip(
                            key: ValueKey('provider-${p.code}'),
                            label: Text(p.displayName),
                            selected: provider?.code == p.code,
                            onSelected: _busy ? null : (_) => _choose(p),
                          ),
                      ],
                    ),
                    if (provider != null) ..._form(provider),
                  ],
                ),
    );
  }

  List<Widget> _form(CollectionProvider provider) => [
        const SizedBox(height: 16),
        BankSection(
          title: provider.displayName,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (provider.description.isNotEmpty) Text(provider.description),
              if (provider.onboarding.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(provider.onboarding, style: const TextStyle(fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (provider.capabilities.supportsStaticAccounts) const StatusChip(label: 'Static accounts', color: Color(0xFF3B5BA5)),
                  if (provider.capabilities.supportsDynamicAccounts) const StatusChip(label: 'Dynamic accounts', color: Color(0xFF3B5BA5)),
                  if (provider.capabilities.requiresCustomerKyc) const StatusChip(label: 'Needs the payer\'s BVN or NIN', color: Color(0xFF8A6D00)),
                  if (provider.requiresAmount) const StatusChip(label: 'Made for an amount', color: Color(0xFF8A6D00)),
                ],
              ),
            ],
          ),
        ),
        if (provider.environments.length > 1) ...[
          const Text('Mode', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [for (final e in provider.environments) ButtonSegment(value: e, label: Text(environmentLabel(e)))],
            selected: {_environment},
            onSelectionChanged: _busy ? null : (s) => setState(() => _environment = s.first),
          ),
          const SizedBox(height: 4),
          Text(
            _environment == 'live' ? 'Live: real payments from real families.' : 'Test: the provider\'s own test mode. No real money.',
            style: const TextStyle(color: Color(0xFF5F6B7A)),
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _label,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Name for this connection (optional)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        for (final f in provider.credentialFields) ...[
          TextField(
            key: ValueKey('credential-${f.name}'),
            controller: _fields['credential:${f.name}'],
            obscureText: f.secret,
            enableSuggestions: false,
            autocorrect: false,
            enableInteractiveSelection: !f.secret,
            decoration: InputDecoration(
              labelText: f.label,
              helperText: f.help.isEmpty ? null : f.help,
              helperMaxLines: 2,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
        ],
        for (final f in provider.settingFields) ...[
          TextField(
            key: ValueKey('setting-${f.name}'),
            controller: _fields['setting:${f.name}'],
            decoration: InputDecoration(labelText: f.label, border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
        ],
        const Text(
          'Credentials go straight to the school\'s server over a secure connection, are stored encrypted, and can never be read back or shown again.',
          style: TextStyle(color: Color(0xFF5F6B7A), fontSize: 12),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Color(0xFFB3261E))),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const ValueKey('connect-provider'),
          onPressed: _busy ? null : _connect,
          icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.link),
          label: Text(_busy ? 'Checking with ${provider.displayName}…' : 'Connect ${provider.displayName}'),
        ),
      ];
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: const Color(0xFF5F6B7A)),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}
