@Tags(['ffi'])
library;

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

void main() {
  group('pasteIsSafe', () {
    test('rejects unsafe content', () {
      expect(pasteIsSafe('rm -rf /\n'), isFalse);
      expect(pasteIsSafe('\x1b[201~injected'), isFalse);
    });

    test('accepts safe content', () {
      expect(pasteIsSafe(''), isTrue);
      expect(pasteIsSafe('a'), isTrue);
      expect(pasteIsSafe('hello world'), isTrue);
      expect(pasteIsSafe('hello world\ttab'), isTrue);
    });
  });
}
