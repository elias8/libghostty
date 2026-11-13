import 'dart:convert';

import '../../generated/libghostty_enums.g.dart';
import '../../generated/libghostty_wasm.g.dart';
import '../../types/types.dart';
import '../result_helpers.dart';
import '../types.dart';
import '../wasm/allocator.dart';
import '../wasm/layouts.dart';
import '../wasm/memory.dart';
import 'mouse.dart';

final class WasmMouseBindings implements MouseBindings {
  final Memory _memory;
  final Layouts _layout;
  final GhosttyExports _exports;

  WasmMouseBindings(this._exports, this._layout) : _memory = Memory(_exports);

  @override
  String mouseEncoderEncode(LibGhosttyHandle encoder, LibGhosttyHandle event) {
    final lengthPointer = _requirePointer(_exports.allocateBytes(4));
    var capacity = 128;
    var allocationLength = capacity;
    var buffer = 0;
    try {
      buffer = _requirePointer(_exports.allocateBytes(allocationLength));
      var result = _exports.ghostty_mouse_encoder_encode(
        encoder.value,
        event.value,
        buffer,
        capacity,
        lengthPointer,
      );
      if (result == Result.outOfSpace.value) {
        _exports.freeBytes(buffer, allocationLength);
        buffer = 0;
        capacity = _memory.readU32(lengthPointer);
        allocationLength = capacity == 0 ? 1 : capacity;
        buffer = _requirePointer(_exports.allocateBytes(allocationLength));
        result = _exports.ghostty_mouse_encoder_encode(
          encoder.value,
          event.value,
          buffer,
          capacity,
          lengthPointer,
        );
      }
      checkResultCode(result, operation: 'ghostty_mouse_encoder_encode');
      return utf8.decode(
        _memory.readBytes(buffer, _memory.readU32(lengthPointer)),
      );
    } finally {
      if (buffer != 0) _exports.freeBytes(buffer, allocationLength);
      _exports.freeBytes(lengthPointer, 4);
    }
  }

  @override
  void mouseEncoderFree(LibGhosttyHandle encoder) {
    _exports.ghostty_mouse_encoder_free(encoder.value);
  }

  @override
  LibGhosttyHandle mouseEncoderNew() {
    final out = _requirePointer(_exports.allocateOpaque());
    try {
      final result = _exports.ghostty_mouse_encoder_new(0, out);
      checkResultCode(result, operation: 'ghostty_mouse_encoder_new');
      return .fromAddress(_exports.ghostty_wasm_take_opaque(out));
    } finally {
      _exports.freeOpaque(out);
    }
  }

  @override
  void mouseEncoderReset(LibGhosttyHandle encoder) {
    checkResultCode(
      _exports.ghostty_mouse_encoder_reset(encoder.value),
      operation: 'ghostty_mouse_encoder_reset',
    );
  }

  @override
  void mouseEncoderSetBoolOpt(
    LibGhosttyHandle encoder,
    MouseEncoderOption option, {
    required bool value,
  }) {
    final pointer = _requirePointer(_exports.allocateBytes(1));
    try {
      _memory.writeU8(pointer, value ? 1 : 0);
      checkResultCode(
        _exports.ghostty_mouse_encoder_set(
          encoder.value,
          option.value,
          pointer,
        ),
        operation: 'ghostty_mouse_encoder_set',
      );
    } finally {
      _exports.freeBytes(pointer, 1);
    }
  }

  @override
  void mouseEncoderSetFormat(LibGhosttyHandle encoder, MouseFormat format) {
    _setIntOption(encoder, MouseEncoderOption.format, format.value);
  }

  @override
  void mouseEncoderSetOptFromTerminal(
    LibGhosttyHandle encoder,
    LibGhosttyHandle terminal,
  ) {
    checkResultCode(
      _exports.ghostty_mouse_encoder_set_from_terminal(
        encoder.value,
        terminal.value,
      ),
      operation: 'ghostty_mouse_encoder_set_from_terminal',
    );
  }

  @override
  void mouseEncoderSetSize(LibGhosttyHandle encoder, MouseEncoderSize size) {
    final pointer = _requirePointer(
      _exports.allocateBytes(_layout.mouseEncoderSizeSize),
    );
    try {
      _memory.writeU32(pointer, _layout.mouseEncoderSizeSize);
      _memory.writeU32(
        pointer + _layout.mouseEncoderSizeScreenWidth,
        size.screenWidth,
      );
      _memory.writeU32(
        pointer + _layout.mouseEncoderSizeScreenHeight,
        size.screenHeight,
      );
      _memory.writeU32(
        pointer + _layout.mouseEncoderSizeCellWidth,
        size.cellWidth,
      );
      _memory.writeU32(
        pointer + _layout.mouseEncoderSizeCellHeight,
        size.cellHeight,
      );
      _memory.writeU32(
        pointer + _layout.mouseEncoderSizePaddingTop,
        size.paddingTop,
      );
      _memory.writeU32(
        pointer + _layout.mouseEncoderSizePaddingBottom,
        size.paddingBottom,
      );
      _memory.writeU32(
        pointer + _layout.mouseEncoderSizePaddingLeft,
        size.paddingLeft,
      );
      _memory.writeU32(
        pointer + _layout.mouseEncoderSizePaddingRight,
        size.paddingRight,
      );
      checkResultCode(
        _exports.ghostty_mouse_encoder_set(
          encoder.value,
          MouseEncoderOption.size.value,
          pointer,
        ),
        operation: 'ghostty_mouse_encoder_set',
      );
    } finally {
      _exports.freeBytes(pointer, _layout.mouseEncoderSizeSize);
    }
  }

  @override
  void mouseEncoderSetTrackingMode(
    LibGhosttyHandle encoder,
    MouseTrackingMode mode,
  ) {
    _setIntOption(encoder, MouseEncoderOption.event, mode.value);
  }

  @override
  void mouseEventClearButton(LibGhosttyHandle event) {
    checkResultCode(
      _exports.ghostty_mouse_event_clear_button(event.value),
      operation: 'ghostty_mouse_event_clear_button',
    );
  }

  @override
  void mouseEventFree(LibGhosttyHandle event) {
    _exports.ghostty_mouse_event_free(event.value);
  }

  @override
  MouseAction mouseEventGetAction(LibGhosttyHandle event) {
    return .fromValue(_exports.ghostty_mouse_event_get_action(event.value));
  }

  @override
  MouseButton? mouseEventGetButton(LibGhosttyHandle event) {
    final out = _requirePointer(_exports.allocateBytes(4));
    try {
      final result = _exports.ghostty_mouse_event_get_button(event.value, out);
      if (!checkOptionalCode(
        result,
        operation: 'ghostty_mouse_event_get_button',
      )) {
        return null;
      }
      return MouseButton.fromValue(_memory.readU32(out));
    } finally {
      _exports.freeBytes(out, 4);
    }
  }

  @override
  int mouseEventGetMods(LibGhosttyHandle event) {
    return _exports.ghostty_mouse_event_get_mods(event.value);
  }

  @override
  (double x, double y) mouseEventGetPosition(LibGhosttyHandle event) {
    final pointer = _requirePointer(
      _exports.allocateBytes(_layout.mousePosSize),
    );
    try {
      _exports.ghostty_mouse_event_get_position(pointer, event.value);
      return (
        _memory.readF32(pointer),
        _memory.readF32(pointer + _layout.mousePosY),
      );
    } finally {
      _exports.freeBytes(pointer, _layout.mousePosSize);
    }
  }

  @override
  LibGhosttyHandle mouseEventNew() {
    final out = _requirePointer(_exports.allocateOpaque());
    try {
      final result = _exports.ghostty_mouse_event_new(0, out);
      checkResultCode(result, operation: 'ghostty_mouse_event_new');
      return .fromAddress(_exports.ghostty_wasm_take_opaque(out));
    } finally {
      _exports.freeOpaque(out);
    }
  }

  @override
  void mouseEventSetAction(LibGhosttyHandle event, MouseAction action) {
    checkResultCode(
      _exports.ghostty_mouse_event_set_action(event.value, action.value),
      operation: 'ghostty_mouse_event_set_action',
    );
  }

  @override
  void mouseEventSetButton(LibGhosttyHandle event, MouseButton button) {
    checkResultCode(
      _exports.ghostty_mouse_event_set_button(event.value, button.value),
      operation: 'ghostty_mouse_event_set_button',
    );
  }

  @override
  void mouseEventSetMods(LibGhosttyHandle event, int mods) {
    checkResultCode(
      _exports.ghostty_mouse_event_set_mods(event.value, mods),
      operation: 'ghostty_mouse_event_set_mods',
    );
  }

  @override
  void mouseEventSetPosition(LibGhosttyHandle event, double x, double y) {
    final pointer = _requirePointer(
      _exports.allocateBytes(_layout.mousePosSize),
    );
    try {
      _memory.writeF32(pointer, x);
      _memory.writeF32(pointer + _layout.mousePosY, y);
      checkResultCode(
        _exports.ghostty_mouse_event_set_position(event.value, pointer),
        operation: 'ghostty_mouse_event_set_position',
      );
    } finally {
      _exports.freeBytes(pointer, _layout.mousePosSize);
    }
  }

  int _requirePointer(int pointer) {
    if (pointer == 0) throw const OutOfMemoryException();
    return pointer;
  }

  void _setIntOption(
    LibGhosttyHandle encoder,
    MouseEncoderOption option,
    int value,
  ) {
    final pointer = _requirePointer(_exports.allocateBytes(4));
    try {
      _memory.writeI32(pointer, value);
      checkResultCode(
        _exports.ghostty_mouse_encoder_set(
          encoder.value,
          option.value,
          pointer,
        ),
        operation: 'ghostty_mouse_encoder_set',
      );
    } finally {
      _exports.freeBytes(pointer, 4);
    }
  }
}
