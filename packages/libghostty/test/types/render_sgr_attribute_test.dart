import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

void main() {
  group('SgrAttribute', () {
    group('constructor', () {
      test('stores optional fields', () {
        const unknown = SgrAttribute(
          tag: SgrAttributeTag.unknown,
          unknownFull: [1, 2],
          unknownPartial: [3],
        );
        expect(unknown.unknownFull, [1, 2]);
        expect(unknown.unknownPartial, [3]);

        const color = SgrAttribute(
          tag: SgrAttributeTag.directColorFg,
          color: RgbColor(255, 128, 64),
        );
        expect(color.color, const RgbColor(255, 128, 64));

        const palette = SgrAttribute(tag: SgrAttributeTag.fg8, paletteIndex: 5);
        expect(palette.paletteIndex, 5);

        const underline = SgrAttribute(
          tag: SgrAttributeTag.underline,
          underlineStyle: SgrUnderline.curly,
        );
        expect(underline.underlineStyle, SgrUnderline.curly);
      });
    });
  });
}
