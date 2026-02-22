import 'package:libghostty/parsing.dart';
import 'package:test/test.dart';

void main() {
  group('OscCommandType', () {
    test('fromNative round-trips for all values', () {
      for (final type in OscCommandType.values) {
        expect(OscCommandType.fromNative(type.index), type);
      }
    });

    test('fromNative returns invalid for negative value', () {
      expect(OscCommandType.fromNative(-1), OscCommandType.invalid);
    });

    test('fromNative returns invalid for out-of-bounds value', () {
      expect(
        OscCommandType.fromNative(OscCommandType.values.length),
        OscCommandType.invalid,
      );
      expect(OscCommandType.fromNative(999), OscCommandType.invalid);
    });

    test('expected values at expected indices', () {
      expect(OscCommandType.fromNative(0), OscCommandType.invalid);
      expect(
        OscCommandType.fromNative(1),
        OscCommandType.changeWindowTitle,
      );
      expect(
        OscCommandType.fromNative(2),
        OscCommandType.changeWindowIcon,
      );
    });

    test('last value is at expected index', () {
      final lastIndex = OscCommandType.values.length - 1;
      expect(
        OscCommandType.fromNative(lastIndex),
        OscCommandType.kittyTextSizing,
      );
    });
  });
}
