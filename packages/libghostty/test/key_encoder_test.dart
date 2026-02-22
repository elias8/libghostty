@Tags(['ffi'])
library;

import 'package:libghostty/input.dart';
import 'package:test/test.dart';

void main() {
  group('KeyEncoder', () {
    late KeyEncoder encoder;
    late KeyEvent event;

    setUp(() {
      encoder = KeyEncoder();
      event = KeyEvent();
    });

    tearDown(() {
      event.dispose();
      encoder.dispose();
    });

    test('encodes Ctrl+C as ETX byte', () {
      event.action = KeyAction.press;
      event.key = Key.keyC;
      event.mods = Mods.ctrl;

      final result = encoder.encode(event);
      expect(result, isNotEmpty);
      expect(result.codeUnitAt(0), 0x03);
    });

    test('encodes Enter as carriage return', () {
      event.action = KeyAction.press;
      event.key = Key.enter;

      final result = encoder.encode(event);
      expect(result, isNotEmpty);
      expect(result.codeUnitAt(0), 0x0D);
    });

    test('encodes Escape key', () {
      event.action = KeyAction.press;
      event.key = Key.escape;

      final result = encoder.encode(event);
      expect(result, isNotEmpty);
      expect(result.codeUnitAt(0), 0x1B);
    });

    test('encodes with Kitty protocol flags', () {
      encoder.setKittyFlags(KittyKeyFlags.all);

      event.action = KeyAction.press;
      event.key = Key.keyC;
      event.mods = Mods.ctrl;
      event.utf8 = 'c';
      event.unshiftedCodepoint = 0x63;

      final result = encoder.encode(event);
      expect(result, isNotEmpty);
      expect(result, contains('['));
    });

    test('modifier-only key produces no output without Kitty flags', () {
      event.action = KeyAction.press;
      event.key = Key.shiftLeft;

      final result = encoder.encode(event);
      expect(result, isEmpty);
    });

    test('cursor key application mode changes arrow encoding', () {
      encoder.setCursorKeyApplication(enabled: true);

      event.action = KeyAction.press;
      event.key = Key.arrowUp;

      final result = encoder.encode(event);
      expect(result, contains('O'));
    });

    test('cursor key normal mode for arrows', () {
      event.action = KeyAction.press;
      event.key = Key.arrowUp;

      final result = encoder.encode(event);
      expect(result, contains('['));
    });

    test('all encoder options can be set without error', () {
      encoder.setCursorKeyApplication(enabled: true);
      encoder.setKeypadKeyApplication(enabled: true);
      encoder.setIgnoreKeypadWithNumLock(enabled: true);
      encoder.setAltEscPrefix(enabled: true);
      encoder.setModifyOtherKeys(enabled: true);
      encoder.setKittyFlags(KittyKeyFlags.disambiguate);
      encoder.setOptionAsAlt(OptionAsAlt.both);
    });
  });
}
