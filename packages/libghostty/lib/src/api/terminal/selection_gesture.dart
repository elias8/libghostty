part of 'terminal.dart';

/// Mutable state machine for terminal text selection gestures.
///
/// The gesture converts reusable [SelectionGestureEvent] values into selection
/// snapshots. Returned selections are not installed automatically. The
/// creating terminal must outlive this gesture for [state], [apply], and
/// [reset].
///
/// Members other than [dispose] throw [StateError] after this gesture or its
/// creating terminal has been disposed. Invalid event data throws
/// [InvalidValueException].
final class SelectionGesture {
  static final _finalizer = Finalizer((
    ({LibGhosttyHandle handle, WeakReference<Terminal> terminal}) token,
  ) {
    final terminal = token.terminal.target;
    bindings.selection.selectionGestureFree(
      token.handle,
      terminal?._handleOrNull ?? const LibGhosttyHandle.fromAddress(0),
    );
  });

  final LibGhosttyHandle _handle;
  Terminal? _terminal;

  /// Creates a gesture state machine bound to [terminal].
  SelectionGesture(Terminal terminal)
    : _handle = bindings.selection.selectionGestureNew(),
      _terminal = terminal {
    _finalizer.attach(this, (
      handle: _handle,
      terminal: WeakReference(terminal),
    ), detach: this);
  }

  /// Current readable gesture state.
  SelectionGestureState get state {
    final handle = _requireHandle();
    final raw = bindings.selection.selectionGestureGetState(
      handle,
      _terminal!._requireHandle(),
    );
    return SelectionGestureState(
      clickCount: raw.clickCount,
      dragged: raw.dragged,
      autoscroll: raw.autoscroll,
      behavior: raw.behavior,
      anchor: raw.anchor == null ? null : ._fromValue(_terminal!, raw.anchor!),
    );
  }

  /// Applies [event] and returns the produced selection snapshot, if any.
  Selection? apply(SelectionGestureEvent event) {
    final handle = _requireHandle();
    event._ensureRefFor(_terminal!);
    final raw = bindings.selection.selectionGestureEvent(
      handle,
      _terminal!._requireHandle(),
      event._requireHandle(),
    );
    return raw == null ? null : Selection._fromRaw(_terminal!, raw);
  }

  /// Releases the native gesture handle.
  ///
  /// Calling [dispose] more than once is safe. The gesture must not be used
  /// afterward. It is safe to dispose after the creating terminal has been
  /// disposed.
  void dispose() {
    final terminal = _terminal;
    if (terminal == null) return;
    bindings.selection.selectionGestureFree(
      _handle,
      terminal._handleOrNull ?? const LibGhosttyHandle.fromAddress(0),
    );
    _finalizer.detach(this);
    _terminal = null;
  }

  /// Clears active gesture state while keeping this gesture reusable.
  void reset() {
    final handle = _requireHandle();
    bindings.selection.selectionGestureReset(
      handle,
      _terminal!._requireHandle(),
    );
  }

  LibGhosttyHandle _requireHandle() {
    if (_terminal == null) {
      throw StateError('SelectionGesture has been disposed');
    }
    return _handle;
  }
}

/// Selection behavior table for single-, double-, and triple-click gestures.
@immutable
final class SelectionGestureBehaviors {
  /// Standard terminal selection behavior: cell, word, line.
  static const standard = SelectionGestureBehaviors(
    singleClick: .cell,
    doubleClick: .word,
    tripleClick: .line,
  );

  /// Behavior for single-click selection gestures.
  final SelectionGestureBehavior singleClick;

  /// Behavior for double-click selection gestures.
  final SelectionGestureBehavior doubleClick;

  /// Behavior for triple-click selection gestures.
  final SelectionGestureBehavior tripleClick;

  /// Creates a behavior table for gesture press events.
  const SelectionGestureBehaviors({
    required this.singleClick,
    required this.doubleClick,
    required this.tripleClick,
  });
}

/// Reusable event data for a selection gesture operation.
///
/// The event kind is fixed at construction time. Set options before applying
/// the event with [SelectionGesture.apply].
///
/// Members other than [dispose] throw [StateError] after disposal. Invalid
/// option values or options unsupported for this event type throw
/// [InvalidValueException].
final class SelectionGestureEvent {
  static final _finalizer = Finalizer(
    bindings.selection.selectionGestureEventFree,
  );

  final LibGhosttyHandle _handle;
  var _disposed = false;
  GridRef? _ref;

  /// Creates an autoscroll tick event.
  SelectionGestureEvent.autoscrollTick() : this._(.autoscrollTick);

  /// Creates a deep-press event.
  SelectionGestureEvent.deepPress() : this._(.deepPress);

  /// Creates a drag event.
  SelectionGestureEvent.drag() : this._(.drag);

  /// Creates a press event.
  SelectionGestureEvent.press() : this._(.press);

  /// Creates a release event.
  SelectionGestureEvent.release() : this._(.release);

  SelectionGestureEvent._(SelectionGestureEventType type)
    : _handle = bindings.selection.selectionGestureEventNew(type) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Clears the surface-space pointer position.
  void clearPosition() => _clear(.position);

  /// Releases the event handle. Calling [dispose] more than once is safe.
  void dispose() {
    if (_disposed) return;
    bindings.selection.selectionGestureEventFree(_handle);
    _finalizer.detach(this);
    _ref = null;
    _disposed = true;
  }

  /// Sets the behavior table for press events, or clears it to restore
  /// libghostty's default cell, word, and line behaviors.
  void setBehaviors(SelectionGestureBehaviors? behaviors) {
    if (behaviors == null) {
      _clear(.behaviors);
      return;
    }
    bindings.selection.selectionGestureEventSetBehaviors(
      _requireHandle(),
      behaviors.singleClick,
      behaviors.doubleClick,
      behaviors.tripleClick,
    );
  }

  /// Sets drag display geometry, or clears it.
  void setGeometry(SelectionGestureGeometry? geometry) {
    if (geometry == null) {
      _clear(.geometry);
      return;
    }
    bindings.selection.selectionGestureEventSetGeometry(
      _requireHandle(),
      columns: geometry.columns,
      cellWidth: geometry.cellWidth,
      paddingLeft: geometry.paddingLeft,
      screenHeight: geometry.screenHeight,
    );
  }

  /// Sets the surface-space pointer position.
  void setPosition(double x, double y) {
    bindings.selection.selectionGestureEventSetPosition(_requireHandle(), x, y);
  }

  /// Sets whether drag/autoscroll events produce a rectangular selection, or
  /// clears the option to restore its initialized default.
  void setRectangle({required bool? value}) {
    if (value == null) {
      _clear(.rectangle);
      return;
    }
    bindings.selection.selectionGestureEventSetRectangle(
      _requireHandle(),
      value: value,
    );
  }

  /// Sets or clears the grid reference under the pointer.
  ///
  /// The reference must remain valid until [SelectionGesture.apply] and must
  /// belong to that gesture's terminal. A reference from another terminal
  /// throws [ArgumentError]. Do not mutate the terminal between assigning the
  /// reference and applying the event.
  void setRef(GridRef? ref) {
    if (ref == null) {
      _clear(.ref);
      _ref = null;
      return;
    }
    final handle = _requireHandle();
    bindings.selection.selectionGestureEventSetRef(handle, ref._value);
    _ref = ref;
  }

  /// Sets the maximum repeat-click distance in pixels, or clears it.
  void setRepeatDistance(double? value) {
    if (value == null) {
      _clear(.repeatDistance);
      return;
    }
    bindings.selection.selectionGestureEventSetRepeatDistance(
      _requireHandle(),
      value,
    );
  }

  /// Sets the maximum interval between repeat clicks in nanoseconds, or clears
  /// it.
  void setRepeatIntervalNs(int? value) {
    if (value == null) {
      _clear(.repeatIntervalNs);
      return;
    }
    bindings.selection.selectionGestureEventSetRepeatIntervalNs(
      _requireHandle(),
      value,
    );
  }

  /// Sets the monotonic event time in nanoseconds, or clears it.
  void setTimeNs(int? value) {
    if (value == null) {
      _clear(.timeNs);
      return;
    }
    bindings.selection.selectionGestureEventSetTimeNs(_requireHandle(), value);
  }

  /// Sets the viewport coordinate for an autoscroll tick, or clears it.
  void setViewport(Position? position) {
    if (position == null) {
      _clear(.viewport);
      return;
    }
    bindings.selection.selectionGestureEventSetViewport(
      _requireHandle(),
      position: position,
    );
  }

  /// Sets word-boundary codepoints. The codepoints are copied into
  /// event-owned storage. An empty list is an explicit empty boundary set;
  /// null restores libghostty's default boundaries.
  void setWordBoundaryCodepoints(List<int>? codepoints) {
    if (codepoints == null) {
      _clear(.wordBoundaryCodepoints);
      return;
    }
    bindings.selection.selectionGestureEventSetWordBoundaryCodepoints(
      _requireHandle(),
      codepoints,
    );
  }

  void _clear(SelectionGestureEventOption option) {
    bindings.selection.selectionGestureEventClear(_requireHandle(), option);
  }

  void _ensureRefFor(Terminal terminal) {
    _requireHandle();
    final ref = _ref;
    if (ref == null) return;
    if (!identical(ref._terminal, terminal)) {
      throw ArgumentError.value(
        ref,
        'event',
        'must belong to gesture terminal',
      );
    }
  }

  LibGhosttyHandle _requireHandle() {
    if (_disposed) {
      throw StateError('SelectionGestureEvent has been disposed');
    }
    return _handle;
  }
}

/// Display geometry used to interpret drag and autoscroll gesture events.
@immutable
final class SelectionGestureGeometry {
  /// Number of rendered terminal columns. Must be non-zero.
  final int columns;

  /// Width of one terminal cell in surface pixels. Must be non-zero.
  final int cellWidth;

  /// Left padding before the terminal grid begins in surface pixels.
  final int paddingLeft;

  /// Height of the rendered terminal surface in surface pixels. Must be
  /// non-zero.
  final int screenHeight;

  /// Creates display geometry for drag and autoscroll events.
  const SelectionGestureGeometry({
    required this.columns,
    required this.cellWidth,
    required this.paddingLeft,
    required this.screenHeight,
  });
}

/// Current readable state for a selection gesture.
@immutable
final class SelectionGestureState {
  /// Current click count. Zero means inactive.
  final int clickCount;

  /// Whether the current or last left-click gesture dragged.
  final bool dragged;

  /// Current autoscroll request.
  final SelectionGestureAutoscroll autoscroll;

  /// Current gesture behavior.
  final SelectionGestureBehavior behavior;

  /// Current left-click anchor, or null when there is no active anchor.
  final GridRef? anchor;

  /// Creates a selection gesture state snapshot.
  const SelectionGestureState({
    required this.clickCount,
    required this.dragged,
    required this.autoscroll,
    required this.behavior,
    required this.anchor,
  });
}
