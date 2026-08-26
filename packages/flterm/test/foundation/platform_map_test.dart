import 'package:flterm/src/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart' show Key, Mods;

void main() {
  group('PlatformMap', () {
    group('keyFromPhysical', () {
      test('maps physical keys to libghostty keys', () {
        expect(keyFromPhysical(.keyA), Key.a);
        expect(keyFromPhysical(.keyZ), Key.z);
        expect(keyFromPhysical(.digit0), Key.digit0);
        expect(keyFromPhysical(.digit9), Key.digit9);
        expect(keyFromPhysical(.arrowUp), Key.arrowUp);
        expect(keyFromPhysical(.arrowDown), Key.arrowDown);
        expect(keyFromPhysical(.f1), Key.f1);
        expect(keyFromPhysical(.f24), Key.f24);
        expect(keyFromPhysical(.shiftLeft), Key.shiftLeft);
        expect(keyFromPhysical(.controlLeft), Key.controlLeft);
        expect(keyFromPhysical(.altLeft), Key.altLeft);
        expect(keyFromPhysical(.metaLeft), Key.metaLeft);
        expect(keyFromPhysical(.enter), Key.enter);
        expect(keyFromPhysical(.backspace), Key.backspace);
        expect(keyFromPhysical(.tab), Key.tab);
        expect(keyFromPhysical(.space), Key.space);
        expect(keyFromPhysical(.escape), Key.escape);
        expect(keyFromPhysical(.home), Key.home);
        expect(keyFromPhysical(.end), Key.end);
        expect(keyFromPhysical(.pageUp), Key.pageUp);
        expect(keyFromPhysical(.delete), Key.delete);
        expect(keyFromPhysical(.numpad0), Key.numpad0);
        expect(keyFromPhysical(.numpadEnter), Key.numpadEnter);
        expect(keyFromPhysical(.comma), Key.comma);
        expect(keyFromPhysical(.semicolon), Key.semicolon);
        expect(keyFromPhysical(.backquote), Key.backquote);
      });

      test('returns unidentified for unmapped keys', () {
        final unknown =
            PhysicalKeyboardKey.findKeyByCode(0x999999) ??
            const PhysicalKeyboardKey(0x999999);
        expect(keyFromPhysical(unknown), Key.unidentified);
      });
    });

    group('keyFromCodepoint', () {
      test('maps ASCII codepoints to keys', () {
        expect(keyFromCodepoint(0x61), Key.a);
        expect(keyFromCodepoint(0x7a), Key.z);
        expect(keyFromCodepoint(0x41), Key.a);
        expect(keyFromCodepoint(0x5a), Key.z);
        expect(keyFromCodepoint(0x30), Key.digit0);
        expect(keyFromCodepoint(0x39), Key.digit9);
        expect(keyFromCodepoint(0x20), Key.space);
        expect(keyFromCodepoint(0x5b), Key.bracketLeft);
        expect(keyFromCodepoint(0x7b), Key.bracketLeft);
        expect(keyFromCodepoint(0x5c), Key.backslash);
        expect(keyFromCodepoint(0x7c), Key.backslash);
        expect(keyFromCodepoint(0x2f), Key.slash);
        expect(keyFromCodepoint(0x3f), Key.slash);
        expect(keyFromCodepoint(0x40), Key.digit2);
      });

      test('returns null for unmapped codepoints', () {
        expect(keyFromCodepoint(0x00), isNull);
        expect(keyFromCodepoint(0x1b), isNull);
        expect(keyFromCodepoint(0x7f), isNull);
        expect(keyFromCodepoint(0x100), isNull);
      });
    });

    group('unshiftedCodepointForKey', () {
      test('returns lowercase ASCII codepoints for character keys', () {
        expect(unshiftedCodepointForKey(Key.a), 0x61);
        expect(unshiftedCodepointForKey(Key.z), 0x7a);
        expect(unshiftedCodepointForKey(Key.digit0), 0x30);
        expect(unshiftedCodepointForKey(Key.digit9), 0x39);
        expect(unshiftedCodepointForKey(Key.bracketLeft), 0x5b);
        expect(unshiftedCodepointForKey(Key.backslash), 0x5c);
        expect(unshiftedCodepointForKey(Key.slash), 0x2f);
        expect(unshiftedCodepointForKey(Key.space), 0x20);
      });

      test('returns zero for non-character keys', () {
        expect(unshiftedCodepointForKey(Key.enter), 0);
        expect(unshiftedCodepointForKey(Key.arrowUp), 0);
        expect(unshiftedCodepointForKey(Key.f1), 0);
      });
    });

    group('programmatic key translation', () {
      test('applies US shift and caps lock translation', () {
        expect(codepointForKey(Key.a, const Mods.shift()), 0x41);
        expect(codepointForKey(Key.a, const Mods.capsLock()), 0x41);
        expect(
          codepointForKey(Key.a, const Mods.shift() | const Mods.capsLock()),
          0x61,
        );
        expect(codepointForKey(Key.digit1, const Mods.shift()), 0x21);
        expect(codepointForKey(Key.space, const Mods.none()), 0x20);
      });

      test('reports modifiers consumed by translation', () {
        expect(consumedModsForKey(Key.a, const Mods.shift()).hasShift, isTrue);
        expect(
          consumedModsForKey(Key.a, const Mods.capsLock()).hasCapsLock,
          isTrue,
        );
        expect(
          consumedModsForKey(Key.digit1, const Mods.shift()).hasShift,
          isTrue,
        );
        expect(
          consumedModsForKey(Key.space, const Mods.shift()).isEmpty,
          isTrue,
        );
      });
    });
  });
}
