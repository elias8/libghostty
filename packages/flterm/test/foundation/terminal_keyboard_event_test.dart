import 'package:flterm/src/foundation/terminal_keyboard_event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart';

void main() {
  group('TerminalKeyboardEvent', () {
    test('stores normalized terminal input', () {
      const event = TerminalKeyboardEvent(
        key: Key.a,
        action: KeyAction.press,
        mods: Mods.shift(),
        consumedMods: Mods.shift(),
        text: 'A',
        unshiftedCodepoint: 0x61,
        composing: true,
        deferToTextInput: true,
      );

      expect(event.key, Key.a);
      expect(event.action, KeyAction.press);
      expect(event.mods.hasShift, isTrue);
      expect(event.consumedMods.hasShift, isTrue);
      expect(event.text, 'A');
      expect(event.unshiftedCodepoint, 0x61);
      expect(event.composing, isTrue);
      expect(event.deferToTextInput, isTrue);
    });

    test('copyWith replaces and clears fields', () {
      const event = TerminalKeyboardEvent(
        key: Key.a,
        action: KeyAction.press,
        mods: Mods.none(),
        text: 'a',
        unshiftedCodepoint: 0x61,
      );

      final copy = event.copyWith(
        key: Key.b,
        action: KeyAction.repeat,
        clearText: true,
        unshiftedCodepoint: 0x62,
      );

      expect(copy.key, Key.b);
      expect(copy.action, KeyAction.repeat);
      expect(copy.text, isNull);
      expect(copy.unshiftedCodepoint, 0x62);
      expect(copy.mods.isEmpty, isTrue);
    });
  });
}
