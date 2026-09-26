import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../../bankconnect/presentation/bank_widgets.dart';
import '../data/mandates_api.dart';
import '../domain/mandate_labels.dart';
import '../domain/mandate_models.dart';

/// Connect a direct-debit provider: the school connects its OWN Remita or Lendsqr account with the credentials that provider issued to it.
///
/// The credentials go to the server once, over HTTPS, and are cleared from the screen whatever the answer. The server never sends one back.
/// Connecting one provider never touches another: a school may connect both, and there is no "active" one.
class ConnectMandateProviderPage extends StatefulWidget {
  const ConnectMandateProviderPage({super.key, required this.api, required this.membership, required this.providers, required this.connected});

  final MandatesApi api;
  final SchoolMembership membership;
  final MandateProvidersInfo providers;

  /// Provider codes the school already has a connection for.
  final Set<String> connected;

  @override
  State<ConnectMandateProviderPage> createState() => _ConnectMandateProviderPageState();
}

class _ConnectMandateProviderPageState extends State<ConnectMandateProviderPage> {
  String? _code;
  String _environment = 'test';
  final _label = TextEditingController();
  final Map<String, TextEditingController> _fields = {};
  bool _busy = false;
  String? _error;

  List<MandateProvider> get _offered => [for (final p in widget.providers.providers) if (p.available && !widget.connected.contains(p.code)) p];
  MandateProvider? get _provider {
    for (final p in _offered) {
      if (p.code == _code) return p;
    }
    return null;
  }

  @override
  void dispose() {
    _label.dispose();
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _choose(MandateProvider provider) {
    for (final c in _fields.values) {
      c.dispose();
    }
    _fields
      ..clear()
      ..addEntries([for (final f in provider.credentialFields) MapEntry(f.name, TextEditingController())]);
    setState(() {
      _code = provider.code;
      _environment = provider.environments.contains('test') ? 'test' : provider.environments.first;
      _error = null;
    });
  }

  Future<void> _submit() async {
    final provider = _provider;
    if (provider == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final connection = await widget.api.connect(
        widget.membership,
        provider: provider.code,
        environment: _environment,
        label: _label.text,
        credentials: {for (final e in _fields.entries) e.key: e.value.text.trim()},
      );
      if (mounted) Navigator.of(context).pop(connection);
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
    } finally {
      // Whatever the answer, the secrets do not stay on the screen.
      for (final c in _fields.values) {
        c.clear();
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    return Scaffold(
      appBar: AppBar(title: const Text('Connect a direct-debit provider')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Connect the school\'s own account at Remita or Lendsqr, with the credentials the provider issued to your school. The provider '
            'executes each debit and moves the money; SchoolOS never holds it. You can connect both: each mandate stays with the provider it was '
            'made under.',
          ),
          const SizedBox(height: 16),
          if (_offered.isEmpty)
            const BankSection(title: 'Nothing left to connect', child: Text('Both providers are connected. To use new credentials for one of them, replace its credentials from its card.')),
          for (final p in _offered)
            Card(
              key: ValueKey('provider-${p.code}'),
              color: p.code == _code ? const Color(0xFFEAF1FF) : null,
              child: InkWell(
                onTap: _busy ? null : () => _choose(p),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text(p.displayName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                        if (p.isSandbox) const SandboxTag(),
                      ]),
                      const SizedBox(height: 4),
                      Text(p.description),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 4, children: [
                        if (p.capabilities.supportsManualDebit)
                          const StatusChip(label: 'Can debit through SchoolOS', color: Color(0xFF1B7F3B))
                        else
                          const StatusChip(label: 'Debits not available through SchoolOS yet', color: Color(0xFF8A6D00)),
                        if (p.capabilities.supportsOtpActivation) const StatusChip(label: 'Activate with a bank one-time password', color: Color(0xFF3B5BA5)),
                        if (p.capabilities.supportsTransferActivation) const StatusChip(label: 'Activate by a transfer', color: Color(0xFF3B5BA5)),
                        if (p.capabilities.requiresProviderCustomer) const StatusChip(label: 'Needs the payer\'s customer id', color: Color(0xFF8A6D00)),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          if (provider != null) ...[
            const SizedBox(height: 8),
            BankSection(
              title: 'Your ${provider.displayName} account',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(provider.onboarding),
                  const SizedBox(height: 12),
                  if (provider.environments.length > 1) ...[
                    SegmentedButton<String>(
                      key: const ValueKey('environment'),
                      segments: [
                        for (final e in provider.environments) ButtonSegment(value: e, label: Text(mandateEnvironmentLabel(e))),
                      ],
                      selected: {_environment},
                      onSelectionChanged: _busy ? null : (s) => setState(() => _environment = s.first),
                    ),
                    if (!provider.liveEnabled && _environment == 'live')
                      Padding(
                        key: const ValueKey('live-note'),
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(provider.liveWhy, style: const TextStyle(color: Color(0xFF8A6D00))),
                      ),
                    if (provider.liveNote.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(provider.liveNote, style: const TextStyle(color: Color(0xFF5F6B7A)))),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    key: const ValueKey('label'),
                    controller: _label,
                    enabled: !_busy,
                    maxLength: 80,
                    decoration: const InputDecoration(labelText: 'A name for this connection (optional)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  for (final f in provider.credentialFields) ...[
                    TextField(
                      key: ValueKey('credential-${f.name}'),
                      controller: _fields[f.name],
                      enabled: !_busy,
                      obscureText: f.secret,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: InputDecoration(labelText: f.label, helperText: f.help.isEmpty ? null : f.help, border: const OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, key: const ValueKey('connect-error'), style: const TextStyle(color: Color(0xFFB3261E)))),
                  if (!widget.providers.secureStorageReady)
                    const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Secure storage is not set up on this server yet, so nothing can be connected.', style: TextStyle(color: Color(0xFFB3261E)))),
                  FilledButton.icon(
                    key: const ValueKey('connect-submit'),
                    onPressed: _busy || !widget.providers.secureStorageReady ? null : _submit,
                    icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.link),
                    label: Text('Connect ${provider.displayName}'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
