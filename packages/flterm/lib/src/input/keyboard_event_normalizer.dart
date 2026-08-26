import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/services.dart';
import 'package:libghostty/libghostty.dart'
    show Key, KeyAction, Mods, OptionAsAlt;

import '../foundation.dart';
import 'native_keyboard_metadata.dart';

final class KeyboardEventNormalizer {
  final _unshiftedByPhysicalKey = <PhysicalKeyboardKey, int>{};
  final NativeKeyboardMetadata? Function(KeyEvent) _nativeMetadataForEvent;

  KeyboardEventNormalizer({
    NativeKeyboardMetadata? Function(KeyEvent)? nativeMetadataForEvent,
  }) : _nativeMetadataForEvent =
           nativeMetadataForEvent ??
           NativeKeyboardMetadataStore.instance.forEvent {
    if (nativeMetadataForEvent == null) {
      NativeKeyboardMetadataStore.instance.ensureInitialized();
    }
  }

  TerminalKeyboardEvent normalize(
    KeyEvent event, {
    required Key key,
    required KeyAction action,
    required Mods mods,
    required String? character,
    required bool composing,
    required OptionAsAlt optionAsAlt,
  }) {
    final native = _nativeMetadataForEvent(event);
    final effectiveMods = native == null ? mods : native.mods | mods;
    var unshiftedCodepoint = native?.unshiftedCodepoint ?? 0;

    if (unshiftedCodepoint == 0) {
      unshiftedCodepoint = _fallbackUnshiftedCodepoint(
        event,
        key: key,
        mods: effectiveMods,
        character: character,
      );
    } else {
      _unshiftedByPhysicalKey[event.physicalKey] = unshiftedCodepoint;
    }

    var text = character;
    final optionActsAsAlt = _optionActsAsAlt(effectiveMods, optionAsAlt);
    var consumedMods = native?.consumedMods ?? const Mods.none();
    consumedMods =
        consumedMods |
        _fallbackConsumedMods(
          text,
          unshiftedCodepoint: unshiftedCodepoint,
          mods: effectiveMods,
        );
    if (optionActsAsAlt) {
      text =
          native?.textWithoutAlt ??
          _textForCodepoint(unshiftedCodepoint) ??
          text;
      consumedMods = _withoutAlt(consumedMods);
    }
    final deadKey = (native?.deadKey ?? false) && !optionActsAsAlt;

    return TerminalKeyboardEvent(
      key: key,
      action: action,
      mods: effectiveMods,
      consumedMods: consumedMods,
      text: text,
      unshiftedCodepoint: unshiftedCodepoint,
      composing: composing || deadKey,
      deferToTextInput: deadKey,
    );
  }

  int _fallbackUnshiftedCodepoint(
    KeyEvent event, {
    required Key key,
    required Mods mods,
    required String? character,
  }) {
    final unmodified =
        !mods.hasShift &&
        !mods.hasCtrl &&
        !mods.hasAlt &&
        !mods.hasSuper &&
        !mods.hasCapsLock;
    if (unmodified) {
      final codepoint = _singleCodepoint(character);
      if (codepoint != 0) {
        _unshiftedByPhysicalKey[event.physicalKey] = codepoint;
        return codepoint;
      }
    }

    final cached = _unshiftedByPhysicalKey[event.physicalKey];
    if (cached != null) return cached;

    final logical = _singleCodepoint(event.logicalKey.keyLabel);
    if (logical != 0) {
      final lowered = _singleCodepoint(event.logicalKey.keyLabel.toLowerCase());
      return lowered == 0 ? logical : lowered;
    }

    return unshiftedCodepointForKey(key);
  }

  Mods _fallbackConsumedMods(
    String? character, {
    required int unshiftedCodepoint,
    required Mods mods,
  }) {
    if (character == null || unshiftedCodepoint == 0) {
      return const Mods.none();
    }
    final codepoint = _singleCodepoint(character);
    if (codepoint == 0) return const Mods.none();

    var consumed = const Mods.none();
    if (mods.hasShift && codepoint != unshiftedCodepoint) {
      consumed = consumed | const Mods.shift();
    }
    if (mods.hasCapsLock && codepoint != unshiftedCodepoint) {
      consumed = consumed | const Mods.capsLock();
    }

    final keyboard = HardwareKeyboard.instance;
    final altGraph = keyboard.logicalKeysPressed.contains(
      LogicalKeyboardKey.altGraph,
    );
    final rightAlt = keyboard.physicalKeysPressed.contains(
      PhysicalKeyboardKey.altRight,
    );
    if (defaultTargetPlatform != TargetPlatform.macOS &&
        mods.hasAlt &&
        (altGraph || (rightAlt && mods.hasCtrl))) {
      consumed = consumed | const Mods.alt();
      if (mods.hasCtrl) consumed = consumed | const Mods.ctrl();
    } else if (defaultTargetPlatform == TargetPlatform.macOS &&
        mods.hasAlt &&
        !mods.hasCtrl &&
        !mods.hasSuper &&
        codepoint != unshiftedCodepoint) {
      consumed = consumed | const Mods.alt();
    }
    return consumed;
  }

  bool _optionActsAsAlt(Mods mods, OptionAsAlt option) {
    if (defaultTargetPlatform != TargetPlatform.macOS || !mods.hasAlt) {
      return false;
    }
    return switch (option) {
      .false$ => false,
      .true$ => true,
      .left => !mods.isAltRight,
      .right => mods.isAltRight,
    };
  }

  Mods _withoutAlt(Mods mods) {
    if (!mods.hasAlt) return mods;
    return mods ^
        const Mods.alt() ^
        (mods.isAltRight ? const Mods.altSide() : const Mods.none());
  }

  int _singleCodepoint(String? value) {
    if (value == null || value.isEmpty) return 0;
    final runes = value.runes.iterator;
    if (!runes.moveNext()) return 0;
    final codepoint = runes.current;
    return runes.moveNext() ? 0 : codepoint;
  }

  String? _textForCodepoint(int codepoint) {
    if (codepoint <= 0 ||
        codepoint > 0x10FFFF ||
        (codepoint >= 0xD800 && codepoint <= 0xDFFF)) {
      return null;
    }
    return String.fromCharCode(codepoint);
  }
}
