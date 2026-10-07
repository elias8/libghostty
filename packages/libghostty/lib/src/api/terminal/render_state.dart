part of 'terminal.dart';

/// Dirty state of a render state after [RenderState.update].
enum DirtyState {
  /// Not dirty: rendering can be skipped entirely.
  clean,

  /// Some rows changed: renderer can redraw incrementally using per-row
  /// dirty flags via [RowIterator.dirty].
  partial,

  /// Global state changed (e.g. colors, cursor shape, screen switch):
  /// renderer should redraw everything.
  full;

  factory DirtyState._fromRaw(RenderStateDirty value) => switch (value) {
    RenderStateDirty.false$ => DirtyState.clean,
    RenderStateDirty.partial => DirtyState.partial,
    RenderStateDirty.full => DirtyState.full,
  };
}

/// Stateful render snapshot of a terminal's visible viewport, optimized for
/// repeated updates and incremental redrawing of dirty regions.
///
/// A [RenderState] holds one native snapshot handle and is reusable across
/// frames. Pair it with pre-allocated [RowIterator] and [CellIterator]
/// instances to walk the snapshot without per-frame allocation.
///
/// ## Lifecycle
///
/// Construct once, call [update] each frame to refresh the snapshot from a
/// [Terminal], then iterate rows and cells using [RowIterator] / [CellIterator]
/// bound with [RowIterator.reset] / [CellIterator.reset]. After rendering,
/// clear the global and per-row dirty flags with [clean]. When done with the
/// state entirely, call [dispose].
///
/// The key design principle is that the render state only needs access to the
/// [Terminal] during the [update] call. Between updates, all data can be read
/// without holding any lock on the terminal, enabling safe multi-threaded
/// rendering.
///
/// Calling [dispose] more than once is safe. Every other member throws a
/// [StateError] after disposal.
///
/// ## Dirty Tracking
///
/// Dirty state is tracked at two independent layers: a global [dirty] state
/// and per-row flags via [RowIterator.dirty]. [update] sets these but does
/// not clear them. After rendering a complete frame, call [clean]. For a
/// partial frame, use [RowIterator.dirty] to clear only the rows consumed.
///
/// ```dart
/// final renderState = RenderState();
/// final rows = RowIterator();
/// final cells = CellIterator();
///
/// void renderFrame(Terminal terminal) {
///   final dirty = renderState.update(terminal);
///   if (dirty == DirtyState.clean) return;
///
///   rows.reset(renderState);
///   while (rows.next()) {
///     if (dirty == DirtyState.partial && !rows.dirty) continue;
///     cells.reset(rows);
///     while (cells.next()) {
///       drawCell(cells.col, rows.index, cells.codepoint, cells.style);
///     }
///     rows.dirty = false;
///   }
///   renderState.clean();
/// }
/// ```
final class RenderState {
  static final _finalizer = Finalizer(bindings.render.renderStateFree);

  final LibGhosttyHandle _handle;

  var _disposed = false;
  var _dirty = DirtyState.clean;
  var _cols = 0;
  var _rows = 0;

  /// Number of rows captured above and below the viewport by the last update.
  ///
  /// The captured amount can be smaller than [overscanRequest] near the
  /// beginning or end of the scrollback.
  RenderOverscan get overscan {
    _ensureAlive();
    return bindings.render.renderStateGetOverscan(_handle);
  }

  /// Requested overscan for subsequent updates.
  ///
  /// Both values default to zero, which captures only the viewport. A new
  /// request takes effect on the next [update].
  RenderOverscan get overscanRequest {
    _ensureAlive();
    return bindings.render.renderStateGetOverscanRequest(_handle);
  }

  set overscanRequest(RenderOverscan value) {
    _ensureAlive();
    if (value.above < 0 || value.above > 0xffff) {
      throw RangeError.range(value.above, 0, 0xffff, 'above');
    }
    if (value.below < 0 || value.below > 0xffff) {
      throw RangeError.range(value.below, 0, 0xffff, 'below');
    }
    bindings.render.renderStateSetOverscanRequest(_handle, value);
  }

  /// Creates an empty render state.
  ///
  /// Call [update] before reading any viewport data. Throws
  /// [OutOfMemoryException] if the native allocation fails.
  RenderState() : _handle = bindings.render.renderStateNew() {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Resolved color information from the last [update]: foreground,
  /// background, cursor color, and the full 256-color palette.
  TerminalColors get colors {
    _ensureAlive();
    return bindings.render.renderStateGetColors(_handle);
  }

  /// Viewport width in cells from the last [update].
  int get cols {
    _ensureAlive();
    return _cols;
  }

  /// Cursor state from the last [update].
  ///
  /// Check [RenderStateCursor.viewportHasValue] before reading its viewport
  /// coordinates or wide-tail state. Viewport presence is independent of
  /// [RenderStateCursor.visible], which reflects terminal cursor modes.
  RenderStateCursor get cursor {
    _ensureAlive();
    return bindings.render.renderStateGetCursor(_handle);
  }

  /// Global dirty state from the last [update].
  DirtyState get dirty {
    _ensureAlive();
    return _dirty;
  }

  /// Sets the global dirty state, typically to [DirtyState.clean] after a
  /// frame has been rendered.
  ///
  /// Only affects the render-state-wide flag. Per-row dirty flags are
  /// independent; clear them via [RowIterator.dirty] during (or after)
  /// the render loop.
  set dirty(DirtyState value) {
    _ensureAlive();
    bindings.render.renderStateSetDirty(_handle, switch (value) {
      DirtyState.clean => RenderStateDirty.false$,
      DirtyState.partial => RenderStateDirty.partial,
      DirtyState.full => RenderStateDirty.full,
    });
    _dirty = value;
  }

  /// Viewport height in cells from the last [update].
  int get rows {
    _ensureAlive();
    return _rows;
  }

  /// Clears the global dirty state and every per-row dirty flag.
  ///
  /// Call this after a complete frame has been rendered. Use [dirty] and
  /// [RowIterator.dirty] when only part of a frame has been consumed.
  void clean() {
    _ensureAlive();
    bindings.render.renderStateClean(_handle);
    _dirty = .clean;
  }

  /// Releases the native render state handle.
  void dispose() {
    if (_disposed) return;
    bindings.render.renderStateFree(_handle);
    _finalizer.detach(this);
    _disposed = true;
  }

  /// Snapshots [terminal]'s state and consumes its dirty flag.
  ///
  /// After this call, all render state properties ([cols], [rows], [colors],
  /// [cursor]) reflect the terminal's current state, and [dirty] indicates
  /// what changed. Does not clear this render state's own dirty tracking;
  /// after rendering a complete frame, call [clean]. For partial rendering,
  /// clear only consumed rows via [RowIterator.dirty].
  ///
  /// Any [RowIterator] or [CellIterator] previously bound to this render
  /// state must be rebound via [RowIterator.reset] / [CellIterator.reset]
  /// before use. Do not access row or cell data through an iterator that was
  /// bound before this update.
  ///
  /// Throws [OutOfMemoryException] if updating requires allocation and
  /// that allocation fails.
  DirtyState update(Terminal terminal) {
    _ensureAlive();
    bindings.render.renderStateUpdate(_handle, terminal._terminalHandle);
    final summary = bindings.render.renderStateGetSummary(_handle);
    _dirty = DirtyState._fromRaw(summary.dirty);
    _cols = summary.cols;
    _rows = summary.rows;
    return _dirty;
  }

  void _ensureAlive() {
    if (_disposed) throw StateError('RenderState has been disposed');
  }
}
