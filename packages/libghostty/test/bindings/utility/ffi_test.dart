@Tags(['ffi'])
library;

import 'package:libghostty/src/bindings/utility/ffi.dart';
import 'package:libghostty/src/generated/libghostty_enums.g.dart';
import 'package:libghostty/src/types/color.dart';
import 'package:libghostty/src/types/exceptions.dart';
import 'package:libghostty/src/types/render.dart';
import 'package:test/test.dart';

void main() {
  group('FfiUtilityBindings', () {
    late FfiUtilityBindings bindings;

    setUp(() {
      bindings = const FfiUtilityBindings();
    });

    test('returns the native default palette and parses colors', () {
      final palette = bindings.colorPaletteDefault();

      expect(palette, hasLength(256));
      expect(palette.first, isA<RgbColor>());
      expect(bindings.colorParse('#102030'), const RgbColor(16, 32, 48));
    });

    test('preserves explicitly skipped palette entries across the mask', () {
      final base = List.generate(
        256,
        (index) => RgbColor(index, (index * 3) % 256, 255 - index),
      );

      final palette = bindings.colorPaletteGenerate(
        base: base,
        skip: {31, 32, 63, 64, 127, 128, 191, 192, 255},
        background: const RgbColor(0, 0, 0),
        foreground: const RgbColor(255, 255, 255),
        harmonious: true,
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

    test('maps invalid color results to the typed exception', () {
      expect(
        () => bindings.colorParse('not-a-color'),
        throwsA(isA<InvalidValueException>()),
      );
    });

    test('preserves Unicode width and paste encoding behavior', () {
      expect(bindings.unicodeCodepointWidth('界'.runes.single), 2);
      expect(bindings.unicodeGraphemeWidth('A'.runes.toList()), (
        consumed: 1,
        width: 1,
      ));
      expect(bindings.pasteEncode('hello', bracketed: true), [
        27,
        91,
        50,
        48,
        48,
        126,
        104,
        101,
        108,
        108,
        111,
        27,
        91,
        50,
        48,
        49,
        126,
      ]);
    });

    test('recognizes every non-default style attribute and color', () {
      const styles = [
        Style(bold: true),
        Style(italic: true),
        Style(faint: true),
        Style(blink: true),
        Style(inverse: true),
        Style(invisible: true),
        Style(strikethrough: true),
        Style(overline: true),
        Style(underline: SgrUnderline.curly),
        Style(foreground: PaletteColor(0)),
        Style(background: RgbColor(1, 2, 3)),
        Style(underlineColor: PaletteColor(3)),
      ];
      for (final style in styles) {
        expect(bindings.styleIsDefault(style), isFalse, reason: '$style');
      }
    });

    test('encodes terminal size reports', () {
      expect(
        bindings.sizeReportEncode(SizeReportStyle.csi18T, 24, 80, 9, 18),
        '\x1b[8;24;80t',
      );
    });

    test('round trips the default style and reports build information', () {
      final style = bindings.styleDefault();

      expect(bindings.styleIsDefault(style), isTrue);
      expect(bindings.buildInfoBool(BuildInfo.simd), isA<bool>());
      expect(bindings.buildInfoString(BuildInfo.versionString), isNotEmpty);
    });
  });
}
