import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../data/mandates_api.dart';
import '../domain/mandate_models.dart';
import 'payer_mandates_page.dart';

/// The payer's way into their own Direct Debit, on the Parent's finance page. It appears only where the app has a school server, because a
/// mandate, a one-time password and the provider's answer exist only there. It says what is waiting for the payer, and never calls a mandate
/// active before the provider says it can be debited.
class DirectDebitCard extends StatefulWidget {
  const DirectDebitCard({super.key, required this.membership});

  final SchoolMembership membership;

  @override
  State<DirectDebitCard> createState() => _DirectDebitCardState();
}

class _DirectDebitCardState extends State<DirectDebitCard> {
  MandatesApi? _api;
  Future<List<Mandate>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final api = MandatesScope.maybeOf(context);
    if (api != _api || (_future == null && api != null)) {
      _api = api;
      _future = api?.myMandates(widget.membership);
    }
  }

  Future<void> _open() async {
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => PayerMandatesPage(membership: widget.membership)));
    final api = _api;
    if (mounted && api != null) setState(() => _future = api.myMandates(widget.membership));
  }

  @override
  Widget build(BuildContext context) {
    final future = _future;
    if (_api == null || future == null) return const SizedBox.shrink();
    return FutureBuilder<List<Mandate>>(
      future: future,
      builder: (context, state) {
        final mandates = state.data;
        if (mandates == null || mandates.isEmpty) return const SizedBox.shrink(); // nothing set up for this payer: nothing is offered or invented
        final waiting = mandates.where((m) => m.consentRequired || m.status == 'pending_activation').length;
        final active = mandates.where((m) => m.debitReady).length;
        return Card(
          key: const ValueKey('direct-debit-card'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Direct Debit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  waiting > 0
                      ? '$waiting direct debit${waiting == 1 ? ' is' : 's are'} waiting for you to authorise or activate. Nothing is debited until you have and your bank has activated it.'
                      : (active > 0 ? 'Your direct debit is active. The school can debit your account only for approved school fees.' : 'Your direct debit is not active yet.'),
                ),
                const SizedBox(height: 10),
                FilledButton(key: const ValueKey('open-direct-debit'), onPressed: _open, child: const Text('Open Direct Debit')),
              ],
            ),
          ),
        );
      },
    );
  }
}
