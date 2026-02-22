import 'package:libghostty/input.dart';
import 'package:test/test.dart';

void main() {
  group('Key', () {
    test('fromNative round-trips for first value', () {
      expect(Key.fromNative(0), Key.unidentified);
      expect(Key.unidentified.nativeValue, 0);
    });

    test('fromNative round-trips for last value', () {
      final lastIndex = Key.values.length - 1;
      expect(Key.fromNative(lastIndex), Key.paste);
      expect(Key.paste.nativeValue, lastIndex);
    });

    test('fromNative round-trips for representative values', () {
      expect(Key.fromNative(Key.keyA.nativeValue), Key.keyA);
      expect(Key.fromNative(Key.enter.nativeValue), Key.enter);
      expect(Key.fromNative(Key.f1.nativeValue), Key.f1);
      expect(Key.fromNative(Key.arrowUp.nativeValue), Key.arrowUp);
      expect(Key.fromNative(Key.space.nativeValue), Key.space);
    });

    test('fromNative returns unidentified for negative value', () {
      expect(Key.fromNative(-1), Key.unidentified);
    });

    test('fromNative returns unidentified for out-of-bounds value', () {
      expect(Key.fromNative(Key.values.length), Key.unidentified);
      expect(Key.fromNative(999), Key.unidentified);
    });

    test('nativeValue equals index for all values', () {
      for (final key in Key.values) {
        expect(key.nativeValue, key.index);
      }
    });

    test('fromNative round-trips for all values', () {
      for (final key in Key.values) {
        expect(Key.fromNative(key.nativeValue), key);
      }
    });
  });
}
