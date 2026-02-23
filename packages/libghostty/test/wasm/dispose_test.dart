@Tags(['wasm'])
library;

import 'package:libghostty/input.dart';
import 'package:libghostty/parsing.dart';
import 'package:test/test.dart';

import 'helpers/setup.dart';

void main() {
  setUpAll(setUpWasm);

  group('dispose', () {
    test('KeyEvent: use after dispose throws DisposedException', () {
      final event = KeyEvent();
      event.dispose();
      expect(() => event.action, throwsA(isA<DisposedException>()));
    });

    test('KeyEvent: double dispose is safe', () {
      final event = KeyEvent();
      event.dispose();
      event.dispose();
    });

    test('KeyEncoder: use after dispose throws DisposedException', () {
      final encoder = KeyEncoder();
      encoder.dispose();
      expect(
        () => encoder.setCursorKeyApplication(enabled: true),
        throwsA(isA<DisposedException>()),
      );
    });

    test('KeyEncoder: double dispose is safe', () {
      final encoder = KeyEncoder();
      encoder.dispose();
      encoder.dispose();
    });

    test('OscParser: use after dispose throws DisposedException', () {
      final parser = OscParser();
      parser.dispose();
      expect(() => parser.feedByte(0), throwsA(isA<DisposedException>()));
    });

    test('OscParser: double dispose is safe', () {
      final parser = OscParser();
      parser.dispose();
      parser.dispose();
    });

    test('SgrParser: use after dispose throws DisposedException', () {
      final parser = SgrParser();
      parser.dispose();
      expect(() => parser.parse([1]), throwsA(isA<DisposedException>()));
    });

    test('SgrParser: double dispose is safe', () {
      final parser = SgrParser();
      parser.dispose();
      parser.dispose();
    });
  });
}
