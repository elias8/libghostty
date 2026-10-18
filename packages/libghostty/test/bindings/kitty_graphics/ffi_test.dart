@Tags(['ffi'])
library;

import 'package:libghostty/src/bindings/kitty_graphics/ffi.dart';
import 'package:libghostty/src/types/exceptions.dart';
import 'package:test/test.dart';

void main() {
  group('FfiKittyGraphicsBindings', () {
    late FfiKittyGraphicsBindings bindings;

    setUp(() {
      bindings = FfiKittyGraphicsBindings();
    });

    test('propagates errors when reading storage from an invalid terminal', () {
      expect(
        () => bindings.kittyGraphicsGet(const .fromAddress(0)),
        throwsA(isA<InvalidValueException>()),
      );
    });

    test('rejects an invalid graphics handle when looking up images', () {
      expect(
        () => bindings.kittyGraphicsImage(const .fromAddress(0), 1),
        throwsA(isA<InvalidValueException>()),
      );
    });

    test('rejects an invalid graphics handle before native access', () {
      expect(
        () => bindings.kittyGraphicsGetGeneration(const .fromAddress(0)),
        throwsA(isA<InvalidValueException>()),
      );
    });
  });
}
