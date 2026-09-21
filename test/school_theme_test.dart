import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/appearance/school_theme.dart';

void main() {
  test('the original five themes keep their ids and colours, and many more are offered', () {
    expect(schoolThemePresets.take(5).map((theme) => theme.id).toList(), ['forest', 'ocean', 'violet', 'rose', 'amber']);
    expect(schoolThemePresets.length, greaterThanOrEqualTo(24));
    expect({for (final t in schoolThemePresets) t.id}.length, schoolThemePresets.length);

    expect(schoolThemeById('forest').darkArgb, 0xFF153D34);
    expect(schoolThemeById('forest').accentArgb, 0xFFC9F28D);
    expect(schoolThemeById('ocean').darkArgb, 0xFF152B4D);
    expect(schoolThemeById('ocean').accentArgb, 0xFFA8D7FF);
    expect(schoolThemeById('amber').darkArgb, 0xFF44301A);
    expect(schoolThemeById('amber').accentArgb, 0xFFFFDF9E);
  });

  test('every ready-made theme is readable: white text on the main colour, and an accent that stands out', () {
    for (final t in schoolThemePresets) {
      expect(colourProblem(darkArgb: t.darkArgb, accentArgb: t.accentArgb), isNull, reason: t.id);
    }
  });

  test('unknown or missing theme falls back to Forest', () {
    expect(schoolThemeById(null).id, 'forest');
    expect(schoolThemeById('not-a-theme').id, 'forest');
    expect(schoolThemeFromPayload(null).id, 'forest');
  });

  test('theme serialization exposes stable school setting values', () {
    expect(schoolThemeById('ocean').toJson(), {
      'themeId': 'ocean',
      'name': 'Ocean',
      'darkArgb': 0xFF152B4D,
      'accentArgb': 0xFFA8D7FF,
    });
  });

  test('the owner own colours come back from a saved record, and a broken record falls back safely', () {
    final custom = schoolThemeFromPayload({'themeId': 'custom', 'primaryArgb': 0xFF112233, 'accentArgb': 0xFFEEDDCC});
    expect(custom.isCustom, isTrue);
    expect(custom.darkArgb, 0xFF112233);
    expect(custom.accentArgb, 0xFFEEDDCC);
    expect(schoolThemeFromPayload({'themeId': 'custom'}).id, 'forest');
  });

  test('colour codes are read with or without the hash and refuse anything else', () {
    expect(parseHexColour('#1A2B3C'), 0xFF1A2B3C);
    expect(parseHexColour('1a2b3c'), 0xFF1A2B3C);
    expect(parseHexColour(' #1A2B3C '), 0xFF1A2B3C);
    expect(parseHexColour('#12345'), isNull);
    expect(parseHexColour('red'), isNull);
    expect(hexOf(0xFF1A2B3C), '#1A2B3C');
  });

  test('a main colour that is too light, or an accent too close to it, is explained', () {
    expect(colourProblem(darkArgb: 0xFFFFFF00, accentArgb: 0xFF000000), contains('too light'));
    expect(colourProblem(darkArgb: 0xFF153D34, accentArgb: 0xFF163E35), contains('too close'));
    expect(colourProblem(darkArgb: 0xFF153D34, accentArgb: 0xFFC9F28D), isNull);
  });
}
