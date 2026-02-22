import 'package:libghostty/parsing.dart';
import 'package:test/test.dart';

void main() {
  group('SgrAttribute', () {
    test('SgrUnset is a valid subtype', () {
      const SgrAttribute attr = SgrUnset();
      expect(attr, isA<SgrUnset>());
    });

    test('SgrUnknown stores parameters', () {
      const attr = SgrUnknown([1, 2], [3]);
      expect(attr.fullParams, [1, 2]);
      expect(attr.partialParams, [3]);
    });

    test('SgrBold is a valid subtype', () {
      const SgrAttribute attr = SgrBold();
      expect(attr, isA<SgrBold>());
    });

    test('SgrForegroundRgb stores color', () {
      const attr = SgrForegroundRgb(RgbColor(255, 128, 64));
      expect(attr.color.r, 255);
      expect(attr.color.g, 128);
      expect(attr.color.b, 64);
    });

    test('SgrBackgroundRgb stores color', () {
      const attr = SgrBackgroundRgb(RgbColor(10, 20, 30));
      expect(attr.color.r, 10);
      expect(attr.color.g, 20);
      expect(attr.color.b, 30);
    });

    test('SgrForeground8 stores palette index', () {
      const attr = SgrForeground8(5);
      expect(attr.index, 5);
    });

    test('SgrBackground8 stores palette index', () {
      const attr = SgrBackground8(7);
      expect(attr.index, 7);
    });

    test('SgrForeground256 stores palette index', () {
      const attr = SgrForeground256(128);
      expect(attr.index, 128);
    });

    test('SgrBackground256 stores palette index', () {
      const attr = SgrBackground256(200);
      expect(attr.index, 200);
    });

    test('SgrUnderline stores style', () {
      const attr = SgrUnderline(UnderlineStyle.curly);
      expect(attr.style, UnderlineStyle.curly);
    });

    test('SgrUnderlineRgb stores color', () {
      const attr = SgrUnderlineRgb(RgbColor(255, 0, 0));
      expect(attr.color, const RgbColor(255, 0, 0));
    });

    test('SgrUnderline256 stores index', () {
      const attr = SgrUnderline256(42);
      expect(attr.index, 42);
    });

    test('sealed class pattern matching covers all subtypes', () {
      String describe(SgrAttribute attr) {
        return switch (attr) {
          SgrUnset() => 'unset',
          SgrUnknown() => 'unknown',
          SgrBold() => 'bold',
          SgrResetBold() => 'reset-bold',
          SgrItalic() => 'italic',
          SgrResetItalic() => 'reset-italic',
          SgrFaint() => 'faint',
          SgrUnderline() => 'underline',
          SgrResetUnderline() => 'reset-underline',
          SgrUnderlineRgb() => 'underline-color',
          SgrUnderline256() => 'underline-color-256',
          SgrResetUnderlineColor() => 'reset-underline-color',
          SgrOverline() => 'overline',
          SgrResetOverline() => 'reset-overline',
          SgrBlink() => 'blink',
          SgrResetBlink() => 'reset-blink',
          SgrInverse() => 'inverse',
          SgrResetInverse() => 'reset-inverse',
          SgrInvisible() => 'invisible',
          SgrResetInvisible() => 'reset-invisible',
          SgrStrikethrough() => 'strikethrough',
          SgrResetStrikethrough() => 'reset-strikethrough',
          SgrForegroundRgb() => 'direct-fg',
          SgrBackgroundRgb() => 'direct-bg',
          SgrForeground8() => 'fg8',
          SgrBackground8() => 'bg8',
          SgrResetForeground() => 'reset-fg',
          SgrResetBackground() => 'reset-bg',
          SgrBrightForeground8() => 'bright-fg8',
          SgrBrightBackground8() => 'bright-bg8',
          SgrForeground256() => 'fg256',
          SgrBackground256() => 'bg256',
        };
      }

      expect(describe(const SgrBold()), 'bold');
      expect(describe(const SgrForegroundRgb(RgbColor(0, 0, 0))), 'direct-fg');
      expect(describe(const SgrForeground256(100)), 'fg256');
      expect(describe(const SgrUnderline(UnderlineStyle.single)), 'underline');
    });
  });
}
