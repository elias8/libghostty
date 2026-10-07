import 'dart:typed_data';

import '../../generated/libghostty_enums.g.dart';
import '../../generated/libghostty_wasm.g.dart';
import '../../types/exceptions.dart';
import '../result_helpers.dart';
import '../types.dart';
import '../wasm/allocator.dart';
import '../wasm/memory.dart';
import 'snapshot.dart';

final class WasmSnapshotBindings implements SnapshotBindings {
  static const _progressKeys = 0;
  static const _progressValues = 12;
  static const _progressScreen = 24;
  static const _progressRows = 28;
  static const _progressRemaining = 32;
  static const _progressWritten = 36;
  static const _progressStorageLength = 40;

  final GhosttyExports _exports;
  final Memory _memory;
  final Map<int, (int, int)> _sources = {};
  late int _encodeBuffer;
  var _encodeCapacity = 4096;
  var _written = 0;
  var _progressStorage = 0;

  WasmSnapshotBindings(this._exports) : _memory = Memory(_exports) {
    _encodeBuffer = _allocate(_encodeCapacity);
    try {
      _written = _allocate(4);
      _progressStorage = _allocate(_progressStorageLength);
      _memory
        ..writeU32(
          _progressStorage + _progressKeys,
          SnapshotDecoderData.progressScreen.value,
        )
        ..writeU32(
          _progressStorage + _progressKeys + 4,
          SnapshotDecoderData.progressRows.value,
        )
        ..writeU32(
          _progressStorage + _progressKeys + 8,
          SnapshotDecoderData.progressRemaining.value,
        )
        ..writePtr(
          _progressStorage + _progressValues,
          _progressStorage + _progressScreen,
        )
        ..writePtr(
          _progressStorage + _progressValues + 4,
          _progressStorage + _progressRows,
        )
        ..writePtr(
          _progressStorage + _progressValues + 8,
          _progressStorage + _progressRemaining,
        );
    } catch (_) {
      _exports.freeBytes(_encodeBuffer, _encodeCapacity);
      if (_written != 0) _exports.freeBytes(_written, 4);
      if (_progressStorage != 0) {
        _exports.freeBytes(_progressStorage, _progressStorageLength);
      }
      rethrow;
    }
  }

  @override
  LibGhosttyHandle snapshotDecoderDecode(LibGhosttyHandle decoder) {
    return _decodeTerminal(decoder, ready: false);
  }

  @override
  void snapshotDecoderFree(LibGhosttyHandle decoder) {
    _exports.ghostty_snapshot_decoder_free(decoder.value);
    final source = _sources.remove(decoder.value);
    if (source != null) _exports.freeBytes(source.$1, source.$2);
  }

  @override
  int? snapshotDecoderHistoryRows(
    LibGhosttyHandle decoder,
    TerminalScreen screen,
  ) => _getOptionalU64(
    decoder,
    screen == .primary ? .historyRowsPrimary : .historyRowsAlternate,
  );

  @override
  LibGhosttyHandle snapshotDecoderNew(
    Uint8List bytes, {
    int? maxContinuationBytes,
    bool retainContinuation = false,
    bool compressHistory = false,
  }) {
    final allocationLength = bytes.isEmpty ? 1 : bytes.length;
    var source = 0;
    var out = 0;
    LibGhosttyHandle? handle;
    try {
      source = _allocate(allocationLength);
      _memory.writeBytes(source, bytes);
      out = _allocate(4);
      final result = _exports.ghostty_snapshot_decoder_new_buf(
        0,
        out,
        source,
        bytes.length,
      );
      checkResultCode(result, operation: 'ghostty_snapshot_decoder_new_buf');
      handle = LibGhosttyHandle.fromAddress(_memory.readPtr(out));
      _sources[handle.value] = (source, allocationLength);
      _setOptions(
        handle,
        maxContinuationBytes: maxContinuationBytes,
        retainContinuation: retainContinuation,
        compressHistory: compressHistory,
      );
      return handle;
    } catch (_) {
      final created = handle;
      if (created == null) {
        if (source != 0) _exports.freeBytes(source, allocationLength);
      } else {
        snapshotDecoderFree(created);
      }
      rethrow;
    } finally {
      if (out != 0) _exports.freeBytes(out, 4);
    }
  }

  @override
  RawSnapshotProgress? snapshotDecoderNext(LibGhosttyHandle decoder) {
    final result = _exports.ghostty_snapshot_decoder_next(decoder.value);
    if (result == Result.noValue.value) return null;
    checkResultCode(result, operation: 'ghostty_snapshot_decoder_next');
    checkResultCode(
      _exports.ghostty_snapshot_decoder_get_multi(
        decoder.value,
        3,
        _progressStorage + _progressKeys,
        _progressStorage + _progressValues,
        _progressStorage + _progressWritten,
      ),
      operation: 'ghostty_snapshot_decoder_get_multi',
    );
    return (
      screen: TerminalScreen.fromValue(
        _memory.readU32(_progressStorage + _progressScreen),
      ),
      rows: _memory.readU32(_progressStorage + _progressRows),
      remaining: _memory.readU32(_progressStorage + _progressRemaining),
    );
  }

  @override
  LibGhosttyHandle snapshotDecoderReady(LibGhosttyHandle decoder) {
    return _decodeTerminal(decoder, ready: true);
  }

  @override
  bool snapshotDecoderRetainContinuation(LibGhosttyHandle decoder) {
    return _getBool(decoder, SnapshotDecoderData.retainContinuation);
  }

  @override
  bool snapshotDecoderCompressHistory(LibGhosttyHandle decoder) {
    return _getBool(decoder, SnapshotDecoderData.compressHistory);
  }

  @override
  int snapshotDecoderSourceOffset(LibGhosttyHandle decoder) {
    return _getU32(decoder, SnapshotDecoderData.sourceOffset);
  }

  @override
  Uint8List snapshotEncode(LibGhosttyHandle terminal) {
    var result = _exports.ghostty_snapshot_encode_buf(
      terminal.value,
      _encodeBuffer,
      _encodeCapacity,
      _written,
    );
    if (result == Result.outOfSpace.value) {
      _growEncodeBuffer(_memory.readU32(_written));
      result = _exports.ghostty_snapshot_encode_buf(
        terminal.value,
        _encodeBuffer,
        _encodeCapacity,
        _written,
      );
    }
    checkResultCode(result, operation: 'ghostty_snapshot_encode_buf');
    return Uint8List.fromList(
      _memory.readBytes(_encodeBuffer, _memory.readU32(_written)),
    );
  }

  int _allocate(int length) {
    final pointer = _exports.allocateBytes(length);
    if (pointer == 0) throw const OutOfMemoryException();
    return pointer;
  }

  LibGhosttyHandle _decodeTerminal(
    LibGhosttyHandle decoder, {
    required bool ready,
  }) {
    final out = _allocate(4);
    try {
      final result = ready
          ? _exports.ghostty_snapshot_decoder_ready(decoder.value, out)
          : _exports.ghostty_snapshot_decoder_decode(decoder.value, out);
      checkResultCode(
        result,
        operation: ready
            ? 'ghostty_snapshot_decoder_ready'
            : 'ghostty_snapshot_decoder_decode',
      );
      return LibGhosttyHandle.fromAddress(_memory.readPtr(out));
    } finally {
      _exports.freeBytes(out, 4);
    }
  }

  bool _get(
    LibGhosttyHandle decoder,
    SnapshotDecoderData data,
    int out, {
    bool optional = false,
  }) {
    final result = _exports.ghostty_snapshot_decoder_get(
      decoder.value,
      data.value,
      out,
    );
    return optional
        ? checkOptionalCode(result, operation: 'ghostty_snapshot_decoder_get')
        : checkRequiredCode(result, operation: 'ghostty_snapshot_decoder_get');
  }

  bool _getBool(LibGhosttyHandle decoder, SnapshotDecoderData data) {
    final out = _allocate(1);
    try {
      _get(decoder, data, out);
      return _memory.readU8(out) != 0;
    } finally {
      _exports.freeBytes(out, 1);
    }
  }

  int? _getOptionalU64(LibGhosttyHandle decoder, SnapshotDecoderData data) {
    final out = _allocate(8);
    try {
      return _get(decoder, data, out, optional: true)
          ? _memory.readU64(out)
          : null;
    } finally {
      _exports.freeBytes(out, 8);
    }
  }

  int _getU32(LibGhosttyHandle decoder, SnapshotDecoderData data) {
    final out = _allocate(4);
    try {
      _get(decoder, data, out);
      return _memory.readU32(out);
    } finally {
      _exports.freeBytes(out, 4);
    }
  }

  void _growEncodeBuffer(int required) {
    if (required <= _encodeCapacity) return;
    final replacement = _allocate(required);
    _exports.freeBytes(_encodeBuffer, _encodeCapacity);
    _encodeBuffer = replacement;
    _encodeCapacity = required;
  }

  void _set(LibGhosttyHandle decoder, SnapshotDecoderOption option, int value) {
    checkResultCode(
      _exports.ghostty_snapshot_decoder_set(decoder.value, option.value, value),
      operation: 'ghostty_snapshot_decoder_set',
    );
  }

  void _setOptions(
    LibGhosttyHandle decoder, {
    required int? maxContinuationBytes,
    required bool retainContinuation,
    required bool compressHistory,
  }) {
    if (maxContinuationBytes != null) {
      final value = _allocate(4);
      try {
        _memory.writeU32(value, maxContinuationBytes);
        _set(decoder, SnapshotDecoderOption.maxContinuationBytes, value);
      } finally {
        _exports.freeBytes(value, 4);
      }
    }
    if (retainContinuation) {
      final value = _allocate(1);
      try {
        _memory.writeU8(value, 1);
        _set(decoder, SnapshotDecoderOption.retainContinuation, value);
      } finally {
        _exports.freeBytes(value, 1);
      }
    }
    if (compressHistory) {
      final value = _allocate(1);
      try {
        _memory.writeU8(value, 1);
        _set(decoder, SnapshotDecoderOption.compressHistory, value);
      } finally {
        _exports.freeBytes(value, 1);
      }
    }
  }
}
