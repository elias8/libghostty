import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../../generated/libghostty.g.dart' hide Allocator, String;
import '../../generated/libghostty.g.dart' as native show String;
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
      var buffer = (allocation + lengthBytes).cast<Uint8>();
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
        buffer = (allocation + lengthBytes).cast<Uint8>();
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
      checkResultCode(
        ghostty_key_encoder_set(
          Pointer.fromAddress(encoder.value),
          option,
          pointer.cast(),
        ).value,
        operation: 'ghostty_key_encoder_set',
      );
    });
  }

  @override
  void keyEncoderSetKittyFlags(LibGhosttyHandle encoder, int flags) {
    using((arena) {
      final pointer = arena<Uint8>()..value = flags;
      checkResultCode(
        ghostty_key_encoder_set(
          Pointer.fromAddress(encoder.value),
          .kittyFlags,
          pointer.cast(),
        ).value,
        operation: 'ghostty_key_encoder_set',
      );
    });
  }

  @override
  void keyEncoderSetOptFromTerminal(
    LibGhosttyHandle encoder,
    LibGhosttyHandle terminal,
  ) {
    checkResultCode(
      ghostty_key_encoder_set_from_terminal(
        Pointer.fromAddress(encoder.value),
        Pointer.fromAddress(terminal.value),
      ).value,
      operation: 'ghostty_key_encoder_set_from_terminal',
    );
  }

  @override
  void keyEncoderSetOptionAsAlt(LibGhosttyHandle encoder, OptionAsAlt value) {
    using((arena) {
      final pointer = arena<Int32>()..value = value.value;
      checkResultCode(
        ghostty_key_encoder_set(
          Pointer.fromAddress(encoder.value),
          .macosOptionAsAlt,
          pointer.cast(),
        ).value,
        operation: 'ghostty_key_encoder_set',
      );
    });
  }

  @override
  void keyEventFree(LibGhosttyHandle event) {
    ghostty_key_event_free(Pointer.fromAddress(event.value));
    final text = _utf8Pointers.remove(event.value);
    if (text != null) _textAllocator.free(text);
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
    final text = ghostty_key_event_get_utf8(Pointer.fromAddress(event.value));
    if (text.ptr == nullptr || text.len == 0) return null;
    return utf8.decode(text.ptr.asTypedList(text.len));
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
    checkResultCode(
      ghostty_key_event_set_action(
        Pointer.fromAddress(event.value),
        action,
      ).value,
      operation: 'ghostty_key_event_set_action',
    );
  }

  @override
  void keyEventSetComposing(LibGhosttyHandle event, {required bool composing}) {
    checkResultCode(
      ghostty_key_event_set_composing(
        Pointer.fromAddress(event.value),
        composing,
      ).value,
      operation: 'ghostty_key_event_set_composing',
    );
  }

  @override
  void keyEventSetConsumedMods(LibGhosttyHandle event, int mods) {
    checkResultCode(
      ghostty_key_event_set_consumed_mods(
        Pointer.fromAddress(event.value),
        mods,
      ).value,
      operation: 'ghostty_key_event_set_consumed_mods',
    );
  }

  @override
  void keyEventSetKey(LibGhosttyHandle event, Key key) {
    checkResultCode(
      ghostty_key_event_set_key(Pointer.fromAddress(event.value), key).value,
      operation: 'ghostty_key_event_set_key',
    );
  }

  @override
  void keyEventSetMods(LibGhosttyHandle event, int mods) {
    checkResultCode(
      ghostty_key_event_set_mods(Pointer.fromAddress(event.value), mods).value,
      operation: 'ghostty_key_event_set_mods',
    );
  }

  @override
  void keyEventSetUnshiftedCodepoint(LibGhosttyHandle event, int codepoint) {
    checkResultCode(
      ghostty_key_event_set_unshifted_codepoint(
        .fromAddress(event.value),
        codepoint,
      ).value,
      operation: 'ghostty_key_event_set_unshifted_codepoint',
    );
  }

  @override
  void keyEventSetUtf8(LibGhosttyHandle event, String? text) {
    final encoded = text == null ? <int>[] : utf8.encode(text);
    Pointer<Uint8>? replacement;
    try {
      if (encoded.isNotEmpty) {
        replacement = _textAllocator<Uint8>(encoded.length);
        replacement.asTypedList(encoded.length).setAll(0, encoded);
      }
      using((arena) {
        final value = native.String.$allocate(
          arena,
          ptr: replacement ?? nullptr,
          len: encoded.length,
        );
        final result = ghostty_key_event_set_utf8(
          Pointer.fromAddress(event.value),
          value.ref,
        );
        checkResultCode(result.value, operation: 'ghostty_key_event_set_utf8');
      });
    } on Object {
      if (replacement != null) _textAllocator.free(replacement);
      rethrow;
    }
    final previous = _utf8Pointers.remove(event.value);
    if (previous != null) _textAllocator.free(previous);
    if (replacement != null) _utf8Pointers[event.value] = replacement.cast();
  }
}
