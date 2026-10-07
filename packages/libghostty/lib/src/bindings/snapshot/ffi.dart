import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../../generated/libghostty.g.dart' as native;
import '../../generated/libghostty_enums.g.dart';
import '../result_helpers.dart';
import '../types.dart';
import 'snapshot.dart';

const _initialEncodeCapacity = 4096;

final class FfiSnapshotBindings implements SnapshotBindings {
  var _encodeBuffer = calloc<Uint8>(_initialEncodeCapacity);
  var _encodeCapacity = _initialEncodeCapacity;
  final Pointer<Size> _written = calloc<Size>();
  final Pointer<UnsignedInt> _progressKeys = calloc<UnsignedInt>(3);
  final Pointer<Pointer<Void>> _progressValues = calloc<Pointer<Void>>(3);
  final Pointer<Uint32> _progressScreen = calloc<Uint32>();
  final Pointer<Size> _progressRows = calloc<Size>();
  final Pointer<Uint32> _progressRemaining = calloc<Uint32>();
  final Pointer<Size> _progressWritten = calloc<Size>();
  final Map<int, (Pointer<Uint8>, int)> _sources = {};

  FfiSnapshotBindings() {
    _progressKeys
      ..[0] = SnapshotDecoderData.progressScreen.value
      ..[1] = SnapshotDecoderData.progressRows.value
      ..[2] = SnapshotDecoderData.progressRemaining.value;
    _progressValues
      ..[0] = _progressScreen.cast()
      ..[1] = _progressRows.cast()
      ..[2] = _progressRemaining.cast();
  }

  @override
  LibGhosttyHandle snapshotDecoderDecode(LibGhosttyHandle decoder) {
    return _decodeTerminal(decoder, ready: false);
  }

  @override
  void snapshotDecoderFree(LibGhosttyHandle decoder) {
    native.ghostty_snapshot_decoder_free(Pointer.fromAddress(decoder.value));
    final source = _sources.remove(decoder.value);
    if (source != null) calloc.free(source.$1);
  }

  @override
  int? snapshotDecoderHistoryRows(
    LibGhosttyHandle decoder,
    TerminalScreen screen,
  ) => _getOptionalUint64(
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
    final source = calloc<Uint8>(allocationLength);
    source.asTypedList(bytes.length).setAll(0, bytes);
    LibGhosttyHandle? handle;
    try {
      return using((arena) {
        final out = arena<Pointer<native.SnapshotDecoderImpl>>();
        final result = native.ghostty_snapshot_decoder_new_buf(
          nullptr,
          out,
          source,
          bytes.length,
        );
        checkResultCode(
          result.value,
          operation: 'ghostty_snapshot_decoder_new_buf',
        );
        final created = LibGhosttyHandle.fromAddress(out.value.address);
        handle = created;
        _sources[created.value] = (source, allocationLength);
        _setOptions(
          created,
          maxContinuationBytes: maxContinuationBytes,
          retainContinuation: retainContinuation,
          compressHistory: compressHistory,
        );
        return created;
      });
    } catch (_) {
      final created = handle;
      if (created == null) {
        calloc.free(source);
      } else {
        snapshotDecoderFree(created);
      }
      rethrow;
    }
  }

  @override
  RawSnapshotProgress? snapshotDecoderNext(LibGhosttyHandle decoder) {
    final result = native.ghostty_snapshot_decoder_next(
      Pointer.fromAddress(decoder.value),
    );
    if (result == Result.noValue) return null;
    checkResultCode(result.value, operation: 'ghostty_snapshot_decoder_next');
    final progressResult = native.ghostty_snapshot_decoder_get_multi(
      Pointer.fromAddress(decoder.value),
      3,
      _progressKeys,
      _progressValues,
      _progressWritten,
    );
    checkResultCode(
      progressResult.value,
      operation: 'ghostty_snapshot_decoder_get_multi',
    );
    return (
      screen: TerminalScreen.fromValue(_progressScreen.value),
      rows: _progressRows.value,
      remaining: _progressRemaining.value,
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
    return _getSize(decoder, SnapshotDecoderData.sourceOffset);
  }

  @override
  Uint8List snapshotEncode(LibGhosttyHandle terminal) {
    var result = native.ghostty_snapshot_encode_buf(
      Pointer.fromAddress(terminal.value),
      _encodeBuffer,
      _encodeCapacity,
      _written,
    );
    if (result == Result.outOfSpace) {
      _growEncodeBuffer(_written.value);
      result = native.ghostty_snapshot_encode_buf(
        Pointer.fromAddress(terminal.value),
        _encodeBuffer,
        _encodeCapacity,
        _written,
      );
    }
    checkResultCode(result.value, operation: 'ghostty_snapshot_encode_buf');
    return Uint8List.fromList(_encodeBuffer.asTypedList(_written.value));
  }

  LibGhosttyHandle _decodeTerminal(
    LibGhosttyHandle decoder, {
    required bool ready,
  }) {
    return using((arena) {
      final out = arena<Pointer<native.TerminalImpl>>();
      final result = ready
          ? native.ghostty_snapshot_decoder_ready(
              Pointer.fromAddress(decoder.value),
              out,
            )
          : native.ghostty_snapshot_decoder_decode(
              Pointer.fromAddress(decoder.value),
              out,
            );
      checkResultCode(
        result.value,
        operation: ready
            ? 'ghostty_snapshot_decoder_ready'
            : 'ghostty_snapshot_decoder_decode',
      );
      return LibGhosttyHandle.fromAddress(out.value.address);
    });
  }

  bool _get(
    LibGhosttyHandle decoder,
    SnapshotDecoderData data,
    Pointer<Void> out, {
    bool optional = false,
  }) {
    final result = native.ghostty_snapshot_decoder_get(
      Pointer.fromAddress(decoder.value),
      data,
      out,
    );
    return optional
        ? checkOptionalCode(
            result.value,
            operation: 'ghostty_snapshot_decoder_get',
          )
        : checkRequiredCode(
            result.value,
            operation: 'ghostty_snapshot_decoder_get',
          );
  }

  bool _getBool(LibGhosttyHandle decoder, SnapshotDecoderData data) {
    return using((arena) {
      final out = arena<Bool>();
      _get(decoder, data, out.cast());
      return out.value;
    });
  }

  int? _getOptionalUint64(LibGhosttyHandle decoder, SnapshotDecoderData data) {
    return using((arena) {
      final out = arena<Uint64>();
      return _get(decoder, data, out.cast(), optional: true) ? out.value : null;
    });
  }

  int _getSize(LibGhosttyHandle decoder, SnapshotDecoderData data) {
    return using((arena) {
      final out = arena<Size>();
      _get(decoder, data, out.cast());
      return out.value;
    });
  }

  void _growEncodeBuffer(int required) {
    if (required <= _encodeCapacity) return;
    final replacement = calloc<Uint8>(required);
    calloc.free(_encodeBuffer);
    _encodeBuffer = replacement;
    _encodeCapacity = required;
  }

  void _set(
    LibGhosttyHandle decoder,
    SnapshotDecoderOption option,
    Pointer<Void> value,
  ) {
    final result = native.ghostty_snapshot_decoder_set(
      Pointer.fromAddress(decoder.value),
      option,
      value,
    );
    checkResultCode(result.value, operation: 'ghostty_snapshot_decoder_set');
  }

  void _setOptions(
    LibGhosttyHandle decoder, {
    required int? maxContinuationBytes,
    required bool retainContinuation,
    required bool compressHistory,
  }) {
    using((arena) {
      if (maxContinuationBytes != null) {
        final value = arena<Size>()..value = maxContinuationBytes;
        _set(decoder, SnapshotDecoderOption.maxContinuationBytes, value.cast());
      }
      if (retainContinuation) {
        final value = arena<Bool>()..value = true;
        _set(decoder, SnapshotDecoderOption.retainContinuation, value.cast());
      }
      if (compressHistory) {
        final value = arena<Bool>()..value = true;
        _set(decoder, SnapshotDecoderOption.compressHistory, value.cast());
      }
    });
  }
}
