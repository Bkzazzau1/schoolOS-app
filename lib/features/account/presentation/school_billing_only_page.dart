import 'package:flutter/material.dart';

import '../../billing/data/billing_repository.dart';
import '../../billing/presentation/school_entitlement_card.dart';

/// A read-only billing view of one school for an organization-level billing administrator
/// who holds no school-level membership there at all - shows only its subscription and
/// premium-entitlement status, never any academic or operational workspace (Phase D Stage
/// 1.5, Task 5: "Do not grant them school-level academic permissions they do not possess").
class SchoolBillingOnlyPage extends StatelessWidget {
  const SchoolBillingOnlyPage({
    super.key,
    required this.schoolId,
    required this.schoolName,
    required this.repository,
  });

  final String schoolId;
  final String schoolName;
  final BillingRepository repository;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('$schoolName · Billing')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'You manage billing for this organization but do not have a role at '
                    'this school, so only its subscription status is shown here.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SchoolEntitlementCard(schoolId: schoolId, repository: repository),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
