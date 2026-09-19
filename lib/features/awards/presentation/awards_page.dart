import 'package:flutter/material.dart';

import '../data/award_demo_data.dart';
import '../data/award_repository.dart';
import '../domain/award_models.dart';

class AwardsPage extends StatefulWidget {
  const AwardsPage({
    super.key,
    required this.schoolName,
    required this.repository,
    required this.onBack,
    this.onAwardsChanged,
  });

  final String schoolName;
  final AwardRepository repository;
  final VoidCallback onBack;
  final VoidCallback? onAwardsChanged;

  @override
  State<AwardsPage> createState() => _AwardsPageState();
}

class _AwardsPageState extends State<AwardsPage> {
  final _searchController = TextEditingController();
  AwardSnapshot? _snapshot;
  AwardRecipientType? _recipientType;
  AwardVisibility? _visibility;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  List<AwardRecognition> get _visibleAwards {
    final awards = _snapshot?.awards ?? const <AwardRecognition>[];
    return awards
        .where(
          (award) => award.matches(
            _searchController.text,
            recipientTypeFilter: _recipientType,
            visibilityFilter: _visibility,
          ),
        )
        .toList(growable: false);
  }

  Future<void> _showAddRecognition() async {
    final title = TextEditingController();
    final recipient = TextEditingController();
    final section = TextEditingController();
    final category = TextEditingController();
    final citation = TextEditingController();
    final issuer = TextEditingController();
    var recipientType = AwardRecipientType.student;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add recognition draft'),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Award title'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: recipient,
                    decoration: const InputDecoration(labelText: 'Recipient'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<AwardRecipientType>(
                    initialValue: recipientType,
                    decoration: const InputDecoration(labelText: 'Recipient type'),
                    items: [
                      for (final type in AwardRecipientType.values)
                        DropdownMenuItem(
                          value: type,
                          child: Text(type.label),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => recipientType = value);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: section,
                    decoration: const InputDecoration(labelText: 'Section'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: category,
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: citation,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Citation'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: issuer,
                    decoration: const InputDecoration(labelText: 'Issuer'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'New native recognitions are saved as Internal only. Public or parent-facing visibility requires a separate authorized review workflow.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save draft'),
            ),
          ],
        ),
      ),
    );

    if (shouldSave != true) return;
    final result = await widget.repository.addDraft(
      title: title.text,
      recipient: recipient.text,
      recipientType: recipientType,
      section: section.text,
      category: category.text,
      citation: citation.text,
      issuer: issuer.text,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
    if (result.success) {
      widget.onAwardsChanged?.call();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Could not load awards: $_error'),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final snapshot = _snapshot!;
    final stats = awardStats(snapshot.awards);
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            compact ? 16 : 28,
            22,
            compact ? 16 : 28,
            40,
          ),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Back to School Life',
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Awards & Recognition',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${widget.schoolName} · Celebrate contribution, growth and excellence',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(recognitionRankingBoundary),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final stat in stats)
                  SizedBox(
                    width: compact ? 160 : 205,
                    child: _StatCard(stat: stat),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            if (compact) ...[
              _RecognitionWall(
                awards: _visibleAwards,
                permissions: snapshot.permissions,
                searchController: _searchController,
                recipientType: _recipientType,
                visibility: _visibility,
                onQueryChanged: (_) => setState(() {}),
                onRecipientTypeChanged: (value) =>
                    setState(() => _recipientType = value),
                onVisibilityChanged: (value) =>
                    setState(() => _visibility = value),
                onAdd: _showAddRecognition,
              ),
              const SizedBox(height: 16),
              const _RecognitionSidebar(),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: _RecognitionWall(
                      awards: _visibleAwards,
                      permissions: snapshot.permissions,
                      searchController: _searchController,
                      recipientType: _recipientType,
                      visibility: _visibility,
                      onQueryChanged: (_) => setState(() {}),
                      onRecipientTypeChanged: (value) =>
                          setState(() => _recipientType = value),
                      onVisibilityChanged: (value) =>
                          setState(() => _visibility = value),
                      onAdd: _showAddRecognition,
                    ),
                  ),
                  const SizedBox(width: 18),
                  const Expanded(flex: 3, child: _RecognitionSidebar()),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat});
  final AwardStat stat;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(stat.label),
            const SizedBox(height: 6),
            Text(
              stat.value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            Text(stat.detail, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _RecognitionWall extends StatelessWidget {
  const _RecognitionWall({
    required this.awards,
    required this.permissions,
    required this.searchController,
    required this.recipientType,
    required this.visibility,
    required this.onQueryChanged,
    required this.onRecipientTypeChanged,
    required this.onVisibilityChanged,
    required this.onAdd,
  });

  final List<AwardRecognition> awards;
  final AwardPermissions permissions;
  final TextEditingController searchController;
  final AwardRecipientType? recipientType;
  final AwardVisibility? visibility;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<AwardRecipientType?> onRecipientTypeChanged;
  final ValueChanged<AwardVisibility?> onVisibilityChanged;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recognition wall',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const Text(
                        'School achievements for dashboards, family portals and approved public showcase areas.',
                      ),
                    ],
                  ),
                ),
                if (permissions.canCreateDrafts)
                  FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add recognition'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 310,
                  child: TextField(
                    controller: searchController,
                    onChanged: onQueryChanged,
                    decoration: const InputDecoration(
                      labelText: 'Search award, recipient, section or category',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<AwardRecipientType?>(
                    initialValue: recipientType,
                    decoration: const InputDecoration(labelText: 'Recipient'),
                    items: [
                      const DropdownMenuItem<AwardRecipientType?>(
                        value: null,
                        child: Text('All recipients'),
                      ),
                      for (final type in AwardRecipientType.values)
                        DropdownMenuItem<AwardRecipientType?>(
                          value: type,
                          child: Text(type.label),
                        ),
                    ],
                    onChanged: onRecipientTypeChanged,
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<AwardVisibility?>(
                    initialValue: visibility,
                    decoration: const InputDecoration(labelText: 'Visibility'),
                    items: [
                      const DropdownMenuItem<AwardVisibility?>(
                        value: null,
                        child: Text('All visibility'),
                      ),
                      for (final item in AwardVisibility.values)
                        DropdownMenuItem<AwardVisibility?>(
                          value: item,
                          child: Text(item.label),
                        ),
                    ],
                    onChanged: onVisibilityChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (awards.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: Text('No recognitions match these filters.')),
              )
            else
              for (final award in awards) ...[
                _AwardTile(award: award),
                if (award != awards.last) const Divider(height: 26),
              ],
          ],
        ),
      ),
    );
  }
}

class _AwardTile extends StatelessWidget {
  const _AwardTile({required this.award});
  final AwardRecognition award;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(child: Text(award.badge)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Chip(label: Text(award.category)),
                  Chip(label: Text(award.section)),
                  Chip(label: Text(award.recipientType.label)),
                  Chip(label: Text(award.visibility.label)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                award.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${award.recipient} · ${award.date} · Issued by ${award.issuer}',
              ),
              const SizedBox(height: 6),
              Text(award.citation),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecognitionSidebar extends StatelessWidget {
  const _RecognitionSidebar();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PolicyCard(title: 'Recognition categories', entries: awardRecognitionCategories),
        const SizedBox(height: 14),
        _PolicyCard(title: 'Where awards appear', entries: awardVisibilityDestinations),
        const SizedBox(height: 14),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('EARLY YEARS GUARDRAIL', style: TextStyle(fontWeight: FontWeight.w900)),
                SizedBox(height: 8),
                Text(earlyYearsRecognitionGuardrail),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({required this.title, required this.entries});
  final String title;
  final Map<String, String> entries;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            for (final entry in entries.entries) ...[
              Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(entry.value),
              if (entry.key != entries.keys.last) const Divider(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}
