import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

/// 16 standard dark-theme base colors used across tests.
const _base = [
  RgbColor(40, 40, 40), // 0: black
  RgbColor(204, 66, 66), // 1: red
  RgbColor(102, 153, 76), // 2: green
  RgbColor(229, 181, 102), // 3: yellow
  RgbColor(102, 142, 204), // 4: blue
  RgbColor(178, 102, 178), // 5: magenta
  RgbColor(76, 178, 178), // 6: cyan
  RgbColor(170, 170, 170), // 7: white
  RgbColor(80, 80, 80), // 8: bright black
  RgbColor(230, 100, 100), // 9: bright red
  RgbColor(140, 190, 110), // 10: bright green
  RgbColor(240, 200, 120), // 11: bright yellow
  RgbColor(130, 160, 220), // 12: bright blue
  RgbColor(200, 130, 200), // 13: bright magenta
  RgbColor(100, 200, 200), // 14: bright cyan
  RgbColor(220, 220, 220), // 15: bright white
];

const _bg = RgbColor(24, 24, 24);
const _fg = RgbColor(216, 216, 216);

void main() {
  group('RgbColor', () {
    test('constructor stores components', () {
      const color = RgbColor(10, 20, 30);
      expect(color.r, 10);
      expect(color.g, 20);
      expect(color.b, 30);
    });

    test('equality with same values', () {
      const a = RgbColor(100, 150, 200);
      const b = RgbColor(100, 150, 200);
      expect(a, equals(b));
    });

    test('inequality with different values', () {
      const a = RgbColor(100, 150, 200);
      const b = RgbColor(100, 150, 201);
      expect(a, isNot(equals(b)));
    });

    test('hashCode is consistent with equality', () {
      const a = RgbColor(50, 100, 150);
      const b = RgbColor(50, 100, 150);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('black (0,0,0)', () {
      const black = RgbColor(0, 0, 0);
      expect(black.r, 0);
      expect(black.g, 0);
      expect(black.b, 0);
    });

    test('white (255,255,255)', () {
      const white = RgbColor(255, 255, 255);
      expect(white.r, 255);
      expect(white.g, 255);
      expect(white.b, 255);
    });

    test('toString contains components', () {
      const color = RgbColor(10, 20, 30);
      expect(color.toString(), 'RgbColor(10, 20, 30)');
    });
  });

  group('NamedColor', () {
    test('standard colors have expected indices', () {
      expect(NamedColor.black, 0);
      expect(NamedColor.red, 1);
      expect(NamedColor.green, 2);
      expect(NamedColor.yellow, 3);
      expect(NamedColor.blue, 4);
      expect(NamedColor.magenta, 5);
      expect(NamedColor.cyan, 6);
      expect(NamedColor.white, 7);
    });

    test('bright colors have expected indices', () {
      expect(NamedColor.brightBlack, 8);
      expect(NamedColor.brightRed, 9);
      expect(NamedColor.brightGreen, 10);
      expect(NamedColor.brightYellow, 11);
      expect(NamedColor.brightBlue, 12);
      expect(NamedColor.brightMagenta, 13);
      expect(NamedColor.brightCyan, 14);
      expect(NamedColor.brightWhite, 15);
    });
  });

  group('generate256Color', () {
    test('returns exactly 256 entries', () {
      final result = generate256Color(
        base: _base,
        background: _bg,
        foreground: _fg,
      );
      expect(result.length, 256);
    });

    test('preserves base 16 colors in indices 0–15', () {
      final result = generate256Color(
        base: _base,
        background: _bg,
        foreground: _fg,
      );
      for (var i = 0; i < 16; i++) {
        expect(result[i], _base[i], reason: 'index $i should match base color');
      }
    });

    test('all outputs are valid RGB components (0–255)', () {
      final result = generate256Color(
        base: _base,
        background: _bg,
        foreground: _fg,
      );
      for (var i = 0; i < 256; i++) {
        expect(result[i].r, inInclusiveRange(0, 255), reason: 'index $i r');
        expect(result[i].g, inInclusiveRange(0, 255), reason: 'index $i g');
        expect(result[i].b, inInclusiveRange(0, 255), reason: 'index $i b');
      }
    });

    test('cube corner (0,0,0) at index 16 equals background color', () {
      // At ri=gi=bi=0 all interpolation t-values are 0, so every lerp
      // returns its first argument — the chain collapses to base8[0] = bg.
      final result = generate256Color(
        base: _base,
        background: _bg,
        foreground: _fg,
      );
      expect(result[16], _bg);
    });

    test('cube corner (5,5,5) at index 231 equals foreground color', () {
      // At ri=gi=bi=5 all t-values are 1.0, so every lerp returns its second
      // argument — the chain collapses to base8[7] = fg.
      final result = generate256Color(
        base: _base,
        background: _bg,
        foreground: _fg,
      );
      expect(result[231], _fg);
    });

    test('grayscale ramp (232–255) increases in perceived brightness', () {
      final result = generate256Color(
        base: _base,
        background: _bg,
        foreground: _fg,
      );
      // Simple luminance proxy; sufficient to verify monotonic direction.
      double luma(RgbColor c) => 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
      for (var i = 233; i < 256; i++) {
        expect(
          luma(result[i]),
          greaterThanOrEqualTo(luma(result[i - 1])),
          reason: 'index $i should not be darker than ${i - 1}',
        );
      }
    });

    test('skip set preserves specified indices unchanged', () {
      final customBase = List<RgbColor>.from(_base);
      const custom = RgbColor(123, 45, 67);
      customBase[0] = custom;
      final result = generate256Color(
        base: customBase,
        background: _bg,
        foreground: _fg,
        skip: {0},
      );
      expect(result[0], custom);
    });

    test('skip set does not affect unspecified indices', () {
      final result = generate256Color(
        base: _base,
        background: _bg,
        foreground: _fg,
        skip: {20, 30},
      );
      // Skipped indices keep the values from base (indices 0–15 always come
      // from base; for 16+ they come from the generated cube — but skip
      // means they keep base values, which for 16+ are uninitialized in
      // the returned list). The key contract: non-skipped indices ARE
      // generated correctly, so index 16 still equals bg and 231 equals fg.
      expect(result[16], _bg);
      expect(result[231], _fg);
    });

    test(
      'dark theme: cube corner orientation runs dark to light by default',
      () {
        // Dark theme: fg is brighter than bg, so is_light_theme=false, no swap.
        // Default harmonious=false; cube (0,0,0)=bg (dark), (5,5,5)=fg (light).
        final result = generate256Color(
          base: _base,
          background: _bg,
          foreground: _fg,
        );
        expect(result[16], _bg);
        expect(result[231], _fg);
      },
    );

    test('light theme: non-harmonious mode swaps orientation', () {
      // For a light theme, bg is light and fg is dark.
      const lightBg = RgbColor(240, 240, 240);
      const lightFg = RgbColor(30, 30, 30);
      // harmonious defaults to false — cube swaps so it still runs dark→light.
      final result = generate256Color(
        base: _base,
        background: lightBg,
        foreground: lightFg,
      );
      // With harmonious=false, bg and fg are swapped internally so the cube
      // still runs dark→light. Index 16 (0,0,0 corner) should be near the
      // darker of the two colors after the swap (which is fg = dark).
      // After swap: base8[0]=fg_lab (dark), base8[7]=bg_lab (light)
      // Corner (0,0,0) collapses to base8[0] = fg = dark
      expect(result[16], lightFg);
    });

    test('requires exactly 16 base colors', () {
      expect(
        () => generate256Color(
          base: const [RgbColor(0, 0, 0)],
          background: _bg,
          foreground: _fg,
        ),
        throwsArgumentError,
      );
    });
  });
}
