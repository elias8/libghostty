part of 'terminal.dart';

/// Row-local selected column range in a [RenderState] snapshot.
///
/// Both columns are inclusive. [RowIterator.selection] returns null when the
/// current row does not intersect the selection captured by the render state.
typedef RowSelectionRange = ({int startCol, int endCol});

/// Reusable iterator over the rows of a [RenderState] snapshot.
///
/// Allocate once and reuse across frames. Advance with [next] and read the
/// current row via the getter properties; there is no standalone row object.
///
/// Bind to a [RenderState] with [reset]; call [reset] again after every
/// [RenderState.update] so the iterator tracks the fresh snapshot.
/// Do not access the iterator after a render update until it has been rebound.
/// Access before a successful [next] throws [StateError].
/// Calling [dispose] more than once is safe; every other member throws
/// [StateError] after disposal.
///
/// ```dart
/// final rows = RowIterator();
///
/// rows.reset(renderState);
/// while (rows.nextDirty()) {
///   renderRow(rows.index);
/// }
/// ```
final class RowIterator {
  static final _finalizer = Finalizer(bindings.render.rowIteratorFree);

  final LibGhosttyHandle _handle;

  var _disposed = false;
  RenderState? _renderState;
  var _positionGeneration = 0;
  var _positioned = false;
  late RawRowSummary _rowSummary;
  var _rowSummaryValid = false;
  var _index = -1;

  /// Creates an unbound row iterator.
  ///
  /// Must be populated with [reset] before [next] is called.
  /// Throws [OutOfMemoryException] if the native allocation fails.
  RowIterator() : _handle = bindings.render.rowIteratorNew() {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Whether the current row has been modified since its dirty flag was
  /// last cleared.
  bool get dirty {
    _ensurePositioned();
    return bindings.render.rowIteratorGetDirty(_handle);
  }

  /// Sets or clears the dirty flag for the current row.
  set dirty(bool value) {
    _ensurePositioned();
    bindings.render.rowIteratorSetDirty(_handle, dirty: value);
  }

  /// Whether any cell in the current row contains a grapheme cluster
  /// (multi-codepoint character).
  bool get hasGrapheme {
    _ensureMetadata();
    return _rowSummary.grapheme;
  }

  /// Whether any cell in the current row has a hyperlink (OSC 8).
  bool get hasHyperlink {
    _ensureMetadata();
    return _rowSummary.hyperlink;
  }

  /// Whether any cell in the current row has a Kitty virtual placeholder.
  bool get hasKittyVirtualPlaceholder {
    _ensureMetadata();
    return _rowSummary.kittyVirtualPlaceholder;
  }

  /// Whether any cell in the current row has non-default styling.
  bool get hasStyled {
    _ensureMetadata();
    return _rowSummary.styled;
  }

  /// Zero-based position among rows captured by the render state.
  ///
  /// Undefined before the first successful [next] call.
  int get index {
    _ensurePositioned();
    return _index;
  }

  /// Row position relative to the viewport top.
  ///
  /// This can be negative for rows above the viewport when overscan is
  /// enabled. Rows below the viewport start at [RenderState.rows].
  int get viewportY {
    _ensurePositioned();
    return bindings.render.rowIteratorGetViewportY(_handle);
  }

  /// Stable opaque identity for the current row across updates.
  ///
  /// Use the value for equality or as a cache key. Rebuild cached row data
  /// whenever [dirty] is true.
  RenderRowId get id {
    _ensurePositioned();
    return bindings.render.rowIteratorGetId(_handle);
  }

  /// Selected column range for the current row, or null when the row does
  /// not intersect the selection captured by the render state.
  ///
  /// The returned columns are row-local and inclusive.
  RowSelectionRange? get selection {
    _ensurePositioned();
    final selection = bindings.render.rowIteratorGetSelection(_handle);
    if (selection case (startCol: final start, endCol: final end)) {
      return (startCol: start, endCol: end);
    }
    return null;
  }

  /// Semantic prompt state of the current row.
  SemanticPrompt get semanticPrompt {
    _ensureMetadata();
    return _rowSummary.semanticPrompt;
  }

  /// Whether the current row is soft-wrapped into the next row.
  bool get wrap {
    _ensureMetadata();
    return _rowSummary.wrap;
  }

  /// Whether the current row is a continuation of a soft-wrap from the
  /// previous row.
  bool get wrapContinuation {
    _ensureMetadata();
    return _rowSummary.wrapContinuation;
  }

  /// Releases the native iterator handle.
  void dispose() {
    if (_disposed) return;
    bindings.render.rowIteratorFree(_handle);
    _finalizer.detach(this);
    _disposed = true;
  }

  /// Advances to the next row. Returns true when a row is available and
  /// the getter properties reflect it; returns false when the snapshot
  /// is exhausted.
  bool next() {
    _ensureCurrent();
    final hasNext = bindings.render.rowIteratorNext(_handle);
    _positionGeneration++;
    if (hasNext) {
      _rowSummaryValid = false;
      _index++;
      _positioned = true;
    } else {
      _rowSummaryValid = false;
      _positioned = false;
    }
    return hasNext;
  }

  /// Advances to the next row requiring a redraw.
  ///
  /// Rows are visited in top-to-bottom order. A clean render state produces
  /// no rows, a partially dirty state skips clean rows, and a fully dirty
  /// state visits every remaining row. The iterator remains positioned on the
  /// returned row, just like [next]. Use [viewportY] for its viewport-relative
  /// position when overscan is enabled.
  bool nextDirty() {
    _ensureCurrent();
    final index = bindings.render.rowIteratorNextDirty(_handle);
    _positionGeneration++;
    if (index case final value?) {
      _rowSummaryValid = false;
      _index = value;
      _positioned = true;
      return true;
    }
    _rowSummaryValid = false;
    _positioned = false;
    return false;
  }

  /// Rebinds this iterator to [renderState] and rewinds to the start.
  ///
  /// The render state must have been populated via [RenderState.update].
  /// Any [CellIterator] previously bound to this iterator must be rebound
  /// via [CellIterator.reset] before further use.
  void reset(RenderState renderState) {
    _ensureAlive();
    renderState._ensureAlive();
    bindings.render.rowIteratorInit(_handle, renderState._handle);
    _renderState = renderState;
    _positionGeneration++;
    _rowSummaryValid = false;
    _index = -1;
    _positioned = false;
  }

  void _ensureAlive() {
    if (_disposed) throw StateError('RowIterator has been disposed');
  }

  void _ensureCurrent() {
    _ensureAlive();
    if (_renderState == null) {
      throw StateError('RowIterator has not been bound to a RenderState');
    }
  }

  void _ensureMetadata() {
    _ensurePositioned();
    if (!_rowSummaryValid) _refreshMetadata();
  }

  void _ensurePositioned() {
    _ensureCurrent();
    if (!_positioned) {
      throw StateError('RowIterator is not positioned on a row');
    }
  }

  void _refreshMetadata() {
    final rawRow = bindings.render.rowIteratorGetRawRow(_handle);
    _rowSummary = bindings.render.rowGetSummary(rawRow);
    _rowSummaryValid = true;
  }
}
