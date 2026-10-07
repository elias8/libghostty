part of 'terminal.dart';

/// Incrementally or completely restores a terminal snapshot.
///
/// The decoder owns a copy of [bytes], so callers may reuse or modify their
/// list after construction. Use [decode] for one-shot restoration, or [ready]
/// followed by [next] to render the active screen before older history pages
/// finish loading. A decoder supports only one of those flows.
///
/// Dispose the decoder after restoration. A terminal returned by [ready] must
/// remain alive until [next] reaches the end or the decoder is disposed.
final class SnapshotDecoder {
  static final _finalizer = Finalizer(bindings.snapshot.snapshotDecoderFree);

  final LibGhosttyHandle _handle;
  var _state = _SnapshotDecoderState.initial;
  Terminal? _terminal;

  /// Creates a decoder over an owned copy of [bytes].
  ///
  /// [maxContinuationBytes] limits unfinished VT input accepted from the
  /// snapshot. It must fit an unsigned 32-bit integer so the behavior is
  /// portable to WebAssembly. When null, libghostty's default limit is used.
  /// Set [retainContinuation] to keep continuation tracking enabled on the
  /// restored terminal. Set [compressHistory] to compress each scrollback
  /// page as it is restored during incremental decoding.
  SnapshotDecoder(
    Uint8List bytes, {
    int? maxContinuationBytes,
    bool retainContinuation = false,
    bool compressHistory = false,
  }) : _handle = bindings.snapshot.snapshotDecoderNew(
         bytes,
         maxContinuationBytes: _checkedContinuationLimit(maxContinuationBytes),
         retainContinuation: retainContinuation,
         compressHistory: compressHistory,
       ) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Declared alternate-screen history rows, or null when unavailable.
  int? get alternateHistoryRows => bindings.snapshot.snapshotDecoderHistoryRows(
    _requireMetadataHandle(),
    .alternate,
  );

  /// Declared primary-screen history rows, or null before they are available.
  int? get primaryHistoryRows => bindings.snapshot.snapshotDecoderHistoryRows(
    _requireMetadataHandle(),
    .primary,
  );

  /// Whether restored terminals retain continuation tracking.
  bool get retainContinuation {
    return bindings.snapshot.snapshotDecoderRetainContinuation(
      _requireHandle(),
    );
  }

  /// Whether scrollback history is compressed while it is restored.
  bool get compressHistory {
    return bindings.snapshot.snapshotDecoderCompressHistory(_requireHandle());
  }

  /// Number of source bytes consumed by the decoder.
  ///
  /// After successful completion, this points to the first byte following the
  /// snapshot and therefore permits snapshots embedded in a larger buffer.
  int get sourceOffset {
    return bindings.snapshot.snapshotDecoderSourceOffset(_requireHandle());
  }

  /// Decodes and validates the complete snapshot in one call.
  ///
  /// The returned terminal is caller-owned and remains valid after this
  /// decoder is disposed.
  Terminal decode() {
    _requireInitial('decode');
    try {
      final terminal = Terminal._fromHandle(
        bindings.snapshot.snapshotDecoderDecode(_handle),
      );
      _terminal = terminal;
      _state = _SnapshotDecoderState.complete;
      return terminal;
    } catch (_) {
      _state = _SnapshotDecoderState.failed;
      rethrow;
    }
  }

  /// Releases decoder resources and its owned source-byte copy.
  ///
  /// Any terminal already returned by [decode] or [ready] remains usable.
  void dispose() {
    if (_state == _SnapshotDecoderState.disposed) return;
    bindings.snapshot.snapshotDecoderFree(_handle);
    _finalizer.detach(this);
    _terminal = null;
    _state = _SnapshotDecoderState.disposed;
  }

  /// Restores the next history page.
  ///
  /// Returns progress for one decoded page, or null after the final snapshot
  /// marker is validated.
  SnapshotProgress? next() {
    final state = _state;
    if (state == _SnapshotDecoderState.complete) return null;
    if (state != _SnapshotDecoderState.ready) {
      throw StateError('ready() must be called before next()');
    }
    if (_terminal!._disposed) {
      throw StateError('The terminal returned by ready() has been disposed');
    }
    try {
      final progress = bindings.snapshot.snapshotDecoderNext(_handle);
      if (progress == null) {
        _state = _SnapshotDecoderState.complete;
        return null;
      }
      return SnapshotProgress(
        screen: progress.screen,
        rows: progress.rows,
        remaining: progress.remaining,
      );
    } catch (_) {
      _state = _SnapshotDecoderState.failed;
      rethrow;
    }
  }

  /// Restores a renderable terminal without waiting for older history pages.
  ///
  /// Continue with [next] until it returns null. The returned terminal remains
  /// caller-owned after the decoder is disposed.
  Terminal ready() {
    _requireInitial('ready');
    try {
      final terminal = Terminal._fromHandle(
        bindings.snapshot.snapshotDecoderReady(_handle),
      );
      _terminal = terminal;
      _state = _SnapshotDecoderState.ready;
      return terminal;
    } catch (_) {
      _state = _SnapshotDecoderState.failed;
      rethrow;
    }
  }

  LibGhosttyHandle _requireHandle() {
    return switch (_state) {
      _SnapshotDecoderState.failed => throw StateError(
        'SnapshotDecoder cannot be used after a decoding failure',
      ),
      _SnapshotDecoderState.disposed => throw StateError(
        'SnapshotDecoder has been disposed',
      ),
      _ => _handle,
    };
  }

  void _requireInitial(String operation) {
    _requireHandle();
    if (_state != _SnapshotDecoderState.initial) {
      throw StateError('$operation() requires a new SnapshotDecoder');
    }
  }

  LibGhosttyHandle _requireMetadataHandle() {
    if (_state == _SnapshotDecoderState.disposed) {
      throw StateError('SnapshotDecoder has been disposed');
    }
    return _handle;
  }

  static int? _checkedContinuationLimit(int? value) {
    if (value == null) return null;
    if (value < 0 || value > 0xffffffff) {
      throw RangeError.range(value, 0, 0xffffffff, 'maxContinuationBytes');
    }
    return value;
  }
}

/// Result of restoring one terminal snapshot history page.
@immutable
final class SnapshotProgress {
  /// Screen whose history received the page.
  final TerminalScreen screen;

  /// Rows prepended from the page.
  ///
  /// Zero means the page was valid but could no longer be safely applied.
  final int rows;

  /// Page records remaining in the current screen's history sequence.
  final int remaining;

  const SnapshotProgress({
    required this.screen,
    required this.rows,
    required this.remaining,
  });

  @override
  int get hashCode => Object.hash(screen, rows, remaining);

  @override
  bool operator ==(Object other) =>
      other is SnapshotProgress &&
      other.screen == screen &&
      other.rows == rows &&
      other.remaining == remaining;
}

enum _SnapshotDecoderState { initial, ready, complete, failed, disposed }
