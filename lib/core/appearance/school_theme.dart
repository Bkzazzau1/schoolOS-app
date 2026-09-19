class SchoolThemePreset {
  const SchoolThemePreset({
    required this.id,
    required this.name,
    required this.description,
    required this.darkArgb,
    required this.accentArgb,
  });

  final String id;
  final String name;
  final String description;
  final int darkArgb;
  final int accentArgb;

  Map<String, Object?> toJson() => {
        'themeId': id,
        'name': name,
        'darkArgb': darkArgb,
        'accentArgb': accentArgb,
      };
}

const schoolThemePresets = <SchoolThemePreset>[
  SchoolThemePreset(
    id: 'forest',
    name: 'Forest',
    description: 'Evergreen and fresh mint',
    darkArgb: 0xFF153D34,
    accentArgb: 0xFFC9F28D,
  ),
  SchoolThemePreset(
    id: 'ocean',
    name: 'Ocean',
    description: 'Deep blue and sky',
    darkArgb: 0xFF152B4D,
    accentArgb: 0xFFA8D7FF,
  ),
  SchoolThemePreset(
    id: 'violet',
    name: 'Violet',
    description: 'Plum and soft lavender',
    darkArgb: 0xFF352047,
    accentArgb: 0xFFE3BEFF,
  ),
  SchoolThemePreset(
    id: 'rose',
    name: 'Rose',
    description: 'Burgundy and blush',
    darkArgb: 0xFF48202D,
    accentArgb: 0xFFFFC5D6,
  ),
  SchoolThemePreset(
    id: 'amber',
    name: 'Amber',
    description: 'Warm brown and gold',
    darkArgb: 0xFF44301A,
    accentArgb: 0xFFFFDF9E,
  ),
];

SchoolThemePreset schoolThemeById(String? id) {
  for (final preset in schoolThemePresets) {
    if (preset.id == id) return preset;
  }
  return schoolThemePresets.first;
}
