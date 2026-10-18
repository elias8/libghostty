import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../../generated/libghostty.g.dart' as native;
import '../../generated/libghostty_enums.g.dart';
import '../../types/types.dart';
import '../result_helpers.dart';
import '../types.dart';
import 'mouse.dart';

final class FfiMouseBindings implements MouseBindings {
  const FfiMouseBindings();

  @override
  String mouseEncoderEncode(LibGhosttyHandle encoder, LibGhosttyHandle event) {
    final lengthBytes = sizeOf<Size>();
    var capacity = 128;
    var allocation = calloc<Uint8>(lengthBytes + capacity);
    try {
      var length = allocation.cast<Size>();
      var buffer = (allocation + lengthBytes).cast<Char>();
      var result = native.ghostty_mouse_encoder_encode(
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
        result = native.ghostty_mouse_encoder_encode(
          Pointer.fromAddress(encoder.value),
          Pointer.fromAddress(event.value),
          buffer,
          capacity,
          length,
        );
      }
      checkResultCode(result.value, operation: 'ghostty_mouse_encoder_encode');
      return utf8.decode(buffer.cast<Uint8>().asTypedList(length.value));
    } finally {
      calloc.free(allocation);
    }
  }

  @override
  void mouseEncoderFree(LibGhosttyHandle encoder) {
    native.ghostty_mouse_encoder_free(.fromAddress(encoder.value));
  }

  @override
  LibGhosttyHandle mouseEncoderNew() {
    return using((arena) {
      final out = arena<Pointer<native.MouseEncoderImpl>>();
      final result = native.ghostty_mouse_encoder_new(nullptr, out);
      checkResultCode(result.value, operation: 'ghostty_mouse_encoder_new');
      return .fromAddress(out.value.address);
    });
  }

  @override
  void mouseEncoderReset(LibGhosttyHandle encoder) {
    native.ghostty_mouse_encoder_reset(.fromAddress(encoder.value));
  }

  @override
  void mouseEncoderSetBoolOpt(
    LibGhosttyHandle encoder,
    MouseEncoderOption option, {
    required bool value,
  }) {
    using((arena) {
      final pointer = arena<Bool>()..value = value;
      native.ghostty_mouse_encoder_setopt(
        .fromAddress(encoder.value),
        option,
        pointer.cast(),
      );
    });
  }

  @override
  void mouseEncoderSetFormat(LibGhosttyHandle encoder, MouseFormat format) {
    using((arena) {
      final pointer = arena<Int32>()..value = format.value;
      native.ghostty_mouse_encoder_setopt(
        .fromAddress(encoder.value),
        MouseEncoderOption.format,
        pointer.cast(),
      );
    });
  }

  @override
  void mouseEncoderSetOptFromTerminal(
    LibGhosttyHandle encoder,
    LibGhosttyHandle terminal,
  ) {
    native.ghostty_mouse_encoder_setopt_from_terminal(
      .fromAddress(encoder.value),
      .fromAddress(terminal.value),
    );
  }

  @override
  void mouseEncoderSetSize(LibGhosttyHandle encoder, MouseEncoderSize size) {
    using((arena) {
      final pointer = native.MouseEncoderSize.$allocate(
        arena,
        size: sizeOf<native.MouseEncoderSize>(),
        screen_width: size.screenWidth,
        screen_height: size.screenHeight,
        cell_width: size.cellWidth,
        cell_height: size.cellHeight,
        padding_top: size.paddingTop,
        padding_bottom: size.paddingBottom,
        padding_left: size.paddingLeft,
        padding_right: size.paddingRight,
      );
      native.ghostty_mouse_encoder_setopt(
        .fromAddress(encoder.value),
        MouseEncoderOption.size,
        pointer.cast(),
      );
    });
  }

  @override
  void mouseEncoderSetTrackingMode(
    LibGhosttyHandle encoder,
    MouseTrackingMode mode,
  ) {
    using((arena) {
      final pointer = arena<Int32>()..value = mode.value;
      native.ghostty_mouse_encoder_setopt(
        .fromAddress(encoder.value),
        MouseEncoderOption.event,
        pointer.cast(),
      );
    });
  }

  @override
  void mouseEventClearButton(LibGhosttyHandle event) {
    native.ghostty_mouse_event_clear_button(.fromAddress(event.value));
  }

  @override
  void mouseEventFree(LibGhosttyHandle event) {
    native.ghostty_mouse_event_free(.fromAddress(event.value));
  }

  @override
  MouseAction mouseEventGetAction(LibGhosttyHandle event) {
    return native.ghostty_mouse_event_get_action(.fromAddress(event.value));
  }

  @override
  MouseButton? mouseEventGetButton(LibGhosttyHandle event) {
    return using((arena) {
      final out = arena<UnsignedInt>();
      final present = native.ghostty_mouse_event_get_button(
        .fromAddress(event.value),
        out,
      );
      if (!present) return null;
      return MouseButton.fromValue(out.value);
    });
  }

  @override
  int mouseEventGetMods(LibGhosttyHandle event) {
    return native.ghostty_mouse_event_get_mods(.fromAddress(event.value));
  }

  @override
  (double x, double y) mouseEventGetPosition(LibGhosttyHandle event) {
    final position = native.ghostty_mouse_event_get_position(
      .fromAddress(event.value),
    );
    return (position.x, position.y);
  }

  @override
  LibGhosttyHandle mouseEventNew() {
    return using((arena) {
      final out = arena<Pointer<native.MouseEventImpl>>();
      final result = native.ghostty_mouse_event_new(nullptr, out);
      checkResultCode(result.value, operation: 'ghostty_mouse_event_new');
      return .fromAddress(out.value.address);
    });
  }

  @override
  void mouseEventSetAction(LibGhosttyHandle event, MouseAction action) {
    native.ghostty_mouse_event_set_action(.fromAddress(event.value), action);
  }

  @override
  void mouseEventSetButton(LibGhosttyHandle event, MouseButton button) {
    native.ghostty_mouse_event_set_button(.fromAddress(event.value), button);
  }

  @override
  void mouseEventSetMods(LibGhosttyHandle event, int mods) {
    native.ghostty_mouse_event_set_mods(.fromAddress(event.value), mods);
  }

  @override
  void mouseEventSetPosition(LibGhosttyHandle event, double x, double y) {
    using((arena) {
      final position = native.MousePosition.$allocate(arena, x: x, y: y);
      native.ghostty_mouse_event_set_position(
        .fromAddress(event.value),
        position.ref,
      );
    });
  }
}
