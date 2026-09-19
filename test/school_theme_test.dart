import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/appearance/school_theme.dart';

void main() {
  test('school appearance presets match the website theme catalog', () {
    expect(
      schoolThemePresets.map((theme) => theme.id).toList(),
      ['forest', 'ocean', 'violet', 'rose', 'amber'],
    );

    expect(schoolThemeById('forest').darkArgb, 0xFF153D34);
    expect(schoolThemeById('forest').accentArgb, 0xFFC9F28D);
    expect(schoolThemeById('ocean').darkArgb, 0xFF152B4D);
    expect(schoolThemeById('ocean').accentArgb, 0xFFA8D7FF);
    expect(schoolThemeById('violet').darkArgb, 0xFF352047);
    expect(schoolThemeById('violet').accentArgb, 0xFFE3BEFF);
    expect(schoolThemeById('rose').darkArgb, 0xFF48202D);
    expect(schoolThemeById('rose').accentArgb, 0xFFFFC5D6);
    expect(schoolThemeById('amber').darkArgb, 0xFF44301A);
    expect(schoolThemeById('amber').accentArgb, 0xFFFFDF9E);
  });

  test('unknown or missing theme falls back to Forest', () {
    expect(schoolThemeById(null).id, 'forest');
    expect(schoolThemeById('not-a-theme').id, 'forest');
  });

  test('theme serialization exposes stable school setting values', () {
    final ocean = schoolThemeById('ocean');
    expect(ocean.toJson(), {
      'themeId': 'ocean',
      'name': 'Ocean',
      'darkArgb': 0xFF152B4D,
      'accentArgb': 0xFFA8D7FF,
    });
  });
}
