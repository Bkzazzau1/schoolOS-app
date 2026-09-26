import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../../bankconnect/domain/bank_labels.dart';
import '../../bankconnect/presentation/bank_widgets.dart';
import '../data/smart_collect_api.dart';
import '../domain/collection_models.dart';
import 'policy_fields_form.dart';

/// Prepare a collection batch: the session and term, the provider it will use, and the policy for this batch. It makes a preview of
/// every family for review and selection. Nothing is sent to any provider, and nothing in what families owe changes.
///
/// Returns the new batch's id when it was made.
class NewBatchPage extends StatefulWidget {
  const NewBatchPage({super.key, required this.api, required this.membership});

  final SmartCollectApi api;
  final SchoolMembership membership;

  @override
  State<NewBatchPage> createState() => _NewBatchPageState();
}

class _NewBatchPageState extends State<NewBatchPage> {
  final _title = TextEditingController();
  final _reason = TextEditingController();
  Periods? _periods;
  CollectionDashboard? _dashboard;
  CollectionPolicy? _policy;
  String? _sessionId;
  String? _termId;
  bool _changePolicy = false;
  Map<String, Object?> _changed = const {};
  String? _error;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([widget.api.periods(widget.membership), widget.api.dashboard(widget.membership)]);
      final periods = results[0] as Periods;
      if (!mounted) return;
      setState(() {
        _periods = periods;
        _dashboard = results[1] as CollectionDashboard;
        _policy = (results[1] as CollectionDashboard).policy;
        _sessionId = periods.currentSessionId ?? (periods.sessions.isEmpty ? null : periods.sessions.first.id);
        _termId = periods.currentTermId;
      });
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  PeriodSession? get _session {
    for (final s in _periods?.sessions ?? const <PeriodSession>[]) {
      if (s.id == _sessionId) return s;
    }
    return null;
  }

  Future<void> _create() async {
    final sessionId = _sessionId;
    if (sessionId == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final batch = await widget.api.createBatch(
        widget.membership,
        sessionId: sessionId,
        termId: _termId,
        title: _title.text,
        policy: _changePolicy ? _changed : null,
        reason: _reason.text,
      );
      if (mounted) Navigator.of(context).pop(batch.id);
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = _dashboard;
    final active = dashboard?.activeProvider;
    final session = _session;
    return Scaffold(
      appBar: AppBar(title: const Text('New collection batch')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _periods == null
              ? ErrorRetry(message: _error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'A batch makes a collection account for each family you select. You prepare it and review a preview; someone else approves it; '
                      'only then are accounts generated. Nothing is sent to the provider until then.',
                    ),
                    const SizedBox(height: 16),
                    BankSection(
                      title: '1. Session and term',
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            key: const ValueKey('batch-session'),
                            initialValue: session?.id,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Session', border: OutlineInputBorder()),
                            items: [for (final s in _periods?.sessions ?? const <PeriodSession>[]) DropdownMenuItem(value: s.id, child: Text(s.name))],
                            onChanged: (v) => setState(() {
                              _sessionId = v;
                              _termId = null;
                            }),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String?>(
                            key: const ValueKey('batch-term'),
                            initialValue: session != null && session.terms.any((t) => t.id == _termId) ? _termId : null,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Term', border: OutlineInputBorder()),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('The whole session')),
                              for (final t in session?.terms ?? const <PeriodTerm>[]) DropdownMenuItem<String?>(value: t.id, child: Text(t.name)),
                            ],
                            onChanged: (v) => setState(() => _termId = v),
                          ),
                        ],
                      ),
                    ),
                    BankSection(
                      title: '2. Provider',
                      child: active == null
                          ? const Text('The school has no active collection provider yet. Choose one in the Providers tab first: accounts are made by the active provider.', style: TextStyle(color: Color(0xFFB3261E)))
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${active.providerName} (${environmentLabel(active.environment)})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                Text(active.merchantName),
                                const SizedBox(height: 4),
                                const Text('This is the school\'s active provider. A batch is approved for it, and cannot use another.', style: TextStyle(color: Color(0xFF5F6B7A))),
                              ],
                            ),
                    ),
                    BankSection(
                      title: '3. Policy, arrears and eligibility',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_policy != null) ..._summary(_policy!),
                          SwitchListTile(
                            key: const ValueKey('change-batch-policy'),
                            contentPadding: EdgeInsets.zero,
                            value: _changePolicy,
                            onChanged: (v) => setState(() => _changePolicy = v),
                            title: const Text('Change the policy for this batch only'),
                            subtitle: const Text('For example dynamic accounts this term, or a different way to treat earlier balances.'),
                          ),
                          if (_changePolicy && _policy != null) ...[
                            PolicyFieldsForm(policy: _policy!, initial: _policy!.values, overrideMode: true, onChanged: (c) => _changed = c),
                            TextField(controller: _reason, maxLength: 300, decoration: const InputDecoration(labelText: 'Why (the school may require a reason)', border: OutlineInputBorder())),
                          ],
                        ],
                      ),
                    ),
                    TextField(controller: _title, maxLength: 120, decoration: const InputDecoration(labelText: 'Name for this batch (optional)', border: OutlineInputBorder())),
                    if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: const TextStyle(color: Color(0xFFB3261E)))),
                    FilledButton.icon(
                      key: const ValueKey('create-batch'),
                      onPressed: _busy || active == null || _sessionId == null ? null : _create,
                      icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.fact_check_outlined),
                      label: Text(_busy ? 'Preparing the preview…' : '4. Prepare the preview'),
                    ),
                  ],
                ),
    );
  }

  List<Widget> _summary(CollectionPolicy p) {
    final v = p.values;
    return [
      Text('School default: ${p.optionLabel('account_mode', v['account_mode'])} accounts. ${p.label('arrears_policy')}: ${p.optionLabel('arrears_policy', v['arrears_policy'])}. '
          '${p.label('eligibility_policy')}: ${p.optionLabel('eligibility_policy', v['eligibility_policy'])}.'),
      const SizedBox(height: 4),
      const Text('A family or term override may still change this for some families. The preview shows what applies to each.', style: TextStyle(color: Color(0xFF5F6B7A), fontSize: 12)),
    ];
  }
}
