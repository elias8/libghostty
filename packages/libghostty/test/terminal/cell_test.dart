@Tags(['ffi'])
library;

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

void main() {
  group('CellColor', () {
    test('DefaultColor equality', () {
      expect(const DefaultColor(), equals(const DefaultColor()));
    });

    test('PaletteColor equality', () {
      expect(const PaletteColor(1), equals(const PaletteColor(1)));
      expect(const PaletteColor(1), isNot(equals(const PaletteColor(2))));
    });

    test('RgbColor equality', () {
      expect(const RgbColor(10, 20, 30), equals(const RgbColor(10, 20, 30)));
      expect(
        const RgbColor(10, 20, 30),
        isNot(equals(const RgbColor(10, 20, 31))),
      );
    });

    test('different subtypes are not equal', () {
      expect(const DefaultColor(), isNot(equals(const PaletteColor(0))));
      expect(const PaletteColor(0), isNot(equals(const RgbColor(0, 0, 0))));
    });

    test('pattern matching works on sealed type', () {
      const CellColor color = RgbColor(100, 150, 200);
      final result = switch (color) {
        DefaultColor() => 'default',
        PaletteColor(index: final i) => 'palette:$i',
        RgbColor(:final r, :final g, :final b) => 'rgb:$r,$g,$b',
      };
      expect(result, 'rgb:100,150,200');
    });

    test('PaletteColor toString', () {
      expect(const PaletteColor(42).toString(), contains('42'));
    });

    test('RgbColor toString', () {
      expect(const RgbColor(10, 20, 30).toString(), contains('10'));
    });
  });

  group('CellStyle', () {
    test('default style has no attributes set', () {
      const style = CellStyle();
      expect(style.bold, isFalse);
      expect(style.italic, isFalse);
      expect(style.faint, isFalse);
      expect(style.strikethrough, isFalse);
      expect(style.blink, isFalse);
      expect(style.inverse, isFalse);
      expect(style.invisible, isFalse);
      expect(style.overline, isFalse);
      expect(style.underline, UnderlineStyle.none);
    });

    test('equality with same attributes', () {
      const a = CellStyle(bold: true, italic: true);
      const b = CellStyle(bold: true, italic: true);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality with different attributes', () {
      const a = CellStyle(bold: true);
      const b = CellStyle(italic: true);
      expect(a, isNot(equals(b)));
    });

    test('copyWith preserves unchanged fields', () {
      const original = CellStyle(bold: true, italic: true);
      final modified = original.copyWith(faint: true);
      expect(modified.bold, isTrue);
      expect(modified.italic, isTrue);
      expect(modified.faint, isTrue);
    });

    test('copyWith overrides specified fields', () {
      const original = CellStyle(bold: true);
      final modified = original.copyWith(bold: false, italic: true);
      expect(modified.bold, isFalse);
      expect(modified.italic, isTrue);
    });

    test('all style flags', () {
      const style = CellStyle(
        bold: true,
        italic: true,
        faint: true,
        strikethrough: true,
        blink: true,
        inverse: true,
        invisible: true,
        overline: true,
        underline: UnderlineStyle.curly,
      );
      expect(style.bold, isTrue);
      expect(style.italic, isTrue);
      expect(style.faint, isTrue);
      expect(style.strikethrough, isTrue);
      expect(style.blink, isTrue);
      expect(style.inverse, isTrue);
      expect(style.invisible, isTrue);
      expect(style.overline, isTrue);
      expect(style.underline, UnderlineStyle.curly);
    });
  });

  group('Cell', () {
    test('empty cell', () {
      const cell = Cell.empty;
      expect(cell.content, '');
      expect(cell.isEmpty, isTrue);
      expect(cell.foreground, isA<DefaultColor>());
      expect(cell.background, isA<DefaultColor>());
      expect(cell.style, const CellStyle());
      expect(cell.hyperlink, isNull);
      expect(cell.isWide, isFalse);
    });

    test('cell with content', () {
      const cell = Cell(content: 'A');
      expect(cell.content, 'A');
      expect(cell.isEmpty, isFalse);
    });

    test('wide character cell', () {
      const cell = Cell(content: '\u{4e16}', isWide: true);
      expect(cell.isWide, isTrue);
      expect(cell.content, '\u{4e16}');
    });

    test('cell equality', () {
      const a = Cell(
        content: 'A',
        foreground: PaletteColor(1),
        style: CellStyle(bold: true),
      );
      const b = Cell(
        content: 'A',
        foreground: PaletteColor(1),
        style: CellStyle(bold: true),
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('cell inequality on content', () {
      const a = Cell(content: 'A');
      const b = Cell(content: 'B');
      expect(a, isNot(equals(b)));
    });

    test('cell inequality on style', () {
      const a = Cell(content: 'A', style: CellStyle(bold: true));
      const b = Cell(content: 'A', style: CellStyle(italic: true));
      expect(a, isNot(equals(b)));
    });

    test('cell inequality on color', () {
      const a = Cell(content: 'A', foreground: PaletteColor(1));
      const b = Cell(content: 'A', foreground: PaletteColor(2));
      expect(a, isNot(equals(b)));
    });

    test('cell with hyperlink', () {
      const cell = Cell(content: 'link', hyperlink: 'https://example.com');
      expect(cell.hyperlink, 'https://example.com');
    });

    test('cell with underline color', () {
      const cell = Cell(content: 'A', underlineColor: RgbColor(255, 0, 0));
      expect(cell.underlineColor, const RgbColor(255, 0, 0));
    });
  });
}
