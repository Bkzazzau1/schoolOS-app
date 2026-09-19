import 'package:flutter/material.dart';

import '../../../core/appearance/school_appearance_controller.dart';
import '../../../core/appearance/school_theme.dart';

class ProprietorAppearancePage extends StatefulWidget {
  const ProprietorAppearancePage({
    super.key,
    required this.schoolName,
    required this.controller,
    required this.onDashboard,
    required this.onAppearanceChanged,
  });

  final String schoolName;
  final SchoolAppearanceController controller;
  final VoidCallback onDashboard;
  final VoidCallback onAppearanceChanged;

  @override
  State<ProprietorAppearancePage> createState() => _ProprietorAppearancePageState();
}

class _ProprietorAppearancePageState extends State<ProprietorAppearancePage> {
  String? _draftThemeId;
  String _message = '';
  bool _saving = false;

  SchoolThemePreset get _selectedTheme =>
      schoolThemeById(_draftThemeId ?? widget.controller.theme.id);

  Future<void> _apply() async {
    if (_saving || _selectedTheme.id == widget.controller.theme.id) return;
    setState(() {
      _saving = true;
      _message = '';
    });
    try {
      await widget.controller.applyTheme(_selectedTheme);
      if (!mounted) return;
      setState(() {
        _draftThemeId = null;
        _saving = false;
        _message =
            '${widget.controller.theme.name} theme saved for ${widget.schoolName}. Saved offline and queued for school-wide sync.';
      });
      widget.onAppearanceChanged();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _message = 'Could not save the school theme: $error';
      });
    }
  }

  void _selectTheme(String id) {
    setState(() {
      _draftThemeId = id;
      _message = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            return ListView(
              padding: EdgeInsets.fromLTRB(
                compact ? 18 : 28,
                24,
                compact ? 18 : 28,
                48,
              ),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1160),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Header(
                          schoolName: widget.schoolName,
                          compact: compact,
                          onDashboard: widget.onDashboard,
                        ),
                        const SizedBox(height: 18),
                        _AppearancePanel(
                          schoolName: widget.schoolName,
                          compact: compact,
                          currentTheme: widget.controller.theme,
                          selectedTheme: _selectedTheme,
                          draftThemeId: _draftThemeId,
                          saving: _saving,
                          message: _message,
                          onSelect: _selectTheme,
                          onApply: _apply,
                          onDefault: () => _selectTheme('forest'),
                          onCancel: _draftThemeId == null
                              ? null
                              : () => setState(() {
                                    _draftThemeId = null;
                                    _message = '';
                                  }),
                        ),
                        const SizedBox(height: 14),
                        _OfflineNote(schoolName: widget.schoolName),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
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
          'SCHOOL SETTINGS',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Make SchoolOS your own.',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose the colours $schoolName sees across leadership, staff, family portals, login and School Life.',
          style: theme.textTheme.bodyLarge?.copyWith(
            height: 1.5,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          text,
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onDashboard,
            icon: const Icon(Icons.dashboard_outlined),
            label: const Text('Dashboard'),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: text),
        const SizedBox(width: 24),
        OutlinedButton.icon(
          onPressed: onDashboard,
          icon: const Icon(Icons.dashboard_outlined),
          label: const Text('Dashboard'),
        ),
      ],
    );
  }
}

class _AppearancePanel extends StatelessWidget {
  const _AppearancePanel({
    required this.schoolName,
    required this.compact,
    required this.currentTheme,
    required this.selectedTheme,
    required this.draftThemeId,
    required this.saving,
    required this.message,
    required this.onSelect,
    required this.onApply,
    required this.onDefault,
    required this.onCancel,
  });

  final String schoolName;
  final bool compact;
  final SchoolThemePreset currentTheme;
  final SchoolThemePreset selectedTheme;
  final String? draftThemeId;
  final bool saving;
  final String message;
  final ValueChanged<String> onSelect;
  final VoidCallback onApply;
  final VoidCallback onDefault;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 18 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'School colour theme',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text('$schoolName · Managed by the Proprietor'),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = compact
                    ? constraints.maxWidth
                    : constraints.maxWidth >= 980
                        ? (constraints.maxWidth - 48) / 5
                        : (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final preset in schoolThemePresets)
                      SizedBox(
                        width: itemWidth,
                        child: _ThemeOption(
                          preset: preset,
                          selected: selectedTheme.id == preset.id,
                          current: currentTheme.id == preset.id,
                          onTap: () => onSelect(preset.id),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 22),
            _ThemePreview(preset: selectedTheme, compact: compact),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: saving || selectedTheme.id == currentTheme.id
                      ? null
                      : onApply,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(saving ? 'Applying…' : 'Apply school theme'),
                ),
                OutlinedButton(
                  onPressed: saving ? null : onDefault,
                  child: const Text('Select default'),
                ),
                OutlinedButton(
                  onPressed: saving ? null : onCancel,
                  child: const Text('Cancel changes'),
                ),
              ],
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: message.startsWith('Could not')
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.preset,
    required this.selected,
    required this.current,
    required this.onTap,
  });

  final SchoolThemePreset preset;
  final bool selected;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = Color(preset.darkArgb);
    final accent = Color(preset.accentArgb);
    return Material(
      color: selected ? theme.colorScheme.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 54,
                decoration: BoxDecoration(
                  color: dark,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.all(10),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                current ? '${preset.name} · Current' : preset.name,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(preset.description, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.preset, required this.compact});

  final SchoolThemePreset preset;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dark = Color(preset.darkArgb);
    final accent = Color(preset.accentArgb);
    final sidebar = Container(
      width: compact ? double.infinity : 220,
      padding: const EdgeInsets.all(20),
      color: dark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SchoolOS',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Overview',
              style: TextStyle(color: dark, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 10),
          const Text('People & classes', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          const Text('School Life', style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
    final content = Expanded(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'YOUR SCHOOL, YOUR IDENTITY',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'A brighter school day',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: dark,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 7),
            const Text(
              'A coordinated look for leadership, teachers and your school community.',
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: dark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Primary action',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: dark, width: 2),
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
      ),
      child: compact
          ? Column(
              children: [
                sidebar,
                SizedBox(height: 220, child: Row(children: [content])),
              ],
            )
          : SizedBox(
              height: 270,
              child: Row(children: [sidebar, content]),
            ),
    );
  }
}

class _OfflineNote extends StatelessWidget {
  const _OfflineNote({required this.schoolName});

  final String schoolName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.offline_bolt_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Unlike the website prototype, $schoolName\'s selected theme is stored in the encrypted offline database and queued for sync. When the backend school-settings API is connected, the same preference can be enforced across authorized devices.',
            ),
          ),
        ],
      ),
    );
  }
}
