import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/appearance/logo_processor.dart';
import '../../../core/appearance/school_appearance_controller.dart';
import '../../../core/appearance/school_logo.dart';
import '../../../core/appearance/school_theme.dart';
import 'appearance_colour_picker.dart';

/// Lets the picture for the logo be chosen. Returns null when the owner cancels. Replaceable in tests.
typedef LogoPicker = Future<Uint8List?> Function();

Future<Uint8List?> pickLogoFromDevice() async {
  final file = await FilePicker.pickFile(type: FileType.image, dialogTitle: 'Choose the school logo');
  if (file == null) return null;
  return file.readAsBytes();
}

/// The owner's page for the school's look: the logo, a colour theme from many ready-made ones, or their own two colours.
class ProprietorAppearancePage extends StatefulWidget {
  const ProprietorAppearancePage({
    super.key,
    required this.schoolName,
    required this.controller,
    required this.onDashboard,
    required this.onAppearanceChanged,
    this.pickLogo = pickLogoFromDevice,
  });

  final String schoolName;
  final SchoolAppearanceController controller;
  final VoidCallback onDashboard;
  final VoidCallback onAppearanceChanged;
  final LogoPicker pickLogo;

  @override
  State<ProprietorAppearancePage> createState() => _ProprietorAppearancePageState();
}

class _ProprietorAppearancePageState extends State<ProprietorAppearancePage> {
  SchoolThemePreset? _draft;
  late int _customDark;
  late int _customAccent;
  String _message = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final current = widget.controller.theme;
    _customDark = current.darkArgb;
    _customAccent = current.accentArgb;
  }

  SchoolThemePreset get _selected => _draft ?? widget.controller.theme;

  bool get _changed {
    final a = _selected, b = widget.controller.theme;
    return a.id != b.id || a.darkArgb != b.darkArgb || a.accentArgb != b.accentArgb;
  }

  String? get _problem =>
      _selected.isCustom ? colourProblem(darkArgb: _selected.darkArgb, accentArgb: _selected.accentArgb) : null;

  void _pickPreset(SchoolThemePreset preset) => setState(() {
        _draft = preset;
        _customDark = preset.darkArgb;
        _customAccent = preset.accentArgb;
        _message = '';
      });

  void _custom({int? dark, int? accent}) => setState(() {
        _customDark = dark ?? _customDark;
        _customAccent = accent ?? _customAccent;
        _draft = SchoolThemePreset.custom(darkArgb: _customDark, accentArgb: _customAccent);
        _message = '';
      });

  Future<void> _run(Future<void> Function() action, String done) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _message = '';
    });
    try {
      await action();
      if (!mounted) return;
      setState(() {
        _saving = false;
        _message = done;
      });
      widget.onAppearanceChanged();
    } on StateError catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _message = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _message = 'That could not be saved. Please try again.';
      });
    }
  }

  Future<void> _apply() => _run(() async {
        await widget.controller.applyTheme(_selected);
        if (mounted) setState(() => _draft = null);
      }, '${_selected.name} saved for ${widget.schoolName}. Everyone in the school will see it.');

  Future<void> _chooseLogo() async {
    final Uint8List? picked;
    try {
      picked = await widget.pickLogo();
    } catch (_) {
      if (mounted) setState(() => _message = 'The picture could not be opened.');
      return;
    }
    if (picked == null) return;
    final logo = picked;
    await _run(() async => widget.controller.applyLogo(await shrinkLogo(logo)), 'Logo saved. Everyone in the school will see it.');
  }

  Future<void> _removeLogo() => _run(() => widget.controller.applyLogo(null), 'Logo removed.');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final problem = _problem;
            return ListView(
              padding: EdgeInsets.fromLTRB(compact ? 18 : 28, 24, compact ? 18 : 28, 48),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1160),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PROPRIETOR · SCHOOL APPEARANCE',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.7,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('School Appearance', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        Text(
                          'Choose the logo and colours of ${widget.schoolName}. Everyone in the school sees them.',
                          style: theme.textTheme.bodyLarge?.copyWith(height: 1.5, color: theme.colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 18),
                        _LogoCard(
                          schoolName: widget.schoolName,
                          controller: widget.controller,
                          busy: _saving,
                          onChoose: _chooseLogo,
                          onRemove: _removeLogo,
                        ),
                        const SizedBox(height: 16),
                        _ThemeCard(
                          compact: compact,
                          current: widget.controller.theme,
                          selected: _selected,
                          customDark: _customDark,
                          customAccent: _customAccent,
                          onPreset: _pickPreset,
                          onCustom: _custom,
                        ),
                        const SizedBox(height: 16),
                        _Preview(schoolName: widget.schoolName, theme: _selected, controller: widget.controller),
                        const SizedBox(height: 14),
                        if (problem != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(problem, style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w700)),
                          ),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton(
                              key: const ValueKey('apply-theme'),
                              onPressed: _saving || !_changed || problem != null ? null : _apply,
                              child: Text(_saving ? 'Saving…' : 'Apply to the whole school'),
                            ),
                            OutlinedButton(
                              onPressed: _draft == null ? null : () => setState(() => _draft = null),
                              child: const Text('Cancel changes'),
                            ),
                            TextButton(onPressed: () => _pickPreset(schoolThemePresets.first), child: const Text('Back to default')),
                          ],
                        ),
                        if (_message.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(_message, key: const ValueKey('appearance-message'), style: theme.textTheme.bodyMedium),
                        ],
                        const SizedBox(height: 14),
                        Text(
                          'Saved on this device and shared with the school when it next connects.',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
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

class _LogoCard extends StatelessWidget {
  const _LogoCard({
    required this.schoolName,
    required this.controller,
    required this.busy,
    required this.onChoose,
    required this.onRemove,
  });

  final String schoolName;
  final SchoolAppearanceController controller;
  final bool busy;
  final VoidCallback onChoose;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLogo = controller.logo != null;
    return _Panel(
      title: 'School logo',
      subtitle: 'Shown next to the school name for everyone. A square picture works best.',
      child: Row(
        children: [
          SchoolLogo(schoolName: schoolName, size: 72, appearance: controller),
          const SizedBox(width: 18),
          Expanded(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  key: const ValueKey('choose-logo'),
                  onPressed: busy ? null : onChoose,
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: Text(hasLogo ? 'Change logo' : 'Choose logo'),
                ),
                if (hasLogo)
                  OutlinedButton(key: const ValueKey('remove-logo'), onPressed: busy ? null : onRemove, child: const Text('Remove logo')),
                Text(
                  hasLogo ? 'Your logo is set.' : 'No logo yet. The first letter of the school name is shown.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.compact,
    required this.current,
    required this.selected,
    required this.customDark,
    required this.customAccent,
    required this.onPreset,
    required this.onCustom,
  });

  final bool compact;
  final SchoolThemePreset current;
  final SchoolThemePreset selected;
  final int customDark;
  final int customAccent;
  final ValueChanged<SchoolThemePreset> onPreset;
  final void Function({int? dark, int? accent}) onCustom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Panel(
      title: 'Colour theme',
      subtitle: '${schoolThemePresets.length} ready-made themes, or make your own from any two colours.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final preset in schoolThemePresets)
                _ThemeTile(
                  preset: preset,
                  selected: !selected.isCustom && selected.id == preset.id,
                  isCurrent: !current.isCustom && current.id == preset.id,
                  onTap: () => onPreset(preset),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Text('Your own colours', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            'Pick the main colour (bars and buttons) and an accent (highlights), or type a colour code.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 32,
            runSpacing: 20,
            children: [
              SizedBox(
                width: compact ? double.infinity : 420,
                child: ColourField(label: 'Main colour', value: customDark, forAccent: false, onChanged: (v) => onCustom(dark: v)),
              ),
              SizedBox(
                width: compact ? double.infinity : 420,
                child: ColourField(label: 'Accent colour', value: customAccent, forAccent: true, onChanged: (v) => onCustom(accent: v)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.preset, required this.selected, required this.isCurrent, required this.onTap});

  final SchoolThemePreset preset;
  final bool selected;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      key: ValueKey('theme-${preset.id}'),
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            width: selected ? 2.5 : 1,
            color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Container(height: 30, decoration: BoxDecoration(color: Color(preset.darkArgb), borderRadius: const BorderRadius.horizontal(left: Radius.circular(8))))),
                Expanded(child: Container(height: 30, decoration: BoxDecoration(color: Color(preset.accentArgb), borderRadius: const BorderRadius.horizontal(right: Radius.circular(8))))),
              ],
            ),
            const SizedBox(height: 8),
            Text(preset.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(isCurrent ? 'In use' : preset.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// A small sample of the school's look with the chosen colours and logo, before anything is saved.
class _Preview extends StatelessWidget {
  const _Preview({required this.schoolName, required this.theme, required this.controller});

  final String schoolName;
  final SchoolThemePreset theme;
  final SchoolAppearanceController controller;

  @override
  Widget build(BuildContext context) {
    final dark = Color(theme.darkArgb), accent = Color(theme.accentArgb);
    return _Panel(
      title: 'Preview',
      subtitle: '${theme.name}${theme.isCustom ? ' · ${hexOf(theme.darkArgb)} and ${hexOf(theme.accentArgb)}' : ''}',
      child: Container(
        key: const ValueKey('theme-preview'),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              color: dark,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  SchoolLogo(schoolName: schoolName, size: 36, appearance: controller),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(schoolName, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(color: dark, borderRadius: BorderRadius.circular(999)),
                    child: const Text('Button', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(999)),
                    child: Text('Highlight', style: TextStyle(color: dark, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(side: BorderSide(color: theme.colorScheme.outlineVariant), borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}
