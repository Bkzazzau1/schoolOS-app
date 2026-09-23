import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../app/open_home.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/organization_membership.dart';
import 'create_school_page.dart';

class AccountHomePage extends StatelessWidget {
  const AccountHomePage({
    super.key,
    required this.profile,
    required this.services,
    required this.onSignOut,
  });

  final AuthProfile profile;
  final AppServices services;
  final Future<void> Function(BuildContext context) onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final organizations = profile.organizations;
    final schoolsByOrganization = <String, List<SchoolMembership>>{
      for (final organization in organizations)
        organization.organizationId:
            _schoolsForOrganization(organization, organizations),
    };
    final assignedSchoolMembershipIds = {
      for (final schools in schoolsByOrganization.values)
        for (final membership in schools) membership.id,
    };
    final otherSchools = profile.memberships
        .where(
          (membership) =>
              !assignedSchoolMembershipIds.contains(membership.id),
        )
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SchoolOS Account'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => onSignOut(context),
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
              children: [
                _AccountHeader(profile: profile),
                const SizedBox(height: 28),
                if (organizations.isNotEmpty) ...[
                  Text(
                    'Your school groups',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage the schools you own or administer. Each school remains a separate tenant with its own people, roles, data and offline workspace.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  for (final organization in organizations) ...[
                    _OrganizationCard(
                      organization: organization,
                      schools: schoolsByOrganization[organization.organizationId] ??
                          const [],
                      canProvision: services.organizations != null,
                      onOpenSchool: (membership) =>
                          _openSchool(context, membership),
                      onCreateSchool: () => _createSchool(
                        context,
                        organization,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
                if (otherSchools.isNotEmpty) ...[
                  if (organizations.isNotEmpty) const SizedBox(height: 12),
                  Text(
                    organizations.isEmpty ? 'Your schools' : 'Other school access',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    organizations.isEmpty
                        ? 'Choose the school and role you want to use.'
                        : 'Schools where you have a role outside the groups you manage.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SchoolGrid(
                    schools: otherSchools,
                    onOpenSchool: (membership) =>
                        _openSchool(context, membership),
                  ),
                ],
                if (organizations.isEmpty && profile.memberships.isEmpty)
                  const _EmptyAccountCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<SchoolMembership> _schoolsForOrganization(
    OrganizationMembership organization,
    List<OrganizationMembership> organizations,
  ) {
    final explicit = profile.memberships
        .where(
          (membership) => membership.organizationId == organization.organizationId,
        )
        .toList(growable: false);
    if (explicit.isNotEmpty || organizations.length != 1) return explicit;

    // Transitional compatibility: during rollout an older school-membership
    // payload may not yet include organizationId. For a person managing exactly
    // one organization, only proprietor memberships are safely attributable to
    // that account; teacher/parent/etc memberships stay under Other school access.
    return profile.memberships
        .where(
          (membership) =>
              membership.organizationId == null &&
              membership.role == SchoolRole.proprietor,
        )
        .toList(growable: false);
  }

  Future<void> _openSchool(
    BuildContext context,
    SchoolMembership membership,
  ) async {
    await openMembershipHome(
      context,
      services,
      membership,
      preserveAccountHome: true,
    );
    if (!context.mounted) return;
    await _refreshAccountRoute(context);
  }

  Future<void> _refreshAccountRoute(BuildContext context) async {
    final auth = services.auth;
    if (auth == null) return;

    try {
      final refreshed = await auth.refreshProfile();
      if (!context.mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => AccountHomePage(
            profile: refreshed,
            services: services,
            onSignOut: onSignOut,
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account details could not be refreshed. Showing the last loaded information.',
          ),
        ),
      );
    }
  }

  Future<void> _createSchool(
    BuildContext context,
    OrganizationMembership organization,
  ) async {
    final repository = services.organizations;
    if (repository == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connect SchoolOS to the server before creating a school.'),
        ),
      );
      return;
    }

    final membership = await Navigator.of(context).push<SchoolMembership>(
      MaterialPageRoute<SchoolMembership>(
        builder: (_) => CreateSchoolPage(
          organization: organization,
          repository: repository,
        ),
      ),
    );
    if (membership == null || !context.mounted) return;
    await _openSchool(context, membership);
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.profile});

  final AuthProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = profile.name.trim().isEmpty
        ? 'Your SchoolOS account'
        : profile.name.trim();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            child: const Icon(Icons.account_circle_rounded, size: 34),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.email,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.78,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'One account can manage multiple schools while each school keeps its own operational data and permissions.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrganizationCard extends StatelessWidget {
  const _OrganizationCard({
    required this.organization,
    required this.schools,
    required this.canProvision,
    required this.onOpenSchool,
    required this.onCreateSchool,
  });

  final OrganizationMembership organization;
  final List<SchoolMembership> schools;
  final bool canProvision;
  final Future<void> Function(SchoolMembership membership) onOpenSchool;
  final VoidCallback onCreateSchool;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 650),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        organization.organizationName.isEmpty
                            ? 'School organization'
                            : organization.organizationName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Chip(label: Text(organization.roleLabel)),
                          Text(
                            '${schools.length} ${schools.length == 1 ? 'school' : 'schools'}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (organization.canCreateSchools)
                  FilledButton.tonalIcon(
                    onPressed: canProvision ? onCreateSchool : null,
                    icon: const Icon(Icons.add_business_rounded),
                    label: const Text('Add school'),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            if (schools.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No schools yet',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      organization.canCreateSchools
                          ? 'Create the first school under this account to begin.'
                          : 'An account owner or administrator can add a school here.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            else
              _SchoolGrid(
                schools: schools,
                onOpenSchool: onOpenSchool,
              ),
          ],
        ),
      ),
    );
  }
}

class _SchoolGrid extends StatelessWidget {
  const _SchoolGrid({
    required this.schools,
    required this.onOpenSchool,
  });

  final List<SchoolMembership> schools;
  final Future<void> Function(SchoolMembership membership) onOpenSchool;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 2 : 1;
        final width = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final membership in schools)
              SizedBox(
                width: width,
                child: _SchoolCard(
                  membership: membership,
                  onOpen: () => onOpenSchool(membership),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SchoolCard extends StatelessWidget {
  const _SchoolCard({required this.membership, required this.onOpen});

  final SchoolMembership membership;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = membership.schoolName.trim().isEmpty
        ? 'S'
        : membership.schoolName.trim().characters.first.toUpperCase();

    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              CircleAvatar(child: Text(initial)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      membership.schoolName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      membership.roleLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.arrow_forward_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyAccountCard extends StatelessWidget {
  const _EmptyAccountCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.domain_disabled_outlined,
              size: 42,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No school access yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'This account is not connected to a school or school organization yet.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
