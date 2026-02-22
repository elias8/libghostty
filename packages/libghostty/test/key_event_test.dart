@Tags(['ffi'])
library;

import 'package:libghostty/input.dart';
import 'package:test/test.dart';

void main() {
  group('KeyEvent', () {
    late KeyEvent event;

    setUp(() {
      event = KeyEvent();
    });

    tearDown(() {
      event.dispose();
    });

    test('default action is press', () {
      expect(event.action, KeyAction.press);
    });

    test('set and get action', () {
      event.action = KeyAction.press;
      expect(event.action, KeyAction.press);

      event.action = KeyAction.repeat;
      expect(event.action, KeyAction.repeat);
    });

    test('default key is unidentified', () {
      expect(event.key, Key.unidentified);
    });

    test('set and get key', () {
      event.key = Key.keyA;
      expect(event.key, Key.keyA);

      event.key = Key.arrowUp;
      expect(event.key, Key.arrowUp);
    });

    test('default mods is none', () {
      expect(event.mods, Mods.none);
    });

    test('set and get mods', () {
      event.mods = Mods.ctrl | Mods.shift;
      expect(event.mods.hasCtrl, isTrue);
      expect(event.mods.hasShift, isTrue);
      expect(event.mods.hasAlt, isFalse);
    });

    test('set and get consumed mods', () {
      event.consumedMods = Mods.alt;
      expect(event.consumedMods.hasAlt, isTrue);
      expect(event.consumedMods.hasCtrl, isFalse);
    });

    test('default composing is false', () {
      expect(event.composing, isFalse);
    });

    test('set and get composing', () {
      event.composing = true;
      expect(event.composing, isTrue);
    });

    test('default utf8 is null', () {
      expect(event.utf8, isNull);
    });

    test('set and get utf8', () {
      event.utf8 = 'a';
      expect(event.utf8, 'a');
    });

    test('set utf8 to null', () {
      event.utf8 = 'x';
      event.utf8 = null;
      expect(event.utf8, isNull);
    });

    test('default unshifted codepoint is 0', () {
      expect(event.unshiftedCodepoint, 0);
    });

    test('set and get unshifted codepoint', () {
      event.unshiftedCodepoint = 0x61;
      expect(event.unshiftedCodepoint, 0x61);
    });

    test('can reuse event by changing properties', () {
      event.action = KeyAction.press;
      event.key = Key.keyA;
      expect(event.key, Key.keyA);

      event.key = Key.keyB;
      expect(event.key, Key.keyB);
      expect(event.action, KeyAction.press);
    });
  });
}
