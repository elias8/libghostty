import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty_flutter/foundation.dart';

void main() {
  group('ColorPalette', () {
    late ColorPalette palette;

    setUp(() {
      palette = ColorPalette.fromAnsiColors(
        ansiColors: _ansiColors,
        background: _bg,
        foreground: _fg,
      );
    });

    test('index operator returns a Color', () {
      expect(palette[0], isA<Color>());
    });

    test('indices 0–15 match the provided ANSI colors', () {
      for (var i = 0; i < 16; i++) {
        expect(palette[i], _ansiColors[i], reason: 'index $i');
      }
    });

    test('all 256 indices are accessible', () {
      for (var i = 0; i < 256; i++) {
        expect(() => palette[i], returnsNormally, reason: 'index $i');
      }
    });

    test('indices 16–255 are valid opaque Colors', () {
      for (var i = 16; i < 256; i++) {
        final c = palette[i];
        expect(
          (c.a * 255.0).round().clamp(0, 255),
          255,
          reason: 'index $i should be opaque',
        );
      }
    });

    test('cube corner index 16 approximates the background color', () {
      // Index 16 = cube corner (0,0,0) which collapses to bg in CIELAB.
      final bg = palette[16];
      // Allow small rounding differences from color space conversions.
      expect((_r(bg) - _r(_bg)).abs(), lessThanOrEqualTo(2));
      expect((_g(bg) - _g(_bg)).abs(), lessThanOrEqualTo(2));
      expect((_b(bg) - _b(_bg)).abs(), lessThanOrEqualTo(2));
    });

    test('cube corner index 231 approximates the foreground color', () {
      // Index 231 = cube corner (5,5,5) which collapses to fg in CIELAB.
      final fg = palette[231];
      expect((_r(fg) - _r(_fg)).abs(), lessThanOrEqualTo(2));
      expect((_g(fg) - _g(_fg)).abs(), lessThanOrEqualTo(2));
      expect((_b(fg) - _b(_fg)).abs(), lessThanOrEqualTo(2));
    });

    test('grayscale ramp (232–255) increases in perceived brightness', () {
      double luma(Color c) => 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
      for (var i = 233; i < 256; i++) {
        expect(
          luma(palette[i]),
          greaterThanOrEqualTo(luma(palette[i - 1])),
          reason: 'index $i should not be darker than ${i - 1}',
        );
      }
    });

    test('requires exactly 16 ANSI colors', () {
      expect(
        () => ColorPalette.fromAnsiColors(
          ansiColors: const [Color(0xFF000000)],
          background: _bg,
          foreground: _fg,
        ),
        throwsArgumentError,
      );
    });
  });
}

const _ansiColors = [
  Color(0xFF282828), // 0: black
  Color(0xFFCC4242), // 1: red
  Color(0xFF66994C), // 2: green
  Color(0xFFE5B566), // 3: yellow
  Color(0xFF668ECC), // 4: blue
  Color(0xFFB266B2), // 5: magenta
  Color(0xFF4CB2B2), // 6: cyan
  Color(0xFFAAAAAA), // 7: white
  Color(0xFF505050), // 8: bright black
  Color(0xFFE66464), // 9: bright red
  Color(0xFF8CBE6E), // 10: bright green
  Color(0xFFF0C878), // 11: bright yellow
  Color(0xFF82A0DC), // 12: bright blue
  Color(0xFFC882C8), // 13: bright magenta
  Color(0xFF64C8C8), // 14: bright cyan
  Color(0xFFDCDCDC), // 15: bright white
];
const _bg = Color(0xFF181818);

const _fg = Color(0xFFD8D8D8);

int _b(Color c) => (c.b * 255.0).round().clamp(0, 255);

int _g(Color c) => (c.g * 255.0).round().clamp(0, 255);

int _r(Color c) => (c.r * 255.0).round().clamp(0, 255);
