import 'package:flutter/material.dart';

import '../data/proprietor_structure_demo_data.dart';
import '../data/proprietor_structure_repository.dart';
import '../domain/proprietor_structure_models.dart';

class ProprietorStructurePage extends StatefulWidget {
  const ProprietorStructurePage({
    super.key,
    required this.schoolName,
    required this.repository,
    required this.onActionRequested,
    required this.onStructureChanged,
  });

  final String schoolName;
  final ProprietorStructureRepository repository;
  final ValueChanged<String> onActionRequested;
  final VoidCallback onStructureChanged;

  @override
  State<ProprietorStructurePage> createState() => _ProprietorStructurePageState();
}

class _ProprietorStructurePageState extends State<ProprietorStructurePage> {
  ProprietorStructureSnapshot? _snapshot;
  String _selectedSectionId = 'secondary';
  String _person = 'Mrs. Grace Musa';
  String _title = 'Vice Principal Administration';
  LeadershipLevel _level = LeadershipLevel.deputy;
  String _department = '';
  String? _reportsTo = 'L-003';
  bool _loading = true;
  bool _saving = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final snapshot = await widget.repository.load();
    if (!mounted) return;
    final sectionExists = snapshot.sections.any((s) => s.id == _selectedSectionId);
    setState(() {
      _snapshot = snapshot;
      if (!sectionExists && snapshot.sections.isNotEmpty) {
        _selectedSectionId = snapshot.sections.first.id;
      }
      _loading = false;
    });
    _resetManagerForSection();
  }

  AcademicSection get _selectedSection {
    final snapshot = _snapshot!;
    return snapshot.sections.firstWhere(
      (section) => section.id == _selectedSectionId,
      orElse: () => snapshot.sections.first,
    );
  }

  List<LeadershipAppointment> get _sectionLeaders {
    final snapshot = _snapshot;
    if (snapshot == null) return const [];
    return snapshot.leaders
        .where((leader) => leader.sectionId == _selectedSectionId)
        .toList(growable: false);
  }

  List<LeadershipAppointment> get _possibleManagers {
    final snapshot = _snapshot;
    if (snapshot == null) return const [];
    return widget.repository.possibleManagers(snapshot.leaders, _selectedSectionId);
  }

  void _selectSection(String sectionId) {
    setState(() {
      _selectedSectionId = sectionId;
      _notice = null;
    });
    _resetManagerForSection();
  }

  void _resetManagerForSection() {
    final managers = _possibleManagers;
    if (!mounted) return;
    setState(() {
      _reportsTo = managers.isEmpty ? null : managers.first.id;
    });
  }

  Future<void> _appoint() async {
    if (_saving || _snapshot == null) return;
    setState(() {
      _saving = true;
      _notice = null;
    });
    final result = await widget.repository.appoint(
      section: _selectedSection,
      person: _person,
      level: _level,
      title: _title,
      department: _department,
      reportsTo: _reportsTo,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _notice = result.message;
    });
    if (result.success) {
      widget.onStructureChanged();
      await _load();
    }
  }

  Future<void> _replaceHead(String person) async {
    if (_saving || _snapshot == null) return;
    setState(() {
      _saving = true;
      _notice = null;
    });
    final result = await widget.repository.replaceSectionHead(
      section: _selectedSection,
      person: person,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _notice = result.message;
    });
    if (result.success) {
      widget.onStructureChanged();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final contentWidth = constraints.maxWidth >= 1460 ? 1280.0 : 1160.0;
        return ListView(
          padding: EdgeInsets.fromLTRB(compact ? 18 : 28, 24, compact ? 18 : 28, 48),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(
                      schoolName: widget.schoolName,
                      compact: compact,
                      onDashboard: () => widget.onActionRequested('overview'),
                    ),
                    const SizedBox(height: 18),
                    const _GovernanceBanner(),
                    const SizedBox(height: 18),
                    _SectionGrid(
                      sections: _snapshot!.sections,
                      selectedSectionId: _selectedSectionId,
                      onSelected: _selectSection,
                      compact: compact,
                    ),
                    const SizedBox(height: 18),
                    _StructureWorkspace(
                      compact: compact,
                      section: _selectedSection,
                      leaders: _sectionLeaders,
                      allLeaders: _snapshot!.leaders,
                      people: proprietorStructurePeople,
                      selectedPerson: _person,
                      level: _level,
                      title: _title,
                      department: _department,
                      reportsTo: _reportsTo,
                      possibleManagers: _possibleManagers,
                      saving: _saving,
                      notice: _notice,
                      onReplaceHead: _replaceHead,
                      onPersonChanged: (value) => setState(() => _person = value),
                      onLevelChanged: (value) => setState(() {
                        _level = value;
                        if (_level == LeadershipLevel.sectionHead) {
                          _reportsTo = null;
                        } else if (_reportsTo == null && _possibleManagers.isNotEmpty) {
                          _reportsTo = _possibleManagers.first.id;
                        }
                      }),
                      onTitleChanged: (value) => setState(() => _title = value),
                      onDepartmentChanged: (value) => setState(() => _department = value),
                      onReportsToChanged: (value) => setState(() => _reportsTo = value),
                      onAppoint: _appoint,
                    ),
                    const SizedBox(height: 18),
                    _AuthorityMatrix(compact: compact),
                    const SizedBox(height: 18),
                    const _AccessResolutionCard(),
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

class _Header extends StatelessWidget {
  const _Header({
    required this.schoolName,
    required this.compact,
    required this.onDashboard,
  });

  final String schoolName;
  final bool compact;
  final VoidCallback onDashboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PROPRIETOR · SCHOOL GOVERNANCE',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'School Structure & Leadership',
          style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          'Create school sections, appoint leaders and define who controls each academic scope in $schoolName.',
          style: theme.textTheme.bodyLarge?.copyWith(
            height: 1.5,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton(onPressed: onDashboard, child: const Text('Dashboard')),
        const Tooltip(
          message: 'Secondary assignments belongs to the Principal feature.',
          child: OutlinedButton(onPressed: null, child: Text('Secondary assignments')),
        ),
      ],
    );
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [text, const SizedBox(height: 16), actions],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: text),
        const SizedBox(width: 24),
        Flexible(child: Align(alignment: Alignment.topRight, child: actions)),
      ],
    );
  }
}

class _GovernanceBanner extends StatelessWidget {
  const _GovernanceBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.admin_panel_settings_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('OWNER CONTROL', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  'Structure first, permissions second',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Every operational leader receives authority from a school membership scoped to campus + section + role. Leadership appointments never grant access outside that scope.',
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Chip(label: Text('Kaduna Campus')),
        ],
      ),
    );
  }
}

class _SectionGrid extends StatelessWidget {
  const _SectionGrid({
    required this.sections,
    required this.selectedSectionId,
    required this.onSelected,
    required this.compact,
  });

  final List<AcademicSection> sections;
  final String selectedSectionId;
  final ValueChanged<String> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = compact ? 1 : (width >= 1100 ? 3 : 2);
    return GridView.count(
      crossAxisCount: columns,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: compact ? 2.15 : 1.4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final section in sections)
          _SectionCard(
            section: section,
            selected: selectedSectionId == section.id,
            onTap: () => onSelected(section.id),
          ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section, required this.selected, required this.onTap});

  final AcademicSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: selected ? 2 : 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(section.stage.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text(section.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              Text(section.campus, style: theme.textTheme.bodySmall),
              const Spacer(),
              Text(section.leaderTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(section.leaderName),
              const SizedBox(height: 8),
              Text('${section.classes} configured classes', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _StructureWorkspace extends StatelessWidget {
  const _StructureWorkspace({
    required this.compact,
    required this.section,
    required this.leaders,
    required this.allLeaders,
    required this.people,
    required this.selectedPerson,
    required this.level,
    required this.title,
    required this.department,
    required this.reportsTo,
    required this.possibleManagers,
    required this.saving,
    required this.notice,
    required this.onReplaceHead,
    required this.onPersonChanged,
    required this.onLevelChanged,
    required this.onTitleChanged,
    required this.onDepartmentChanged,
    required this.onReportsToChanged,
    required this.onAppoint,
  });

  final bool compact;
  final AcademicSection section;
  final List<LeadershipAppointment> leaders;
  final List<LeadershipAppointment> allLeaders;
  final List<String> people;
  final String selectedPerson;
  final LeadershipLevel level;
  final String title;
  final String department;
  final String? reportsTo;
  final List<LeadershipAppointment> possibleManagers;
  final bool saving;
  final String? notice;
  final ValueChanged<String> onReplaceHead;
  final ValueChanged<String> onPersonChanged;
  final ValueChanged<LeadershipLevel> onLevelChanged;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onDepartmentChanged;
  final ValueChanged<String?> onReportsToChanged;
  final VoidCallback onAppoint;

  @override
  Widget build(BuildContext context) {
    final left = _ModuleCard(
      title: section.name,
      subtitle: 'Section head and delegated leadership.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeadControl(section: section, people: people, saving: saving, onChanged: onReplaceHead),
          const SizedBox(height: 16),
          for (final leader in leaders)
            _HierarchyRow(leader: leader, allLeaders: allLeaders),
        ],
      ),
    );
    final right = _ModuleCard(
      title: 'Appoint leader',
      subtitle: 'Add a deputy, HOD, coordinator or section head.',
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            key: ValueKey('person-$selectedPerson'),
            initialValue: selectedPerson,
            decoration: const InputDecoration(labelText: 'Staff member'),
            items: [for (final person in people) DropdownMenuItem(value: person, child: Text(person))],
            onChanged: saving ? null : (value) { if (value != null) onPersonChanged(value); },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<LeadershipLevel>(
            key: ValueKey('level-${level.name}'),
            initialValue: level,
            decoration: const InputDecoration(labelText: 'Leadership level'),
            items: [for (final item in LeadershipLevel.values) DropdownMenuItem(value: item, child: Text(item.label))],
            onChanged: saving ? null : (value) { if (value != null) onLevelChanged(value); },
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: title,
            decoration: const InputDecoration(labelText: 'Official title', hintText: 'e.g. Vice Principal Academics'),
            onChanged: onTitleChanged,
          ),
          if (level == LeadershipLevel.hod) ...[
            const SizedBox(height: 12),
            TextFormField(
              initialValue: department,
              decoration: const InputDecoration(labelText: 'Department', hintText: 'e.g. Science'),
              onChanged: onDepartmentChanged,
            ),
          ],
          if (level != LeadershipLevel.sectionHead) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('manager-${section.id}-${reportsTo ?? 'none'}'),
              initialValue: possibleManagers.any((m) => m.id == reportsTo) ? reportsTo : null,
              decoration: const InputDecoration(labelText: 'Reports to'),
              items: [
                for (final manager in possibleManagers)
                  DropdownMenuItem(value: manager.id, child: Text('${manager.title} · ${manager.person}')),
              ],
              onChanged: saving ? null : onReportsToChanged,
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: saving ? null : onAppoint,
              icon: saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.person_add_alt_1_rounded),
              label: Text(saving ? 'Saving…' : 'Create appointment'),
            ),
          ),
          if (notice != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(notice!),
            ),
          ],
        ],
      ),
    );

    if (compact) return Column(children: [left, const SizedBox(height: 14), right]);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Expanded(flex: 3, child: left), const SizedBox(width: 14), Expanded(flex: 2, child: right)],
    );
  }
}

class _HeadControl extends StatelessWidget {
  const _HeadControl({required this.section, required this.people, required this.saving, required this.onChanged});

  final AcademicSection section;
  final List<String> people;
  final bool saving;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SECTION HEAD', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(section.leaderTitle, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          Text(section.leaderName),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('head-${section.id}-${section.leaderName}'),
            initialValue: people.contains(section.leaderName) ? section.leaderName : null,
            decoration: const InputDecoration(labelText: 'Replace section head'),
            items: [for (final person in people) DropdownMenuItem(value: person, child: Text(person))],
            onChanged: saving ? null : (value) { if (value != null && value != section.leaderName) onChanged(value); },
          ),
        ],
      ),
    );
  }
}

class _HierarchyRow extends StatelessWidget {
  const _HierarchyRow({required this.leader, required this.allLeaders});

  final LeadershipAppointment leader;
  final List<LeadershipAppointment> allLeaders;

  @override
  Widget build(BuildContext context) {
    LeadershipAppointment? manager;
    for (final item in allLeaders) {
      if (item.id == leader.reportsTo) {
        manager = item;
        break;
      }
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(leader.level.label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(leader.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                Text(leader.person),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(leader.department == null ? 'Section leadership' : 'Department: ${leader.department}'),
                const SizedBox(height: 3),
                Text(manager == null ? 'Top of section' : 'Reports to ${manager.title}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthorityMatrix extends StatelessWidget {
  const _AuthorityMatrix({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _ModuleCard(
      title: 'Who controls what?',
      subtitle: 'Default delegated authority by school section.',
      child: compact
          ? Column(
              children: [
                for (final row in proprietorAuthorityMatrix)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(row.role, style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text(
                      'Students: ${row.students} · Teachers: ${row.teachers}\nAssignments: ${row.assignments} · Results: ${row.results} · School identity: ${row.schoolIdentity}',
                    ),
                  ),
              ],
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Leadership role')),
                  DataColumn(label: Text('Students')),
                  DataColumn(label: Text('Teachers')),
                  DataColumn(label: Text('Subject assignments')),
                  DataColumn(label: Text('Results')),
                  DataColumn(label: Text('School identity')),
                ],
                rows: [
                  for (final row in proprietorAuthorityMatrix)
                    DataRow(cells: [
                      DataCell(Text(row.role, style: const TextStyle(fontWeight: FontWeight.w800))),
                      DataCell(Text(row.students)),
                      DataCell(Text(row.teachers)),
                      DataCell(Text(row.assignments)),
                      DataCell(Text(row.results)),
                      DataCell(Text(row.schoolIdentity)),
                    ]),
                ],
              ),
            ),
    );
  }
}

class _AccessResolutionCard extends StatelessWidget {
  const _AccessResolutionCard();

  @override
  Widget build(BuildContext context) {
    return _ModuleCard(
      title: 'How SchoolOS decides what a leader can see',
      subtitle: 'ACCESS RESOLUTION',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < proprietorAccessResolution.length; i++) ...[
                Chip(label: Text(proprietorAccessResolution[i])),
                if (i != proprietorAccessResolution.length - 1)
                  const Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'One person can hold multiple valid memberships. For example, a small school may appoint the same person as Primary Headmaster and Secondary Principal, but the two memberships remain distinct and can be revoked independently.',
          ),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
