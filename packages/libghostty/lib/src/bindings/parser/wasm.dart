import 'dart:typed_data';

import '../../generated/libghostty_enums.g.dart';
import '../../generated/libghostty_wasm.g.dart';
import '../../types/types.dart';
import '../result_helpers.dart';
import '../types.dart';
import '../wasm/allocator.dart';
import '../wasm/layouts.dart';
import '../wasm/memory.dart';
import '../wasm/scratch.dart';
import 'parser.dart';

final class WasmParserBindings implements ParserBindings {
  final Memory _memory;
  final Layouts _layout;
  final GhosttyExports _exports;
  final WasmScratchPool _scratch;

  WasmParserBindings(this._exports, this._layout)
    : _memory = Memory(_exports),
      _scratch = WasmScratchPool(
        WasmExportScratchAllocator(_exports),
        maxVariableLength: WasmScratchPool.defaultMaxVariableLength,
      );

  @override
  OscCommandType oscCommandType(LibGhosttyHandle command) {
    return .fromValue(_exports.ghostty_osc_command_type(command.value));
  }

  @override
  String? oscCommandWindowTitle(LibGhosttyHandle command) {
    final out = _requirePointer(_exports.allocateOpaque());
    try {
      final present = _exports.ghostty_osc_command_data(
        command.value,
        OscCommandData.changeWindowTitleStr.value,
        out,
      );
      if (present == 0) return null;
      final pointer = _exports.ghostty_wasm_take_opaque(out);
      if (pointer == 0) return null;
      return _memory.readCString(pointer);
    } finally {
      _exports.freeOpaque(out);
    }
  }

  @override
  RawOscUnknownCommandData? oscCommandUnknownData(LibGhosttyHandle command) {
    final frame = _scratch.acquire(const []);
    try {
      final content = frame.variableAddress(0, _layout.stringSize);
      if (_exports.ghostty_osc_command_data(
            command.value,
            OscCommandData.unknownContent.value,
            content,
          ) ==
          0) {
        return null;
      }
      final truncated = frame.variableAddress(1, 1);
      final hasTruncated = _exports.ghostty_osc_command_data(
        command.value,
        OscCommandData.unknownTruncated.value,
        truncated,
      );
      final terminator = frame.variableAddress(2, 4, alignment: 4);
      final hasTerminator = _exports.ghostty_osc_command_data(
        command.value,
        OscCommandData.unknownTerminator.value,
        terminator,
      );
      if (hasTruncated == 0 || hasTerminator == 0) return null;
      final pointer = _memory.readPtr(content);
      final length = _memory.readU32(content + _layout.stringLen);
      return (
        content: pointer == 0 || length == 0
            ? Uint8List(0)
            : Uint8List.fromList(_memory.readBytes(pointer, length)),
        truncated: _memory.readU8(truncated) != 0,
        terminator: .fromValue(_memory.readU32(terminator)),
      );
    } finally {
      frame.release();
    }
  }

  @override
  LibGhosttyHandle oscEnd(LibGhosttyHandle parser, int terminator) {
    return .fromAddress(_exports.ghostty_osc_end(parser.value, terminator));
  }

  @override
  void oscFeedByte(LibGhosttyHandle parser, int byte) {
    _exports.ghostty_osc_next(parser.value, byte);
  }

  @override
  void oscFree(LibGhosttyHandle parser) {
    _exports.ghostty_osc_free(parser.value);
  }

  @override
  LibGhosttyHandle oscNew({required int unknownMaxBytes}) {
    final out = _requirePointer(_exports.allocateOpaque());
    try {
      final result = _exports.ghostty_osc_new(0, out);
      checkResultCode(result, operation: 'ghostty_osc_new');
      final handle = LibGhosttyHandle.fromAddress(
        _exports.ghostty_wasm_take_opaque(out),
      );
      if (unknownMaxBytes == 0) return handle;
      var value = 0;
      try {
        value = _requirePointer(_exports.allocateBytes(wasm32PointerSize));
        _memory.writeU32(value, unknownMaxBytes);
        checkResultCode(
          _exports.ghostty_osc_set(
            handle.value,
            OscOption.unknownMaxBytes.value,
            value,
          ),
          operation: 'ghostty_osc_set',
        );
      } on Object {
        _exports.ghostty_osc_free(handle.value);
        rethrow;
      } finally {
        if (value != 0) _exports.freeBytes(value, wasm32PointerSize);
      }
      return handle;
    } finally {
      _exports.freeOpaque(out);
    }
  }

  @override
  void oscReset(LibGhosttyHandle parser) {
    _exports.ghostty_osc_reset(parser.value);
  }

  @override
  void sgrFree(LibGhosttyHandle parser) {
    _exports.ghostty_sgr_free(parser.value);
  }

  @override
  LibGhosttyHandle sgrNew() {
    final out = _requirePointer(_exports.allocateOpaque());
    try {
      final result = _exports.ghostty_sgr_new(0, out);
      checkResultCode(result, operation: 'ghostty_sgr_new');
      return .fromAddress(_exports.ghostty_wasm_take_opaque(out));
    } finally {
      _exports.freeOpaque(out);
    }
  }

  @override
  SgrAttribute? sgrNext(LibGhosttyHandle parser) {
    final pointer = _requirePointer(
      _exports.allocateBytes(_layout.sgrAttributeSize),
    );
    try {
      if (_exports.ghostty_sgr_next(parser.value, pointer) == 0) return null;
      return _readSgrAttribute(pointer);
    } finally {
      _exports.freeBytes(pointer, _layout.sgrAttributeSize);
    }
  }

  @override
  void sgrReset(LibGhosttyHandle parser) {
    _exports.ghostty_sgr_reset(parser.value);
  }

  @override
  void sgrSetParams(
    LibGhosttyHandle parser,
    List<int> params,
    List<String>? separators,
  ) {
    final frame = _scratch.acquire(const []);
    try {
      final paramsPointer = frame.variableAddress(
        0,
        params.length * 2 == 0 ? 1 : params.length * 2,
        alignment: 2,
      );
      var separatorsPointer = 0;
      if (separators != null) {
        separatorsPointer = frame.variableAddress(
          1,
          separators.isEmpty ? 1 : separators.length,
        );
      }
      for (var i = 0; i < params.length; i++) {
        _memory.writeU16(paramsPointer + i * 2, params[i]);
      }
      if (separators != null) {
        for (var i = 0; i < separators.length; i++) {
          _memory.writeU8(separatorsPointer + i, separators[i].codeUnitAt(0));
        }
      }
      final result = _exports.ghostty_sgr_set_params(
        parser.value,
        paramsPointer,
        separatorsPointer,
        params.length,
      );
      checkResultCode(result, operation: 'ghostty_sgr_set_params');
    } finally {
      frame.release();
    }
  }

  SgrAttribute _readSgrAttribute(int pointer) {
    final tag = SgrAttributeTag.fromValue(
      _exports.ghostty_sgr_attribute_tag(pointer),
    );
    final value = _exports.ghostty_sgr_attribute_value(pointer);
    return switch (tag) {
      .unknown => _readSgrUnknown(value),
      .underline => SgrAttribute(
        tag: tag,
        underlineStyle: .fromValue(_memory.readI32(value)),
      ),
      .underlineColor ||
      .directColorFg ||
      .directColorBg => _readSgrRgb(tag, value),
      .underlineColor256 ||
      .fg8 ||
      .bg8 ||
      .brightFg8 ||
      .brightBg8 ||
      .fg256 ||
      .bg256 => SgrAttribute(tag: tag, paletteIndex: _memory.readU8(value)),
      _ => SgrAttribute(tag: tag),
    };
  }

  SgrAttribute _readSgrRgb(SgrAttributeTag tag, int value) {
    final frame = _scratch.acquire(const []);
    try {
      final r = frame.variableAddress(0, 1);
      final g = frame.variableAddress(1, 1);
      final b = frame.variableAddress(2, 1);
      _exports.ghostty_color_rgb_get(value, r, g, b);
      return SgrAttribute(
        tag: tag,
        color: RgbColor(
          _memory.readU8(r),
          _memory.readU8(g),
          _memory.readU8(b),
        ),
      );
    } finally {
      frame.release();
    }
  }

  SgrAttribute _readSgrUnknown(int value) {
    final frame = _scratch.acquire(const []);
    try {
      final fullOut = frame.variableAddress(
        0,
        wasm32PointerSize,
        alignment: wasm32PointerSize,
      );
      final partialOut = frame.variableAddress(
        1,
        wasm32PointerSize,
        alignment: wasm32PointerSize,
      );
      final fullLength = _exports.ghostty_sgr_unknown_full(value, fullOut);
      final partialLength = _exports.ghostty_sgr_unknown_partial(
        value,
        partialOut,
      );
      final fullPointer = _memory.readPtr(fullOut);
      final partialPointer = _memory.readPtr(partialOut);
      return SgrAttribute(
        tag: .unknown,
        unknownFull: [
          for (var i = 0; i < fullLength; i++)
            _memory.readU16(fullPointer + i * 2),
        ],
        unknownPartial: [
          for (var i = 0; i < partialLength; i++)
            _memory.readU16(partialPointer + i * 2),
        ],
      );
    } finally {
      frame.release();
    }
  }

  int _requirePointer(int pointer) {
    if (pointer == 0) throw const OutOfMemoryException();
    return pointer;
  }
}
