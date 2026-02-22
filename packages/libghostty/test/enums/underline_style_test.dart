import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

void main() {
  group('UnderlineStyle', () {
    test('fromNative round-trips for all values', () {
      for (final style in UnderlineStyle.values) {
        expect(UnderlineStyle.fromNative(style.index), style);
      }
    });

    test('fromNative returns none for negative value', () {
      expect(UnderlineStyle.fromNative(-1), UnderlineStyle.none);
    });

    test('fromNative returns none for out-of-bounds value', () {
      expect(
        UnderlineStyle.fromNative(UnderlineStyle.values.length),
        UnderlineStyle.none,
      );
      expect(UnderlineStyle.fromNative(999), UnderlineStyle.none);
    });

    test('expected values at expected indices', () {
      expect(UnderlineStyle.fromNative(0), UnderlineStyle.none);
      expect(UnderlineStyle.fromNative(1), UnderlineStyle.single);
      expect(UnderlineStyle.fromNative(2), UnderlineStyle.doubleLine);
      expect(UnderlineStyle.fromNative(3), UnderlineStyle.curly);
      expect(UnderlineStyle.fromNative(4), UnderlineStyle.dotted);
      expect(UnderlineStyle.fromNative(5), UnderlineStyle.dashed);
    });
  });
}
