import 'dart:convert';

import '../../generated/libghostty_enums.g.dart';
import '../../generated/libghostty_wasm.g.dart';
import '../../types/types.dart';
import '../result_helpers.dart';
import '../types.dart';
import '../wasm/allocation_owner.dart';
import '../wasm/allocator.dart';
import '../wasm/layouts.dart';
import '../wasm/memory.dart';
import '../wasm/scratch.dart';
import 'formatter.dart';

final class WasmFormatterBindings implements FormatterBindings {
  final Memory _memory;
  final Layouts _layout;
  final GhosttyExports _exports;
  final WasmScratchPool _scratch;
  late int _formatBuffer;
  late int _formatBufferCapacity;
  late int _written;

  factory WasmFormatterBindings(GhosttyExports exports, Layouts layout) {
    final owner = WasmAllocationOwner(exports);
    try {
      final bindings = WasmFormatterBindings._(exports, layout, owner);
      owner.commit();
      return bindings;
    } on Object {
      owner.rollback();
      rethrow;
    }
  }

  WasmFormatterBindings._(
    this._exports,
    this._layout,
    WasmAllocationOwner owner,
  ) : _memory = Memory(_exports),
      _scratch = WasmScratchPool(
        WasmExportScratchAllocator(_exports),
        maxVariableLength: WasmScratchPool.defaultMaxVariableLength,
      ) {
    _formatBufferCapacity = 4096;
    _formatBuffer = owner.allocate(_formatBufferCapacity);
    _written = owner.allocate(4);
  }

  @override
  String formatterFormat(LibGhosttyHandle formatter) {
    var result = _exports.ghostty_formatter_format_buf(
      formatter.value,
      _formatBuffer,
      _formatBufferCapacity,
      _written,
    );
    if (result == Result.outOfSpace.value) {
      _growFormatBuffer(_memory.readU32(_written));
      result = _exports.ghostty_formatter_format_buf(
        formatter.value,
        _formatBuffer,
        _formatBufferCapacity,
        _written,
      );
    }
    checkResultCode(result, operation: 'ghostty_formatter_format_buf');
    final length = _memory.readU32(_written);
    return length == 0
        ? ''
        : utf8.decode(_memory.readBytes(_formatBuffer, length));
  }

  @override
  void formatterFree(LibGhosttyHandle formatter) {
    _exports.ghostty_formatter_free(formatter.value);
  }

  @override
  LibGhosttyHandle formatterTerminalNew(
    LibGhosttyHandle terminal,
    FormatterFormat format, {
    bool unwrap = false,
    bool trim = false,
    FormatterExtra extra = const FormatterExtra(),
    RawSelection? selection,
  }) {
    final frame = _scratch.acquire(const []);
    try {
      final out = frame.variableAddress(
        0,
        wasm32PointerSize,
        alignment: wasm32PointerSize,
      );
      final options = frame.variableAddress(
        1,
        _layout.formatterOptsSize,
        alignment: wasm32PointerSize,
      );
      for (var i = 0; i < _layout.formatterOptsSize; i++) {
        _memory.writeU8(options + i, 0);
      }
      _memory.writeU32(options, _layout.formatterOptsSize);
      _memory.writeU32(options + _layout.formatterOptsFormat, format.value);
      _memory.writeU8(options + _layout.formatterOptsUnwrap, unwrap ? 1 : 0);
      _memory.writeU8(options + _layout.formatterOptsTrim, trim ? 1 : 0);

      final extraBase = options + _layout.formatterOptsExtra;
      _memory.writeU32(extraBase, _layout.formatterTermExtraSize);
      _memory.writeU8(
        extraBase + _layout.formatterTermExtraPalette,
        extra.palette ? 1 : 0,
      );
      _memory.writeU8(
        extraBase + _layout.formatterTermExtraModes,
        extra.modes ? 1 : 0,
      );
      _memory.writeU8(
        extraBase + _layout.formatterTermExtraScrollingRegion,
        extra.scrollingRegion ? 1 : 0,
      );
      _memory.writeU8(
        extraBase + _layout.formatterTermExtraTabstops,
        extra.tabstops ? 1 : 0,
      );
      _memory.writeU8(
        extraBase + _layout.formatterTermExtraPwd,
        extra.pwd ? 1 : 0,
      );
      _memory.writeU8(
        extraBase + _layout.formatterTermExtraKeyboard,
        extra.keyboard ? 1 : 0,
      );

      final screenBase = extraBase + _layout.formatterTermExtraScreen;
      _memory.writeU32(screenBase, _layout.formatterScreenExtraSize);
      _memory.writeU8(
        screenBase + _layout.formatterScreenExtraCursor,
        extra.cursor ? 1 : 0,
      );
      _memory.writeU8(
        screenBase + _layout.formatterScreenExtraStyle,
        extra.style ? 1 : 0,
      );
      _memory.writeU8(
        screenBase + _layout.formatterScreenExtraHyperlink,
        extra.hyperlink ? 1 : 0,
      );
      _memory.writeU8(
        screenBase + _layout.formatterScreenExtraProtection,
        extra.protection ? 1 : 0,
      );
      _memory.writeU8(
        screenBase + _layout.formatterScreenExtraKittyKeyboard,
        extra.kittyKeyboard ? 1 : 0,
      );
      _memory.writeU8(
        screenBase + _layout.formatterScreenExtraCharsets,
        extra.charsets ? 1 : 0,
      );

      var selectionPointer = 0;
      if (selection != null) {
        selectionPointer = frame.variableAddress(
          2,
          _layout.selectionSize,
          alignment: wasm32PointerSize,
        );
        _memory.writeU32(selectionPointer, _layout.selectionSize);
        _writeGridRef(
          selectionPointer + _layout.selectionStart,
          selection.start,
        );
        _writeGridRef(selectionPointer + _layout.selectionEnd, selection.end);
        _memory.writeU8(
          selectionPointer + _layout.selectionRectangle,
          selection.rectangle ? 1 : 0,
        );
      }
      _memory.writeU32(
        options + _layout.formatterOptsSelection,
        selectionPointer,
      );

      final result = _exports.ghostty_formatter_terminal_new(
        0,
        out,
        terminal.value,
        options,
      );
      checkResultCode(result, operation: 'ghostty_formatter_terminal_new');
      return .fromAddress(_exports.ghostty_wasm_take_opaque(out));
    } finally {
      frame.release();
    }
  }

  void _growFormatBuffer(int required) {
    if (required <= _formatBufferCapacity) return;
    final replacement = _allocateBytes(required);
    _exports.freeBytes(_formatBuffer, _formatBufferCapacity);
    _formatBuffer = replacement;
    _formatBufferCapacity = required;
  }

  int _allocateBytes(int length) {
    final pointer = _exports.allocateBytes(length);
    if (pointer == 0) throw const OutOfMemoryException();
    return pointer;
  }

  void _writeGridRef(int pointer, RawGridRef value) {
    _memory.writeU32(pointer, _layout.gridRefSize);
    _memory.writeU32(pointer + _layout.gridRefNode, value.node);
    _memory.writeU16(pointer + _layout.gridRefX, value.x);
    _memory.writeU16(pointer + _layout.gridRefY, value.y);
  }
}
