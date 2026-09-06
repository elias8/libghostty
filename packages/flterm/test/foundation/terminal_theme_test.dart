import 'package:flterm/src/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('CursorTheme', () {
    group('constructor', () {
      test('uses default values', () {
        const cursor = CursorTheme();

        expect(cursor.shape, CursorShape.block);
        expect(cursor.color, isNull);
        expect(cursor.blinkInterval, const Duration(milliseconds: 600));
        expect(cursor.opacity, 1.0);
      });

      test('stores custom values', () {
        const cursor = CursorTheme(
          shape: CursorShape.bar,
          color: DynamicColor.fixed(Color(0xFFFF0000)),
          text: DynamicColor.cellBackground(),
          blinkInterval: Duration(milliseconds: 500),
          opacity: 0.7,
        );

        expect(cursor.shape, CursorShape.bar);
        expect(cursor.color, const DynamicColor.fixed(Color(0xFFFF0000)));
        expect(cursor.text, const DynamicColor.cellBackground());
        expect(cursor.blinkInterval, const Duration(milliseconds: 500));
        expect(cursor.opacity, 0.7);
      });
    });

    group('equality', () {
      test('compares cursor themes by value', () {
        const a = CursorTheme();
        const b = CursorTheme();

        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
        expect(a, isNot(equals(const CursorTheme(shape: CursorShape.bar))));
        expect(a, isNot(equals(const CursorTheme(opacity: 0.5))));
        expect(
          a,
          isNot(equals(const CursorTheme(text: DynamicColor.cellBackground()))),
        );
      });
    });

    group('lerp', () {
      test('returns endpoints at boundaries', () {
        const a = CursorTheme(
          color: DynamicColor.fixed(Color(0xFF000000)),
          blinkInterval: Duration(milliseconds: 400),
          opacity: 0.2,
        );
        const b = CursorTheme(
          shape: CursorShape.bar,
          color: DynamicColor.fixed(Color(0xFFFFFFFF)),
          blinkInterval: Duration(milliseconds: 800),
          opacity: 0.8,
        );

        final at0 = CursorTheme.lerp(a, b, 0.0)!;
        expect(at0.shape, CursorShape.block);
        expect(at0.blinkInterval, const Duration(milliseconds: 400));
        expect(at0.opacity, 0.2);

        final at1 = CursorTheme.lerp(a, b, 1.0)!;
        expect(at1.shape, CursorShape.bar);
        expect(at1.blinkInterval, const Duration(milliseconds: 800));
        expect(at1.opacity, 0.8);
      });

      test('interpolates opacity and snaps shape at midpoint', () {
        const a = CursorTheme(opacity: 0.0);
        const b = CursorTheme(shape: CursorShape.bar);

        final mid = CursorTheme.lerp(a, b, 0.5)!;

        expect(mid.opacity, 0.5);
        expect(CursorTheme.lerp(a, b, 0.49)!.shape, CursorShape.block);
        expect(CursorTheme.lerp(a, b, 0.5)!.shape, CursorShape.bar);
      });

      test('returns nullable endpoints at boundaries', () {
        const a = CursorTheme();

        expect(CursorTheme.lerp(a, null, 0.0), a);
        expect(CursorTheme.lerp(a, null, 1.0), isNull);
        expect(CursorTheme.lerp(null, a, 0.0), isNull);
        expect(CursorTheme.lerp(null, a, 1.0), a);
      });
    });
  });

  group('SelectionTheme', () {
    test('defaults: null background and foreground', () {
      const theme = SelectionTheme();
      expect(theme.background, isNull);
      expect(theme.foreground, isNull);
    });

    test('stores custom values', () {
      const theme = SelectionTheme(
        background: DynamicColor.fixed(Color(0xFF112233)),
        foreground: DynamicColor.cellBackground(),
      );
      expect(theme.background, const DynamicColor.fixed(Color(0xFF112233)));
      expect(theme.foreground, const DynamicColor.cellBackground());
    });

    test('equality and hashCode', () {
      const a = SelectionTheme();
      const b = SelectionTheme();
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(
          equals(
            const SelectionTheme(
              background: DynamicColor.fixed(Color(0xFFFF0000)),
            ),
          ),
        ),
      );
      expect(
        a,
        isNot(
          equals(
            const SelectionTheme(
              foreground: DynamicColor.fixed(Color(0xFF00FF00)),
            ),
          ),
        ),
      );
    });

    test('lerp at boundaries returns endpoints', () {
      const a = SelectionTheme(
        background: DynamicColor.fixed(Color(0xFF000000)),
      );
      const b = SelectionTheme(
        background: DynamicColor.fixed(Color(0xFFFFFFFF)),
      );
      expect(SelectionTheme.lerp(a, b, 0.0), a);
      expect(SelectionTheme.lerp(a, b, 1.0), b);
    });

    test('lerp snaps background at midpoint', () {
      const a = SelectionTheme(
        background: DynamicColor.fixed(Color(0xFF000000)),
      );
      const b = SelectionTheme(background: DynamicColor.cellForeground());
      expect(SelectionTheme.lerp(a, b, 0.49)!.background, a.background);
      expect(SelectionTheme.lerp(a, b, 0.5)!.background, b.background);
    });

    test('lerp with null returns other at boundary', () {
      const a = SelectionTheme();
      expect(SelectionTheme.lerp(a, null, 0.0), a);
      expect(SelectionTheme.lerp(a, null, 1.0), isNull);
      expect(SelectionTheme.lerp(null, a, 0.0), isNull);
      expect(SelectionTheme.lerp(null, a, 1.0), a);
    });
  });

  group('SearchTheme', () {
    test('distinguishes matches from the selected match by default', () {
      const theme = SearchTheme();

      expect(theme.match, isNot(theme.selectedMatch));
      expect(theme.match.background, isNotNull);
      expect(theme.selectedMatch.background, isNotNull);
    });
  });

  group('HyperlinkStyle', () {
    test('defaults: no underline, no colors', () {
      const style = HyperlinkStyle();
      expect(style.underline, UnderlineStyle.none);
      expect(style.underlineColor, isNull);
      expect(style.textColor, isNull);
    });

    test('stores custom values', () {
      const style = HyperlinkStyle(
        underline: UnderlineStyle.single,
        underlineColor: Color(0xFF00FF00),
        textColor: Color(0xFF0000FF),
      );
      expect(style.underline, UnderlineStyle.single);
      expect(style.underlineColor, const Color(0xFF00FF00));
      expect(style.textColor, const Color(0xFF0000FF));
    });

    test('equality compares all fields', () {
      const a = HyperlinkStyle();
      const b = HyperlinkStyle();
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(equals(const HyperlinkStyle(underline: UnderlineStyle.single))),
      );
      expect(
        a,
        isNot(equals(const HyperlinkStyle(underlineColor: Color(0xFFFF0000)))),
      );
      expect(
        a,
        isNot(equals(const HyperlinkStyle(textColor: Color(0xFFFF0000)))),
      );
    });

    test('lerp snaps underline at midpoint', () {
      const a = HyperlinkStyle();
      const b = HyperlinkStyle(underline: UnderlineStyle.single);
      expect(HyperlinkStyle.lerp(a, b, 0.49)!.underline, UnderlineStyle.none);
      expect(HyperlinkStyle.lerp(a, b, 0.5)!.underline, UnderlineStyle.single);
    });

    test('lerp interpolates colors', () {
      const a = HyperlinkStyle(textColor: Color(0xFF000000));
      const b = HyperlinkStyle(textColor: Color(0xFFFFFFFF));
      final mid = HyperlinkStyle.lerp(a, b, 0.5)!;
      expect(mid.textColor, isNot(equals(a.textColor)));
      expect(mid.textColor, isNot(equals(b.textColor)));
    });

    test('lerp with null returns other at boundary', () {
      const a = HyperlinkStyle();
      expect(HyperlinkStyle.lerp(a, null, 0.0), a);
      expect(HyperlinkStyle.lerp(a, null, 1.0), isNull);
      expect(HyperlinkStyle.lerp(null, a, 0.0), isNull);
      expect(HyperlinkStyle.lerp(null, a, 1.0), a);
    });
  });

  group('HyperlinkTheme', () {
    test('defaults: idle plain, highlighted single underline', () {
      const theme = HyperlinkTheme();
      expect(theme.idle.underline, UnderlineStyle.none);
      expect(theme.idle.textColor, isNull);
      expect(theme.highlighted.underline, UnderlineStyle.single);
      expect(theme.highlighted.textColor, isNull);
    });

    test('equality and hashCode', () {
      const a = HyperlinkTheme();
      const b = HyperlinkTheme();
      const c = HyperlinkTheme(highlighted: HyperlinkStyle());
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    test('lerp with null returns other at boundary', () {
      const a = HyperlinkTheme();
      expect(HyperlinkTheme.lerp(a, null, 0.0), a);
      expect(HyperlinkTheme.lerp(a, null, 1.0), isNull);
      expect(HyperlinkTheme.lerp(null, a, 0.0), isNull);
      expect(HyperlinkTheme.lerp(null, a, 1.0), a);
    });
  });

  group('TerminalTheme', () {
    void expectPaletteIndexesReadable(TerminalTheme theme) {
      for (var i = 0; i < 256; i++) {
        expect(() => theme.palette[i], returnsNormally, reason: 'index $i');
      }
    }

    test('dark() produces valid dark theme', () {
      final theme = TerminalTheme.dark();

      expect((theme.foreground.a * 255.0).round(), 255);
      expect((theme.background.a * 255.0).round(), 255);
      expectPaletteIndexesReadable(theme);
    });

    test('light() produces valid light theme', () {
      final theme = TerminalTheme.light();

      expect((theme.foreground.a * 255.0).round(), 255);
      expect((theme.background.a * 255.0).round(), 255);
      expectPaletteIndexesReadable(theme);
    });

    test('defaults: boldIsBright, faintOpacity, minimumContrast, '
        'fontFamilyFallback', () {
      final theme = TerminalTheme.dark();
      expect(theme.boldIsBright, isFalse);
      expect(theme.boldColor, isNull);
      expect(theme.faintOpacity, 0.5);
      expect(theme.minimumContrast, 1.0);
      expect(theme.fontFamilyFallback, isNotEmpty);
      expect(theme.selection, const SelectionTheme());
      expect(theme.search, const SearchTheme());
    });

    test('prioritizes the proportional Nerd Symbols fallback', () {
      final theme = TerminalTheme.dark();

      expect(theme.fontFamilyFallback.first, 'Symbols Nerd Font');
    });

    test('defaults: fully opaque background, per-cell opacity off', () {
      final theme = TerminalTheme.dark();
      expect(theme.backgroundOpacity, 1.0);
      expect(theme.backgroundOpacityCells, isFalse);
      expect(theme.backgroundOpacityAlpha, 255);
    });

    test('backgroundOpacityAlpha precomputes opacity as a 0-255 byte', () {
      final dim = TerminalTheme.dark().copyWith(backgroundOpacity: 0.5);
      expect(dim.backgroundOpacityAlpha, 128);
    });

    test('backgroundOpacity must be in [0.0, 1.0]', () {
      final palette = ColorPalette(
        ansiColors: List.filled(16, const Color(0xFF000000)),
        background: const Color(0xFF000000),
        foreground: const Color(0xFFFFFFFF),
      );
      expect(
        () => TerminalTheme(palette: palette, backgroundOpacity: -0.1),
        throwsAssertionError,
      );
      expect(
        () => TerminalTheme(palette: palette, backgroundOpacity: 1.1),
        throwsAssertionError,
      );
    });

    test('dark and light have different foreground and background', () {
      final dark = TerminalTheme.dark();
      final light = TerminalTheme.light();
      expect(dark.foreground, isNot(equals(light.foreground)));
      expect(dark.background, isNot(equals(light.background)));
      expect(dark, isNot(equals(light)));
    });

    test('resolveColor maps CellColor to Flutter Color', () {
      final theme = TerminalTheme.dark();
      expect(
        theme.resolveColor(const DefaultColor(), isForeground: true),
        theme.foreground,
      );
      expect(
        theme.resolveColor(const DefaultColor(), isForeground: false),
        theme.background,
      );
      expect(
        theme.resolveColor(const RgbColor(255, 0, 0), isForeground: true),
        const Color(0xFFFF0000),
      );
      expect(
        theme.resolveColor(const PaletteColor(1), isForeground: true),
        theme.palette[1],
      );
    });

    test('equality compares all fields', () {
      final a = TerminalTheme.dark();
      final b = TerminalTheme.dark();
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(
          equals(
            a.copyWith(
              palette: a.palette.copyWith(foreground: const Color(0xFFFFFFFF)),
            ),
          ),
        ),
      );
      expect(a, isNot(equals(a.copyWith(boldIsBright: true))));
      expect(a, isNot(equals(a.copyWith(boldColor: const Color(0xFF123456)))));
      expect(a, isNot(equals(a.copyWith(faintOpacity: 0.3))));
      expect(a, isNot(equals(a.copyWith(minimumContrast: 4.5))));
      expect(a, isNot(equals(a.copyWith(fontFamilyFallback: ['Menlo']))));
      expect(a, isNot(equals(a.copyWith(backgroundOpacity: 0.5))));
      expect(a, isNot(equals(a.copyWith(backgroundOpacityCells: true))));
      expect(
        a,
        isNot(
          equals(
            a.copyWith(
              selection: const SelectionTheme(
                background: DynamicColor.fixed(Color(0xFFFF0000)),
              ),
            ),
          ),
        ),
      );
    });

    test('copyWith replaces fields and preserves the rest', () {
      final original = TerminalTheme.dark();
      final modified = original.copyWith(
        palette: original.palette.copyWith(foreground: const Color(0xFFFFFFFF)),
        boldIsBright: true,
        faintOpacity: 0.3,
        minimumContrast: 4.5,
        fontFamily: 'Fira Code',
        fontFamilyFallback: const ['Fira Code', 'Menlo'],
        selection: const SelectionTheme(
          foreground: DynamicColor.fixed(Color(0xFF000000)),
        ),
      );
      expect(modified.foreground, const Color(0xFFFFFFFF));
      expect(modified.boldIsBright, isTrue);
      expect(modified.faintOpacity, 0.3);
      expect(modified.minimumContrast, 4.5);
      expect(modified.fontFamilyFallback, ['Fira Code', 'Menlo']);
      expect(modified.background, original.background);
    });

    test('copyWith without palette reuses the same instance', () {
      final original = TerminalTheme.dark();
      final modified = original.copyWith(
        cursor: const CursorTheme(shape: CursorShape.bar),
        hyperlink: const HyperlinkTheme(),
      );
      expect(identical(modified.palette, original.palette), isTrue);
    });

    test('background and foreground delegate to palette', () {
      final theme = TerminalTheme.dark();
      expect(theme.background, theme.palette.background);
      expect(theme.foreground, theme.palette.foreground);
    });

    test('lerp at boundaries returns endpoints', () {
      final dark = TerminalTheme.dark();
      final light = TerminalTheme.light();
      expect(TerminalTheme.lerp(dark, light, 0.0), dark);
      expect(TerminalTheme.lerp(dark, light, 1.0), light);
    });

    test('lerp at midpoint produces intermediate values', () {
      final dark = TerminalTheme.dark();
      final light = TerminalTheme.light();
      final mid = TerminalTheme.lerp(dark, light, 0.5)!;
      expect(mid.foreground, isNot(equals(dark.foreground)));
      expect(mid.foreground, isNot(equals(light.foreground)));
      expect(mid.background, isNot(equals(dark.background)));
      expect(mid.background, isNot(equals(light.background)));
    });

    test('lerp interpolates continuous fields', () {
      final a = TerminalTheme.dark().copyWith(
        faintOpacity: 0.0,
        minimumContrast: 1.0,
        backgroundOpacity: 0.0,
      );
      final b = TerminalTheme.dark().copyWith(
        faintOpacity: 1.0,
        minimumContrast: 7.0,
        backgroundOpacity: 1.0,
      );
      final mid = TerminalTheme.lerp(a, b, 0.5)!;
      expect(mid.faintOpacity, 0.5);
      expect(mid.minimumContrast, 4.0);
      expect(mid.backgroundOpacity, 0.5);
    });

    test('lerp snaps discrete fields at midpoint', () {
      final a = TerminalTheme.dark().copyWith(
        boldIsBright: true,
        fontFamily: 'Menlo',
        fontFamilyFallback: ['Menlo'],
      );
      final b = TerminalTheme.dark().copyWith(
        boldIsBright: false,
        fontFamily: 'Consolas',
        fontFamilyFallback: ['Consolas'],
      );
      expect(TerminalTheme.lerp(a, b, 0.49)!.boldIsBright, isTrue);
      expect(TerminalTheme.lerp(a, b, 0.5)!.boldIsBright, isFalse);
      expect(TerminalTheme.lerp(a, b, 0.49)!.fontFamily, 'Menlo');
      expect(TerminalTheme.lerp(a, b, 0.5)!.fontFamily, 'Consolas');
      expect(TerminalTheme.lerp(a, b, 0.49)!.fontFamilyFallback, ['Menlo']);
      expect(TerminalTheme.lerp(a, b, 0.5)!.fontFamilyFallback, ['Consolas']);

      final c = TerminalTheme.dark().copyWith(backgroundOpacityCells: false);
      final d = TerminalTheme.dark().copyWith(backgroundOpacityCells: true);
      expect(TerminalTheme.lerp(c, d, 0.49)!.backgroundOpacityCells, isFalse);
      expect(TerminalTheme.lerp(c, d, 0.5)!.backgroundOpacityCells, isTrue);
    });

    test('lerp with null returns other at boundary', () {
      final theme = TerminalTheme.dark();
      expect(TerminalTheme.lerp(theme, null, 0.0), theme);
      expect(TerminalTheme.lerp(theme, null, 1.0), isNull);
      expect(TerminalTheme.lerp(null, theme, 0.0), isNull);
      expect(TerminalTheme.lerp(null, theme, 1.0), theme);
    });
  });
}
