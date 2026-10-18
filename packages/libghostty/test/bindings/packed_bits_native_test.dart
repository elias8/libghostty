@TestOn('vm')
library;

import 'package:libghostty/src/bindings/packed_bits_native.dart' as bits;
import 'package:test/test.dart';

void main() {
  group('extract', () {
    test('extracts unsigned fields from a negative native cell', () {
      expect(bits.extract((-1 << 63) | 0x1f642, 0, 1, 2097152), 128578);
      expect(bits.extract(-1, 48, 281474976710656, 65536), 65535);
    });
  });
}
