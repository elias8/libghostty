import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

import '../helpers/setup.dart';

void main() {
  setUp(() => testEnvironment);

  group('SgrParser', () {
    late SgrParser parser;

    Matcher hasTag(SgrAttributeTag tag) {
      return predicate<SgrAttribute>((a) => a.tag == tag, 'has tag $tag');
    }

    setUp(() => parser = SgrParser());

    tearDown(() => parser.dispose());

    group('parse', () {
      test('rejects mismatched separator lengths and remains usable', () {
        for (final separators in <List<String>>[
          [],
          [';', ';'],
        ]) {
          expect(
            () => parser.parse([1], separators: separators),
            throwsArgumentError,
          );
        }
        expect(parser.parse([1]).single, hasTag(SgrAttributeTag.bold));
      });

      test('rejects invalid separators', () {
        for (final separator in ['', ',', ';;']) {
          expect(
            () => parser.parse([1], separators: [separator]),
            throwsArgumentError,
          );
        }
      });

      test('rejects parameters outside the native uint16 range', () {
        for (final parameter in [-1, 65536]) {
          expect(() => parser.parse([parameter]), throwsRangeError);
        }
        expect(parser.parse([1]).single, hasTag(SgrAttributeTag.bold));
      });

      test('returns simple attributes', () {
        final bold = parser.parse([1]);
        expect(bold, hasLength(1));
        expect(bold.first, hasTag(SgrAttributeTag.bold));

        final italic = parser.parse([3]);
        expect(italic, hasLength(1));
        expect(italic.first, hasTag(SgrAttributeTag.italic));

        final reset = parser.parse([0]);
        expect(reset, hasLength(1));
        expect(reset.first, hasTag(SgrAttributeTag.unset));

        final strikethrough = parser.parse([9]);
        expect(strikethrough, hasLength(1));
        expect(strikethrough.first, hasTag(SgrAttributeTag.strikethrough));

        final inverse = parser.parse([7]);
        expect(inverse, hasLength(1));
        expect(inverse.first, hasTag(SgrAttributeTag.inverse));
      });

      test('returns color attributes', () {
        final foreground = parser.parse([38, 2, 51, 102, 153]);
        expect(foreground, hasLength(1));
        expect(foreground.first, hasTag(SgrAttributeTag.directColorFg));
        expect(foreground.first.color, const RgbColor(51, 102, 153));

        final background = parser.parse([48, 2, 10, 20, 30]);
        expect(background, hasLength(1));
        expect(background.first, hasTag(SgrAttributeTag.directColorBg));
        expect(background.first.color, const RgbColor(10, 20, 30));

        final palette = parser.parse([38, 5, 196]);
        expect(palette, hasLength(1));
        expect(palette.first, hasTag(SgrAttributeTag.fg256));
        expect(palette.first.paletteIndex, 196);
      });

      test('returns adjacent bold and palette foreground attributes', () {
        final attrs = parser.parse([1, 31]);
        expect(attrs, hasLength(2));
        expect(attrs[0], hasTag(SgrAttributeTag.bold));
        expect(attrs[1], hasTag(SgrAttributeTag.fg8));
        expect(attrs[1].paletteIndex, const NamedColor.red());
      });

      test('returns curly underline with colon separator', () {
        final attrs = parser.parse([4, 3], separators: [':', ';']);
        expect(attrs, hasLength(1));
        expect(attrs.first, hasTag(SgrAttributeTag.underline));
        expect(attrs.first.underlineStyle, UnderlineStyle.curly);
      });

      test('returns colon underline before RGB foreground', () {
        final attrs = parser.parse(
          [4, 3, 38, 2, 51, 51, 51],
          separators: [':', ';', ';', ';', ';', ';', ';'],
        );
        expect(attrs, hasLength(2));
        expect(attrs[0], hasTag(SgrAttributeTag.underline));
        expect(attrs[0].underlineStyle, UnderlineStyle.curly);
        expect(attrs[1], hasTag(SgrAttributeTag.directColorFg));
        expect(attrs[1].color, const RgbColor(51, 51, 51));
      });

      test('can be called repeatedly', () {
        final first = parser.parse([1]);
        expect(first.first, hasTag(SgrAttributeTag.bold));

        final second = parser.parse([3]);
        expect(second.first, hasTag(SgrAttributeTag.italic));
      });
    });

    group('dispose', () {
      test('is idempotent', () {
        parser.dispose();

        parser.dispose();
      });

      test('rejects all operations after disposal', () {
        parser.dispose();

        expect(() => parser.reset(), throwsStateError);
        expect(() => parser.parse(const [0]), throwsStateError);
      });
    });
  });
}
