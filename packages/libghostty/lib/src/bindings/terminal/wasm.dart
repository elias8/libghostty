import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../../generated/libghostty_enums.g.dart';
import '../../generated/libghostty_wasm.g.dart';
import '../../types/types.dart';
import '../result_helpers.dart';
import '../types.dart';
import '../wasm/adapter.dart';
import '../wasm/allocator.dart';
import '../wasm/layouts.dart';
import '../wasm/memory.dart';
import '../wasm/scratch.dart';
import 'terminal.dart';

const _wasmOutputSlotSize = 8;
const _wasmPointerSize = 4;
const _wasmSizeSize = 4;

final class WasmTerminalBindings implements TerminalBindings {
  final Memory _memory;
  final Layouts _layout;
  final web.Table _table;
  final GhosttyExports _exports;
  final WasmScratchPool _scratch;
  final _freeTableIndices = <int>[];
  final _callbacks = <int, Map<TerminalOption, (int index, Function fn)>>{};
  final _stringBuffers = <int, Map<TerminalOption, (int ptr, int len)>>{};
  ({Object error, StackTrace stackTrace})? _callbackError;

  WasmTerminalBindings(this._exports, this._layout)
    : _memory = Memory(_exports),
      _scratch = WasmScratchPool(
        WasmExportScratchAllocator(_exports),
        maxVariableLength: WasmScratchPool.defaultMaxVariableLength,
      ),
      _table =
          (_exports as JSObject)['__indirect_function_table'] as web.Table? ??
          (throw StateError(
            'WASM module does not export __indirect_function_table',
          ));
  @override
  TerminalCompressionResult terminalCompress(
    LibGhosttyHandle terminal,
    TerminalCompressionMode mode,
  ) {
    final frame = _scratch.acquire(const []);
    try {
      final out = frame.variableAddress(
        0,
        wasm32PointerSize,
        alignment: wasm32PointerSize,
      );
      _memory.writeU32(out, TerminalCompressionResult.unsupported.value);
      final result = _exports.ghostty_terminal_compress(
        terminal.value,
        mode.value,
        out,
      );
      checkResultCode(result, operation: 'ghostty_terminal_compress');
      return .fromValue(_memory.readU32(out));
    } finally {
      frame.release();
    }
  }

  @override
  int terminalCompressionActivity(LibGhosttyHandle terminal) {
    final frame = _scratch.acquire(const []);
    try {
      final out = frame.variableAddress(0, 8, alignment: 8);
      final result = _exports.ghostty_terminal_compression_activity(
        terminal.value,
        out,
      );
      checkResultCode(
        result,
        operation: 'ghostty_terminal_compression_activity',
      );
      return _memory.readU64(out);
    } finally {
      frame.release();
    }
  }

  @override
  Uint8List terminalContinuationGet(LibGhosttyHandle terminal) {
    final frame = _scratch.acquire(const []);
    try {
      final written = frame.variableAddress(
        0,
        wasm32PointerSize,
        alignment: wasm32PointerSize,
      );
      var result = _exports.ghostty_terminal_continuation_buf(
        terminal.value,
        0,
        0,
        written,
      );
      if (result != Result.outOfSpace.value) {
        checkResultCode(result, operation: 'ghostty_terminal_continuation_buf');
        return Uint8List(0);
      }
      final capacity = _memory.readU32(written);
      if (capacity == 0) return Uint8List(0);
      final buffer = frame.variableAddress(1, capacity);
      result = _exports.ghostty_terminal_continuation_buf(
        terminal.value,
        buffer,
        capacity,
        written,
      );
      checkResultCode(result, operation: 'ghostty_terminal_continuation_buf');
      final length = _memory.readU32(written);
      return Uint8List.fromList(_memory.readBytes(buffer, length));
    } finally {
      frame.release();
    }
  }

  @override
  void terminalContinuationWrite(
    LibGhosttyHandle terminal,
    ContinuationWriter writer,
  ) {
    final frame = _scratch.acquire(const []);
    Object? resultError;
    StackTrace? resultStackTrace;
    try {
      final callbackIndex = _registerCallback(
        ((int _, int data, int length) {
          try {
            return writer(Uint8List.fromList(_memory.readBytes(data, length)))
                ? 1
                : 0;
          } on Object catch (error, stackTrace) {
            _captureCallbackError(error, stackTrace);
            return 0;
          }
        }).toJS,
        ['i32', 'i32', 'i32'],
        results: ['i32'],
      );
      try {
        final pointer = frame.variableAddress(0, _layout.writerSize);
        _memory.writePtr(pointer + _layout.writerWrite, callbackIndex);
        _memory.writePtr(pointer + _layout.writerUserdata, 0);
        try {
          checkResultCode(
            _exports.ghostty_terminal_continuation_write(
              terminal.value,
              pointer,
            ),
            operation: 'ghostty_terminal_continuation_write',
          );
        } on Object catch (error, stackTrace) {
          resultError = error;
          resultStackTrace = stackTrace;
        }
      } finally {
        _releaseTableIndex(callbackIndex);
      }
    } finally {
      frame.release();
    }
    final callbackFailure = _callbackError;
    if (callbackFailure != null) {
      _callbackError = null;
      Error.throwWithStackTrace(
        callbackFailure.error,
        callbackFailure.stackTrace,
      );
    }
    if (resultError case final error?) {
      Error.throwWithStackTrace(error, resultStackTrace!);
    }
  }

  @override
  void terminalFree(LibGhosttyHandle terminal) {
    _exports.ghostty_terminal_free(terminal.value);
    final callbacks = _callbacks.remove(terminal.value);
    if (callbacks != null) {
      for (final callback in callbacks.values) {
        _releaseTableIndex(callback.$1);
      }
    }
    final buffers = _stringBuffers.remove(terminal.value);
    if (buffers != null) {
      for (final buffer in buffers.values) {
        _exports.freeBytes(buffer.$1, buffer.$2);
      }
    }
  }

  @override
  TerminalScreen terminalGetActiveScreen(LibGhosttyHandle terminal) =>
      .fromValue(_getI32(terminal, .activeScreen, 'ghostty_terminal_get'));

  @override
  int terminalGetClipboardWriteMaxBytes(LibGhosttyHandle terminal) =>
      _getU32(terminal, .clipboardWriteMaxBytes, 'ghostty_terminal_get');

  @override
  RgbColor? terminalGetColorBackground(LibGhosttyHandle terminal) =>
      _getOptionalColor(terminal, .colorBackground);

  @override
  RgbColor? terminalGetColorBackgroundDefault(LibGhosttyHandle terminal) =>
      _getOptionalColor(terminal, .colorBackgroundDefault);

  @override
  RgbColor? terminalGetColorCursor(LibGhosttyHandle terminal) =>
      _getOptionalColor(terminal, .colorCursor);

  @override
  RgbColor? terminalGetColorCursorDefault(LibGhosttyHandle terminal) =>
      _getOptionalColor(terminal, .colorCursorDefault);

  @override
  RgbColor? terminalGetColorForeground(LibGhosttyHandle terminal) =>
      _getOptionalColor(terminal, .colorForeground);

  @override
  RgbColor? terminalGetColorForegroundDefault(LibGhosttyHandle terminal) =>
      _getOptionalColor(terminal, .colorForegroundDefault);

  @override
  List<RgbColor> terminalGetColorPalette(LibGhosttyHandle terminal) =>
      _getPalette(terminal, .colorPalette);

  @override
  List<RgbColor> terminalGetColorPaletteDefault(LibGhosttyHandle terminal) =>
      _getPalette(terminal, .colorPaletteDefault);

  @override
  int terminalGetCols(LibGhosttyHandle terminal) =>
      _getU16(terminal, .cols, 'ghostty_terminal_get');

  @override
  int terminalGetContinuationMaxBytes(LibGhosttyHandle terminal) =>
      _getU32(terminal, .continuationMaxBytes, 'ghostty_terminal_get');

  @override
  bool terminalGetCursorAtPrompt(LibGhosttyHandle terminal) =>
      _getBool(terminal, .cursorAtPrompt, 'ghostty_terminal_get');

  @override
  bool terminalGetCursorPendingWrap(LibGhosttyHandle terminal) =>
      _getBool(terminal, .cursorPendingWrap, 'ghostty_terminal_get');

  @override
  Style terminalGetCursorStyle(LibGhosttyHandle terminal) =>
      _getStyle(terminal, .cursorStyle);

  @override
  bool terminalGetCursorVisible(LibGhosttyHandle terminal) =>
      _getBool(terminal, .cursorVisible, 'ghostty_terminal_get');

  @override
  int terminalGetCursorX(LibGhosttyHandle terminal) =>
      _getU16(terminal, .cursorX, 'ghostty_terminal_get');

  @override
  int terminalGetCursorY(LibGhosttyHandle terminal) =>
      _getU16(terminal, .cursorY, 'ghostty_terminal_get');

  @override
  TerminalGeometry terminalGetGeometry(LibGhosttyHandle terminal) {
    const keys = <TerminalData>[.cols, .rows, .widthPx, .heightPx];
    final frame = _scratch.acquire(const []);
    try {
      final keyPointers = frame.variableAddress(
        0,
        keys.length * _wasmPointerSize,
        alignment: wasm32PointerSize,
      );
      for (var i = 0; i < keys.length; i++) {
        _memory.writeU32(keyPointers + i * _wasmPointerSize, keys[i].value);
      }
      final values = frame.variableAddress(
        1,
        keys.length * _wasmOutputSlotSize,
        alignment: 8,
      );
      final pointers = frame.variableAddress(
        2,
        keys.length * _wasmPointerSize,
        alignment: wasm32PointerSize,
      );
      for (var i = 0; i < keys.length; i++) {
        _memory.writeU32(
          pointers + i * _wasmPointerSize,
          values + i * _wasmOutputSlotSize,
        );
      }
      final written = frame.variableAddress(
        3,
        wasm32PointerSize,
        alignment: wasm32PointerSize,
      );
      final result = _exports.ghostty_terminal_get_multi(
        terminal.value,
        keys.length,
        keyPointers,
        pointers,
        written,
      );
      checkResultCode(result, operation: 'ghostty_terminal_get_multi');
      return TerminalGeometry(
        cols: _memory.readU16(values),
        rows: _memory.readU16(values + _wasmOutputSlotSize),
        widthPx: _memory.readU32(values + 2 * _wasmOutputSlotSize),
        heightPx: _memory.readU32(values + 3 * _wasmOutputSlotSize),
      );
    } finally {
      frame.release();
    }
  }

  @override
  int terminalGetHeightPx(LibGhosttyHandle terminal) =>
      _getU32(terminal, .heightPx, 'ghostty_terminal_get');

  @override
  bool? terminalGetKittyImageMediumFile(LibGhosttyHandle terminal) =>
      _getOptionalBool(terminal, .kittyImageMediumFile);

  @override
  bool? terminalGetKittyImageMediumSharedMem(LibGhosttyHandle terminal) =>
      _getOptionalBool(terminal, .kittyImageMediumSharedMem);

  @override
  String? terminalGetKittyImageMediumTempFile(LibGhosttyHandle terminal) =>
      _getOptionalString(terminal, .kittyImageMediumTempFile);

  @override
  int? terminalGetKittyImageStorageLimit(LibGhosttyHandle terminal) =>
      _getOptionalU64(terminal, .kittyImageStorageLimit);

  @override
  int terminalGetKittyKeyboardFlags(LibGhosttyHandle terminal) =>
      _getU8(terminal, .kittyKeyboardFlags, 'ghostty_terminal_get');

  @override
  bool terminalGetMouseTracking(LibGhosttyHandle terminal) =>
      _getBool(terminal, .mouseTracking, 'ghostty_terminal_get');

  @override
  MouseShape terminalGetMouseShape(LibGhosttyHandle terminal) =>
      .fromValue(_getU32(terminal, .mouseShape, 'ghostty_terminal_get'));

  @override
  TerminalMemoryUsage terminalGetMemoryUsage(LibGhosttyHandle terminal) {
    final pointer = _allocateBytes(_layout.terminalMemoryUsageSize);
    try {
      _memory.writeU32(pointer, _layout.terminalMemoryUsageSize);
      final result = _exports.ghostty_terminal_get(
        terminal.value,
        TerminalData.memoryUsage.value,
        pointer,
      );
      checkResultCode(result, operation: 'ghostty_terminal_get');
      int read(int offset) => _memory.readU64(pointer + offset);
      return TerminalMemoryUsage(
        compressionSupported:
            _memory.readU8(
              pointer + _layout.terminalMemoryUsageCompressionSupported,
            ) !=
            0,
        primaryPages: read(_layout.terminalMemoryUsagePrimaryPages),
        primaryVirtualBytes: read(
          _layout.terminalMemoryUsagePrimaryVirtualBytes,
        ),
        primaryResidentBytes: read(
          _layout.terminalMemoryUsagePrimaryResidentBytes,
        ),
        primaryCompressedPages: read(
          _layout.terminalMemoryUsagePrimaryCompressedPages,
        ),
        primaryCompressedBytes: read(
          _layout.terminalMemoryUsagePrimaryCompressedBytes,
        ),
        primaryImageBytes: read(_layout.terminalMemoryUsagePrimaryImageBytes),
        alternatePages: read(_layout.terminalMemoryUsageAlternatePages),
        alternateVirtualBytes: read(
          _layout.terminalMemoryUsageAlternateVirtualBytes,
        ),
        alternateResidentBytes: read(
          _layout.terminalMemoryUsageAlternateResidentBytes,
        ),
        alternateCompressedPages: read(
          _layout.terminalMemoryUsageAlternateCompressedPages,
        ),
        alternateCompressedBytes: read(
          _layout.terminalMemoryUsageAlternateCompressedBytes,
        ),
        alternateImageBytes: read(
          _layout.terminalMemoryUsageAlternateImageBytes,
        ),
      );
    } finally {
      _exports.freeBytes(pointer, _layout.terminalMemoryUsageSize);
    }
  }

  @override
  String terminalGetPwd(LibGhosttyHandle terminal) =>
      _getString(terminal, .pwd);

  @override
  int terminalGetRows(LibGhosttyHandle terminal) =>
      _getU16(terminal, .rows, 'ghostty_terminal_get');

  @override
  int? terminalGetScrollbackMaxBytes(LibGhosttyHandle terminal) =>
      _getOptionalUsize(terminal, .scrollbackMaxBytes);

  @override
  int? terminalGetScrollbackMaxLines(LibGhosttyHandle terminal) =>
      _getOptionalUsize(terminal, .scrollbackMaxLines);

  @override
  int terminalGetScrollbackRows(LibGhosttyHandle terminal) =>
      _getU32(terminal, .scrollbackRows, 'ghostty_terminal_get');

  @override
  Scrollbar terminalGetScrollbar(LibGhosttyHandle terminal) {
    final pointer = _allocateBytes(_layout.scrollbarSize);
    try {
      final result = _exports.ghostty_terminal_get(
        terminal.value,
        TerminalData.scrollbar.value,
        pointer,
      );
      checkResultCode(result, operation: 'ghostty_terminal_get');
      return Scrollbar(
        total: _memory.readU32(pointer),
        offset: _memory.readU32(pointer + _layout.scrollbarOffset),
        visible: _memory.readU32(pointer + _layout.scrollbarVisible),
      );
    } finally {
      _exports.freeBytes(pointer, _layout.scrollbarSize);
    }
  }

  @override
  String terminalGetTitle(LibGhosttyHandle terminal) =>
      _getString(terminal, .title);

  @override
  int terminalGetTotalRows(LibGhosttyHandle terminal) =>
      _getU32(terminal, .totalRows, 'ghostty_terminal_get');

  @override
  bool terminalGetViewportActive(LibGhosttyHandle terminal) =>
      _getBool(terminal, .viewportActive, 'ghostty_terminal_get');

  @override
  bool terminalGetVtGround(LibGhosttyHandle terminal) =>
      _getBool(terminal, .vtGround, 'ghostty_terminal_get');

  @override
  bool terminalGetVtProcessingError(LibGhosttyHandle terminal) =>
      _getBool(terminal, .vtProcessingError, 'ghostty_terminal_get');

  @override
  int terminalGetWidthPx(LibGhosttyHandle terminal) =>
      _getU32(terminal, .widthPx, 'ghostty_terminal_get');

  @override
  bool terminalModeGet(LibGhosttyHandle terminal, int mode) {
    final pointer = _allocateBytes(_layout.terminalModeConfigSize);
    try {
      _memory.writeU16(pointer + _layout.terminalModeConfigMode, mode);
      final result = _exports.ghostty_terminal_get(
        terminal.value,
        TerminalData.mode.value,
        pointer,
      );
      checkResultCode(result, operation: 'ghostty_terminal_get');
      return _memory.readU8(pointer + _layout.terminalModeConfigValue) != 0;
    } finally {
      _exports.freeBytes(pointer, _layout.terminalModeConfigSize);
    }
  }

  @override
  void terminalModeSet(
    LibGhosttyHandle terminal,
    int mode, {
    required bool value,
  }) {
    _setMode(terminal, .mode, mode, value);
  }

  @override
  void terminalModeSetDefault(
    LibGhosttyHandle terminal,
    int mode, {
    required bool value,
  }) {
    _setMode(terminal, .modeDefault, mode, value);
  }

  @override
  LibGhosttyHandle terminalNew(int cols, int rows) {
    final out = _requirePointer(_exports.allocateOpaque());
    try {
      final result = _exports.ghostty_terminal_new(0, out, cols, rows);
      checkResultCode(result, operation: 'ghostty_terminal_new');
      return .fromAddress(_exports.ghostty_wasm_take_opaque(out));
    } finally {
      _exports.freeOpaque(out);
    }
  }

  @override
  bool terminalPasteText(
    LibGhosttyHandle terminal,
    String text, {
    required bool allowUnsafe,
  }) {
    final textBytes = utf8.encode(text);
    final mimeBytes = utf8.encode('text/plain');
    final dataPointer = _allocateBytes(
      textBytes.isEmpty ? 1 : textBytes.length,
    );
    final mimeDataPointer = _allocateBytes(mimeBytes.length);
    final mimesPointer = _allocateBytes(_layout.stringSize);
    final pastePointer = _allocateBytes(_layout.pasteSize);
    try {
      if (textBytes.isNotEmpty) _memory.writeBytes(dataPointer, textBytes);
      _memory.writeBytes(mimeDataPointer, mimeBytes);
      _memory.writePtr(mimesPointer, mimeDataPointer);
      _memory.writeU32(mimesPointer + _layout.stringLen, mimeBytes.length);
      final readerIndex = _registerCallback(
        ((int _, int mimePointer, int writerPointer) {
          try {
            if (_readString(mimePointer) != 'text/plain') {
              return 0;
            }
            final writerIndex = _memory.readPtr(
              writerPointer + _layout.writerWrite,
            );
            final writerUserdata = _memory.readPtr(
              writerPointer + _layout.writerUserdata,
            );
            return _callTable3(
              writerIndex,
              writerUserdata,
              dataPointer,
              textBytes.length,
            );
          } on Object catch (error, stackTrace) {
            _captureCallbackError(error, stackTrace);
            return 0;
          }
        }).toJS,
        ['i32', 'i32', 'i32'],
        results: ['i32'],
      );
      try {
        _memory.writeU32(
          pastePointer + _layout.pasteSizeField,
          _layout.pasteSize,
        );
        _memory.writeU32(
          pastePointer + _layout.pasteLocation,
          ClipboardLocation.standard.value,
        );
        _memory.writeU32(
          pastePointer + _layout.pasteSource,
          PasteSource.text.value,
        );
        _memory.writePtr(pastePointer + _layout.pasteMimes, mimesPointer);
        _memory.writeU32(pastePointer + _layout.pasteMimesLen, 1);
        _memory.writeU32(pastePointer + _layout.pasteReader, readerIndex);
        _memory.writeU32(pastePointer + _layout.pasteReaderUserdata, 0);
        _memory.writeU8(
          pastePointer + _layout.pasteAllowUnsafe,
          allowUnsafe ? 1 : 0,
        );
        final written = _allocateBytes(1);
        try {
          final result = _exports.ghostty_terminal_paste(
            terminal.value,
            pastePointer,
            written,
          );
          checkResultCode(result, operation: 'ghostty_terminal_paste');
          return _memory.readU8(written) != 0;
        } finally {
          _exports.freeBytes(written, 1);
        }
      } finally {
        _releaseTableIndex(readerIndex);
      }
    } finally {
      _exports.freeBytes(dataPointer, textBytes.isEmpty ? 1 : textBytes.length);
      _exports.freeBytes(mimeDataPointer, mimeBytes.length);
      _exports.freeBytes(mimesPointer, _layout.stringSize);
      _exports.freeBytes(pastePointer, _layout.pasteSize);
    }
  }

  @override
  void terminalReset(LibGhosttyHandle terminal) {
    _exports.ghostty_terminal_reset(terminal.value);
  }

  @override
  void terminalResize(
    LibGhosttyHandle terminal,
    int cols,
    int rows,
    int cellWidthPx,
    int cellHeightPx,
  ) {
    int result() => _exports.ghostty_terminal_resize(
      terminal.value,
      cols,
      rows,
      cellWidthPx,
      cellHeightPx,
    );
    final code = _callbacks.isNotEmpty && _callbackError != null
        ? _runNestedCallbackOperation(result)
        : result();
    checkResultCode(code, operation: 'ghostty_terminal_resize');
    final failure = _callbackError;
    if (failure != null) {
      _callbackError = null;
      Error.throwWithStackTrace(failure.error, failure.stackTrace);
    }
  }

  @override
  void terminalScrollViewport(
    LibGhosttyHandle terminal,
    TerminalScrollViewportTag tag,
    int delta,
  ) {
    final frame = _scratch.acquire(const []);
    try {
      final pointer = frame.variableAddress(
        0,
        _layout.scrollViewportSize,
        alignment: wasm32PointerSize,
      );
      _memory.writeU32(pointer, tag.value);
      switch (tag) {
        case .row:
          _memory.writeU32(pointer + _layout.scrollViewportDelta, delta);
        case .delta:
          _memory.writeI32(pointer + _layout.scrollViewportDelta, delta);
        case .top || .bottom:
          _memory.writeI32(pointer + _layout.scrollViewportDelta, 0);
      }
      _exports.ghostty_terminal_scroll_viewport(terminal.value, pointer);
    } finally {
      frame.release();
    }
  }

  @override
  void terminalSetApcBufferLimit(LibGhosttyHandle terminal, int? bytes) {
    _setU32(terminal, .apcMaxBytes, bytes);
  }

  @override
  void terminalSetClipboardWriteMaxBytes(
    LibGhosttyHandle terminal,
    int? bytes,
  ) {
    _setU32(terminal, .clipboardWriteMaxBytes, bytes);
  }

  @override
  void terminalSetColorBackground(LibGhosttyHandle terminal, RgbColor? color) {
    _setColor(terminal, .colorBackground, color);
  }

  @override
  void terminalSetColorCursor(LibGhosttyHandle terminal, RgbColor? color) {
    _setColor(terminal, .colorCursor, color);
  }

  @override
  void terminalSetColorForeground(LibGhosttyHandle terminal, RgbColor? color) {
    _setColor(terminal, .colorForeground, color);
  }

  @override
  void terminalSetColorPalette(
    LibGhosttyHandle terminal,
    List<RgbColor>? palette,
  ) {
    if (palette == null) {
      _setNull(terminal, .colorPalette);
      return;
    }
    if (palette.length != 256) {
      throw ArgumentError.value(
        palette.length,
        'palette',
        'must contain 256 colors',
      );
    }
    final size = 256 * _layout.colorRgbSize;
    final pointer = _allocateBytes(size);
    try {
      for (var i = 0; i < palette.length; i++) {
        _writeRgb(pointer + i * _layout.colorRgbSize, palette[i]);
      }
      final result = _exports.ghostty_terminal_set(
        terminal.value,
        TerminalOption.colorPalette.value,
        pointer,
      );
      checkResultCode(result, operation: 'ghostty_terminal_set');
    } finally {
      _exports.freeBytes(pointer, size);
    }
  }

  @override
  void terminalSetContinuationMaxBytes(LibGhosttyHandle terminal, int? bytes) {
    _setU32(terminal, .continuationMaxBytes, bytes);
  }

  @override
  void terminalSetDefaultCursorBlink(
    LibGhosttyHandle terminal, {
    bool? blinking,
  }) {
    _setBool(terminal, .defaultCursorBlink, blinking);
  }

  @override
  void terminalSetDefaultCursorShape(
    LibGhosttyHandle terminal,
    TerminalCursorShape? shape,
  ) {
    _setI32(terminal, .defaultCursorStyle, shape?.value);
  }

  @override
  void terminalSetGlyphProtocol(
    LibGhosttyHandle terminal, {
    required bool enabled,
  }) {
    _setBool(terminal, .glyphProtocol, enabled);
  }

  @override
  void terminalSetKittyApcBufferLimit(LibGhosttyHandle terminal, int? bytes) {
    _setU32(terminal, .apcMaxBytesKitty, bytes);
  }

  @override
  void terminalSetKittyImageMediumFile(
    LibGhosttyHandle terminal, {
    bool? enabled,
  }) {
    _setBool(terminal, .kittyImageMediumFile, enabled);
  }

  @override
  void terminalSetKittyImageMediumSharedMem(
    LibGhosttyHandle terminal, {
    bool? enabled,
  }) {
    _setBool(terminal, .kittyImageMediumSharedMem, enabled);
  }

  @override
  void terminalSetKittyImageMediumTempFile(
    LibGhosttyHandle terminal,
    String? directory,
  ) {
    _setString(terminal, .kittyImageMediumTempFile, directory);
  }

  @override
  void terminalSetKittyImageStorageLimit(
    LibGhosttyHandle terminal,
    int? limit,
  ) {
    _setU64(terminal, .kittyImageStorageLimit, limit);
  }

  @override
  void terminalSetOnBell(LibGhosttyHandle terminal, VoidCallback? callback) {
    _setCallback(
      terminal,
      .bell,
      callback,
      (reuseIndex) => _registerCallback(
        ((int _, int _) {
          try {
            callback!();
          } on Object catch (error, stackTrace) {
            _captureCallbackError(error, stackTrace);
          }
        }).toJS,
        ['i32', 'i32'],
        reuseIndex: reuseIndex,
      ),
    );
  }

  @override
  void terminalSetOnClipboardRead(
    LibGhosttyHandle terminal,
    ClipboardReadCallback? callback,
  ) {
    _setCallback(
      terminal,
      .clipboardRead,
      callback,
      (reuseIndex) => _registerCallback(
        ((int _, int _, int readPointer) {
          try {
            if (_memory.readU32(readPointer) < _layout.clipboardReadSize) {
              return;
            }
            final mimesPointer = _memory.readPtr(
              readPointer + _layout.clipboardReadMimes,
            );
            final mimesLength = _memory.readU32(
              readPointer + _layout.clipboardReadMimesLen,
            );
            final request = ClipboardReadRequest(
              location: .fromValue(
                _memory.readU32(readPointer + _layout.clipboardReadLocation),
              ),
              mimes: [
                for (var i = 0; i < mimesLength; i++)
                  _readString(mimesPointer + i * _layout.stringSize),
              ],
              list:
                  _memory.readU8(readPointer + _layout.clipboardReadList) != 0,
              name: _readString(readPointer + _layout.clipboardReadName),
              granted:
                  _memory.readU8(readPointer + _layout.clipboardReadGranted) !=
                  0,
              canRemember:
                  _memory.readU8(
                    readPointer + _layout.clipboardReadCanRemember,
                  ) !=
                  0,
            );
            _replyClipboardRead(readPointer, callback!(request));
          } on Object catch (error, stackTrace) {
            _captureCallbackError(error, stackTrace);
            _replyClipboardRead(
              readPointer,
              const ClipboardReadReply(result: .ioError),
            );
          }
        }).toJS,
        ['i32', 'i32', 'i32'],
        reuseIndex: reuseIndex,
      ),
    );
  }

  @override
  void terminalSetOnClipboardWrite(
    LibGhosttyHandle terminal,
    ClipboardWriteCallback? callback,
  ) {
    _setCallback(
      terminal,
      .clipboardWrite,
      callback,
      (reuseIndex) => _registerCallback(
        ((int _, int _, int writePointer) {
          try {
            if (_memory.readU32(writePointer) < _layout.clipboardWriteSize) {
              return;
            }
            final contentsPointer = _memory.readPtr(
              writePointer + _layout.clipboardWriteContents,
            );
            final contentsLength = _memory.readU32(
              writePointer + _layout.clipboardWriteContentsLen,
            );
            final contents = <ClipboardContent>[
              for (var i = 0; i < contentsLength; i++)
                _readClipboardContent(
                  contentsPointer + i * _layout.clipboardContentSize,
                ),
            ];
            final result = callback!(
              ClipboardWrite(
                location: .fromValue(
                  _memory.readU32(
                    writePointer + _layout.clipboardWriteLocation,
                  ),
                ),
                contents: List.unmodifiable(contents),
                name: _readString(writePointer + _layout.clipboardWriteName),
                granted:
                    _memory.readU8(
                      writePointer + _layout.clipboardWriteGranted,
                    ) !=
                    0,
                canRemember:
                    _memory.readU8(
                      writePointer + _layout.clipboardWriteCanRemember,
                    ) !=
                    0,
              ),
            );
            _replyClipboardWrite(writePointer, result);
          } on Object catch (error, stackTrace) {
            _captureCallbackError(error, stackTrace);
            _replyClipboardWrite(writePointer, .ioError);
          }
        }).toJS,
        ['i32', 'i32', 'i32'],
        reuseIndex: reuseIndex,
      ),
    );
  }

  @override
  void terminalSetOnColorScheme(
    LibGhosttyHandle terminal,
    ValueGetter<ColorScheme?>? callback,
  ) {
    _setCallback(
      terminal,
      .colorScheme,
      callback,
      (reuseIndex) => _registerCallback(
        ((int _, int _, int outPointer) {
          try {
            final value = callback!();
            if (value == null) return 0;
            _memory.writeU32(outPointer, value.value);
            return 1;
          } on Object catch (error, stackTrace) {
            _captureCallbackError(error, stackTrace);
            return 0;
          }
        }).toJS,
        ['i32', 'i32', 'i32'],
        results: ['i32'],
        reuseIndex: reuseIndex,
      ),
    );
  }

  @override
  void terminalSetOnDesktopNotification(
    LibGhosttyHandle terminal,
    DesktopNotificationCallback? callback,
  ) {
    _setCallback(
      terminal,
      .desktopNotification,
      callback,
      (reuseIndex) => _registerCallback(
        ((int _, int _, int pointer) {
          try {
            if (_memory.readU32(pointer) < _layout.desktopNotificationSize) {
              return;
            }
            callback!(
              DesktopNotification(
                title: _readString(pointer + _layout.desktopNotificationTitle),
                body: _readString(pointer + _layout.desktopNotificationBody),
              ),
            );
          } on Object catch (error, stackTrace) {
            _captureCallbackError(error, stackTrace);
          }
        }).toJS,
        ['i32', 'i32', 'i32'],
        reuseIndex: reuseIndex,
      ),
    );
  }

  @override
  void terminalSetOnDeviceAttributes(
    LibGhosttyHandle terminal,
    ValueGetter<DeviceAttributesResponse?>? callback,
  ) {
    _setCallback(
      terminal,
      .deviceAttributes,
      callback,
      (reuseIndex) => _registerCallback(
        ((int _, int _, int outPointer) {
          try {
            final value = callback!();
            if (value == null) return 0;
            _memory.writeU16(outPointer, value.primary.conformanceLevel);
            final featureCount = value.primary.features.length.clamp(0, 64);
            for (var i = 0; i < featureCount; i++) {
              _memory.writeU16(
                outPointer + _layout.deviceAttrsFeatures + i * 2,
                value.primary.features[i],
              );
            }
            _memory.writeU32(
              outPointer + _layout.deviceAttrsNumFeatures,
              featureCount,
            );
            _memory.writeU16(
              outPointer + _layout.deviceAttrsDeviceType,
              value.secondary.deviceType,
            );
            _memory.writeU16(
              outPointer + _layout.deviceAttrsFirmwareVersion,
              value.secondary.firmwareVersion,
            );
            _memory.writeU16(
              outPointer + _layout.deviceAttrsRomCartridge,
              value.secondary.romCartridge,
            );
            _memory.writeU32(
              outPointer + _layout.deviceAttrsUnitId,
              value.tertiary.unitId,
            );
            return 1;
          } on Object catch (error, stackTrace) {
            _captureCallbackError(error, stackTrace);
            return 0;
          }
        }).toJS,
        ['i32', 'i32', 'i32'],
        results: ['i32'],
        reuseIndex: reuseIndex,
      ),
    );
  }

  @override
  void terminalSetOnEnquiry(
    LibGhosttyHandle terminal,
    ValueGetter<Uint8List>? callback,
  ) {
    if (callback == null) {
      _setNull(terminal, TerminalOption.enquiry);
      _clearCallback(terminal, TerminalOption.enquiry);
      _freeStringBuffer(terminal.value, TerminalOption.enquiry);
      return;
    }
    _setCallback(
      terminal,
      .enquiry,
      callback,
      (reuseIndex) => _registerCallback(
        ((int returnPointer, int terminalPointer, int _) {
          try {
            final value = callback();
            _replaceStringBuffer(terminalPointer, .enquiry, value);
            final buffer =
                _stringBuffers[terminalPointer]![TerminalOption.enquiry]!;
            _memory.writeU32(returnPointer, buffer.$1);
            _memory.writeU32(returnPointer + _layout.stringLen, buffer.$2);
          } on Object catch (error, stackTrace) {
            _captureCallbackError(error, stackTrace);
            _memory.writeU32(returnPointer, 0);
            _memory.writeU32(returnPointer + _layout.stringLen, 0);
          }
        }).toJS,
        ['i32', 'i32', 'i32'],
        reuseIndex: reuseIndex,
      ),
    );
  }

  @override
  void terminalSetOnProgressReport(
    LibGhosttyHandle terminal,
    TerminalProgressCallback? callback,
  ) {
    _setCallback(
      terminal,
      .progressReport,
      callback,
      (reuseIndex) => _registerCallback(
        ((int _, int _, int pointer) {
          try {
            if (_memory.readU32(pointer) < _layout.terminalProgressReportSize) {
              return;
            }
            final rawProgress = _memory.readU8(
              pointer + _layout.terminalProgressReportProgress,
            );
            callback!(
              TerminalProgress(
                state: .fromValue(
                  _memory.readU32(
                    pointer + _layout.terminalProgressReportState,
                  ),
                ),
                progress: rawProgress == 0xff ? null : rawProgress,
              ),
            );
          } on Object catch (error, stackTrace) {
            _captureCallbackError(error, stackTrace);
          }
        }).toJS,
        ['i32', 'i32', 'i32'],
        reuseIndex: reuseIndex,
      ),
    );
  }

  @override
  void terminalSetOnPwdChanged(
    LibGhosttyHandle terminal,
    VoidCallback? callback,
  ) {
    _setCallback(
      terminal,
      .pwdChanged,
      callback,
      (reuseIndex) => _registerCallback(
        ((int _, int _) {
          try {
            callback!();
          } on Object catch (error, stackTrace) {
            _captureCallbackError(error, stackTrace);
          }
        }).toJS,
        ['i32', 'i32'],
        reuseIndex: reuseIndex,
      ),
    );
  }

  @override
  void terminalSetOnSize(
    LibGhosttyHandle terminal,
    ValueGetter<TerminalSizeInfo?>? callback,
  ) {
    _setCallback(
      terminal,
      .size,
      callback,
      (reuseIndex) => _registerCallback(
        ((int _, int _, int outPointer) {
          try {
            final value = callback!();
            if (value == null) return 0;
            _memory.writeU16(outPointer, value.rows);
            _memory.writeU16(
              outPointer + _layout.sizeReportColumns,
              value.columns,
            );
            _memory.writeU32(
              outPointer + _layout.sizeReportCellWidth,
              value.cellWidth,
            );
            _memory.writeU32(
              outPointer + _layout.sizeReportCellHeight,
              value.cellHeight,
            );
            return 1;
          } on Object catch (error, stackTrace) {
            _captureCallbackError(error, stackTrace);
            return 0;
          }
        }).toJS,
        ['i32', 'i32', 'i32'],
        results: ['i32'],
        reuseIndex: reuseIndex,
      ),
    );
  }

  @override
  void terminalSetOnTitleChanged(
    LibGhosttyHandle terminal,
    VoidCallback? callback,
  ) {
    _setCallback(
      terminal,
      .titleChanged,
      callback,
      (reuseIndex) => _registerCallback(
        ((int _, int _) {
          try {
            callback!();
          } on Object catch (error, stackTrace) {
            _captureCallbackError(error, stackTrace);
          }
        }).toJS,
        ['i32', 'i32'],
        reuseIndex: reuseIndex,
      ),
    );
  }

  @override
  void terminalSetOnUnknownSequence(
    LibGhosttyHandle terminal,
    TerminalUnknownSequenceCallback? callback,
  ) {
    _setCallback(
      terminal,
      .unknownSequence,
      callback,
      (reuseIndex) => _registerCallback(
        ((int _, int _, int pointer) {
          try {
            final tag = TerminalUnknownSequenceTag.fromValue(
              _memory.readU32(pointer + _layout.unknownSequenceTag),
            );
            final value = pointer + _layout.unknownSequenceValue;
            final (contentOffset, truncatedOffset, terminator) = switch (tag) {
              .apc => (
                _layout.unknownStringSequenceContent,
                _layout.unknownStringSequenceTruncated,
                null,
              ),
              .osc => (
                _layout.unknownOscSequenceContent,
                _layout.unknownOscSequenceTruncated,
                OscTerminator.fromValue(
                  _memory.readU32(value + _layout.unknownOscSequenceTerminator),
                ),
              ),
            };
            final content = value + contentOffset;
            final contentPointer = _memory.readPtr(content);
            final contentLength = _memory.readU32(content + _layout.stringLen);
            callback!(
              TerminalUnknownSequence(
                tag: tag,
                content: contentPointer == 0 || contentLength == 0
                    ? Uint8List(0)
                    : Uint8List.fromList(
                        _memory.readBytes(contentPointer, contentLength),
                      ),
                truncated: _memory.readU8(value + truncatedOffset) != 0,
                terminator: terminator,
              ),
            );
          } on Object catch (error, stackTrace) {
            _captureCallbackError(error, stackTrace);
          }
        }).toJS,
        ['i32', 'i32', 'i32'],
        reuseIndex: reuseIndex,
      ),
    );
  }

  @override
  void terminalSetOnWritePty(
    LibGhosttyHandle terminal,
    ValueSetter<Uint8List>? callback,
  ) {
    _setCallback(
      terminal,
      .writePty,
      callback,
      (reuseIndex) => _registerCallback(
        ((int _, int _, int pointer, int length) {
          try {
            callback!(Uint8List.fromList(_memory.readBytes(pointer, length)));
          } on Object catch (error, stackTrace) {
            _captureCallbackError(error, stackTrace);
          }
        }).toJS,
        ['i32', 'i32', 'i32', 'i32'],
        reuseIndex: reuseIndex,
      ),
    );
  }

  @override
  void terminalSetOnXtversion(
    LibGhosttyHandle terminal,
    ValueGetter<String>? callback,
  ) {
    if (callback == null) {
      _setNull(terminal, TerminalOption.xtversion);
      _clearCallback(terminal, TerminalOption.xtversion);
      _freeStringBuffer(terminal.value, TerminalOption.xtversion);
      return;
    }
    _setCallback(
      terminal,
      .xtversion,
      callback,
      (reuseIndex) => _registerCallback(
        ((int returnPointer, int terminalPointer, int _) {
          try {
            _replaceStringBuffer(
              terminalPointer,
              .xtversion,
              utf8.encode(callback()),
            );
            final buffer =
                _stringBuffers[terminalPointer]![TerminalOption.xtversion]!;
            _memory.writeU32(returnPointer, buffer.$1);
            _memory.writeU32(returnPointer + _layout.stringLen, buffer.$2);
          } on Object catch (error, stackTrace) {
            _captureCallbackError(error, stackTrace);
            _memory.writeU32(returnPointer, 0);
            _memory.writeU32(returnPointer + _layout.stringLen, 0);
          }
        }).toJS,
        ['i32', 'i32', 'i32'],
        reuseIndex: reuseIndex,
      ),
    );
  }

  @override
  void terminalSetPwd(LibGhosttyHandle terminal, String? pwd) {
    _setString(terminal, .pwd, pwd);
  }

  @override
  void terminalSetScrollbackMaxBytes(LibGhosttyHandle terminal, int? bytes) {
    _setU32(terminal, .scrollbackMaxBytes, bytes);
  }

  @override
  void terminalSetScrollbackMaxLines(LibGhosttyHandle terminal, int? lines) {
    _setU32(terminal, .scrollbackMaxLines, lines);
  }

  @override
  void terminalSetResizePullScrollback(
    LibGhosttyHandle terminal, {
    required bool? value,
  }) {
    _setBool(terminal, .resizePullScrollback, value);
  }

  @override
  void terminalSetXtChecksumReport(
    LibGhosttyHandle terminal, {
    required bool enabled,
  }) {
    _setBool(terminal, .xtChecksumReport, enabled);
  }

  @override
  void terminalSetXtChecksumExtension(LibGhosttyHandle terminal, int? value) {
    if (value == null) {
      _setNull(terminal, .xtChecksumExtension);
      return;
    }
    RangeError.checkValueInInterval(value, 0, 31, 'value');
    final pointer = _allocateBytes(1);
    try {
      _memory.writeU8(pointer, value);
      final result = _exports.ghostty_terminal_set(
        terminal.value,
        TerminalOption.xtChecksumExtension.value,
        pointer,
      );
      checkResultCode(result, operation: 'ghostty_terminal_set');
    } finally {
      _exports.freeBytes(pointer, 1);
    }
  }

  @override
  void terminalSetTerminfoName(LibGhosttyHandle terminal, String? name) {
    _setString(terminal, .terminfoName, name);
  }

  @override
  void terminalSetTitle(LibGhosttyHandle terminal, String? title) {
    _setString(terminal, .title, title);
  }

  @override
  void terminalSetTitleReport(
    LibGhosttyHandle terminal, {
    required bool enabled,
  }) {
    _setBool(terminal, .titleReport, enabled);
  }

  @override
  void terminalSetUnknownSequenceMaxBytes(
    LibGhosttyHandle terminal,
    int? bytes,
  ) {
    _setU32(terminal, .unknownMaxBytes, bytes);
  }

  @override
  void terminalVtWrite(LibGhosttyHandle terminal, Uint8List data) {
    if (data.isEmpty) return;
    final frame = _scratch.acquire(const []);
    try {
      final pointer = frame.variableAddress(0, data.length);
      _memory.writeBytes(pointer, data);
      if (_callbacks.isEmpty || _callbackError != null) {
        void operation() {
          _exports.ghostty_terminal_vt_write(
            terminal.value,
            pointer,
            data.length,
          );
        }

        if (_callbackError != null) {
          _runNestedCallbackOperation(operation);
        } else {
          operation();
        }
      } else {
        _exports.ghostty_terminal_vt_write(
          terminal.value,
          pointer,
          data.length,
        );
        final failure = _callbackError;
        if (failure != null) {
          _callbackError = null;
          Error.throwWithStackTrace(failure.error, failure.stackTrace);
        }
      }
    } finally {
      frame.release();
    }
  }

  @override
  int? terminalWriteUntilGround(LibGhosttyHandle terminal, Uint8List data) {
    final frame = _scratch.acquire(const []);
    try {
      final pointer = data.isEmpty ? 0 : frame.variableAddress(0, data.length);
      if (data.isNotEmpty) _memory.writeBytes(pointer, data);
      final consumed = frame.variableAddress(
        1,
        _wasmSizeSize,
        alignment: _wasmSizeSize,
      );
      var reachedGround = true;
      void operation() {
        final result = _exports.ghostty_terminal_vt_write_until_ground(
          terminal.value,
          pointer,
          data.length,
          consumed,
        );
        if (result == Result.noValue.value) {
          reachedGround = false;
          return;
        }
        checkResultCode(
          result,
          operation: 'ghostty_terminal_vt_write_until_ground',
        );
      }

      if (_callbacks.isEmpty || _callbackError != null) {
        if (_callbackError != null) {
          _runNestedCallbackOperation(operation);
        } else {
          operation();
        }
      } else {
        operation();
        final failure = _callbackError;
        if (failure != null) {
          _callbackError = null;
          Error.throwWithStackTrace(failure.error, failure.stackTrace);
        }
      }
      final result = _memory.readU32(consumed);
      return reachedGround ? result : null;
    } finally {
      frame.release();
    }
  }

  int _allocateBytes(int size) => _requirePointer(_exports.allocateBytes(size));

  int _allocateSize() {
    final pointer = _requirePointer(_exports.allocateBytes(4));
    if (pointer % _wasmSizeSize != 0) {
      _exports.freeBytes(pointer, 4);
      throw StateError('libghostty WASM allocator returned misaligned memory.');
    }
    return pointer;
  }

  (int, int, int) _allocateUtf8(String value) {
    final bytes = utf8.encode(value);
    final allocationLength = bytes.isEmpty ? 1 : bytes.length;
    final pointer = _allocateBytes(allocationLength);
    if (bytes.isNotEmpty) _memory.writeBytes(pointer, bytes);
    return (pointer, bytes.length, allocationLength);
  }

  void _callTable2(int index, int first, int second) {
    final function = _table.get(index)! as JSFunction;
    function.callAsFunction(null, first.toJS, second.toJS);
  }

  int _callTable3(int index, int first, int second, int third) {
    final function = _table.get(index)! as JSFunction;
    return (function.callAsFunction(null, first.toJS, second.toJS, third.toJS)!
            as JSNumber)
        .toDartInt;
  }

  void _captureCallbackError(Object error, StackTrace stackTrace) {
    _callbackError ??= (error: error, stackTrace: stackTrace);
  }

  void _clearCallback(LibGhosttyHandle terminal, TerminalOption option) {
    final map = _callbacks[terminal.value];
    final previous = map?.remove(option);
    if (previous != null) _releaseTableIndex(previous.$1);
    if (map != null && map.isEmpty) _callbacks.remove(terminal.value);
  }

  void _freeStringBuffer(int terminal, TerminalOption option) {
    final map = _stringBuffers[terminal];
    final previous = map?.remove(option);
    if (previous != null) {
      _exports.freeBytes(previous.$1, previous.$2);
    }
    if (map != null && map.isEmpty) _stringBuffers.remove(terminal);
  }

  bool _getBool(
    LibGhosttyHandle terminal,
    TerminalData data,
    String operation,
  ) {
    return _getU8(terminal, data, operation) != 0;
  }

  int _getI32(LibGhosttyHandle terminal, TerminalData data, String operation) {
    final pointer = _allocateSize();
    try {
      final result = _exports.ghostty_terminal_get(
        terminal.value,
        data.value,
        pointer,
      );
      checkResultCode(result, operation: operation);
      return _memory.readI32(pointer);
    } finally {
      _exports.freeBytes(pointer, 4);
    }
  }

  bool? _getOptionalBool(LibGhosttyHandle terminal, TerminalData data) {
    final pointer = _requirePointer(_exports.allocateBytes(1));
    try {
      final result = _exports.ghostty_terminal_get(
        terminal.value,
        data.value,
        pointer,
      );
      if (!checkOptionalCode(result, operation: 'ghostty_terminal_get')) {
        return null;
      }
      return _memory.readU8(pointer) != 0;
    } finally {
      _exports.freeBytes(pointer, 1);
    }
  }

  RgbColor? _getOptionalColor(LibGhosttyHandle terminal, TerminalData data) {
    final pointer = _allocateBytes(_layout.colorRgbSize);
    try {
      final result = _exports.ghostty_terminal_get(
        terminal.value,
        data.value,
        pointer,
      );
      if (!checkOptionalCode(result, operation: 'ghostty_terminal_get')) {
        return null;
      }
      return _readRgb(pointer);
    } finally {
      _exports.freeBytes(pointer, _layout.colorRgbSize);
    }
  }

  String? _getOptionalString(LibGhosttyHandle terminal, TerminalData data) {
    final pointer = _allocateBytes(_layout.stringSize);
    try {
      final result = _exports.ghostty_terminal_get(
        terminal.value,
        data.value,
        pointer,
      );
      if (!checkOptionalCode(result, operation: 'ghostty_terminal_get')) {
        return null;
      }
      return _readString(pointer);
    } finally {
      _exports.freeBytes(pointer, _layout.stringSize);
    }
  }

  int? _getOptionalU64(LibGhosttyHandle terminal, TerminalData data) {
    final pointer = _allocateBytes(8);
    try {
      final result = _exports.ghostty_terminal_get(
        terminal.value,
        data.value,
        pointer,
      );
      if (!checkOptionalCode(result, operation: 'ghostty_terminal_get')) {
        return null;
      }
      return _memory.readU64(pointer);
    } finally {
      _exports.freeBytes(pointer, 8);
    }
  }

  int? _getOptionalUsize(LibGhosttyHandle terminal, TerminalData data) {
    final pointer = _allocateSize();
    try {
      final result = _exports.ghostty_terminal_get(
        terminal.value,
        data.value,
        pointer,
      );
      if (!checkOptionalCode(result, operation: 'ghostty_terminal_get')) {
        return null;
      }
      return _memory.readU32(pointer);
    } finally {
      _exports.freeBytes(pointer, 4);
    }
  }

  List<RgbColor> _getPalette(LibGhosttyHandle terminal, TerminalData data) {
    final size = 256 * _layout.colorRgbSize;
    final pointer = _allocateBytes(size);
    try {
      final result = _exports.ghostty_terminal_get(
        terminal.value,
        data.value,
        pointer,
      );
      checkResultCode(result, operation: 'ghostty_terminal_get');
      return [
        for (var i = 0; i < 256; i++)
          _readRgb(pointer + i * _layout.colorRgbSize),
      ];
    } finally {
      _exports.freeBytes(pointer, size);
    }
  }

  String _getString(LibGhosttyHandle terminal, TerminalData data) {
    final pointer = _allocateBytes(_layout.stringSize);
    try {
      final result = _exports.ghostty_terminal_get(
        terminal.value,
        data.value,
        pointer,
      );
      checkResultCode(result, operation: 'ghostty_terminal_get');
      return _readString(pointer);
    } finally {
      _exports.freeBytes(pointer, _layout.stringSize);
    }
  }

  Style _getStyle(LibGhosttyHandle terminal, TerminalData data) {
    final pointer = _allocateBytes(_layout.styleSize);
    try {
      _memory.writeU32(pointer, _layout.styleSize);
      final result = _exports.ghostty_terminal_get(
        terminal.value,
        data.value,
        pointer,
      );
      checkResultCode(result, operation: 'ghostty_terminal_get');
      return _readStyle(pointer);
    } finally {
      _exports.freeBytes(pointer, _layout.styleSize);
    }
  }

  int _getU16(LibGhosttyHandle terminal, TerminalData data, String operation) {
    final pointer = _allocateSize();
    try {
      final result = _exports.ghostty_terminal_get(
        terminal.value,
        data.value,
        pointer,
      );
      checkResultCode(result, operation: operation);
      return _memory.readU16(pointer);
    } finally {
      _exports.freeBytes(pointer, 4);
    }
  }

  int _getU32(LibGhosttyHandle terminal, TerminalData data, String operation) {
    final pointer = _allocateSize();
    try {
      final result = _exports.ghostty_terminal_get(
        terminal.value,
        data.value,
        pointer,
      );
      checkResultCode(result, operation: operation);
      return _memory.readU32(pointer);
    } finally {
      _exports.freeBytes(pointer, 4);
    }
  }

  int _getU8(LibGhosttyHandle terminal, TerminalData data, String operation) {
    final pointer = _requirePointer(_exports.allocateBytes(1));
    try {
      final result = _exports.ghostty_terminal_get(
        terminal.value,
        data.value,
        pointer,
      );
      checkResultCode(result, operation: operation);
      return _memory.readU8(pointer);
    } finally {
      _exports.freeBytes(pointer, 1);
    }
  }

  ClipboardContent _readClipboardContent(int pointer) {
    final mime = pointer + _layout.clipboardContentMime;
    final data = pointer + _layout.clipboardContentData;
    final mimePointer = _memory.readPtr(mime);
    final mimeLength = _memory.readU32(mime + _layout.stringLen);
    final dataPointer = _memory.readPtr(data);
    final dataLength = _memory.readU32(data + _layout.stringLen);
    return ClipboardContent(
      mime: mimeLength == 0
          ? ''
          : utf8.decode(_memory.readBytes(mimePointer, mimeLength)),
      data: dataLength == 0
          ? Uint8List(0)
          : Uint8List.fromList(_memory.readBytes(dataPointer, dataLength)),
    );
  }

  RawColor _readRawColor(int pointer) => (
    tag: .fromValue(_memory.readU32(pointer)),
    palette: _memory.readU8(pointer + _layout.styleColorR),
    r: _memory.readU8(pointer + _layout.styleColorR),
    g: _memory.readU8(pointer + _layout.styleColorG),
    b: _memory.readU8(pointer + _layout.styleColorB),
  );

  RgbColor _readRgb(int pointer) => RgbColor(
    _memory.readU8(pointer + _layout.colorRgbR),
    _memory.readU8(pointer + _layout.colorRgbG),
    _memory.readU8(pointer + _layout.colorRgbB),
  );

  String _readString(int pointer) {
    final data = _memory.readPtr(pointer);
    final length = _memory.readU32(pointer + _layout.stringLen);
    if (data == 0 || length == 0) return '';
    return utf8.decode(_memory.readBytes(data, length));
  }

  Style _readStyle(int pointer) {
    final underlineColor = _readRawColor(pointer + _layout.styleUnderlineColor);
    return Style(
      foreground: cellColorFromRaw(_readRawColor(pointer + _layout.styleFg)),
      background: cellColorFromRaw(_readRawColor(pointer + _layout.styleBg)),
      underlineColor: switch (underlineColor.tag) {
        .rgb || .palette => cellColorFromRaw(underlineColor),
        .none => null,
      },
      bold: _memory.readU8(pointer + _layout.styleBold) != 0,
      italic: _memory.readU8(pointer + _layout.styleItalic) != 0,
      faint: _memory.readU8(pointer + _layout.styleFaint) != 0,
      blink: _memory.readU8(pointer + _layout.styleBlink) != 0,
      inverse: _memory.readU8(pointer + _layout.styleInverse) != 0,
      invisible: _memory.readU8(pointer + _layout.styleInvisible) != 0,
      strikethrough: _memory.readU8(pointer + _layout.styleStrikethrough) != 0,
      overline: _memory.readU8(pointer + _layout.styleOverline) != 0,
      underline: .fromValue(_memory.readI32(pointer + _layout.styleUnderline)),
    );
  }

  int _registerCallback(
    JSFunction function,
    List<String> params, {
    List<String> results = const [],
    int? reuseIndex,
  }) {
    final wasmFunction = wrapJsAsWasmFunction(function, params, results);
    final index =
        reuseIndex ??
        (_freeTableIndices.isEmpty
            ? _table.grow(1)
            : _freeTableIndices.removeLast());
    _table.set(index, wasmFunction);
    return index;
  }

  void _releaseTableIndex(int index) {
    _table.set(index);
    _freeTableIndices.add(index);
  }

  void _replaceStringBuffer(
    int terminal,
    TerminalOption option,
    List<int> bytes,
  ) {
    final map = _stringBuffers.putIfAbsent(terminal, () => {});
    final previous = map[option];
    final allocationLength = bytes.isEmpty ? 1 : bytes.length;
    final pointer = _requirePointer(_exports.allocateBytes(allocationLength));
    _memory.writeBytes(pointer, bytes);
    if (previous != null) {
      _exports.freeBytes(previous.$1, previous.$2);
    }
    map[option] = (pointer, allocationLength);
  }

  void _replyClipboardRead(int pointer, ClipboardReadReply value) {
    final replyPointer = _allocateBytes(_layout.clipboardReadReplySize);
    final contentPointer = _allocateBytes(
      value.contents.isEmpty
          ? 1
          : value.contents.length * _layout.clipboardContentSize,
    );
    final availablePointer = _allocateBytes(
      value.available.isEmpty ? 1 : value.available.length * _layout.stringSize,
    );
    final allocations = <(int, int)>[];
    try {
      for (var i = 0; i < value.contents.length; i++) {
        final content = value.contents[i];
        final contentOffset = contentPointer + i * _layout.clipboardContentSize;
        final mime = _allocateUtf8(content.mime);
        final data = _allocateBytes(
          content.data.isEmpty ? 1 : content.data.length,
        );
        allocations
          ..add((mime.$1, mime.$3))
          ..add((data, content.data.isEmpty ? 1 : content.data.length));
        _memory.writeBytes(data, content.data);
        _memory.writePtr(contentOffset + _layout.clipboardContentMime, mime.$1);
        _memory.writeU32(contentOffset + _layout.stringLen, mime.$2);
        _memory.writePtr(contentOffset + _layout.clipboardContentData, data);
        _memory.writeU32(
          contentOffset + _layout.clipboardContentData + _layout.stringLen,
          content.data.length,
        );
      }
      for (var i = 0; i < value.available.length; i++) {
        final available = _allocateUtf8(value.available[i]);
        allocations.add((available.$1, available.$3));
        final offset = availablePointer + i * _layout.stringSize;
        _memory.writePtr(offset, available.$1);
        _memory.writeU32(offset + _layout.stringLen, available.$2);
      }
      _memory.writeU32(
        replyPointer + _layout.clipboardReadReplySizeField,
        _layout.clipboardReadReplySize,
      );
      _memory.writeU32(
        replyPointer + _layout.clipboardReadReplyResult,
        value.result.value,
      );
      _memory.writePtr(
        replyPointer + _layout.clipboardReadReplyContents,
        contentPointer,
      );
      _memory.writeU32(
        replyPointer + _layout.clipboardReadReplyContentsLen,
        value.contents.length,
      );
      _memory.writePtr(
        replyPointer + _layout.clipboardReadReplyAvailable,
        availablePointer,
      );
      _memory.writeU32(
        replyPointer + _layout.clipboardReadReplyAvailableLen,
        value.available.length,
      );
      _memory.writeU8(
        replyPointer + _layout.clipboardReadReplyRemember,
        value.remember ? 1 : 0,
      );
      _callTable2(
        _memory.readPtr(pointer + _layout.clipboardReadReply),
        pointer,
        replyPointer,
      );
    } finally {
      for (final (pointer, length) in allocations) {
        _exports.freeBytes(pointer, length);
      }
      _exports.freeBytes(replyPointer, _layout.clipboardReadReplySize);
      _exports.freeBytes(
        contentPointer,
        value.contents.isEmpty
            ? 1
            : value.contents.length * _layout.clipboardContentSize,
      );
      _exports.freeBytes(
        availablePointer,
        value.available.isEmpty
            ? 1
            : value.available.length * _layout.stringSize,
      );
    }
  }

  void _replyClipboardWrite(int pointer, ClipboardWriteResult result) {
    final replyPointer = _allocateBytes(_layout.clipboardWriteReplySize);
    try {
      _memory.writeU32(
        replyPointer + _layout.clipboardWriteReplySizeField,
        _layout.clipboardWriteReplySize,
      );
      _memory.writeU32(
        replyPointer + _layout.clipboardWriteReplyResult,
        result.value,
      );
      _memory.writeU8(replyPointer + _layout.clipboardWriteReplyRemember, 0);
      _callTable2(
        _memory.readPtr(pointer + _layout.clipboardWriteReply),
        pointer,
        replyPointer,
      );
    } finally {
      _exports.freeBytes(replyPointer, _layout.clipboardWriteReplySize);
    }
  }

  int _requirePointer(int pointer) {
    if (pointer == 0) throw const OutOfMemoryException();
    return pointer;
  }

  T _runNestedCallbackOperation<T>(T Function() operation) {
    final previousFailure = _callbackError!;
    _callbackError = null;
    late final T result;
    late final ({Object error, StackTrace stackTrace})? failure;
    try {
      result = operation();
    } finally {
      failure = _callbackError;
      _callbackError = previousFailure;
    }
    if (failure != null) {
      Error.throwWithStackTrace(failure.error, failure.stackTrace);
    }
    return result;
  }

  void _setBool(LibGhosttyHandle terminal, TerminalOption option, bool? value) {
    if (value == null) {
      _setNull(terminal, option);
      return;
    }
    final pointer = _requirePointer(_exports.allocateBytes(1));
    try {
      _memory.writeU8(pointer, value ? 1 : 0);
      final result = _exports.ghostty_terminal_set(
        terminal.value,
        option.value,
        pointer,
      );
      checkResultCode(result, operation: 'ghostty_terminal_set');
    } finally {
      _exports.freeBytes(pointer, 1);
    }
  }

  void _setCallback(
    LibGhosttyHandle terminal,
    TerminalOption option,
    Function? callback,
    int Function(int? reuseIndex) register,
  ) {
    if (callback == null) {
      _setNull(terminal, option);
      _clearCallback(terminal, option);
      return;
    }
    final previous = _callbacks[terminal.value]?[option];
    // Register a fresh table slot while replacing a callback. Reusing the old
    // slot before terminal_set succeeds would overwrite the live callback and
    // leave no way to restore it if the C call rejects the new value.
    final index = register(null);
    final result = _exports.ghostty_terminal_set(
      terminal.value,
      option.value,
      index,
    );
    try {
      checkResultCode(result, operation: 'ghostty_terminal_set');
    } catch (_) {
      _releaseTableIndex(index);
      rethrow;
    }
    if (previous != null) _releaseTableIndex(previous.$1);
    (_callbacks[terminal.value] ??= {})[option] = (index, callback);
  }

  void _setColor(
    LibGhosttyHandle terminal,
    TerminalOption option,
    RgbColor? value,
  ) {
    if (value == null) {
      _setNull(terminal, option);
      return;
    }
    final pointer = _allocateBytes(_layout.colorRgbSize);
    try {
      _writeRgb(pointer, value);
      final result = _exports.ghostty_terminal_set(
        terminal.value,
        option.value,
        pointer,
      );
      checkResultCode(result, operation: 'ghostty_terminal_set');
    } finally {
      _exports.freeBytes(pointer, _layout.colorRgbSize);
    }
  }

  void _setI32(LibGhosttyHandle terminal, TerminalOption option, int? value) {
    if (value == null) {
      _setNull(terminal, option);
      return;
    }
    final pointer = _allocateSize();
    try {
      _memory.writeI32(pointer, value);
      final result = _exports.ghostty_terminal_set(
        terminal.value,
        option.value,
        pointer,
      );
      checkResultCode(result, operation: 'ghostty_terminal_set');
    } finally {
      _exports.freeBytes(pointer, 4);
    }
  }

  void _setMode(
    LibGhosttyHandle terminal,
    TerminalOption option,
    int mode,
    bool value,
  ) {
    final pointer = _allocateBytes(_layout.terminalModeConfigSize);
    try {
      _memory.writeU16(pointer + _layout.terminalModeConfigMode, mode);
      _memory.writeU8(pointer + _layout.terminalModeConfigValue, value ? 1 : 0);
      final result = _exports.ghostty_terminal_set(
        terminal.value,
        option.value,
        pointer,
      );
      checkResultCode(result, operation: 'ghostty_terminal_set');
    } finally {
      _exports.freeBytes(pointer, _layout.terminalModeConfigSize);
    }
  }

  void _setNull(LibGhosttyHandle terminal, TerminalOption option) {
    final result = _exports.ghostty_terminal_set(
      terminal.value,
      option.value,
      0,
    );
    checkResultCode(result, operation: 'ghostty_terminal_set');
  }

  void _setString(
    LibGhosttyHandle terminal,
    TerminalOption option,
    String? value,
  ) {
    if (value == null) {
      _setNull(terminal, option);
      return;
    }
    final bytes = utf8.encode(value);
    final bytesPointer = _allocateBytes(bytes.isEmpty ? 1 : bytes.length);
    var stringPointer = 0;
    try {
      _memory.writeBytes(bytesPointer, bytes);
      stringPointer = _allocateBytes(_layout.stringSize);
      _memory.writeU32(stringPointer, bytesPointer);
      _memory.writeU32(stringPointer + _layout.stringLen, bytes.length);
      final result = _exports.ghostty_terminal_set(
        terminal.value,
        option.value,
        stringPointer,
      );
      checkResultCode(result, operation: 'ghostty_terminal_set');
    } finally {
      _exports.freeBytes(bytesPointer, bytes.isEmpty ? 1 : bytes.length);
      if (stringPointer != 0) {
        _exports.freeBytes(stringPointer, _layout.stringSize);
      }
    }
  }

  void _setU32(LibGhosttyHandle terminal, TerminalOption option, int? value) {
    if (value == null) {
      _setNull(terminal, option);
      return;
    }
    final pointer = _allocateSize();
    try {
      _memory.writeU32(pointer, value);
      final result = _exports.ghostty_terminal_set(
        terminal.value,
        option.value,
        pointer,
      );
      checkResultCode(result, operation: 'ghostty_terminal_set');
    } finally {
      _exports.freeBytes(pointer, 4);
    }
  }

  void _setU64(LibGhosttyHandle terminal, TerminalOption option, int? value) {
    if (value == null) {
      _setNull(terminal, option);
      return;
    }
    final pointer = _allocateBytes(8);
    try {
      _memory.writeU64(pointer, value);
      final result = _exports.ghostty_terminal_set(
        terminal.value,
        option.value,
        pointer,
      );
      checkResultCode(result, operation: 'ghostty_terminal_set');
    } finally {
      _exports.freeBytes(pointer, 8);
    }
  }

  void _writeRgb(int pointer, RgbColor value) {
    _memory.writeU8(pointer + _layout.colorRgbR, value.r);
    _memory.writeU8(pointer + _layout.colorRgbG, value.g);
    _memory.writeU8(pointer + _layout.colorRgbB, value.b);
  }
}
