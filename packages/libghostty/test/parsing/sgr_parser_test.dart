@Tags(['ffi'])
library;

import 'package:libghostty/parsing.dart';
import 'package:test/test.dart';

void main() {
  group('SgrParser', () {
    late SgrParser parser;

    setUp(() {
      parser = SgrParser();
    });

    tearDown(() {
      parser.dispose();
    });

    test('parses bold', () {
      final attrs = parser.parse([1]);
      expect(attrs, hasLength(1));
      expect(attrs.first, isA<SgrBold>());
    });

    test('parses bold and red foreground', () {
      final attrs = parser.parse([1, 31]);
      expect(attrs, hasLength(2));
      expect(attrs[0], isA<SgrBold>());
      expect(attrs[1], isA<SgrForeground8>());
      final fg = attrs[1] as SgrForeground8;
      expect(fg.index, NamedColor.red);
    });

    test('parses italic', () {
      final attrs = parser.parse([3]);
      expect(attrs, hasLength(1));
      expect(attrs.first, isA<SgrItalic>());
    });

    test('parses reset (SGR 0)', () {
      final attrs = parser.parse([0]);
      expect(attrs, hasLength(1));
      expect(attrs.first, isA<SgrUnset>());
    });

    test('parses RGB foreground color', () {
      final attrs = parser.parse([38, 2, 51, 102, 153]);
      expect(attrs, hasLength(1));
      expect(attrs.first, isA<SgrForegroundRgb>());
      final fg = attrs.first as SgrForegroundRgb;
      expect(fg.color, const RgbColor(51, 102, 153));
    });

    test('parses RGB background color', () {
      final attrs = parser.parse([48, 2, 10, 20, 30]);
      expect(attrs, hasLength(1));
      expect(attrs.first, isA<SgrBackgroundRgb>());
      final bg = attrs.first as SgrBackgroundRgb;
      expect(bg.color, const RgbColor(10, 20, 30));
    });

    test('parses 256-color foreground', () {
      final attrs = parser.parse([38, 5, 196]);
      expect(attrs, hasLength(1));
      expect(attrs.first, isA<SgrForeground256>());
      expect((attrs.first as SgrForeground256).index, 196);
    });

    test('parses curly underline with colon separator', () {
      final attrs = parser.parse([4, 3], separators: [':', ';']);
      expect(attrs, hasLength(1));
      expect(attrs.first, isA<SgrUnderline>());
      final ul = attrs.first as SgrUnderline;
      expect(ul.style, UnderlineStyle.curly);
    });

    test('parses complex styling: curly underline + RGB foreground', () {
      final attrs = parser.parse(
        [4, 3, 38, 2, 51, 51, 51],
        separators: [':', ';', ';', ';', ';', ';', ';'],
      );
      expect(attrs.length, greaterThanOrEqualTo(2));

      final underline = attrs.whereType<SgrUnderline>().firstOrNull;
      expect(underline, isNotNull);
      expect(underline!.style, UnderlineStyle.curly);

      final fg = attrs.whereType<SgrForegroundRgb>().firstOrNull;
      expect(fg, isNotNull);
      expect(fg!.color, const RgbColor(51, 51, 51));
    });

    test('parses strikethrough', () {
      final attrs = parser.parse([9]);
      expect(attrs, hasLength(1));
      expect(attrs.first, isA<SgrStrikethrough>());
    });

    test('parses inverse', () {
      final attrs = parser.parse([7]);
      expect(attrs, hasLength(1));
      expect(attrs.first, isA<SgrInverse>());
    });

    test('parser can be reused', () {
      final first = parser.parse([1]);
      expect(first.first, isA<SgrBold>());

      final second = parser.parse([3]);
      expect(second.first, isA<SgrItalic>());
    });
  });
}
