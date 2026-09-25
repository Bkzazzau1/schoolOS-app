import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../data/transfer_verify_associations_api.dart';
import '../domain/association_models.dart';

/// Where a school's owner requests to join a verified Proprietor Association
/// network, and sees the schools their own school currently belongs to. Live
/// only - association membership is cross-tenant and does not fit the
/// offline sync model, the same reason apps.billing works this way.
class TransferVerifyAssociationsPage extends StatefulWidget {
  const TransferVerifyAssociationsPage({super.key, required this.api, required this.membership});

  final TransferVerifyAssociationsApi? api;
  final SchoolMembership membership;

  @override
  State<TransferVerifyAssociationsPage> createState() => _TransferVerifyAssociationsPageState();
}

class _TransferVerifyAssociationsPageState extends State<TransferVerifyAssociationsPage> {
  Future<(List<TransferVerifyAssociation>, List<SchoolAssociationMembershipRecord>)>? _future;
  String? _notice;

  @override
  void initState() {
    super.initState();
    final api = widget.api;
    if (api != null) _future = _load(api);
  }

  Future<(List<TransferVerifyAssociation>, List<SchoolAssociationMembershipRecord>)> _load(
    TransferVerifyAssociationsApi api,
  ) async {
    final catalog = await api.catalog();
    final memberships = await api.myMemberships(widget.membership);
    return (catalog, memberships);
  }

  void _reload() {
    final api = widget.api;
    if (api == null) return;
    setState(() {
      _future = _load(api);
    });
  }

  Future<void> _join(TransferVerifyAssociation association) async {
    final api = widget.api;
    if (api == null) return;
    try {
      await api.join(widget.membership, association.id);
      if (!mounted) return;
      setState(() => _notice = 'Request sent to ${association.name}. An association administrator will decide.');
      _reload();
    } catch (error) {
      if (mounted) setState(() => _notice = '$error');
    }
  }

  Future<void> _exit(SchoolAssociationMembershipRecord row) async {
    final api = widget.api;
    if (api == null) return;
    try {
      await api.exit(widget.membership, row.id);
      if (!mounted) return;
      setState(() => _notice = 'Left ${row.associationName}.');
      _reload();
    } catch (error) {
      if (mounted) setState(() => _notice = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.api == null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('TRANSFERVERIFY', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
          const SizedBox(height: 6),
          Text('Proprietor Associations', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          const _Notice(
            text: 'Joining a Proprietor Association network requires a connected school server. '
                'This device is running in demo mode, so no association network is reachable here.',
          ),
        ],
      );
    }

    return FutureBuilder<(List<TransferVerifyAssociation>, List<SchoolAssociationMembershipRecord>)>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 42),
                  const SizedBox(height: 12),
                  Text('${snapshot.error ?? 'Could not load associations.'}'),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _reload, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }

        final (catalog, memberships) = snapshot.data!;
        final joinedIds = {for (final m in memberships) if (m.status != AssociationMembershipStatus.exited) m.associationId};
        final joinable = [for (final a in catalog) if (!joinedIds.contains(a.id)) a];

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('TRANSFERVERIFY', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
            const SizedBox(height: 6),
            Text('Proprietor Associations', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text(
              'Publishing a bad-debt case to TransferVerify only ever reaches the associations your school actively '
              'belongs to - never automatically, and never every association at once.',
            ),
            if (_notice != null) ...[
              const SizedBox(height: 12),
              _Notice(text: _notice!),
            ],
            const SizedBox(height: 16),
            Text('Your memberships', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            if (memberships.isEmpty)
              const Card(elevation: 0, child: Padding(padding: EdgeInsets.all(18), child: Text('Not a member of any association yet.')))
            else
              for (final row in memberships) ...[
                _MembershipCard(row: row, onExit: row.isActive ? () => _exit(row) : null),
                const SizedBox(height: 10),
              ],
            const SizedBox(height: 20),
            Text('Associations you can join', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            if (joinable.isEmpty)
              const Card(elevation: 0, child: Padding(padding: EdgeInsets.all(18), child: Text('No open associations to join right now.')))
            else
              for (final association in joinable) ...[
                Card(
                  elevation: 0,
                  child: ListTile(
                    title: Text(association.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(association.geographicScope.isEmpty ? association.description : association.geographicScope),
                    trailing: FilledButton(onPressed: () => _join(association), child: const Text('Request to join')),
                  ),
                ),
                const SizedBox(height: 8),
              ],
          ],
        );
      },
    );
  }
}

class _MembershipCard extends StatelessWidget {
  const _MembershipCard({required this.row, this.onExit});

  final SchoolAssociationMembershipRecord row;
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ListTile(
        title: Text(row.associationName, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(row.decisionNote.trim().isEmpty ? 'Requested ${_date(row.requestedAt)}' : row.decisionNote),
        trailing: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Chip(label: Text(row.status.label)),
            if (onExit != null) OutlinedButton(onPressed: onExit, child: const Text('Exit')),
          ],
        ),
      ),
    );
  }

  static String _date(DateTime d) {
    final local = d.toLocal();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(14)),
        child: Text(text),
      );
}
