import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../../generated/libghostty.g.dart' hide Allocator, String;
import '../../generated/libghostty_enums.g.dart';
import '../result_helpers.dart';
import '../types.dart';
import 'key.dart';

final class FfiKeyBindings implements KeyBindings {
  final _utf8Pointers = <int, Pointer<Char>>{};

  final Allocator _textAllocator;

  FfiKeyBindings({Allocator textAllocator = calloc})
    : _textAllocator = textAllocator;

  @override
  String keyEncoderEncode(LibGhosttyHandle encoder, LibGhosttyHandle event) {
    final lengthBytes = sizeOf<Size>();
    var capacity = 128;
    var allocation = calloc<Uint8>(lengthBytes + capacity);
    try {
      var length = allocation.cast<Size>();
      var buffer = (allocation + lengthBytes).cast<Char>();
      var result = ghostty_key_encoder_encode(
        Pointer.fromAddress(encoder.value),
        Pointer.fromAddress(event.value),
        buffer,
        capacity,
        length,
      );
      if (result == .outOfSpace) {
        capacity = length.value;
        calloc.free(allocation);
        allocation = nullptr;
        allocation = calloc<Uint8>(lengthBytes + capacity);
        length = allocation.cast<Size>();
        buffer = (allocation + lengthBytes).cast<Char>();
        result = ghostty_key_encoder_encode(
          Pointer.fromAddress(encoder.value),
          Pointer.fromAddress(event.value),
          buffer,
          capacity,
          length,
        );
      }
      checkResultCode(result.value, operation: 'ghostty_key_encoder_encode');
      return utf8.decode(buffer.cast<Uint8>().asTypedList(length.value));
    } finally {
      calloc.free(allocation);
    }
  }

  @override
  void keyEncoderFree(LibGhosttyHandle encoder) {
    ghostty_key_encoder_free(Pointer.fromAddress(encoder.value));
  }

  @override
  LibGhosttyHandle keyEncoderNew() {
    return using((arena) {
      final out = arena<Pointer<KeyEncoderImpl>>();
      final result = ghostty_key_encoder_new(nullptr, out);
      checkRequiredCode(result.value, operation: 'ghostty_key_encoder_new');
      return .fromAddress(out.value.address);
    });
  }

  @override
  void keyEncoderSetBoolOpt(
    LibGhosttyHandle encoder,
    KeyEncoderOption option, {
    required bool value,
  }) {
    using((arena) {
      final pointer = arena<Bool>()..value = value;
      ghostty_key_encoder_setopt(
        Pointer.fromAddress(encoder.value),
        option,
        pointer.cast(),
      );
    });
  }

  @override
  void keyEncoderSetKittyFlags(LibGhosttyHandle encoder, int flags) {
    using((arena) {
      final pointer = arena<Uint8>()..value = flags;
      ghostty_key_encoder_setopt(
        Pointer.fromAddress(encoder.value),
        .kittyFlags,
        pointer.cast(),
      );
    });
  }

  @override
  void keyEncoderSetOptFromTerminal(
    LibGhosttyHandle encoder,
    LibGhosttyHandle terminal,
  ) {
    ghostty_key_encoder_setopt_from_terminal(
      Pointer.fromAddress(encoder.value),
      Pointer.fromAddress(terminal.value),
    );
  }

  @override
  void keyEncoderSetOptionAsAlt(LibGhosttyHandle encoder, OptionAsAlt value) {
    using((arena) {
      final pointer = arena<Int32>()..value = value.value;
      ghostty_key_encoder_setopt(
        Pointer.fromAddress(encoder.value),
        .macosOptionAsAlt,
        pointer.cast(),
      );
    });
  }

  @override
  void keyEventFree(LibGhosttyHandle event) {
    final text = _utf8Pointers.remove(event.value);
    if (text != null) _textAllocator.free(text);
    ghostty_key_event_free(Pointer.fromAddress(event.value));
  }

  @override
  KeyAction keyEventGetAction(LibGhosttyHandle event) {
    return ghostty_key_event_get_action(Pointer.fromAddress(event.value));
  }

  @override
  bool keyEventGetComposing(LibGhosttyHandle event) {
    return ghostty_key_event_get_composing(Pointer.fromAddress(event.value));
  }

  @override
  int keyEventGetConsumedMods(LibGhosttyHandle event) {
    return ghostty_key_event_get_consumed_mods(
      Pointer.fromAddress(event.value),
    );
  }

  @override
  Key keyEventGetKey(LibGhosttyHandle event) {
    return ghostty_key_event_get_key(Pointer.fromAddress(event.value));
  }

  @override
  int keyEventGetMods(LibGhosttyHandle event) {
    return ghostty_key_event_get_mods(Pointer.fromAddress(event.value));
  }

  @override
  int keyEventGetUnshiftedCodepoint(LibGhosttyHandle event) {
    return ghostty_key_event_get_unshifted_codepoint(
      Pointer.fromAddress(event.value),
    );
  }

  @override
  String? keyEventGetUtf8(LibGhosttyHandle event) {
    return using((arena) {
      final length = arena<Size>();
      final pointer = ghostty_key_event_get_utf8(
        Pointer.fromAddress(event.value),
        length,
      );
      if (pointer == nullptr || length.value == 0) return null;
      return utf8.decode(pointer.cast<Uint8>().asTypedList(length.value));
    });
  }

  @override
  LibGhosttyHandle keyEventNew() {
    return using((arena) {
      final out = arena<Pointer<KeyEventImpl>>();
      final result = ghostty_key_event_new(nullptr, out);
      checkRequiredCode(result.value, operation: 'ghostty_key_event_new');
      return .fromAddress(out.value.address);
    });
  }

  @override
  void keyEventSetAction(LibGhosttyHandle event, KeyAction action) {
    ghostty_key_event_set_action(Pointer.fromAddress(event.value), action);
  }

  @override
  void keyEventSetComposing(LibGhosttyHandle event, {required bool composing}) {
    ghostty_key_event_set_composing(
      Pointer.fromAddress(event.value),
      composing,
    );
  }

  @override
  void keyEventSetConsumedMods(LibGhosttyHandle event, int mods) {
    ghostty_key_event_set_consumed_mods(Pointer.fromAddress(event.value), mods);
  }

  @override
  void keyEventSetKey(LibGhosttyHandle event, Key key) {
    ghostty_key_event_set_key(Pointer.fromAddress(event.value), key);
  }

  @override
  void keyEventSetMods(LibGhosttyHandle event, int mods) {
    ghostty_key_event_set_mods(Pointer.fromAddress(event.value), mods);
  }

  @override
  void keyEventSetUnshiftedCodepoint(LibGhosttyHandle event, int codepoint) {
    ghostty_key_event_set_unshifted_codepoint(
      .fromAddress(event.value),
      codepoint,
    );
  }

  @override
  void keyEventSetUtf8(LibGhosttyHandle event, String? text) {
    final pointer = Pointer<KeyEventImpl>.fromAddress(event.value);
    final previous = _utf8Pointers.remove(event.value);
    if (previous != null) _textAllocator.free(previous);

    Pointer<Char>? replacement;
    try {
      if (text == null || text.isEmpty) {
        ghostty_key_event_set_utf8(pointer, nullptr, 0);
        return;
      }
      final encoded = utf8.encode(text);
      replacement = _textAllocator<Char>(encoded.length);
      replacement.cast<Uint8>().asTypedList(encoded.length).setAll(0, encoded);
      _utf8Pointers[event.value] = replacement;
      ghostty_key_event_set_utf8(pointer, replacement, encoded.length);
    } on Object {
      ghostty_key_event_set_utf8(pointer, nullptr, 0);
      _utf8Pointers.remove(event.value);
      if (replacement != null) _textAllocator.free(replacement);
      rethrow;
    }
  }
}
