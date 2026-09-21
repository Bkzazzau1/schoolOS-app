import 'package:flutter/material.dart';

import '../data/concession_repository.dart';
import '../domain/concession_request.dart';

class ProprietorConcessionApprovalsPage extends StatefulWidget {
  const ProprietorConcessionApprovalsPage({
    super.key,
    required this.repository,
    required this.onBack,
    required this.onDecisionSaved,
  });

  final ConcessionRepository repository;
  final VoidCallback onBack;
  final VoidCallback onDecisionSaved;

  @override
  State<ProprietorConcessionApprovalsPage> createState() =>
      _ProprietorConcessionApprovalsPageState();
}

class _ProprietorConcessionApprovalsPageState
    extends State<ProprietorConcessionApprovalsPage> {
  final _searchController = TextEditingController();
  final _noteController = TextEditingController();
  List<ConcessionRequest> _requests = const [];
  String _filter = 'Pending Approval';
  String? _selectedId;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final requests = await widget.repository.loadRequests();
    if (!mounted) return;
    setState(() {
      _requests = requests;
      _loading = false;
      _selectedId ??= _filteredRequests(requests).firstOrNull?.id ?? requests.firstOrNull?.id;
    });
  }

  List<ConcessionRequest> _filteredRequests([List<ConcessionRequest>? source]) {
    final requests = source ?? _requests;
    final query = _searchController.text.trim().toLowerCase();
    return requests.where((request) {
      final matchesFilter = _filter == 'All' || request.statusLabel == _filter;
      final haystack = '${request.student} ${request.className} ${request.typeLabel} ${request.requestedBy}'.toLowerCase();
      return matchesFilter && (query.isEmpty || haystack.contains(query));
    }).toList();
  }

  ConcessionRequest? get _selected {
    final filtered = _filteredRequests();
    for (final request in _requests) {
      if (request.id == _selectedId) return request;
    }
    return filtered.firstOrNull ?? _requests.firstOrNull;
  }

  Future<void> _decide(ConcessionStatus status) async {
    final request = _selected;
    if (request == null || request.status != ConcessionStatus.pendingApproval) return;

    setState(() => _saving = true);
    try {
      await widget.repository.decide(
        request: request,
        status: status,
        note: _noteController.text,
      );
      _noteController.clear();
      await _load();
      widget.onDecisionSaved();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${request.student} · ${status == ConcessionStatus.approved ? 'approved' : 'declined'} and queued for sync.')),
      );
    } catch (error) {
      // The school refused it (or a note is missing): say so, and show what the school holds.
      await _load();
      if (!mounted) return;
      final message = error is StateError ? error.message : error is ArgumentError ? '${error.message}' : error.toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());

    final filtered = _filteredRequests();
    final selected = _selected;
    final pendingCount = _requests.where((r) => r.status == ConcessionStatus.pendingApproval).length;
    final approvedValue = _requests
        .where((r) => r.status == ConcessionStatus.approved)
        .fold<int>(0, (sum, r) => sum + r.amount);
    final declinedCount = _requests.where((r) => r.status == ConcessionStatus.declined).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 860;
        return ListView(
          padding: EdgeInsets.fromLTRB(compact ? 18 : 28, 24, compact ? 18 : 28, 48),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      runSpacing: 12,
                      spacing: 16,
                      children: [
                        SizedBox(
                          width: compact ? constraints.maxWidth : 760,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PROPRIETOR · APPROVALS',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Scholarship & Discount Approvals',
                                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Only the Proprietor can approve a concession. Finance Office, Administrator, Head Master, Principal and Directors may request one.',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: widget.onBack,
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Back to Finance'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _ApprovalKpis(
                      pendingCount: pendingCount,
                      approvedValue: approvedValue,
                      declinedCount: declinedCount,
                      totalCount: _requests.length,
                    ),
                    const SizedBox(height: 18),
                    if (_requests.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('No concession requests yet.'),
                        ),
                      )
                    else if (compact) ...[
                      _QueueCard(
                        requests: filtered,
                        selectedId: selected?.id,
                        filter: _filter,
                        searchController: _searchController,
                        onFilterChanged: (value) => setState(() {
                          _filter = value;
                          _selectedId = _filteredRequests().firstOrNull?.id;
                        }),
                        onSearchChanged: () => setState(() {
                          _selectedId = _filteredRequests().firstOrNull?.id;
                        }),
                        onSelected: (id) => setState(() {
                          _selectedId = id;
                          _noteController.clear();
                        }),
                      ),
                      const SizedBox(height: 18),
                      if (selected != null)
                        _ReviewCard(
                          request: selected,
                          noteController: _noteController,
                          saving: _saving,
                          onApprove: () => _decide(ConcessionStatus.approved),
                          onDecline: () => _decide(ConcessionStatus.declined),
                        ),
                    ] else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: _QueueCard(
                              requests: filtered,
                              selectedId: selected?.id,
                              filter: _filter,
                              searchController: _searchController,
                              onFilterChanged: (value) => setState(() {
                                _filter = value;
                                _selectedId = _filteredRequests().firstOrNull?.id;
                              }),
                              onSearchChanged: () => setState(() {
                                _selectedId = _filteredRequests().firstOrNull?.id;
                              }),
                              onSelected: (id) => setState(() {
                                _selectedId = id;
                                _noteController.clear();
                              }),
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            flex: 6,
                            child: selected == null
                                ? const SizedBox.shrink()
                                : _ReviewCard(
                                    request: selected,
                                    noteController: _noteController,
                                    saving: _saving,
                                    onApprove: () => _decide(ConcessionStatus.approved),
                                    onDecline: () => _decide(ConcessionStatus.declined),
                                  ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 18),
                    Card(
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Approval rule', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 8),
                            Text(
                              'Finance Office, Administrator, Head Master, Principal and Director accounts can only request a scholarship or discount. It does not reduce the student’s net fee obligation until the Proprietor approves it here.',
                              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ApprovalKpis extends StatelessWidget {
  const _ApprovalKpis({
    required this.pendingCount,
    required this.approvedValue,
    required this.declinedCount,
    required this.totalCount,
  });

  final int pendingCount;
  final int approvedValue;
  final int declinedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final items = <(String, String, String)>[
      ('Pending your approval', '$pendingCount', 'Needs a decision'),
      ('Approved concessions', formatNaira(approvedValue), 'Total value approved'),
      ('Declined', '$declinedCount', 'Requests turned down'),
      ('Total requests', '$totalCount', 'Current local working set'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 4 : constraints.maxWidth >= 520 ? 2 : 1;
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.$1),
                        const SizedBox(height: 10),
                        Text(item.$2, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text(item.$3, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({
    required this.requests,
    required this.selectedId,
    required this.filter,
    required this.searchController,
    required this.onFilterChanged,
    required this.onSearchChanged,
    required this.onSelected,
  });

  final List<ConcessionRequest> requests;
  final String? selectedId;
  final String filter;
  final TextEditingController searchController;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onSearchChanged;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Request queue', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('Concessions submitted for your decision.', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 14),
            TextField(
              controller: searchController,
              onChanged: (_) => onSearchChanged(),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search student, class or requester...',
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: filter,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                'Pending Approval',
                'Approved',
                'Declined',
                'All',
              ].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
              onChanged: (value) {
                if (value != null) onFilterChanged(value);
              },
            ),
            const SizedBox(height: 12),
            if (requests.isEmpty)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text('Nothing matches this filter.', style: theme.textTheme.bodySmall),
              )
            else
              ...requests.map(
                (request) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: selectedId == request.id
                        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.7)
                        : theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () => onSelected(request.id),
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(request.student, style: const TextStyle(fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 3),
                                  Text('${request.typeLabel} · ${request.className}'),
                                  const SizedBox(height: 3),
                                  Text('${request.requestedByRole} · ${request.requestedAt}', style: theme.textTheme.bodySmall),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            _StatusBadge(status: request.status),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.request,
    required this.noteController,
    required this.saving,
    required this.onApprove,
    required this.onDecline,
  });

  final ConcessionRequest request;
  final TextEditingController noteController;
  final bool saving;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending = request.status == ConcessionStatus.pendingApproval;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                      Text('${request.typeLabel} · ${request.id}', style: theme.textTheme.labelMedium),
                      const SizedBox(height: 5),
                      Text(request.student, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text('${request.className} · requested by ${request.requestedBy} (${request.requestedByRole}) on ${request.requestedAt}'),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _StatusBadge(status: request.status),
              ],
            ),
            const SizedBox(height: 20),
            _DetailGrid(request: request),
            if (pending) ...[
              const SizedBox(height: 18),
              TextField(
                controller: noteController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Proprietor note (optional)',
                  hintText: 'Add a note for the audit trail...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: saving ? null : onDecline,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: saving ? null : onApprove,
                      icon: const Icon(Icons.check_rounded),
                      label: Text(saving ? 'Saving...' : 'Approve'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (request.status == ConcessionStatus.approved
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.errorContainer)
                      .withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  request.status == ConcessionStatus.approved
                      ? 'Approved. Finance Office can apply this concession to the student’s term account.'
                      : 'Declined. Finance Office will see this decision on the concession ledger.',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.request});

  final ConcessionRequest request;

  @override
  Widget build(BuildContext context) {
    final items = <(String, String)>[
      ('Gross term fee', formatNaira(request.grossFee)),
      ('Requested concession', formatNaira(request.amount)),
      ('Net parent obligation if approved', formatNaira(request.netObligation)),
      ('Reason / sponsor', request.reason),
      if (request.decidedBy != null) ('Decided by', '${request.decidedBy} · ${request.decidedAt ?? ''}'),
      if (request.decisionNote != null) ('Decision note', request.decisionNote!),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 650 ? 2 : 1;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              Container(
                width: width,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.$1, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 5),
                    Text(item.$2, style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final ConcessionStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (status) {
      ConcessionStatus.approved => theme.colorScheme.primary,
      ConcessionStatus.declined => theme.colorScheme.error,
      ConcessionStatus.pendingApproval => Colors.orange.shade800,
    };
    final label = switch (status) {
      ConcessionStatus.approved => 'Approved',
      ConcessionStatus.declined => 'Declined',
      ConcessionStatus.pendingApproval => 'Pending',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12)),
    );
  }
}

extension _FirstOrNullExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
