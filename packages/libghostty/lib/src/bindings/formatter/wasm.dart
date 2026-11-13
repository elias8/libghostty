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
  void formatterSetSelection(
    LibGhosttyHandle formatter,
    RawSelection? selection,
  ) {
    final frame = _scratch.acquire(const []);
    try {
      var selected = 0;
      if (selection != null) {
        selected = frame.variableAddress(
          0,
          _layout.selectionSize,
          alignment: wasm32PointerSize,
        );
        _writeGridRef(selected + _layout.selectionStart, selection.start);
        _writeGridRef(selected + _layout.selectionEnd, selection.end);
        _memory.writeU8(
          selected + _layout.selectionRectangle,
          selection.rectangle ? 1 : 0,
        );
      }
      checkResultCode(
        _exports.ghostty_formatter_set(
          formatter.value,
          FormatterOption.selection.value,
          selected,
        ),
        operation: 'ghostty_formatter_set',
      );
    } finally {
      frame.release();
    }
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
      final result = _exports.ghostty_formatter_terminal_new(
        0,
        out,
        terminal.value,
      );
      checkResultCode(result, operation: 'ghostty_formatter_terminal_new');
      final formatter = _exports.ghostty_wasm_take_opaque(out);
      try {
        final value = frame.variableAddress(1, 4, alignment: 4);
        void set(FormatterOption option) {
          checkResultCode(
            _exports.ghostty_formatter_set(formatter, option.value, value),
            operation: 'ghostty_formatter_set',
          );
        }

        _memory.writeU32(value, format.value);
        set(.emit);
        _memory.writeU8(value, unwrap ? 1 : 0);
        set(.unwrap);
        _memory.writeU8(value, trim ? 1 : 0);
        set(.trim);
        _memory.writeU32(value, formatterExtrasMask(extra));
        set(.extras);
        if (selection != null) {
          final selected = frame.variableAddress(
            2,
            _layout.selectionSize,
            alignment: wasm32PointerSize,
          );
          _writeGridRef(selected + _layout.selectionStart, selection.start);
          _writeGridRef(selected + _layout.selectionEnd, selection.end);
          _memory.writeU8(
            selected + _layout.selectionRectangle,
            selection.rectangle ? 1 : 0,
          );
          checkResultCode(
            _exports.ghostty_formatter_set(
              formatter,
              FormatterOption.selection.value,
              selected,
            ),
            operation: 'ghostty_formatter_set',
          );
        }
        return .fromAddress(formatter);
      } on Object {
        _exports.ghostty_formatter_free(formatter);
        rethrow;
      }
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
    _memory.writeU32(pointer + _layout.gridRefNode, value.node);
    _memory.writeU16(pointer + _layout.gridRefX, value.x);
    _memory.writeU16(pointer + _layout.gridRefY, value.y);
  }
}
