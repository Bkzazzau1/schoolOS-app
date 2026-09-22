import 'package:flutter/material.dart';

import '../data/principal_approvals_demo_data.dart';
import '../data/principal_approvals_repository.dart';
import '../domain/principal_approvals_models.dart';

class PrincipalApprovalsPage extends StatefulWidget {
  const PrincipalApprovalsPage({
    super.key,
    required this.repository,
    required this.onNavigate,
    this.onMutationQueued,
  });

  final PrincipalApprovalsRepository repository;
  final ValueChanged<String> onNavigate;
  final VoidCallback? onMutationQueued;

  @override
  State<PrincipalApprovalsPage> createState() => _PrincipalApprovalsPageState();
}

class _PrincipalApprovalsPageState extends State<PrincipalApprovalsPage> {
  final _commentController = TextEditingController();
  PrincipalApprovalsSnapshot? _snapshot;
  String? _error;
  String _selectedId = '';
  String _filter = 'Pending';
  String _query = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snapshot = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _error = null;
        if (!snapshot.items.any((item) => item.id == _selectedId) &&
            snapshot.items.isNotEmpty) {
          _selectedId = snapshot.items.first.id;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  List<PrincipalApprovalItem> _ordered(List<PrincipalApprovalItem> source) {
    final items = [...source];
    items.sort((a, b) => b.submitted.compareTo(a.submitted));
    return items;
  }

  List<PrincipalApprovalItem> _filtered(PrincipalApprovalsSnapshot snapshot) {
    final query = _query.trim().toLowerCase();
    return _ordered(snapshot.items)
        .where((item) {
          final matchesFilter =
              _filter == 'All' || item.status.label == _filter;
          final haystack =
              '${item.type} ${item.title} ${item.teacher} ${item.className}'
                  .toLowerCase();
          return matchesFilter && (query.isEmpty || haystack.contains(query));
        })
        .toList(growable: false);
  }

  PrincipalApprovalItem _selected(PrincipalApprovalsSnapshot snapshot) {
    return snapshot.items.firstWhere(
      (item) => item.id == _selectedId,
      orElse: () => _ordered(snapshot.items).first,
    );
  }

  Future<void> _decide(PrincipalApprovalStatus status) async {
    final snapshot = _snapshot;
    if (snapshot == null || snapshot.items.isEmpty || _saving) return;
    setState(() => _saving = true);
    final selected = _selected(snapshot);
    final result = await widget.repository.decide(
      approvalId: selected.id,
      status: status,
      comment: _commentController.text,
    );
    if (!mounted) return;
    _commentController.clear();
    await _load();
    widget.onMutationQueued?.call();
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 40),
              const SizedBox(height: 10),
              const Text(
                'Could not load approvals.',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _Header(onNavigate: widget.onNavigate),
          const Text(
            'No submitted Secondary work awaiting review. Lesson plans and score sheets appear after a teacher submits a recorded version.',
          ),
          const Text(
            'No report batches or score-correction requests have been recorded.',
          ),
        ],
      );
    }
    final selected = _selected(snapshot);
    final filtered = _filtered(snapshot);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _Header(onNavigate: widget.onNavigate),
        const SizedBox(height: 16),
        _Kpis(snapshot: snapshot),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            final queue = _QueuePanel(
              items: filtered,
              selectedId: selected.id,
              filter: _filter,
              query: _query,
              onQueryChanged: (value) => setState(() => _query = value),
              onFilterChanged: (value) => setState(() => _filter = value),
              onSelected: (id) {
                _commentController.clear();
                setState(() => _selectedId = id);
              },
            );
            final review = _ReviewPanel(
              item: selected,
              commentController: _commentController,
              saving: _saving,
              canDecide: snapshot.permissions.canDecideSecondaryApprovals,
              onApprove: () => _decide(PrincipalApprovalStatus.approved),
              onReturn: () => _decide(PrincipalApprovalStatus.returned),
            );
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: queue),
                  const SizedBox(width: 16),
                  Expanded(flex: 6, child: review),
                ],
              );
            }
            return Column(
              children: [queue, const SizedBox(height: 16), review],
            );
          },
        ),
        const SizedBox(height: 16),
        _Rules(onNavigate: widget.onNavigate),
        const SizedBox(height: 12),
        _BoundaryCard(text: principalApprovalAuthorityBoundary),
        const SizedBox(height: 8),
        _BoundaryCard(text: principalApprovalAuditBoundary),
        const SizedBox(height: 8),
        _BoundaryCard(text: principalApprovalDownstreamBoundary),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onNavigate});
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    runSpacing: 12,
    spacing: 16,
    children: [
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PRINCIPAL · APPROVALS',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
            SizedBox(height: 4),
            Text(
              'Approvals',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 28),
            ),
            SizedBox(height: 4),
            Text(
              'Review teacher work, approve it, or return it with clear comments.',
            ),
          ],
        ),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton(
            onPressed: () => onNavigate('dashboard'),
            child: const Text('Dashboard'),
          ),
          OutlinedButton(
            onPressed: () => onNavigate('teachers'),
            child: const Text('Teachers'),
          ),
          OutlinedButton(
            onPressed: () => onNavigate('results'),
            child: const Text('Results & Reports'),
          ),
        ],
      ),
    ],
  );
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.snapshot});
  final PrincipalApprovalsSnapshot snapshot;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      _Kpi(
        label: 'Pending',
        value: '${snapshot.pendingCount}',
        note: 'Needs action',
      ),
      _Kpi(
        label: 'High priority',
        value: '${snapshot.highPriorityPendingCount}',
        note: 'Review first',
      ),
      _Kpi(
        label: 'Approved today',
        value: '${snapshot.approvedCount}',
        note: 'Prototype count',
      ),
      _Kpi(
        label: 'Returned',
        value: '${snapshot.returnedCount}',
        note: 'Needs teacher changes',
      ),
    ],
  );
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, required this.note});
  final String label;
  final String value;
  final String note;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 190,
    child: Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            Text(note, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );
}

class _QueuePanel extends StatelessWidget {
  const _QueuePanel({
    required this.items,
    required this.selectedId,
    required this.filter,
    required this.query,
    required this.onQueryChanged,
    required this.onFilterChanged,
    required this.onSelected,
  });

  final List<PrincipalApprovalItem> items;
  final String selectedId;
  final String filter;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Approval queue',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const Text('Teacher work sent to school leadership.'),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search teacher, class or work...',
              border: OutlineInputBorder(),
            ),
            onChanged: onQueryChanged,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: filter,
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final value in principalApprovalFilters)
                DropdownMenuItem(value: value, child: Text(value)),
            ],
            onChanged: (value) {
              if (value != null) onFilterChanged(value);
            },
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No approval items match this filter.'),
              ),
            )
          else
            for (final item in items) ...[
              _ApprovalTile(
                item: item,
                selected: item.id == selectedId,
                onTap: () => onSelected(item.id),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    ),
  );
}

class _ApprovalTile extends StatelessWidget {
  const _ApprovalTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });
  final PrincipalApprovalItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceContainerLowest,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Pill(
              text: item.priority.label,
              attention: item.priority == PrincipalApprovalPriority.high,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.type,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${item.teacher} · ${item.className} · ${item.submitted}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _Pill(
              text: item.status.label,
              attention: item.status == PrincipalApprovalStatus.returned,
            ),
          ],
        ),
      ),
    ),
  );
}

class _ReviewPanel extends StatelessWidget {
  const _ReviewPanel({
    required this.item,
    required this.commentController,
    required this.saving,
    required this.canDecide,
    required this.onApprove,
    required this.onReturn,
  });

  final PrincipalApprovalItem item;
  final TextEditingController commentController;
  final bool saving;
  final bool canDecide;
  final VoidCallback onApprove;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.type,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                    Text('${item.teacher} · ${item.className} · ${item.id}'),
                  ],
                ),
              ),
              _Pill(
                text: item.status.label,
                attention: item.status == PrincipalApprovalStatus.returned,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SUBMISSION PREVIEW',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                ),
                const SizedBox(height: 6),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(item.summary),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final detail in item.details) _Detail(detail: detail),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: commentController,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Principal comment',
              hintText: 'Add feedback, approval note, or required changes...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: saving || !canDecide ? null : onReturn,
                icon: const Icon(Icons.undo_rounded),
                label: const Text('Return for changes'),
              ),
              FilledButton.icon(
                onPressed: saving || !canDecide ? null : onApprove,
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: Text(saving ? 'Saving...' : 'Approve'),
              ),
            ],
          ),
          if (item.status == PrincipalApprovalStatus.approved) ...[
            const SizedBox(height: 12),
            const _Result(
              text:
                  'Approved. The teacher can see the Principal decision after synchronization.',
              good: true,
            ),
          ],
          if (item.status == PrincipalApprovalStatus.returned) ...[
            const SizedBox(height: 12),
            const _Result(
              text: 'Returned to the teacher for revision.',
              good: false,
            ),
          ],
          if (item.lastReviewedAt != null) ...[
            const SizedBox(height: 10),
            Text(
              'Last decision: ${item.lastReviewedAt}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if ((item.lastComment ?? '').isNotEmpty)
              Text(
                'Comment: ${item.lastComment}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ],
      ),
    ),
  );
}

class _Detail extends StatelessWidget {
  const _Detail({required this.detail});
  final PrincipalApprovalDetail detail;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 210,
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(detail.label, style: Theme.of(context).textTheme.bodySmall),
          Text(
            detail.value,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    ),
  );
}

class _Result extends StatelessWidget {
  const _Result({required this.text, required this.good});
  final String text;
  final bool good;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: good
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
  );
}

class _Rules extends StatelessWidget {
  const _Rules({required this.onNavigate});
  final ValueChanged<String> onNavigate;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Approval rules',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final detail in principalApprovalRules)
                _Detail(detail: detail),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            principalApprovalAiBoundary,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.attention});
  final String text;
  final bool attention;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: attention
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
    ),
  );
}

class _BoundaryCard extends StatelessWidget {
  const _BoundaryCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.policy_outlined, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
