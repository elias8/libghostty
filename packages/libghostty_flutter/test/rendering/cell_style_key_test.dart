import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart';
import 'package:libghostty_flutter/src/rendering/cell_style_key.dart';

void main() {
  const fg = Color(0xFFD8D8D8);

  CellStyleKey base({
    bool bold = false,
    bool italic = false,
    bool faint = false,
    bool strikethrough = false,
    bool overline = false,
    UnderlineStyle underline = UnderlineStyle.none,
    Color? underlineColor,
  }) {
    return CellStyleKey(
      bold: bold,
      italic: italic,
      faint: faint,
      strikethrough: strikethrough,
      overline: overline,
      foreground: fg,
      underline: underline,
      underlineColor: underlineColor,
    );
  }

  group('CellStyleKey equality', () {
    test('same attributes produce equal keys', () {
      expect(base(), equals(base()));
    });

    test('same keys have same hashCode', () {
      expect(base().hashCode, equals(base().hashCode));
    });

    test('different bold produces different key', () {
      expect(base(), isNot(equals(base(bold: true))));
    });

    test('different italic produces different key', () {
      expect(base(), isNot(equals(base(italic: true))));
    });

    test('different faint produces different key', () {
      expect(base(), isNot(equals(base(faint: true))));
    });

    test('different foreground produces different key', () {
      const a = CellStyleKey(
        bold: false,
        italic: false,
        faint: false,
        strikethrough: false,
        overline: false,
        foreground: Color(0xFFFF0000),
        underline: UnderlineStyle.none,
      );
      const b = CellStyleKey(
        bold: false,
        italic: false,
        faint: false,
        strikethrough: false,
        overline: false,
        foreground: Color(0xFF0000FF),
        underline: UnderlineStyle.none,
      );
      expect(a, isNot(equals(b)));
    });

    test('different underline style produces different key', () {
      expect(
        base(underline: UnderlineStyle.single),
        isNot(equals(base(underline: UnderlineStyle.doubleLine))),
      );
    });

    test('different underlineColor produces different key', () {
      expect(
        base(
          underline: UnderlineStyle.single,
          underlineColor: const Color(0xFFFF0000),
        ),
        isNot(equals(base(underline: UnderlineStyle.single))),
      );
    });

    test('different strikethrough produces different key', () {
      expect(base(), isNot(equals(base(strikethrough: true))));
    });

    test('different overline produces different key', () {
      expect(base(), isNot(equals(base(overline: true))));
    });
  });

  group('CellStyleKey.buildTextStyle', () {
    const fontFamily = 'monospace';
    const fontSize = 14.0;

    test('plain style has normal weight and upright style', () {
      final ts = base().buildTextStyle(fontFamily, fontSize);
      expect(ts.fontWeight, FontWeight.normal);
      expect(ts.fontStyle, FontStyle.normal);
    });

    test('bold sets FontWeight.bold', () {
      final ts = base(bold: true).buildTextStyle(fontFamily, fontSize);
      expect(ts.fontWeight, FontWeight.bold);
    });

    test('italic sets FontStyle.italic', () {
      final ts = base(italic: true).buildTextStyle(fontFamily, fontSize);
      expect(ts.fontStyle, FontStyle.italic);
    });

    test('no decoration when all flags are false', () {
      final ts = base().buildTextStyle(fontFamily, fontSize);
      expect(ts.decoration, TextDecoration.none);
    });

    test('single underline maps to solid', () {
      final ts = base(
        underline: UnderlineStyle.single,
      ).buildTextStyle(fontFamily, fontSize);
      expect(ts.decoration, containsDecoration(TextDecoration.underline));
      expect(ts.decorationStyle, TextDecorationStyle.solid);
    });

    test('double underline maps to double', () {
      final ts = base(
        underline: UnderlineStyle.doubleLine,
      ).buildTextStyle(fontFamily, fontSize);
      expect(ts.decoration, containsDecoration(TextDecoration.underline));
      expect(ts.decorationStyle, TextDecorationStyle.double);
    });

    test('curly underline maps to wavy', () {
      final ts = base(
        underline: UnderlineStyle.curly,
      ).buildTextStyle(fontFamily, fontSize);
      expect(ts.decoration, containsDecoration(TextDecoration.underline));
      expect(ts.decorationStyle, TextDecorationStyle.wavy);
    });

    test('dotted underline maps to dotted', () {
      final ts = base(
        underline: UnderlineStyle.dotted,
      ).buildTextStyle(fontFamily, fontSize);
      expect(ts.decoration, containsDecoration(TextDecoration.underline));
      expect(ts.decorationStyle, TextDecorationStyle.dotted);
    });

    test('dashed underline maps to dashed', () {
      final ts = base(
        underline: UnderlineStyle.dashed,
      ).buildTextStyle(fontFamily, fontSize);
      expect(ts.decoration, containsDecoration(TextDecoration.underline));
      expect(ts.decorationStyle, TextDecorationStyle.dashed);
    });

    test('strikethrough sets lineThrough', () {
      final ts = base(strikethrough: true).buildTextStyle(fontFamily, fontSize);
      expect(ts.decoration, containsDecoration(TextDecoration.lineThrough));
    });

    test('overline sets overline', () {
      final ts = base(overline: true).buildTextStyle(fontFamily, fontSize);
      expect(ts.decoration, containsDecoration(TextDecoration.overline));
    });

    test('combined underline + strikethrough includes both', () {
      final ts = base(
        underline: UnderlineStyle.single,
        strikethrough: true,
      ).buildTextStyle(fontFamily, fontSize);
      expect(ts.decoration, containsDecoration(TextDecoration.underline));
      expect(ts.decoration, containsDecoration(TextDecoration.lineThrough));
    });

    test('underlineColor sets decorationColor', () {
      final ts = base(
        underline: UnderlineStyle.single,
        underlineColor: const Color(0xFFFF0000),
      ).buildTextStyle(fontFamily, fontSize);
      expect(ts.decorationColor, const Color(0xFFFF0000));
    });

    test('foreground color is applied', () {
      final ts = base().buildTextStyle(fontFamily, fontSize);
      expect(ts.color, fg);
    });

    test('fontFamily and fontSize are applied', () {
      final ts = base().buildTextStyle(fontFamily, fontSize);
      expect(ts.fontFamily, fontFamily);
      expect(ts.fontSize, fontSize);
    });
  });

  group('containsDecoration matcher', () {
    test('none does not contain underline', () {
      expect(
        TextDecoration.none,
        isNot(containsDecoration(TextDecoration.underline)),
      );
    });

    test('underline contains underline', () {
      expect(
        TextDecoration.underline,
        containsDecoration(TextDecoration.underline),
      );
    });
  });
}

Matcher containsDecoration(TextDecoration decoration) {
  return _ContainsDecoration(decoration);
}

final class _ContainsDecoration extends Matcher {
  final TextDecoration _decoration;

  const _ContainsDecoration(this._decoration);

  @override
  Description describe(Description description) {
    return description.add('TextDecoration containing $_decoration');
  }

  @override
  bool matches(Object? item, Map<Object?, Object?> matchState) {
    if (item is! TextDecoration) return false;
    return item.contains(_decoration);
  }
}
