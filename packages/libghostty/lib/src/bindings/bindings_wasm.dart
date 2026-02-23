import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../exceptions.dart';
import 'interface.dart';

const _oscChangeWindowTitle = 1;
const _resultOutOfMemory = -1;

JSObject? _compiledModule;
JSObject? _freshExports;

GhosttyBindings? _instance;

GhosttyBindings get bindings =>
    _instance ??
    (throw StateError(
      'Call initializeForWeb() before using libghostty on web.',
    ));

/// Loads the libghostty-vt WASM module and initializes bindings for web use.
///
/// ```dart
/// await initializeForWeb(Uri.parse('assets/ghostty-vt.wasm'));
/// ```
Future<void> initializeForWeb(Uri wasmUri) async {
  final response = await web.window.fetch(wasmUri.toString().toJS).toDart;
  final bytes = await response.arrayBuffer().toDart;
  final imports = _buildImports();
  final resultObj =
      (await _wasmInstantiate(bytes, imports).toDart)! as JSObject;
  _compiledModule = resultObj['module']! as JSObject;
  final instance = resultObj['instance']! as JSObject;
  final exports = instance['exports']! as JSObject;
  _instance = WasmBindings._(exports);
  _prepareSpareInstance();
}

JSObject _buildImports() {
  final env = _newJsObject();
  env['log'] = ((JSNumber ptr, JSNumber len) {}).toJS;
  final imports = _newJsObject();
  imports['env'] = env;
  return imports;
}

JSObject _newJsObject() =>
    (globalContext['Object']! as JSFunction).callAsConstructor<JSObject>();

void _prepareSpareInstance() {
  if (_compiledModule == null || _freshExports != null) return;
  final imports = _buildImports();
  unawaited(
    _wasmInstantiateModule(_compiledModule!, imports).toDart.then((result) {
      _freshExports = (result! as JSObject)['exports']! as JSObject;
    }),
  );
}

@JS('WebAssembly.instantiate')
external JSPromise _wasmInstantiate(JSArrayBuffer bytes, JSObject imports);

@JS('WebAssembly.instantiate')
external JSPromise _wasmInstantiateModule(JSObject module, JSObject imports);

class WasmBindings implements GhosttyBindings {
  _Fn _fn;

  _Mem _mem;
  final _utf8Ptrs = <int, (int ptr, int len)>{};
  var _activeTerminals = 0;

  WasmBindings._(JSObject exports) : _fn = _Fn(exports), _mem = _Mem(exports);

  @override
  String keyEncoderEncode(int encoder, int event) {
    final outLen = _fn.call0('ghostty_wasm_alloc_usize');
    var bufSize = 128;
    var buf = _fn.call1('ghostty_wasm_alloc_u8_array', bufSize);
    try {
      var result = _fn.callN('ghostty_key_encoder_encode', [
        encoder,
        event,
        buf,
        bufSize,
        outLen,
      ]);

      if (result == _resultOutOfMemory) {
        bufSize = _mem.readU32(outLen);
        _fn.void2('ghostty_wasm_free_u8_array', buf, 128);
        buf = _fn.call1('ghostty_wasm_alloc_u8_array', bufSize);
        result = _fn.callN('ghostty_key_encoder_encode', [
          encoder,
          event,
          buf,
          bufSize,
          outLen,
        ]);
      }

      checkResult(result);
      final len = _mem.readU32(outLen);
      if (len == 0) return '';
      return utf8.decode(_mem.readBytes(buf, len));
    } finally {
      _fn.void1('ghostty_wasm_free_usize', outLen);
      _fn.void2('ghostty_wasm_free_u8_array', buf, bufSize);
    }
  }

  @override
  void keyEncoderFree(int handle) {
    _fn.void1('ghostty_key_encoder_free', handle);
  }

  @override
  int keyEncoderNew() {
    final outPtr = _fn.call0('ghostty_wasm_alloc_opaque');
    try {
      checkResult(_fn.call2('ghostty_key_encoder_new', 0, outPtr));
      return _mem.readPtr(outPtr);
    } finally {
      _fn.void1('ghostty_wasm_free_opaque', outPtr);
    }
  }

  @override
  void keyEncoderSetBoolOpt(int handle, int option, {required bool value}) {
    final ptr = _fn.call0('ghostty_wasm_alloc_u8');
    try {
      _mem.writeU8(ptr, value ? 1 : 0);
      _fn.void3('ghostty_key_encoder_setopt', handle, option, ptr);
    } finally {
      _fn.void1('ghostty_wasm_free_u8', ptr);
    }
  }

  @override
  void keyEncoderSetKittyFlags(int handle, int flags) {
    final ptr = _fn.call0('ghostty_wasm_alloc_u8');
    try {
      _mem.writeU8(ptr, flags);
      _fn.void3(
        'ghostty_key_encoder_setopt',
        handle,
        KeyEncoderOpt.kittyFlags,
        ptr,
      );
    } finally {
      _fn.void1('ghostty_wasm_free_u8', ptr);
    }
  }

  @override
  void keyEncoderSetOptionAsAlt(int handle, int value) {
    final ptr = _fn.call0('ghostty_wasm_alloc_u8');
    try {
      _mem.writeI32(ptr, value);
      _fn.void3(
        'ghostty_key_encoder_setopt',
        handle,
        KeyEncoderOpt.macosOptionAsAlt,
        ptr,
      );
    } finally {
      _fn.void1('ghostty_wasm_free_u8', ptr);
    }
  }

  @override
  void keyEventFree(int handle) {
    final prev = _utf8Ptrs.remove(handle);
    if (prev != null) {
      _fn.void2('ghostty_wasm_free_u8_array', prev.$1, prev.$2);
    }
    _fn.void1('ghostty_key_event_free', handle);
  }

  @override
  int keyEventGetAction(int handle) =>
      _fn.call1('ghostty_key_event_get_action', handle);

  @override
  bool keyEventGetComposing(int handle) =>
      _fn.call1('ghostty_key_event_get_composing', handle) != 0;

  @override
  int keyEventGetConsumedMods(int handle) =>
      _fn.call1('ghostty_key_event_get_consumed_mods', handle);

  @override
  int keyEventGetKey(int handle) =>
      _fn.call1('ghostty_key_event_get_key', handle);

  @override
  int keyEventGetMods(int handle) =>
      _fn.call1('ghostty_key_event_get_mods', handle);

  @override
  int keyEventGetUnshiftedCodepoint(int handle) =>
      _fn.call1('ghostty_key_event_get_unshifted_codepoint', handle);

  @override
  String? keyEventGetUtf8(int handle) {
    final lenPtr = _fn.call0('ghostty_wasm_alloc_usize');
    try {
      final charPtr = _fn.call2('ghostty_key_event_get_utf8', handle, lenPtr);
      if (charPtr == 0) return null;
      final len = _mem.readU32(lenPtr);
      if (len == 0) return null;
      return utf8.decode(_mem.readBytes(charPtr, len));
    } finally {
      _fn.void1('ghostty_wasm_free_usize', lenPtr);
    }
  }

  @override
  int keyEventNew() {
    final outPtr = _fn.call0('ghostty_wasm_alloc_opaque');
    try {
      checkResult(_fn.call2('ghostty_key_event_new', 0, outPtr));
      return _mem.readPtr(outPtr);
    } finally {
      _fn.void1('ghostty_wasm_free_opaque', outPtr);
    }
  }

  @override
  void keyEventSetAction(int handle, int action) {
    _fn.void2('ghostty_key_event_set_action', handle, action);
  }

  @override
  void keyEventSetComposing(int handle, {required bool composing}) {
    _fn.void2('ghostty_key_event_set_composing', handle, composing ? 1 : 0);
  }

  @override
  void keyEventSetConsumedMods(int handle, int mods) {
    _fn.void2('ghostty_key_event_set_consumed_mods', handle, mods);
  }

  @override
  void keyEventSetKey(int handle, int key) {
    _fn.void2('ghostty_key_event_set_key', handle, key);
  }

  @override
  void keyEventSetMods(int handle, int mods) {
    _fn.void2('ghostty_key_event_set_mods', handle, mods);
  }

  @override
  void keyEventSetUnshiftedCodepoint(int handle, int codepoint) {
    _fn.void2('ghostty_key_event_set_unshifted_codepoint', handle, codepoint);
  }

  @override
  void keyEventSetUtf8(int handle, String? text) {
    final prev = _utf8Ptrs.remove(handle);
    if (prev != null) {
      _fn.void2('ghostty_wasm_free_u8_array', prev.$1, prev.$2);
    }

    if (text == null) {
      _fn.void3('ghostty_key_event_set_utf8', handle, 0, 0);
      return;
    }

    final encoded = utf8.encode(text);
    final ptr = _fn.call1('ghostty_wasm_alloc_u8_array', encoded.length);
    _mem.writeBytes(ptr, encoded);
    _fn.void3('ghostty_key_event_set_utf8', handle, ptr, encoded.length);
    _utf8Ptrs[handle] = (ptr, encoded.length);
  }

  @override
  OscEndResult oscEnd(int handle, int terminator) {
    final commandPtr = _fn.call2('ghostty_osc_end', handle, terminator);
    final commandType = _fn.call1('ghostty_osc_command_type', commandPtr);

    String? windowTitle;
    if (commandType == _oscChangeWindowTitle) {
      windowTitle = _extractWindowTitle(commandPtr);
    }

    return OscEndResult(commandType: commandType, windowTitle: windowTitle);
  }

  @override
  void oscFeedByte(int handle, int byte) {
    _fn.void2('ghostty_osc_next', handle, byte);
  }

  @override
  void oscFree(int handle) {
    _fn.void1('ghostty_osc_free', handle);
  }

  @override
  int oscNew() {
    final outPtr = _fn.call0('ghostty_wasm_alloc_opaque');
    try {
      checkResult(_fn.call2('ghostty_osc_new', 0, outPtr));
      return _mem.readPtr(outPtr);
    } finally {
      _fn.void1('ghostty_wasm_free_opaque', outPtr);
    }
  }

  @override
  void oscReset(int handle) {
    _fn.void1('ghostty_osc_reset', handle);
  }

  @override
  bool pasteIsSafe(String data) {
    final encoded = utf8.encode(data);
    if (encoded.isEmpty) {
      return _fn.bool2('ghostty_paste_is_safe', 0, 0);
    }
    final ptr = _fn.call1('ghostty_wasm_alloc_u8_array', encoded.length);
    try {
      _mem.writeBytes(ptr, encoded);
      return _fn.bool2('ghostty_paste_is_safe', ptr, encoded.length);
    } finally {
      _fn.void2('ghostty_wasm_free_u8_array', ptr, encoded.length);
    }
  }

  @override
  int renderStateGetBgColor(int handle) =>
      _fn.call1('ghostty_render_state_get_bg_color', handle);

  @override
  int renderStateGetCols(int handle) =>
      _fn.call1('ghostty_render_state_get_cols', handle);

  @override
  int renderStateGetCursorStyle(int handle) =>
      _fn.call1('ghostty_render_state_get_cursor_style', handle);

  @override
  bool renderStateGetCursorVisible(int handle) =>
      _fn.call1('ghostty_render_state_get_cursor_visible', handle) != 0;

  @override
  int renderStateGetCursorX(int handle) =>
      _fn.call1('ghostty_render_state_get_cursor_x', handle);

  @override
  int renderStateGetCursorY(int handle) =>
      _fn.call1('ghostty_render_state_get_cursor_y', handle);

  @override
  int renderStateGetFgColor(int handle) =>
      _fn.call1('ghostty_render_state_get_fg_color', handle);

  @override
  List<int> renderStateGetGrapheme(int handle, int row, int col) {
    const bufBytes = 32 * 4;
    final buf = _fn.call1('ghostty_wasm_alloc_u8_array', bufBytes);
    try {
      final count = _fn.callN('ghostty_render_state_get_grapheme', [
        handle,
        row,
        col,
        buf,
        32,
      ]);
      if (count <= 0) return const [];
      return [for (var i = 0; i < count; i++) _mem.readU32(buf + i * 4)];
    } finally {
      _fn.void2('ghostty_wasm_free_u8_array', buf, bufBytes);
    }
  }

  @override
  int renderStateGetRows(int handle) =>
      _fn.call1('ghostty_render_state_get_rows', handle);

  @override
  List<RawCell> renderStateGetViewport(int handle, int cols, int rows) {
    final totalCells = cols * rows;
    if (totalCells == 0) return const [];
    final bufSize = totalCells * 16;
    final buf = _fn.call1('ghostty_wasm_alloc_u8_array', bufSize);
    try {
      final count = _fn.call3(
        'ghostty_render_state_get_viewport',
        handle,
        buf,
        totalCells,
      );
      if (count < 0) return const [];
      return [for (var i = 0; i < count; i++) _readCell(buf + i * 16)];
    } finally {
      _fn.void2('ghostty_wasm_free_u8_array', buf, bufSize);
    }
  }

  @override
  bool renderStateIsRowDirty(int handle, int row) =>
      _fn.call2('ghostty_render_state_is_row_dirty', handle, row) != 0;

  @override
  void renderStateMarkClean(int handle) {
    _fn.void1('ghostty_render_state_mark_clean', handle);
  }

  @override
  int renderStateUpdate(int handle) =>
      _fn.call1('ghostty_render_state_update', handle);

  @override
  void sgrFree(int handle) {
    _fn.void1('ghostty_sgr_free', handle);
  }

  @override
  int sgrNew() {
    final outPtr = _fn.call0('ghostty_wasm_alloc_opaque');
    try {
      checkResult(_fn.call2('ghostty_sgr_new', 0, outPtr));
      return _mem.readPtr(outPtr);
    } finally {
      _fn.void1('ghostty_wasm_free_opaque', outPtr);
    }
  }

  @override
  List<RawSgrAttribute> sgrParse(
    int handle,
    List<int> params,
    List<String>? separators,
  ) {
    final paramsPtr = _fn.call1('ghostty_wasm_alloc_u16_array', params.length);
    var sepsPtr = 0;

    try {
      for (var i = 0; i < params.length; i++) {
        _mem.writeU16(paramsPtr + i * 2, params[i]);
      }

      if (separators != null) {
        sepsPtr = _fn.call1('ghostty_wasm_alloc_u8_array', separators.length);
        for (var i = 0; i < separators.length; i++) {
          _mem.writeU8(sepsPtr + i, separators[i].codeUnitAt(0));
        }
      }

      checkResult(
        _fn.call4(
          'ghostty_sgr_set_params',
          handle,
          paramsPtr,
          sepsPtr,
          params.length,
        ),
      );

      return _iterateSgrAttributes(handle);
    } finally {
      _fn.void2('ghostty_wasm_free_u16_array', paramsPtr, params.length);
      if (sepsPtr != 0) {
        _fn.void2('ghostty_wasm_free_u8_array', sepsPtr, separators!.length);
      }
    }
  }

  @override
  void sgrReset(int handle) {
    _fn.void1('ghostty_sgr_reset', handle);
  }

  @override
  void terminalFree(int handle) {
    _fn.void1('ghostty_terminal_free', handle);
    _activeTerminals--;
  }

  @override
  int terminalGetBellCount(int handle) =>
      _fn.call1('ghostty_terminal_get_bell_count', handle);

  @override
  bool terminalGetMode(int handle, int mode, {required bool isAnsi}) =>
      _fn.call3('ghostty_terminal_get_mode', handle, mode, isAnsi ? 1 : 0) != 0;

  @override
  int terminalGetScrollbackLength(int handle) =>
      _fn.call1('ghostty_terminal_get_scrollback_length', handle);

  @override
  List<RawCell>? terminalGetScrollbackLine(int handle, int offset, int cols) {
    if (cols <= 0) return null;
    final bufSize = cols * 16;
    final buf = _fn.call1('ghostty_wasm_alloc_u8_array', bufSize);
    try {
      final count = _fn.call4(
        'ghostty_terminal_get_scrollback_line',
        handle,
        offset,
        buf,
        cols,
      );
      if (count < 0) return null;
      return [for (var i = 0; i < count; i++) _readCell(buf + i * 16)];
    } finally {
      _fn.void2('ghostty_wasm_free_u8_array', buf, bufSize);
    }
  }

  @override
  String? terminalGetTitle(int handle) {
    const bufSize = 1024;
    final buf = _fn.call1('ghostty_wasm_alloc_u8_array', bufSize);
    try {
      final len = _fn.call3('ghostty_terminal_get_title', handle, buf, bufSize);
      if (len <= 0) return null;
      return utf8.decode(_mem.readBytes(buf, len));
    } finally {
      _fn.void2('ghostty_wasm_free_u8_array', buf, bufSize);
    }
  }

  @override
  bool terminalHasTitleChanged(int handle) =>
      _fn.call1('ghostty_terminal_has_title_changed', handle) != 0;

  @override
  bool terminalIsAlternateScreen(int handle) =>
      _fn.call1('ghostty_terminal_is_alternate_screen', handle) != 0;

  @override
  int terminalNew(int cols, int rows) {
    _applyFreshInstanceIfReady();
    final outPtr = _fn.call0('ghostty_wasm_alloc_opaque');
    try {
      checkResult(_fn.call4('ghostty_terminal_new', 0, cols, rows, outPtr));
      _activeTerminals++;
      return _mem.readPtr(outPtr);
    } finally {
      _fn.void1('ghostty_wasm_free_opaque', outPtr);
    }
  }

  @override
  int terminalNewWithConfig(int cols, int rows, RawTerminalConfig config) {
    _applyFreshInstanceIfReady();
    final outPtr = _fn.call0('ghostty_wasm_alloc_opaque');
    final cfgPtr = _fn.call1('ghostty_wasm_alloc_u8_array', 16);
    try {
      _mem.writeU32(cfgPtr, config.scrollbackLimit);
      _mem.writeU8(cfgPtr + 4, config.fgR);
      _mem.writeU8(cfgPtr + 5, config.fgG);
      _mem.writeU8(cfgPtr + 6, config.fgB);
      _mem.writeU8(cfgPtr + 7, config.fgSet ? 1 : 0);
      _mem.writeU8(cfgPtr + 8, config.bgR);
      _mem.writeU8(cfgPtr + 9, config.bgG);
      _mem.writeU8(cfgPtr + 10, config.bgB);
      _mem.writeU8(cfgPtr + 11, config.bgSet ? 1 : 0);
      _mem.writeU8(cfgPtr + 12, config.cursorR);
      _mem.writeU8(cfgPtr + 13, config.cursorG);
      _mem.writeU8(cfgPtr + 14, config.cursorB);
      _mem.writeU8(cfgPtr + 15, config.cursorSet ? 1 : 0);
      checkResult(
        _fn.callN('ghostty_terminal_new_with_config', [
          0,
          cols,
          rows,
          cfgPtr,
          outPtr,
        ]),
      );
      _activeTerminals++;
      return _mem.readPtr(outPtr);
    } finally {
      _fn.void1('ghostty_wasm_free_opaque', outPtr);
      _fn.void2('ghostty_wasm_free_u8_array', cfgPtr, 16);
    }
  }

  @override
  void terminalResetBellCount(int handle) {
    _fn.void1('ghostty_terminal_reset_bell_count', handle);
  }

  @override
  void terminalResize(int handle, int cols, int rows) {
    checkResult(_fn.call3('ghostty_terminal_resize', handle, cols, rows));
  }

  @override
  void terminalWrite(int handle, Uint8List data) {
    if (data.isEmpty) return;
    final ptr = _fn.call1('ghostty_wasm_alloc_u8_array', data.length);
    try {
      _mem.writeBytes(ptr, data);
      _fn.void3('ghostty_terminal_write', handle, ptr, data.length);
    } finally {
      _fn.void2('ghostty_wasm_free_u8_array', ptr, data.length);
    }
  }

  void _applyFreshInstanceIfReady() {
    if (_activeTerminals > 0) return;
    final exports = _freshExports;
    if (exports == null) return;
    _freshExports = null;
    _fn = _Fn(exports);
    _mem = _Mem(exports);
    _utf8Ptrs.clear();
    _prepareSpareInstance();
  }

  String? _extractWindowTitle(int commandPtr) {
    final outPtr = _fn.call0('ghostty_wasm_alloc_opaque');
    try {
      final success = _fn.call3(
        'ghostty_osc_command_data',
        commandPtr,
        OscDataField.changeWindowTitleStr,
        outPtr,
      );
      if (success == 0) return null;
      final charPtr = _mem.readPtr(outPtr);
      if (charPtr == 0) return null;
      return _mem.readCString(charPtr);
    } finally {
      _fn.void1('ghostty_wasm_free_opaque', outPtr);
    }
  }

  List<RawSgrAttribute> _iterateSgrAttributes(int handle) {
    final results = <RawSgrAttribute>[];
    final attrPtr = _fn.call0('ghostty_wasm_alloc_sgr_attribute');
    try {
      while (_fn.bool2('ghostty_sgr_next', handle, attrPtr)) {
        results.add(_readSgrAttribute(attrPtr));
      }
    } finally {
      _fn.void1('ghostty_wasm_free_sgr_attribute', attrPtr);
    }
    return results;
  }

  RawCell _readCell(int addr) => RawCell(
    codepoint: _mem.readU32(addr),
    fgR: _mem.readU8(addr + 4),
    fgG: _mem.readU8(addr + 5),
    fgB: _mem.readU8(addr + 6),
    bgR: _mem.readU8(addr + 7),
    bgG: _mem.readU8(addr + 8),
    bgB: _mem.readU8(addr + 9),
    flags: _mem.readU8(addr + 10),
    width: _mem.readU8(addr + 11),
    underlineStyle: _mem.readU8(addr + 12),
    graphemeLen: _mem.readU8(addr + 13),
  );

  RawSgrAttribute _readSgrAttribute(int attrPtr) {
    final tag = _fn.call1('ghostty_sgr_attribute_tag', attrPtr);
    final valuePtr = _fn.call1('ghostty_sgr_attribute_value', attrPtr);

    switch (tag) {
      case SgrTag.unknown:
        return _readSgrUnknown(valuePtr);

      case SgrTag.underline:
        return RawSgrAttribute(
          tag: tag,
          underlineStyle: _mem.readI32(valuePtr),
        );

      case SgrTag.underlineColor:
      case SgrTag.directColorFg:
      case SgrTag.directColorBg:
        final rPtr = _fn.call0('ghostty_wasm_alloc_u8');
        final gPtr = _fn.call0('ghostty_wasm_alloc_u8');
        final bPtr = _fn.call0('ghostty_wasm_alloc_u8');
        try {
          _fn.void4('ghostty_color_rgb_get', valuePtr, rPtr, gPtr, bPtr);
          return RawSgrAttribute(
            tag: tag,
            r: _mem.readU8(rPtr),
            g: _mem.readU8(gPtr),
            b: _mem.readU8(bPtr),
          );
        } finally {
          _fn.void1('ghostty_wasm_free_u8', rPtr);
          _fn.void1('ghostty_wasm_free_u8', gPtr);
          _fn.void1('ghostty_wasm_free_u8', bPtr);
        }

      case SgrTag.underlineColor256:
      case SgrTag.fg8:
      case SgrTag.bg8:
      case SgrTag.brightFg8:
      case SgrTag.brightBg8:
      case SgrTag.fg256:
      case SgrTag.bg256:
        return RawSgrAttribute(tag: tag, paletteIndex: _mem.readU8(valuePtr));

      default:
        return RawSgrAttribute(tag: tag);
    }
  }

  RawSgrAttribute _readSgrUnknown(int valuePtr) {
    final fullLen = _fn.call1('ghostty_sgr_unknown_full', valuePtr);
    final partialLen = _fn.call1('ghostty_sgr_unknown_partial', valuePtr);

    final fullPtrAddr = _mem.readPtr(valuePtr);
    final partialPtrAddr = _mem.readPtr(valuePtr + 4 + 4);

    final full = <int>[];
    for (var i = 0; i < fullLen; i++) {
      full.add(_mem.readU16(fullPtrAddr + i * 2));
    }

    final partial = <int>[];
    for (var i = 0; i < partialLen; i++) {
      partial.add(_mem.readU16(partialPtrAddr + i * 2));
    }

    return RawSgrAttribute(
      tag: SgrTag.unknown,
      unknownFull: full,
      unknownPartial: partial,
    );
  }
}

class _Fn {
  final JSObject _exports;

  _Fn(this._exports);

  bool bool2(String name, int a, int b) => call2(name, a, b) != 0;

  int call0(String name) {
    final fn = _exports[name]! as JSFunction;
    return (fn.callAsFunction()! as JSNumber).toDartInt;
  }

  int call1(String name, int a) {
    final fn = _exports[name]! as JSFunction;
    return (fn.callAsFunction(null, a.toJS)! as JSNumber).toDartInt;
  }

  int call2(String name, int a, int b) {
    final fn = _exports[name]! as JSFunction;
    return (fn.callAsFunction(null, a.toJS, b.toJS)! as JSNumber).toDartInt;
  }

  int call3(String name, int a, int b, int c) {
    final fn = _exports[name]! as JSFunction;
    return (fn.callAsFunction(null, a.toJS, b.toJS, c.toJS)! as JSNumber)
        .toDartInt;
  }

  int call4(String name, int a, int b, int c, int d) {
    final fn = _exports[name]! as JSFunction;
    return (fn.callAsFunction(null, a.toJS, b.toJS, c.toJS, d.toJS)!
            as JSNumber)
        .toDartInt;
  }

  int callN(String name, List<int> args) {
    final fn = _exports[name]! as JSFunction;
    final jsArgs = <JSAny?>[null, ...args.map((a) => a.toJS)];
    return (fn as JSObject)
        .callMethodVarArgs<JSNumber>('call'.toJS, jsArgs)
        .toDartInt;
  }

  void void1(String name, int a) {
    final fn = _exports[name]! as JSFunction;
    fn.callAsFunction(null, a.toJS);
  }

  void void2(String name, int a, int b) {
    final fn = _exports[name]! as JSFunction;
    fn.callAsFunction(null, a.toJS, b.toJS);
  }

  void void3(String name, int a, int b, int c) {
    final fn = _exports[name]! as JSFunction;
    fn.callAsFunction(null, a.toJS, b.toJS, c.toJS);
  }

  void void4(String name, int a, int b, int c, int d) {
    final fn = _exports[name]! as JSFunction;
    fn.callAsFunction(null, a.toJS, b.toJS, c.toJS, d.toJS);
  }
}

class _Mem {
  final JSObject _exports;

  _Mem(this._exports);

  ByteData get view => _buffer.asByteData();

  ByteBuffer get _buffer => (_memory['buffer']! as JSArrayBuffer).toDart;

  JSObject get _memory => _exports['memory']! as JSObject;

  Uint8List readBytes(int addr, int len) => _buffer.asUint8List(addr, len);

  String readCString(int addr) {
    if (addr == 0) return '';
    final bytes = <int>[];
    var offset = addr;
    while (true) {
      final byte = readU8(offset);
      if (byte == 0) break;
      bytes.add(byte);
      offset++;
    }
    return utf8.decode(bytes);
  }

  int readI32(int addr) => view.getInt32(addr, Endian.little);

  int readPtr(int addr) => readU32(addr);

  int readU16(int addr) => view.getUint16(addr, Endian.little);

  int readU32(int addr) => view.getUint32(addr, Endian.little);

  int readU8(int addr) => view.getUint8(addr);

  void writeBytes(int addr, List<int> bytes) {
    _buffer.asUint8List(addr, bytes.length).setAll(0, bytes);
  }

  void writeI32(int addr, int val) => view.setInt32(addr, val, Endian.little);

  void writeU16(int addr, int val) => view.setUint16(addr, val, Endian.little);

  void writeU32(int addr, int val) => view.setUint32(addr, val, Endian.little);

  void writeU8(int addr, int val) => view.setUint8(addr, val);
}
