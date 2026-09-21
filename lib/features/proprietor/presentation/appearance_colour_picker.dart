import 'package:flutter/material.dart';

import '../../../core/appearance/school_theme.dart';

const _mainSwatches = <int>[
  0xFF153D34, 0xFF0B6B3A, 0xFF1B7F3B, 0xFF4A5420, 0xFF0B5C63, 0xFF0E7C86, 0xFF1769AA, 0xFF1F3FA8,
  0xFF152B4D, 0xFF0F2247, 0xFF2E2A7A, 0xFF352047, 0xFF6A2C9C, 0xFF9C1F6B, 0xFF48202D, 0xFF5C1522,
  0xFF9B1C2E, 0xFFB4501A, 0xFF6B4E0B, 0xFF44301A, 0xFF3E2A20, 0xFF37474F, 0xFF212529, 0xFF000000,
];

const _accentSwatches = <int>[
  0xFFC9F28D, 0xFFD8F5B5, 0xFFE8F7EC, 0xFFEFE9B8, 0xFFA6EFE8, 0xFFCFF7F2, 0xFFDCEEFF, 0xFFA8D7FF,
  0xFFD6E2FF, 0xFFC9C6FF, 0xFFE3BEFF, 0xFFF0DDFF, 0xFFFFD1EA, 0xFFFFC5D6, 0xFFFFD9DE, 0xFFFFB4B4,
  0xFFFFE0C2, 0xFFFFDF9E, 0xFFFFE27A, 0xFFF2C94C, 0xFFF8E9C8, 0xFFEAD5C2, 0xFFDDE1E6, 0xFFFFFFFF,
];

/// One colour to choose: a row of ready-made swatches and a box for any colour written as #RRGGBB.
class ColourField extends StatefulWidget {
  const ColourField({super.key, required this.label, required this.value, required this.onChanged, required this.forAccent});

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  /// Offers light colours (for highlights) instead of dark ones (for bars and buttons).
  final bool forAccent;

  @override
  State<ColourField> createState() => _ColourFieldState();
}

class _ColourFieldState extends State<ColourField> {
  late final TextEditingController _hex = TextEditingController(text: hexOf(widget.value));
  bool _invalid = false;

  @override
  void didUpdateWidget(ColourField old) {
    super.didUpdateWidget(old);
    final typed = parseHexColour(_hex.text);
    if (widget.value != old.value && typed != widget.value) {
      _hex.text = hexOf(widget.value);
      _invalid = false;
    }
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _typed(String text) {
    final parsed = parseHexColour(text);
    setState(() => _invalid = parsed == null);
    if (parsed != null) widget.onChanged(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final swatches = widget.forAccent ? _accentSwatches : _mainSwatches;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Color(widget.value),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 140,
              child: TextField(
                controller: _hex,
                onChanged: _typed,
                decoration: InputDecoration(
                  labelText: 'Colour code',
                  hintText: '#1A2B3C',
                  isDense: true,
                  errorText: _invalid ? 'Use #RRGGBB' : null,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final argb in swatches)
              Semantics(
                button: true,
                label: 'Use ${hexOf(argb)}',
                child: InkWell(
                  key: ValueKey('swatch-${widget.forAccent ? 'accent' : 'main'}-${hexOf(argb)}'),
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => widget.onChanged(argb),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(argb),
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: argb == widget.value ? 3 : 1,
                        color: argb == widget.value ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
