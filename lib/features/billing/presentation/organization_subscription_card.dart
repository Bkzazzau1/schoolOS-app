import 'package:flutter/material.dart';

import '../../../core/network/api_exceptions.dart';
import '../../account/domain/organization_membership.dart';
import '../data/billing_repository.dart';
import '../domain/subscription_summary.dart';

class OrganizationSubscriptionCard extends StatefulWidget {
  const OrganizationSubscriptionCard({
    super.key,
    required this.organization,
    required this.repository,
  });

  final OrganizationMembership organization;
  final BillingRepository repository;

  @override
  State<OrganizationSubscriptionCard> createState() =>
      _OrganizationSubscriptionCardState();
}

class _OrganizationSubscriptionCardState
    extends State<OrganizationSubscriptionCard> {
  OrganizationSubscriptionSummary? _summary;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant OrganizationSubscriptionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.organization.organizationId !=
        widget.organization.organizationId) {
      _load();
    }
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final summary = await widget.repository.organizationSubscription(
        widget.organization.organizationId,
      );
      if (!mounted) return;
      setState(() => _summary = summary);
    } on ApiOfflineException {
      if (!mounted) return;
      setState(() {
        _error = 'Subscription details are unavailable while SchoolOS is offline.';
      });
    } on SessionExpiredException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.credit_card_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'SchoolOS subscription',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (_summary != null)
                  Chip(label: Text(_summary!.statusLabel)),
              ],
            ),
            if (_loading) ...[
              const SizedBox(height: 14),
              const LinearProgressIndicator(),
            ] else if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                ),
              ),
            ] else if (_summary != null) ...[
              const SizedBox(height: 14),
              _SubscriptionDetails(summary: _summary!),
            ],
          ],
        ),
      ),
    );
  }
}

class _SubscriptionDetails extends StatelessWidget {
  const _SubscriptionDetails({required this.summary});

  final OrganizationSubscriptionSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = summary.plan;
    final schoolProvisioning = summary.entitlements['school_provisioning'];
    final multiSchool = summary.entitlements['multi_school'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 24,
          runSpacing: 16,
          children: [
            _Metric(
              label: 'Plan',
              value: plan?.name ?? 'Plan not assigned',
            ),
            if (plan != null && plan.studentUnitAmountMinor > 0)
              _Metric(
                label: 'Price basis',
                value: '${_money(plan.currency, plan.studentUnitAmountMinor)} / student',
              ),
            _Metric(
              label: 'Active schools',
              value: '${summary.usage.activeSchools}',
            ),
            if (summary.usage.billableStudents != null)
              _Metric(
                label: 'Billable students',
                value: '${summary.usage.billableStudents}',
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          _accessMessage(summary),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (plan != null && plan.billingInterval == null) ...[
          const SizedBox(height: 6),
          Text(
            'The billing interval has not been activated yet. This plan currently defines the commercial price basis and entitlements only.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (schoolProvisioning != null)
              _EntitlementChip(
                label: schoolProvisioning.available
                    ? 'School provisioning included'
                    : 'School provisioning unavailable',
                enabled: schoolProvisioning.available,
                limit: schoolProvisioning.limit,
              ),
            if (multiSchool != null)
              _EntitlementChip(
                label: multiSchool.available
                    ? 'Multi-school included'
                    : 'Multi-school unavailable',
                enabled: multiSchool.available,
                limit: multiSchool.limit,
              ),
          ],
        ),
        if (summary.canManageBilling) ...[
          const SizedBox(height: 12),
          Text(
            'You have billing authority for this organization.',
            style: theme.textTheme.labelMedium,
          ),
        ],
      ],
    );
  }

  static String _accessMessage(OrganizationSubscriptionSummary summary) {
    return switch (summary.accessMode) {
      'full' => 'Account-level changes are available under the current subscription.',
      'account_restricted' =>
        'Account-level changes are restricted. Existing school data and daily school work remain available.',
      'suspended' =>
        'The subscription is suspended. Existing local school data is preserved while the account is resolved.',
      _ => 'Subscription access state is not available.',
    };
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 260),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EntitlementChip extends StatelessWidget {
  const _EntitlementChip({
    required this.label,
    required this.enabled,
    this.limit,
  });

  final String label;
  final bool enabled;
  final int? limit;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(
        enabled ? Icons.check_circle_rounded : Icons.block_rounded,
        size: 18,
      ),
      label: Text(limit == null ? label : '$label · limit $limit'),
    );
  }
}

String _money(String currency, int minor) {
  final major = minor ~/ 100;
  final cents = minor.remainder(100);
  final digits = major.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  final symbol = currency == 'NGN' ? '₦' : '$currency ';
  if (cents == 0) return '$symbol$buffer';
  return '$symbol$buffer.${cents.toString().padLeft(2, '0')}';
}
