import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

import '../helpers/setup.dart';

void main() {
  setUp(() => testEnvironment);

  group('color utilities', () {
    group('parseColor', () {
      test('parses X11 color names', () {
        final color = parseColor('ForestGreen');
        expect(color, const RgbColor(34, 139, 34));
      });

      test('ignores surrounding spaces and tabs', () {
        final color = parseColor('\t ForestGreen \t');
        expect(color, const RgbColor(34, 139, 34));
      });

      test('throws for invalid color values', () {
        expect(
          () => parseColor('not-a-color'),
          throwsA(isA<InvalidValueException>()),
        );
      });
    });

    group('parsePaletteEntry', () {
      test('returns index and color', () {
        final entry = parsePaletteEntry('0x10=#282c34');
        expect(entry.index, 16);
        expect(entry.color, const RgbColor(40, 44, 52));
      });

      test('accepts surrounding spaces and tabs', () {
        final entry = parsePaletteEntry('\t 0b10000 = ForestGreen \t');
        expect(entry.index, 16);
        expect(entry.color, const RgbColor(34, 139, 34));
      });
    });

    group('defaultColorPalette', () {
      test('returns 256 colors', () {
        final palette = defaultColorPalette();
        expect(palette, hasLength(256));
        expect(palette, everyElement(isA<RgbColor>()));
      });
    });

    group('colorContrast', () {
      test('returns maximum contrast for black and white', () {
        final contrast = colorContrast(
          const RgbColor(0, 0, 0),
          const RgbColor(255, 255, 255),
        );
        expect(contrast, closeTo(21, 0.001));
      });
    });

    group('generateColorPalette', () {
      test('preserves explicitly skipped entries at high mask indices', () {
        final base = List.generate(
          256,
          (index) => RgbColor(index, (index * 3) % 256, 255 - index),
        );

        final palette = generateColorPalette(
          base: base,
          skip: {31, 32, 63, 64, 127, 128, 191, 192, 255},
          background: const RgbColor(0, 0, 0),
          foreground: const RgbColor(255, 255, 255),
        );

        expect(palette[31], base[31]);
        expect(palette[32], base[32]);
        expect(palette[63], base[63]);
        expect(palette[64], base[64]);
        expect(palette[127], base[127]);
        expect(palette[128], base[128]);
        expect(palette[191], base[191]);
        expect(palette[192], base[192]);
        expect(palette[255], base[255]);
      });
    });
  });
}
