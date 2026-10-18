part of 'terminal.dart';

/// A tracked reference to a specific cell position in the terminal grid.
///
/// Created via [TrackedGridRef.at]. Unlike [GridRef], a tracked grid reference
/// follows its cell as the terminal page list changes due to scrolling,
/// pruning, resize/reflow, and similar mutations. Call [snapshot] immediately
/// before reading cell data, and call [dispose] when done.
///
/// If the tracked cell is discarded by reset, screen replacement, or terminal
/// disposal, [hasValue] becomes false and [snapshot] / [positionIn] return null.
/// Calling [dispose] more than once is safe; every other member throws
/// [StateError] after disposal.
///
/// Not intended for render loops. Use [RenderState] with [RowIterator] and
/// [CellIterator] for performance-critical rendering.
///
/// ```dart
/// final tracked = TrackedGridRef.at(
///   terminal,
///   const Position(row: 0, col: 0),
/// );
/// final ref = tracked.snapshot();
/// print(ref?.content);
/// tracked.dispose();
/// ```
final class TrackedGridRef {
  static final _finalizer = Finalizer(bindings.render.trackedGridRefFree);

  final LibGhosttyHandle _handle;
  Terminal? _terminal;

  /// Resolves and tracks the grid cell at [position] in the coordinate
  /// space identified by [pointTag].
  ///
  /// Throws [InvalidValueException] if the coordinates are out of range.
  factory TrackedGridRef.at(
    Terminal terminal,
    Position position, {
    PointTag pointTag = .active,
  }) => TrackedGridRef._(terminal, position, pointTag: pointTag);

  TrackedGridRef._(
    Terminal terminal,
    Position position, {
    PointTag pointTag = .active,
  }) : _terminal = terminal,
       _handle = bindings.render.terminalGridRefTrack(
         terminal._requireHandle(),
         pointTag,
         position,
       ) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Whether this reference currently resolves to a meaningful grid position.
  bool get hasValue {
    return bindings.render.trackedGridRefHasValue(_requireHandle());
  }

  /// Releases the native tracked grid reference handle.
  ///
  /// It is safe to dispose after the creating terminal has been disposed.
  void dispose() {
    final terminal = _terminal;
    if (terminal == null) return;
    bindings.render.trackedGridRefFree(_handle);
    _finalizer.detach(this);
    _terminal = null;
  }

  /// Converts this tracked reference to coordinates in the given coordinate
  /// space.
  ///
  /// Returns null if the tracked location has been discarded or cannot be
  /// represented in [pointTag].
  Position? positionIn(PointTag pointTag) {
    return bindings.render.trackedGridRefPoint(_requireHandle(), pointTag);
  }

  /// Moves this tracked reference to a new position.
  ///
  /// The new position is resolved against the same terminal that created this
  /// tracked reference. The terminal must not have been disposed.
  void set(Position position, {PointTag pointTag = .active}) {
    bindings.render.trackedGridRefSet(
      _requireHandle(),
      _terminal!._requireHandle(),
      pointTag,
      position,
    );
  }

  /// Creates a short-lived [GridRef] snapshot for reading cell data.
  ///
  /// The returned [GridRef] follows normal grid-reference lifetime rules.
  /// Returns null if this tracked reference no longer has a meaningful value.
  GridRef? snapshot() {
    final ref = bindings.render.trackedGridRefSnapshot(_requireHandle());
    return ref == null ? null : GridRef._fromValue(_terminal!, ref);
  }

  LibGhosttyHandle _requireHandle() {
    if (_terminal == null) throw StateError('TrackedGridRef has been disposed');
    return _handle;
  }
}
