import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../../bankconnect/domain/bank_labels.dart';
import '../../bankconnect/presentation/bank_widgets.dart';
import '../../familyfees/data/family_fees_api.dart';
import '../../familyfees/domain/family_fees_models.dart';
import '../data/mandates_api.dart';
import '../domain/mandate_labels.dart';
import '../domain/mandate_models.dart';

/// Start a mandate for a payer. A member of staff starts it; the PAYER authorises it themselves. There is no "the customer consented" box:
/// staff cannot give consent for anyone.
///
/// The account number is typed here, goes to the server once over HTTPS, is sealed there and is never shown again (only a bank and a masked
/// number are). It is cleared from the screen whatever the answer.
class StartMandatePage extends StatefulWidget {
  const StartMandatePage({super.key, required this.api, required this.membership, required this.connections, this.familyId, this.familyName});

  final MandatesApi api;
  final SchoolMembership membership;

  /// The connections a mandate can be made under (working ones only).
  final List<MandateConnection> connections;
  final String? familyId;
  final String? familyName;

  @override
  State<StartMandatePage> createState() => _StartMandatePageState();
}

class _StartMandatePageState extends State<StartMandatePage> {
  final _search = TextEditingController();
  final _account = TextEditingController();
  final _maximum = TextEditingController();
  final _customer = TextEditingController();
  List<FamilyRow> _families = const [];
  String? _familyId;
  String? _familyName;
  List<FamilyPayer> _payers = const [];
  String? _payerId;
  MandateConnection? _connection;
  List<BankOption> _banks = const [];
  String? _bankCode;
  String _route = 'provider';
  bool _busy = false;
  String? _error;

  List<MandateConnection> get _usable => [for (final c in widget.connections) if (c.usable) c];

  @override
  void initState() {
    super.initState();
    _familyId = widget.familyId;
    _familyName = widget.familyName;
    if (_usable.length == 1) _connection = _usable.first;
    if (_familyId != null) _loadPayers();
    if (_connection != null) _loadBanks();
  }

  @override
  void dispose() {
    _search.dispose();
    _account.dispose();
    _maximum.dispose();
    _customer.dispose();
    super.dispose();
  }

  Future<void> _findFamilies() async {
    final families = FamilyFeesScope.maybeOf(context);
    if (families == null) return;
    try {
      final page = await families.families(widget.membership, query: _search.text, limit: 10);
      if (mounted) setState(() => _families = page.families);
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
    }
  }

  Future<void> _pickFamily(FamilyRow family) async {
    setState(() {
      _familyId = family.id;
      _familyName = family.displayName;
      _families = const [];
      _payerId = null;
    });
    await _loadPayers();
  }

  Future<void> _loadPayers() async {
    final id = _familyId;
    if (id == null) return;
    try {
      final payers = await widget.api.familyPayers(widget.membership, id);
      if (!mounted) return;
      setState(() {
        _payers = payers;
        final primary = payers.where((p) => p.isPrimaryPayer);
        _payerId = primary.isNotEmpty ? primary.first.id : (payers.length == 1 ? payers.first.id : null);
        _syncRoute();
      });
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
    }
  }

  Future<void> _loadBanks() async {
    final c = _connection;
    if (c == null) return;
    try {
      final banks = await widget.api.banks(widget.membership, c.id);
      if (mounted) setState(() => _banks = banks);
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
    }
  }

  FamilyPayer? get _payer {
    for (final p in _payers) {
      if (p.id == _payerId) return p;
    }
    return null;
  }

  /// A payer with a signed-in account can authorise in the app; one without can only authorise with the provider.
  void _syncRoute() {
    final payer = _payer;
    _route = payer != null && payer.hasAppAccount ? 'payer_app' : 'provider';
  }

  Future<void> _submit() async {
    final maximum = double.tryParse(_maximum.text.replaceAll(',', '').trim());
    if (_familyId == null || _payerId == null || _connection == null || _bankCode == null) {
      setState(() => _error = 'Choose the family, the payer, the provider and the bank.');
      return;
    }
    if (maximum == null || maximum <= 0) {
      setState(() => _error = 'Say the most that can be debited, in naira.');
      return;
    }
    if (_connection!.capabilities.requiresProviderCustomer && _customer.text.trim().isEmpty) {
      setState(() => _error = 'Enter the payer\'s ${_connection!.providerName} customer id.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final mandate = await widget.api.startMandate(
        widget.membership,
        StartMandateRequest(
          familyId: _familyId!,
          payerId: _payerId!,
          connectionId: _connection!.id,
          bankCode: _bankCode!,
          accountNumber: _account.text.trim(),
          maximumAmountMinor: (maximum * 100).round(),
          consentRoute: _route,
          providerCustomerRef: _customer.text.trim(),
        ),
      );
      if (mounted) Navigator.of(context).pop(mandate);
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
    } finally {
      _account.clear(); // the account number does not stay on the screen, whatever the answer
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final payer = _payer;
    final connection = _connection;
    return Scaffold(
      appBar: AppBar(title: const Text('Start a direct-debit mandate')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'The payer authorises the mandate themselves: SchoolOS asks them, and nothing is debited until they have and their bank has '
            'activated it. Staff cannot give that consent for them.',
          ),
          const SizedBox(height: 16),
          BankSection(
            title: '1. The family and its payer',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_familyId == null) ...[
                  TextField(
                    key: const ValueKey('family-search'),
                    controller: _search,
                    decoration: InputDecoration(
                      labelText: 'Find a family',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(key: const ValueKey('family-search-go'), icon: const Icon(Icons.search), onPressed: _findFamilies),
                    ),
                    onSubmitted: (_) => _findFamilies(),
                  ),
                  for (final f in _families) ListTile(key: ValueKey('family-${f.id}'), title: Text(f.displayName), subtitle: Text(f.code), onTap: () => _pickFamily(f)),
                ] else
                  Row(children: [
                    Expanded(child: Text(_familyName ?? '', style: const TextStyle(fontWeight: FontWeight.w700))),
                    if (widget.familyId == null) TextButton(onPressed: () => setState(() { _familyId = null; _payers = const []; _payerId = null; }), child: const Text('Change')),
                  ]),
                if (_payers.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('payer'),
                    initialValue: _payerId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Payer', border: OutlineInputBorder()),
                    items: [
                      for (final p in _payers) DropdownMenuItem(value: p.id, child: Text('${p.name}${p.relationship.isEmpty ? '' : ' (${p.relationship})'}', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) => setState(() {
                      _payerId = v;
                      _syncRoute();
                    }),
                  ),
                ],
              ],
            ),
          ),
          BankSection(
            title: '2. The provider and the payer\'s bank',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_usable.isEmpty) const Text('No provider is connected and working. Connect one first.'),
                if (_usable.isNotEmpty)
                  DropdownButtonFormField<MandateConnection>(
                    key: const ValueKey('connection'),
                    initialValue: connection,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Provider', border: OutlineInputBorder()),
                    items: [for (final c in _usable) DropdownMenuItem(value: c, child: Text('${c.providerName} (${mandateEnvironmentLabel(c.environment)})', overflow: TextOverflow.ellipsis))],
                    onChanged: (c) {
                      setState(() {
                        _connection = c;
                        _bankCode = null;
                        _banks = const [];
                      });
                      _loadBanks();
                    },
                  ),
                const SizedBox(height: 12),
                if (_banks.isNotEmpty)
                  DropdownButtonFormField<String>(
                    key: const ValueKey('bank'),
                    initialValue: _bankCode,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Bank', border: OutlineInputBorder()),
                    items: [for (final b in _banks) DropdownMenuItem(value: b.code, child: Text(b.name, overflow: TextOverflow.ellipsis))],
                    onChanged: (v) => setState(() => _bankCode = v),
                  ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('account'),
                  controller: _account,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  maxLength: 10,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Account number (10 digits)',
                    helperText: 'Kept sealed on the server. It is never shown again: only the bank and the last four digits are.',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (connection != null && connection.capabilities.requiresProviderCustomer) ...[
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('provider-customer'),
                    controller: _customer,
                    decoration: InputDecoration(labelText: 'Payer\'s ${connection.providerName} customer id', border: const OutlineInputBorder()),
                  ),
                ],
              ],
            ),
          ),
          BankSection(
            title: '3. The limit and how the payer authorises',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: const ValueKey('maximum'),
                  controller: _maximum,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Most that can be debited (naira)',
                    helperText: 'A limit on the payer\'s authority, never the amount that is debited: each debit comes from what the ledger says is owed.',
                    helperMaxLines: 3,
                    border: const OutlineInputBorder(),
                    prefixText: '${formatMoneyMinor(0).replaceAll(RegExp(r'[0-9.,]'), '').trim()} ',
                  ),
                ),
                const SizedBox(height: 12),
                if (payer != null)
                  Text(
                    payer.hasAppAccount
                        ? '${payer.name} has an account in the app, so they will be asked to review and authorise it there.'
                        : '${payer.name} has no account in the app, so they will authorise with the provider (the bank\'s one-time password, a signed form, or an activation transfer).',
                    key: const ValueKey('route-note'),
                  ),
                if (payer != null && payer.hasAppAccount)
                  SegmentedButton<String>(
                    key: const ValueKey('route'),
                    segments: const [
                      ButtonSegment(value: 'payer_app', label: Text('In the app')),
                      ButtonSegment(value: 'provider', label: Text('With the provider')),
                    ],
                    selected: {_route},
                    onSelectionChanged: (s) => setState(() => _route = s.first),
                  ),
              ],
            ),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, key: const ValueKey('start-error'), style: const TextStyle(color: Color(0xFFB3261E)))),
          FilledButton.icon(
            key: const ValueKey('start-submit'),
            onPressed: _busy ? null : _submit,
            icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.assignment_turned_in_outlined),
            label: const Text('Start the mandate'),
          ),
        ],
      ),
    );
  }
}
