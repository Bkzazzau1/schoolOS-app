import 'dart:math' as math;

/// A school colour theme: a main (dark) colour used for bars and buttons, and a light accent used for highlights.
class SchoolThemePreset {
  const SchoolThemePreset({
    required this.id,
    required this.name,
    required this.description,
    required this.darkArgb,
    required this.accentArgb,
  });

  /// The owner's own pair of colours. Its id is [customThemeId].
  factory SchoolThemePreset.custom({required int darkArgb, required int accentArgb}) => SchoolThemePreset(
        id: customThemeId,
        name: 'Custom colours',
        description: 'Chosen by the owner',
        darkArgb: darkArgb,
        accentArgb: accentArgb,
      );

  final String id;
  final String name;
  final String description;
  final int darkArgb;
  final int accentArgb;

  bool get isCustom => id == customThemeId;

  Map<String, Object?> toJson() => {
        'themeId': id,
        'name': name,
        'darkArgb': darkArgb,
        'accentArgb': accentArgb,
      };
}

const customThemeId = 'custom';

const schoolThemePresets = <SchoolThemePreset>[
  SchoolThemePreset(id: 'forest', name: 'Forest', description: 'Evergreen and fresh mint', darkArgb: 0xFF153D34, accentArgb: 0xFFC9F28D),
  SchoolThemePreset(id: 'ocean', name: 'Ocean', description: 'Deep blue and sky', darkArgb: 0xFF152B4D, accentArgb: 0xFFA8D7FF),
  SchoolThemePreset(id: 'violet', name: 'Violet', description: 'Plum and soft lavender', darkArgb: 0xFF352047, accentArgb: 0xFFE3BEFF),
  SchoolThemePreset(id: 'rose', name: 'Rose', description: 'Burgundy and blush', darkArgb: 0xFF48202D, accentArgb: 0xFFFFC5D6),
  SchoolThemePreset(id: 'amber', name: 'Amber', description: 'Warm brown and gold', darkArgb: 0xFF44301A, accentArgb: 0xFFFFDF9E),
  SchoolThemePreset(id: 'royal', name: 'Royal blue', description: 'Bright blue and ice', darkArgb: 0xFF1F3FA8, accentArgb: 0xFFD6E2FF),
  SchoolThemePreset(id: 'navy-gold', name: 'Navy and gold', description: 'Classic school colours', darkArgb: 0xFF0F2247, accentArgb: 0xFFF2C94C),
  SchoolThemePreset(id: 'navy-red', name: 'Navy and red', description: 'Deep navy with a red spark', darkArgb: 0xFF14264B, accentArgb: 0xFFFFB4B4),
  SchoolThemePreset(id: 'crimson', name: 'Crimson', description: 'Strong red and soft pink', darkArgb: 0xFF9B1C2E, accentArgb: 0xFFFFD9DE),
  SchoolThemePreset(id: 'maroon', name: 'Maroon and cream', description: 'Dark red and warm cream', darkArgb: 0xFF5C1522, accentArgb: 0xFFF8E9C8),
  SchoolThemePreset(id: 'emerald', name: 'Emerald', description: 'Rich green and pale lime', darkArgb: 0xFF0B6B3A, accentArgb: 0xFFD8F5B5),
  SchoolThemePreset(id: 'green-white', name: 'Green and white', description: 'Fresh green with white light', darkArgb: 0xFF1B7F3B, accentArgb: 0xFFE8F7EC),
  SchoolThemePreset(id: 'teal', name: 'Teal', description: 'Deep teal and aqua', darkArgb: 0xFF0B5C63, accentArgb: 0xFFA6EFE8),
  SchoolThemePreset(id: 'turquoise', name: 'Turquoise', description: 'Sea green and foam', darkArgb: 0xFF0E7C86, accentArgb: 0xFFCFF7F2),
  SchoolThemePreset(id: 'sky', name: 'Sky', description: 'Clear blue and cloud', darkArgb: 0xFF1769AA, accentArgb: 0xFFDCEEFF),
  SchoolThemePreset(id: 'indigo', name: 'Indigo', description: 'Deep indigo and periwinkle', darkArgb: 0xFF2E2A7A, accentArgb: 0xFFC9C6FF),
  SchoolThemePreset(id: 'purple', name: 'Purple', description: 'Vivid purple and lilac', darkArgb: 0xFF6A2C9C, accentArgb: 0xFFF0DDFF),
  SchoolThemePreset(id: 'magenta', name: 'Magenta', description: 'Bold magenta and pink', darkArgb: 0xFF9C1F6B, accentArgb: 0xFFFFD1EA),
  SchoolThemePreset(id: 'sunset', name: 'Sunset', description: 'Burnt orange and peach', darkArgb: 0xFFB4501A, accentArgb: 0xFFFFE0C2),
  SchoolThemePreset(id: 'gold', name: 'Gold', description: 'Dark bronze and bright gold', darkArgb: 0xFF6B4E0B, accentArgb: 0xFFFFE27A),
  SchoolThemePreset(id: 'coffee', name: 'Coffee', description: 'Espresso and latte', darkArgb: 0xFF3E2A20, accentArgb: 0xFFEAD5C2),
  SchoolThemePreset(id: 'olive', name: 'Olive', description: 'Olive green and sand', darkArgb: 0xFF4A5420, accentArgb: 0xFFEFE9B8),
  SchoolThemePreset(id: 'slate', name: 'Slate', description: 'Blue grey and mist', darkArgb: 0xFF37474F, accentArgb: 0xFFD5E1E8),
  SchoolThemePreset(id: 'graphite', name: 'Graphite', description: 'Charcoal and silver', darkArgb: 0xFF212529, accentArgb: 0xFFDDE1E6),
];

SchoolThemePreset schoolThemeById(String? id) {
  for (final preset in schoolThemePresets) {
    if (preset.id == id) return preset;
  }
  return schoolThemePresets.first;
}

/// The theme a saved appearance record describes: a built-in one by id, or the owner's own colours.
SchoolThemePreset schoolThemeFromPayload(Map<String, Object?>? payload) {
  if (payload == null) return schoolThemePresets.first;
  if (payload['themeId'] == customThemeId) {
    final dark = payload['primaryArgb'];
    final accent = payload['accentArgb'];
    if (dark is int && accent is int) return SchoolThemePreset.custom(darkArgb: dark, accentArgb: accent);
  }
  return schoolThemeById(payload['themeId'] as String?);
}

/// "#1A2B3C" or "1A2B3C" to an opaque ARGB value, or null when it is not a colour.
int? parseHexColour(String text) {
  final match = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(text.trim());
  if (match == null) return null;
  return 0xFF000000 | int.parse(match.group(1)!, radix: 16);
}

String hexOf(int argb) => '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

double _luminance(int argb) {
  double channel(int v) {
    final s = v / 255;
    return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel((argb >> 16) & 0xFF) + 0.7152 * channel((argb >> 8) & 0xFF) + 0.0722 * channel(argb & 0xFF);
}

/// How easily two colours can be told apart, from 1 (identical) to 21 (black on white).
double contrastRatio(int a, int b) {
  final la = _luminance(a), lb = _luminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Why a pair of colours would be hard to read, in words for the owner, or null when they are fine.
/// The main colour carries white text, and the accent sits on the main colour.
String? colourProblem({required int darkArgb, required int accentArgb}) {
  if (contrastRatio(darkArgb, 0xFFFFFFFF) < 3) {
    return 'The main colour is too light: white text on it would be hard to read. Choose a darker main colour.';
  }
  if (contrastRatio(darkArgb, accentArgb) < 2) {
    return 'The accent colour is too close to the main colour. Choose an accent that stands out from it.';
  }
  return null;
}
