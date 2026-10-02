import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../../bankconnect/presentation/collections_hub_page.dart';
import '../../mandates/presentation/mandates_hub_page.dart';
import '../data/my_duties_repository.dart';

/// Where a holder of a Mandates or Smart Money Collection duty reaches the hub that duty unlocks,
/// when they log in under a role whose workspace has no menu path to it (Finance Office and the
/// Proprietor already have their own direct menu entries and never need this screen). Shows nothing
/// made up: a person who holds no such duty sees a plain honest message, never a fabricated hub.
class MyDutiesPage extends StatefulWidget {
  const MyDutiesPage({super.key, required this.membership, required this.repository});

  final SchoolMembership membership;
  final MyDutiesRepository repository;

  @override
  State<MyDutiesPage> createState() => _MyDutiesPageState();
}

class _MyDutiesPageState extends State<MyDutiesPage> {
  late Future<Set<String>> _duties = widget.repository.activeDuties();

  void _refresh() => setState(() => _duties = widget.repository.activeDuties());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Set<String>>(
      future: _duties,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final duties = snapshot.data!;
        final hasMandates = duties.any(myDutiesMandateDuties.contains);
        final hasCollections = duties.any(myDutiesCollectionDuties.contains);
        if (!hasMandates && !hasCollections) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.badge_outlined, size: 42, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 12),
                    Text(
                      'The school owner has not given you a duty that opens a screen here yet.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (hasMandates)
              _DutyHubTile(
                icon: Icons.account_balance_outlined,
                title: 'Mandates & Direct Debit',
                subtitle: 'The duty you were given to manage providers, mandates or debit batches.',
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Mandates & Direct Debit')),
                    body: MandatesHubPage(membership: widget.membership, onChanged: _refresh),
                  ),
                )),
              ),
            if (hasCollections)
              _DutyHubTile(
                icon: Icons.payments_outlined,
                title: 'Smart Money Collection',
                subtitle: 'The duty you were given to manage collection providers, policy or batches.',
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Smart Money Collection')),
                    body: CollectionsHubPage(membership: widget.membership, onChanged: _refresh),
                  ),
                )),
              ),
          ],
        );
      },
    );
  }
}

class _DutyHubTile extends StatelessWidget {
  const _DutyHubTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: ListTile(
          leading: Icon(icon),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      );
}
