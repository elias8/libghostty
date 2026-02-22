import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../exceptions.dart';
import '../ffi/bindings.g.dart' as native;
import 'interface.dart';

final GhosttyBindings bindings = NativeBindings();

Future<void> initializeForWeb(Uri wasmUri) async {}

RawCell _cellFromNative(native.GhosttyCell c) => RawCell(
  codepoint: c.codepoint,
  fgR: c.fg_r,
  fgG: c.fg_g,
  fgB: c.fg_b,
  bgR: c.bg_r,
  bgG: c.bg_g,
  bgB: c.bg_b,
  flags: c.flags,
  width: c.width,
  underlineStyle: c.underline_style,
  graphemeLen: c.grapheme_len,
);

class NativeBindings implements GhosttyBindings {
  final _utf8Ptrs = <int, ffi.Pointer<ffi.Char>>{};

  NativeBindings();

  @override
  String keyEncoderEncode(int encoder, int event) {
    final outLen = calloc<ffi.Size>();
    var buf = calloc<ffi.Char>(128);
    var bufSize = 128;
    try {
      var result = native.ghostty_key_encoder_encode(
        ffi.Pointer.fromAddress(encoder),
        ffi.Pointer.fromAddress(event),
        buf,
        bufSize,
        outLen,
      );

      if (result == native.GhosttyResult.GHOSTTY_OUT_OF_MEMORY) {
        bufSize = outLen.value;
        calloc.free(buf);
        buf = calloc<ffi.Char>(bufSize);
        result = native.ghostty_key_encoder_encode(
          ffi.Pointer.fromAddress(encoder),
          ffi.Pointer.fromAddress(event),
          buf,
          bufSize,
          outLen,
        );
      }

      checkResult(result.value);
      final len = outLen.value;
      if (len == 0) return '';
      return utf8.decode(buf.cast<ffi.Uint8>().asTypedList(len));
    } finally {
      calloc.free(outLen);
      calloc.free(buf);
    }
  }

  @override
  void keyEncoderFree(int handle) {
    native.ghostty_key_encoder_free(ffi.Pointer.fromAddress(handle));
  }

  @override
  int keyEncoderNew() {
    final ptr = calloc<ffi.Pointer<native.GhosttyKeyEncoder>>();
    try {
      checkResult(native.ghostty_key_encoder_new(ffi.nullptr, ptr).value);
      return ptr.value.address;
    } finally {
      calloc.free(ptr);
    }
  }

  @override
  void keyEncoderSetBoolOpt(int handle, int option, bool value) {
    final ptr = calloc<ffi.Bool>();
    try {
      ptr.value = value;
      native.ghostty_key_encoder_setopt(
        ffi.Pointer.fromAddress(handle),
        native.GhosttyKeyEncoderOption.fromValue(option),
        ptr.cast(),
      );
    } finally {
      calloc.free(ptr);
    }
  }

  @override
  void keyEncoderSetKittyFlags(int handle, int flags) {
    final ptr = calloc<ffi.Uint8>();
    try {
      ptr.value = flags;
      native.ghostty_key_encoder_setopt(
        ffi.Pointer.fromAddress(handle),
        native.GhosttyKeyEncoderOption.fromValue(KeyEncoderOpt.kittyFlags),
        ptr.cast(),
      );
    } finally {
      calloc.free(ptr);
    }
  }

  @override
  void keyEncoderSetOptionAsAlt(int handle, int value) {
    final ptr = calloc<ffi.Int32>();
    try {
      ptr.value = value;
      native.ghostty_key_encoder_setopt(
        ffi.Pointer.fromAddress(handle),
        native.GhosttyKeyEncoderOption.fromValue(
          KeyEncoderOpt.macosOptionAsAlt,
        ),
        ptr.cast(),
      );
    } finally {
      calloc.free(ptr);
    }
  }

  @override
  void keyEventFree(int handle) {
    _freeUtf8(handle);
    native.ghostty_key_event_free(ffi.Pointer.fromAddress(handle));
  }

  @override
  int keyEventGetAction(int handle) => native
      .ghostty_key_event_get_action(ffi.Pointer.fromAddress(handle))
      .value;

  @override
  bool keyEventGetComposing(int handle) =>
      native.ghostty_key_event_get_composing(ffi.Pointer.fromAddress(handle));

  @override
  int keyEventGetConsumedMods(int handle) => native
      .ghostty_key_event_get_consumed_mods(ffi.Pointer.fromAddress(handle));

  @override
  int keyEventGetKey(int handle) =>
      native.ghostty_key_event_get_key(ffi.Pointer.fromAddress(handle)).value;

  @override
  int keyEventGetMods(int handle) =>
      native.ghostty_key_event_get_mods(ffi.Pointer.fromAddress(handle));

  @override
  int keyEventGetUnshiftedCodepoint(int handle) =>
      native.ghostty_key_event_get_unshifted_codepoint(
        ffi.Pointer.fromAddress(handle),
      );

  @override
  String? keyEventGetUtf8(int handle) {
    final lenPtr = calloc<ffi.Size>();
    try {
      final charPtr = native.ghostty_key_event_get_utf8(
        ffi.Pointer.fromAddress(handle),
        lenPtr,
      );
      if (charPtr == ffi.nullptr) return null;
      final len = lenPtr.value;
      if (len == 0) return null;
      return utf8.decode(charPtr.cast<ffi.Uint8>().asTypedList(len));
    } finally {
      calloc.free(lenPtr);
    }
  }

  @override
  int keyEventNew() {
    final ptr = calloc<ffi.Pointer<native.GhosttyKeyEvent>>();
    try {
      checkResult(native.ghostty_key_event_new(ffi.nullptr, ptr).value);
      return ptr.value.address;
    } finally {
      calloc.free(ptr);
    }
  }

  @override
  void keyEventSetAction(int handle, int action) {
    native.ghostty_key_event_set_action(
      ffi.Pointer.fromAddress(handle),
      native.GhosttyKeyAction.fromValue(action),
    );
  }

  @override
  void keyEventSetComposing(int handle, bool composing) {
    native.ghostty_key_event_set_composing(
      ffi.Pointer.fromAddress(handle),
      composing,
    );
  }

  @override
  void keyEventSetConsumedMods(int handle, int mods) {
    native.ghostty_key_event_set_consumed_mods(
      ffi.Pointer.fromAddress(handle),
      mods,
    );
  }

  @override
  void keyEventSetKey(int handle, int key) {
    native.ghostty_key_event_set_key(
      ffi.Pointer.fromAddress(handle),
      native.GhosttyKey.fromValue(key),
    );
  }

  @override
  void keyEventSetMods(int handle, int mods) {
    native.ghostty_key_event_set_mods(ffi.Pointer.fromAddress(handle), mods);
  }

  @override
  void keyEventSetUnshiftedCodepoint(int handle, int codepoint) {
    native.ghostty_key_event_set_unshifted_codepoint(
      ffi.Pointer.fromAddress(handle),
      codepoint,
    );
  }

  @override
  void keyEventSetUtf8(int handle, String? text) {
    _freeUtf8(handle);
    final ptr = ffi.Pointer<native.GhosttyKeyEvent>.fromAddress(handle);
    if (text == null) {
      native.ghostty_key_event_set_utf8(ptr, ffi.nullptr, 0);
      return;
    }
    final encoded = utf8.encode(text);
    final charPtr = calloc<ffi.Char>(encoded.length);
    charPtr.cast<ffi.Uint8>().asTypedList(encoded.length).setAll(0, encoded);
    _utf8Ptrs[handle] = charPtr;
    native.ghostty_key_event_set_utf8(ptr, charPtr, encoded.length);
  }

  @override
  OscEndResult oscEnd(int handle, int terminator) {
    final commandPtr = native.ghostty_osc_end(
      ffi.Pointer.fromAddress(handle),
      terminator,
    );
    final commandType = native.ghostty_osc_command_type(commandPtr).value;

    String? windowTitle;
    if (commandType ==
        native
            .GhosttyOscCommandType
            .GHOSTTY_OSC_COMMAND_CHANGE_WINDOW_TITLE
            .value) {
      windowTitle = _extractWindowTitle(commandPtr);
    }

    return OscEndResult(commandType: commandType, windowTitle: windowTitle);
  }

  @override
  void oscFeedByte(int handle, int byte) {
    native.ghostty_osc_next(ffi.Pointer.fromAddress(handle), byte);
  }

  @override
  void oscFree(int handle) {
    native.ghostty_osc_free(ffi.Pointer.fromAddress(handle));
  }

  @override
  int oscNew() {
    final ptr = calloc<ffi.Pointer<native.GhosttyOscParser>>();
    try {
      checkResult(native.ghostty_osc_new(ffi.nullptr, ptr).value);
      return ptr.value.address;
    } finally {
      calloc.free(ptr);
    }
  }

  @override
  void oscReset(int handle) {
    native.ghostty_osc_reset(ffi.Pointer.fromAddress(handle));
  }

  @override
  bool pasteIsSafe(String data) {
    final encoded = utf8.encode(data);
    final ptr = calloc<ffi.Char>(encoded.length);
    try {
      ptr.cast<ffi.Uint8>().asTypedList(encoded.length).setAll(0, encoded);
      return native.ghostty_paste_is_safe(ptr, encoded.length);
    } finally {
      calloc.free(ptr);
    }
  }

  @override
  int renderStateGetBgColor(int handle) =>
      native.ghostty_render_state_get_bg_color(ffi.Pointer.fromAddress(handle));

  @override
  int renderStateGetCols(int handle) =>
      native.ghostty_render_state_get_cols(ffi.Pointer.fromAddress(handle));

  @override
  int renderStateGetCursorStyle(int handle) => native
      .ghostty_render_state_get_cursor_style(ffi.Pointer.fromAddress(handle));

  @override
  bool renderStateGetCursorVisible(int handle) => native
      .ghostty_render_state_get_cursor_visible(ffi.Pointer.fromAddress(handle));

  @override
  int renderStateGetCursorX(int handle) =>
      native.ghostty_render_state_get_cursor_x(ffi.Pointer.fromAddress(handle));

  @override
  int renderStateGetCursorY(int handle) =>
      native.ghostty_render_state_get_cursor_y(ffi.Pointer.fromAddress(handle));

  @override
  int renderStateGetFgColor(int handle) =>
      native.ghostty_render_state_get_fg_color(ffi.Pointer.fromAddress(handle));

  @override
  List<int> renderStateGetGrapheme(int handle, int row, int col) {
    final buf = calloc<ffi.Uint32>(32);
    try {
      final count = native.ghostty_render_state_get_grapheme(
        ffi.Pointer.fromAddress(handle),
        row,
        col,
        buf,
        32,
      );
      if (count <= 0) return const [];
      return [for (var i = 0; i < count; i++) buf[i]];
    } finally {
      calloc.free(buf);
    }
  }

  @override
  int renderStateGetRows(int handle) =>
      native.ghostty_render_state_get_rows(ffi.Pointer.fromAddress(handle));

  @override
  List<RawCell> renderStateGetViewport(int handle, int cols, int rows) {
    final totalCells = cols * rows;
    if (totalCells == 0) return const [];
    final buf = calloc<native.GhosttyCell>(totalCells);
    try {
      final count = native.ghostty_render_state_get_viewport(
        ffi.Pointer.fromAddress(handle),
        buf,
        totalCells,
      );
      if (count < 0) return const [];
      return [for (var i = 0; i < count; i++) _cellFromNative(buf[i])];
    } finally {
      calloc.free(buf);
    }
  }

  @override
  bool renderStateIsRowDirty(int handle, int row) => native
      .ghostty_render_state_is_row_dirty(ffi.Pointer.fromAddress(handle), row);

  @override
  void renderStateMarkClean(int handle) {
    native.ghostty_render_state_mark_clean(ffi.Pointer.fromAddress(handle));
  }

  @override
  int renderStateUpdate(int handle) =>
      native.ghostty_render_state_update(ffi.Pointer.fromAddress(handle));

  @override
  void sgrFree(int handle) {
    native.ghostty_sgr_free(ffi.Pointer.fromAddress(handle));
  }

  @override
  int sgrNew() {
    final ptr = calloc<ffi.Pointer<native.GhosttySgrParser>>();
    try {
      checkResult(native.ghostty_sgr_new(ffi.nullptr, ptr).value);
      return ptr.value.address;
    } finally {
      calloc.free(ptr);
    }
  }

  @override
  List<RawSgrAttribute> sgrParse(
    int handle,
    List<int> params,
    List<String>? separators,
  ) {
    final nativeParams = calloc<ffi.Uint16>(params.length);
    ffi.Pointer<ffi.Char> nativeSeps = ffi.nullptr;

    try {
      for (var i = 0; i < params.length; i++) {
        nativeParams[i] = params[i];
      }

      if (separators != null) {
        nativeSeps = calloc<ffi.Char>(separators.length);
        for (var i = 0; i < separators.length; i++) {
          (nativeSeps + i).value = separators[i].codeUnitAt(0);
        }
      }

      checkResult(
        native
            .ghostty_sgr_set_params(
              ffi.Pointer.fromAddress(handle),
              nativeParams,
              nativeSeps,
              params.length,
            )
            .value,
      );

      return _iterateSgrAttributes(handle);
    } finally {
      calloc.free(nativeParams);
      if (nativeSeps != ffi.nullptr) {
        calloc.free(nativeSeps);
      }
    }
  }

  @override
  void sgrReset(int handle) {
    native.ghostty_sgr_reset(ffi.Pointer.fromAddress(handle));
  }

  @override
  void terminalFree(int handle) {
    native.ghostty_terminal_free(ffi.Pointer.fromAddress(handle));
  }

  @override
  int terminalGetBellCount(int handle) =>
      native.ghostty_terminal_get_bell_count(ffi.Pointer.fromAddress(handle));

  @override
  bool terminalGetMode(int handle, int mode, bool isAnsi) => native
      .ghostty_terminal_get_mode(ffi.Pointer.fromAddress(handle), mode, isAnsi);

  @override
  int terminalGetScrollbackLength(int handle) => native
      .ghostty_terminal_get_scrollback_length(ffi.Pointer.fromAddress(handle));

  @override
  List<RawCell>? terminalGetScrollbackLine(int handle, int offset, int cols) {
    if (cols <= 0) return null;
    final buf = calloc<native.GhosttyCell>(cols);
    try {
      final count = native.ghostty_terminal_get_scrollback_line(
        ffi.Pointer.fromAddress(handle),
        offset,
        buf,
        cols,
      );
      if (count < 0) return null;
      return [for (var i = 0; i < count; i++) _cellFromNative(buf[i])];
    } finally {
      calloc.free(buf);
    }
  }

  @override
  String? terminalGetTitle(int handle) {
    final buf = calloc<ffi.Uint8>(1024);
    try {
      final len = native.ghostty_terminal_get_title(
        ffi.Pointer.fromAddress(handle),
        buf,
        1024,
      );
      if (len <= 0) return null;
      return utf8.decode(buf.asTypedList(len));
    } finally {
      calloc.free(buf);
    }
  }

  @override
  bool terminalHasTitleChanged(int handle) => native
      .ghostty_terminal_has_title_changed(ffi.Pointer.fromAddress(handle));

  @override
  bool terminalIsAlternateScreen(int handle) => native
      .ghostty_terminal_is_alternate_screen(ffi.Pointer.fromAddress(handle));

  @override
  int terminalNew(int cols, int rows) {
    final ptr = calloc<ffi.Pointer<native.GhosttyTerminal>>();
    try {
      checkResult(
        native.ghostty_terminal_new(ffi.nullptr, cols, rows, ptr).value,
      );
      return ptr.value.address;
    } finally {
      calloc.free(ptr);
    }
  }

  @override
  int terminalNewWithConfig(int cols, int rows, RawTerminalConfig config) {
    final ptr = calloc<ffi.Pointer<native.GhosttyTerminal>>();
    final cfg = calloc<native.GhosttyTerminalConfig>();
    try {
      cfg.ref.scrollback_limit = config.scrollbackLimit;
      cfg.ref.fg_r = config.fgR;
      cfg.ref.fg_g = config.fgG;
      cfg.ref.fg_b = config.fgB;
      cfg.ref.fg_set = config.fgSet ? 1 : 0;
      cfg.ref.bg_r = config.bgR;
      cfg.ref.bg_g = config.bgG;
      cfg.ref.bg_b = config.bgB;
      cfg.ref.bg_set = config.bgSet ? 1 : 0;
      cfg.ref.cursor_r = config.cursorR;
      cfg.ref.cursor_g = config.cursorG;
      cfg.ref.cursor_b = config.cursorB;
      cfg.ref.cursor_set = config.cursorSet ? 1 : 0;
      checkResult(
        native
            .ghostty_terminal_new_with_config(ffi.nullptr, cols, rows, cfg, ptr)
            .value,
      );
      return ptr.value.address;
    } finally {
      calloc.free(cfg);
      calloc.free(ptr);
    }
  }

  @override
  void terminalResetBellCount(int handle) {
    native.ghostty_terminal_reset_bell_count(ffi.Pointer.fromAddress(handle));
  }

  @override
  void terminalResize(int handle, int cols, int rows) {
    checkResult(
      native
          .ghostty_terminal_resize(ffi.Pointer.fromAddress(handle), cols, rows)
          .value,
    );
  }

  @override
  void terminalWrite(int handle, Uint8List data) {
    if (data.isEmpty) return;
    final ptr = calloc<ffi.Uint8>(data.length);
    try {
      ptr.asTypedList(data.length).setAll(0, data);
      native.ghostty_terminal_write(
        ffi.Pointer.fromAddress(handle),
        ptr,
        data.length,
      );
    } finally {
      calloc.free(ptr);
    }
  }

  RawSgrAttribute _convertNativeSgrAttribute(native.GhosttySgrAttribute attr) {
    final tag = attr.tagAsInt;
    final value = attr.value;

    switch (tag) {
      case SgrTag.unknown:
        final unknown = value.unknown;
        final full = <int>[];
        for (var i = 0; i < unknown.full_len; i++) {
          full.add(unknown.full_ptr[i]);
        }
        final partial = <int>[];
        for (var i = 0; i < unknown.partial_len; i++) {
          partial.add(unknown.partial_ptr[i]);
        }
        return RawSgrAttribute(
          tag: tag,
          unknownFull: full,
          unknownPartial: partial,
        );

      case SgrTag.underline:
        return RawSgrAttribute(tag: tag, underlineStyle: value.underlineAsInt);

      case SgrTag.underlineColor:
        return RawSgrAttribute(
          tag: tag,
          r: value.underline_color.r,
          g: value.underline_color.g,
          b: value.underline_color.b,
        );

      case SgrTag.directColorFg:
        return RawSgrAttribute(
          tag: tag,
          r: value.direct_color_fg.r,
          g: value.direct_color_fg.g,
          b: value.direct_color_fg.b,
        );

      case SgrTag.directColorBg:
        return RawSgrAttribute(
          tag: tag,
          r: value.direct_color_bg.r,
          g: value.direct_color_bg.g,
          b: value.direct_color_bg.b,
        );

      case SgrTag.underlineColor256:
        return RawSgrAttribute(
          tag: tag,
          paletteIndex: value.underline_color_256,
        );

      case SgrTag.fg8:
        return RawSgrAttribute(tag: tag, paletteIndex: value.fg_8);

      case SgrTag.bg8:
        return RawSgrAttribute(tag: tag, paletteIndex: value.bg_8);

      case SgrTag.brightFg8:
        return RawSgrAttribute(tag: tag, paletteIndex: value.bright_fg_8);

      case SgrTag.brightBg8:
        return RawSgrAttribute(tag: tag, paletteIndex: value.bright_bg_8);

      case SgrTag.fg256:
        return RawSgrAttribute(tag: tag, paletteIndex: value.fg_256);

      case SgrTag.bg256:
        return RawSgrAttribute(tag: tag, paletteIndex: value.bg_256);

      default:
        return RawSgrAttribute(tag: tag);
    }
  }

  String? _extractWindowTitle(
    ffi.Pointer<native.GhosttyOscCommand> commandPtr,
  ) {
    final outPtr = calloc<ffi.Pointer<ffi.Char>>();
    try {
      final success = native.ghostty_osc_command_data(
        commandPtr,
        native.GhosttyOscCommandData.fromValue(
          OscDataField.changeWindowTitleStr,
        ),
        outPtr.cast(),
      );
      if (!success) return null;
      final charPtr = outPtr.value;
      if (charPtr == ffi.nullptr) return null;
      return charPtr.cast<Utf8>().toDartString();
    } finally {
      calloc.free(outPtr);
    }
  }

  void _freeUtf8(int handle) {
    final ptr = _utf8Ptrs.remove(handle);
    if (ptr != null) calloc.free(ptr);
  }

  List<RawSgrAttribute> _iterateSgrAttributes(int handle) {
    final results = <RawSgrAttribute>[];
    final attrPtr = calloc<native.GhosttySgrAttribute>();
    try {
      while (native.ghostty_sgr_next(
        ffi.Pointer.fromAddress(handle),
        attrPtr,
      )) {
        results.add(_convertNativeSgrAttribute(attrPtr.ref));
      }
    } finally {
      calloc.free(attrPtr);
    }
    return results;
  }
}
