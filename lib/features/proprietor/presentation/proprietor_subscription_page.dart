import 'package:flutter/material.dart';

import '../../../core/network/api_exceptions.dart';
import '../../account/domain/organization_membership.dart';
import '../../billing/data/billing_repository.dart';
import '../../billing/domain/subscription_summary.dart';
import '../../billing/presentation/organization_invoices_card.dart';
import '../../billing/presentation/organization_subscription_card.dart';

/// The owner's own school-level view of the account's SchoolOS subscription -
/// the same real data Account Home shows for the account as a whole, reached
/// from inside a school without leaving it. Only ever built when
/// BillingScope is present (a connected server); the calling nav already
/// hides this destination otherwise, the same way it hides Access &
/// Activities on demo data.
class ProprietorSubscriptionPage extends StatefulWidget {
  const ProprietorSubscriptionPage({
    super.key,
    required this.organizationId,
    required this.schoolName,
    required this.repository,
  });

  /// Empty when this school has not been linked to an organization account
  /// yet - shown as an honest, unavailable state rather than guessed at.
  final String organizationId;
  final String schoolName;
  final BillingRepository repository;

  @override
  State<ProprietorSubscriptionPage> createState() => _ProprietorSubscriptionPageState();
}

class _ProprietorSubscriptionPageState extends State<ProprietorSubscriptionPage> {
  late Future<OrganizationSubscriptionSummary> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<OrganizationSubscriptionSummary> _load() =>
      widget.repository.organizationSubscription(widget.organizationId);

  void _reload() => setState(() => _future = _load());

  /// A minimal, real organizationId wrapped in the shape OrganizationInvoicesCard
  /// expects - its name and role are never read or shown by that widget (only
  /// .organizationId is), so nothing here is display text a viewer could see
  /// and mistake for something it is not.
  OrganizationMembership get _organization => OrganizationMembership(
        id: widget.organizationId,
        organizationId: widget.organizationId,
        organizationName: widget.schoolName,
        role: OrganizationRole.owner,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: EdgeInsets.all(constraints.maxWidth < 700 ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PROPRIETOR · SUBSCRIPTION',
              style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 1.1),
            ),
            const SizedBox(height: 5),
            Text('Subscription', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            const Text('The SchoolOS plan, billing cadence and entitlements for this account.'),
            const SizedBox(height: 18),
            if (widget.organizationId.isEmpty)
              const Card(
                elevation: 0,
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('This school has not been linked to an organization account yet.'),
                ),
              )
            else
              _body(),
          ],
        ),
      ),
    );
  }

  Widget _body() => FutureBuilder<OrganizationSubscriptionSummary>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            final message = error is ApiOfflineException
                ? 'Subscription details are unavailable while SchoolOS is offline.'
                : error is ApiException
                    ? error.message
                    : 'Could not load the subscription.';
            return Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: _reload, child: const Text('Retry')),
                  ],
                ),
              ),
            );
          }
          final summary = snapshot.requireData;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.credit_card_rounded, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'SchoolOS subscription',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Chip(label: Text(summary.statusLabel)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SubscriptionDetailsView(summary: summary),
                    ],
                  ),
                ),
              ),
              if (summary.canManageBilling) ...[
                const SizedBox(height: 10),
                OrganizationInvoicesCard(
                  organization: _organization,
                  repository: widget.repository,
                  automation: summary.automation,
                ),
              ],
            ],
          );
        },
      );
}
