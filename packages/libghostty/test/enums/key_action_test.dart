import 'package:libghostty/input.dart';
import 'package:test/test.dart';

void main() {
  group('KeyAction', () {
    test('fromNative round-trips for all values', () {
      expect(KeyAction.fromNative(0), KeyAction.release);
      expect(KeyAction.fromNative(1), KeyAction.press);
      expect(KeyAction.fromNative(2), KeyAction.repeat);
    });

    test('nativeValue equals index', () {
      expect(KeyAction.release.nativeValue, 0);
      expect(KeyAction.press.nativeValue, 1);
      expect(KeyAction.repeat.nativeValue, 2);
    });

    test('fromNative defaults to press for unknown values', () {
      expect(KeyAction.fromNative(-1), KeyAction.press);
      expect(KeyAction.fromNative(3), KeyAction.press);
      expect(KeyAction.fromNative(999), KeyAction.press);
    });

    test('nativeValue round-trips for all values', () {
      for (final action in KeyAction.values) {
        expect(KeyAction.fromNative(action.nativeValue), action);
      }
    });
  });
}
