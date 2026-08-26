import 'package:flterm/src/input/keyboard_event_normalizer.dart';
import 'package:flterm/src/input/native_keyboard_metadata.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart' hide KeyEvent;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const keyEvent = KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.keyA,
    logicalKey: LogicalKeyboardKey.keyA,
    character: 'A',
    timeStamp: Duration.zero,
  );

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('uses native layout translation and consumed modifiers', () {
    final normalizer = KeyboardEventNormalizer(
      nativeMetadataForEvent: (_) => const NativeKeyboardMetadata(
        mods: Mods.shift(),
        consumedMods: Mods.shift(),
        unshiftedCodepoint: 0x71,
        textWithoutAlt: null,
        deadKey: false,
      ),
    );

    final result = normalizer.normalize(
      keyEvent,
      key: Key.a,
      action: KeyAction.press,
      mods: const Mods.shift(),
      character: 'A',
      composing: false,
      optionAsAlt: OptionAsAlt.false$,
    );

    expect(result.unshiftedCodepoint, 0x71);
    expect(result.consumedMods.hasShift, isTrue);
    expect(result.text, 'A');
    expect(result.deferToTextInput, isFalse);
  });

  test('option as alt preserves other translation modifiers', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final normalizer = KeyboardEventNormalizer(
      nativeMetadataForEvent: (_) => const NativeKeyboardMetadata(
        mods: Mods.none(),
        consumedMods: Mods.none(),
        unshiftedCodepoint: 0x32,
        textWithoutAlt: '@',
        deadKey: true,
      ),
    );

    final result = normalizer.normalize(
      keyEvent,
      key: Key.digit2,
      action: KeyAction.press,
      mods: const Mods.shift() | const Mods.alt(),
      character: '€',
      composing: false,
      optionAsAlt: OptionAsAlt.true$,
    );

    expect(result.text, '@');
    expect(result.mods.hasAlt, isTrue);
    expect(result.consumedMods.hasAlt, isFalse);
    expect(result.consumedMods.hasShift, isTrue);
    expect(result.composing, isFalse);
    expect(result.deferToTextInput, isFalse);
  });

  test('dead key defers to platform text input', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final normalizer = KeyboardEventNormalizer(
      nativeMetadataForEvent: (_) => const NativeKeyboardMetadata(
        mods: Mods.alt(),
        consumedMods: Mods.alt(),
        unshiftedCodepoint: 0x65,
        textWithoutAlt: 'e',
        deadKey: true,
      ),
    );

    final result = normalizer.normalize(
      keyEvent,
      key: Key.e,
      action: KeyAction.press,
      mods: const Mods.alt(),
      character: null,
      composing: false,
      optionAsAlt: OptionAsAlt.false$,
    );

    expect(result.composing, isTrue);
    expect(result.deferToTextInput, isTrue);
  });

  test('option as alt honors the configured side', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final normalizer = KeyboardEventNormalizer(
      nativeMetadataForEvent: (_) => const NativeKeyboardMetadata(
        mods: Mods.none(),
        consumedMods: Mods.none(),
        unshiftedCodepoint: 0x61,
        textWithoutAlt: 'a',
        deadKey: false,
      ),
    );

    final left = normalizer.normalize(
      keyEvent,
      key: Key.a,
      action: KeyAction.press,
      mods: const Mods.alt(),
      character: 'å',
      composing: false,
      optionAsAlt: OptionAsAlt.right,
    );
    final right = normalizer.normalize(
      keyEvent,
      key: Key.a,
      action: KeyAction.press,
      mods: const Mods.alt() | const Mods.altSide(),
      character: 'å',
      composing: false,
      optionAsAlt: OptionAsAlt.right,
    );

    expect(left.text, 'å');
    expect(right.text, 'a');
  });
}
