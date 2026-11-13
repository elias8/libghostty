import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

void main() {
  group('CursorStyle', () {
    group('values', () {
      test('contains supported shapes', () {
        expect(
          CursorStyle.values,
          containsAll([
            CursorStyle.block,
            CursorStyle.underline,
            CursorStyle.bar,
            CursorStyle.blockHollow,
          ]),
        );
      });
    });
  });

  group('RenderStateCursor', () {
    RenderStateCursor create({int viewportY = 5, bool visible = true}) =>
        RenderStateCursor(
          viewportHasValue: true,
          viewportX: 10,
          viewportY: viewportY,
          visible: visible,
          visualStyle: .bar,
        );

    group('constructor', () {
      test('retains viewport presence independently of its coordinates', () {
        const cursor = RenderStateCursor();

        expect(cursor.viewportHasValue, isFalse);
      });
    });

    group('equality', () {
      test('compares by value', () {
        final first = create();
        final second = create();

        expect(first, second);
      });

      test('produces equal hashes for equal values', () {
        final first = create();
        final second = create();

        expect(first.hashCode, second.hashCode);
      });

      test('distinguishes changed properties', () {
        final base = create();

        expect(base, isNot(create(viewportY: 6)));
        expect(base, isNot(create(visible: false)));
      });
    });

    group('copyWith', () {
      test('overrides selected fields', () {
        const cursor = RenderStateCursor(
          viewportHasValue: true,
          viewportX: 10,
          viewportY: 5,
          visualStyle: .bar,
        );

        final moved = cursor.copyWith(viewportX: 11, viewportY: 6);

        expect(moved.viewportX, 11);
        expect(moved.viewportY, 6);
        expect(moved.visualStyle, CursorStyle.bar);
        expect(moved.visible, isTrue);
      });
    });
  });

  group('Style', () {
    Style create({bool bold = true}) =>
        Style(bold: bold, foreground: const RgbColor(1, 2, 3));

    group('constructor', () {
      test('initializes default state', () {
        const style = Style();

        expect(style.bold, isFalse);
        expect(style.italic, isFalse);
        expect(style.faint, isFalse);
        expect(style.blink, isFalse);
        expect(style.inverse, isFalse);
        expect(style.overline, isFalse);
        expect(style.invisible, isFalse);
        expect(style.strikethrough, isFalse);
        expect(style.foreground, isA<DefaultColor>());
        expect(style.background, isA<DefaultColor>());
        expect(style.underlineColor, isNull);
        expect(style.underline, SgrUnderline.none);
      });
    });

    group('equality', () {
      test('compares equal values structurally', () {
        final first = create();
        final second = create();

        expect(first, second);
      });

      test('produces equal hashes for equal values', () {
        final first = create();
        final second = create();

        expect(first.hashCode, second.hashCode);
      });

      test('distinguishes changed values', () {
        final first = create();
        final second = create(bold: false);

        expect(first, isNot(second));
      });
    });
  });
}
