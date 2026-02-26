import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart';
import 'package:libghostty_flutter/foundation.dart';

void main() {
  group('CursorTheme', () {
    test('defaults: block shape, no color, 600ms blink', () {
      const cursor = CursorTheme();
      expect(cursor.shape, CursorShape.block);
      expect(cursor.color, isNull);
      expect(cursor.blinkInterval, const Duration(milliseconds: 600));
    });

    test('stores custom values', () {
      const cursor = CursorTheme(
        shape: CursorShape.bar,
        color: Color(0xFFFF0000),
        blinkInterval: Duration(milliseconds: 500),
      );
      expect(cursor.shape, CursorShape.bar);
      expect(cursor.color, const Color(0xFFFF0000));
      expect(cursor.blinkInterval, const Duration(milliseconds: 500));
    });

    test('equality', () {
      expect(const CursorTheme(), equals(const CursorTheme()));
    });

    test('inequality with different shape', () {
      expect(
        const CursorTheme(),
        isNot(equals(const CursorTheme(shape: CursorShape.bar))),
      );
    });
  });

  group('TerminalTheme', () {
    test('defaults constructs without error', () {
      expect(() => TerminalTheme.defaults, returnsNormally);
    });

    test('defaults has opaque foreground and background', () {
      final theme = TerminalTheme.defaults;
      expect((theme.foreground.a * 255.0).round(), 255);
      expect((theme.background.a * 255.0).round(), 255);
    });

    test('defaults has a 256-color palette', () {
      final theme = TerminalTheme.defaults;
      for (var i = 0; i < 256; i++) {
        expect(() => theme.palette[i], returnsNormally, reason: 'index $i');
      }
    });

    test('resolveColor: DefaultColor foreground returns theme foreground', () {
      final theme = TerminalTheme.defaults;
      expect(
        theme.resolveColor(const DefaultColor(), isForeground: true),
        theme.foreground,
      );
    });

    test('resolveColor: DefaultColor background returns theme background', () {
      final theme = TerminalTheme.defaults;
      expect(
        theme.resolveColor(const DefaultColor(), isForeground: false),
        theme.background,
      );
    });

    test('resolveColor: RgbColor returns the exact color', () {
      final theme = TerminalTheme.defaults;
      expect(
        theme.resolveColor(const RgbColor(255, 0, 0), isForeground: true),
        const Color(0xFFFF0000),
      );
    });

    test('resolveColor: PaletteColor returns palette entry', () {
      final theme = TerminalTheme.defaults;
      expect(
        theme.resolveColor(
          const PaletteColor(NamedColor.red),
          isForeground: true,
        ),
        theme.palette[NamedColor.red],
      );
    });

    test('copyWith changes specific fields', () {
      final original = TerminalTheme.defaults;
      const newFg = Color(0xFFFFFFFF);
      final modified = original.copyWith(foreground: newFg);
      expect(modified.foreground, newFg);
      expect(modified.background, original.background);
      expect(modified.fontFamily, original.fontFamily);
    });

    test('equality with same values', () {
      final a = TerminalTheme.defaults;
      final b = TerminalTheme.defaults;
      expect(a, equals(b));
    });

    test('inequality after copyWith', () {
      final original = TerminalTheme.defaults;
      final modified = original.copyWith(foreground: const Color(0xFFFFFFFF));
      expect(original, isNot(equals(modified)));
    });
  });
}
