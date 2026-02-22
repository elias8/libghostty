import 'package:libghostty/input.dart';
import 'package:test/test.dart';

void main() {
  group('OptionAsAlt', () {
    test('nativeValue equals index for all values', () {
      for (final option in OptionAsAlt.values) {
        expect(option.nativeValue, option.index);
      }
    });

    test('expected values at expected indices', () {
      expect(OptionAsAlt.none.nativeValue, 0);
      expect(OptionAsAlt.both.nativeValue, 1);
      expect(OptionAsAlt.left.nativeValue, 2);
      expect(OptionAsAlt.right.nativeValue, 3);
    });
  });
}
