part of 'terminal.dart';

/// Reusable iterator over the cells of a row inside a [RenderState] snapshot.
///
/// Allocate once and reuse across rows and frames. Advance with [next]
/// (sequential) or [select] (random access within the row) and read the
/// current cell via the getter properties; there is no standalone cell
/// object.
///
/// Bind to a row with [reset]; call [reset] again after each
/// [RowIterator.next] or [RenderState.update] so the iterator tracks the
/// current row.
/// Access after the row advances, after a render update, or before a
/// successful [next] or [select] throws [StateError].
/// Calling [dispose] more than once is safe; every other member throws
/// [StateError] after disposal.
///
/// ```dart
/// final cells = CellIterator();
///
/// rows.reset(renderState);
/// while (rows.next()) {
///   cells.reset(rows);
///   while (cells.next()) {
///     print('col ${cells.col}: ${cells.content}');
///   }
/// }
/// ```
final class CellIterator {
  static final _finalizer = Finalizer(bindings.render.rowCellsFree);

  final LibGhosttyHandle _handle;

  var _disposed = false;
  RowIterator? _rowIterator;
  RawCellsView? _rawCells;
  var _rawCellsAvailable = false;
  var _rowPositionGeneration = 0;
  final _rawCellData = RawCellData();
  RawCell? _fallbackCell;
  var _graphemeLen = 0;
  var _prevStyleId = -1;
  var _cachedStyle = const Style();
  var _col = -1;
  var _isSelected = false;
  var _metadataValid = false;
  var _selectedValid = false;

  /// Creates an unbound cell iterator.
  ///
  /// Must be populated with [reset] before [next] or [select] is called.
  /// Throws [OutOfMemoryException] if the native allocation fails.
  CellIterator() : _handle = bindings.render.rowCellsNew() {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Resolved background color of the current cell, or null when the cell
  /// has no explicit background. Resolves palette indices through the
  /// active palette; when null, the caller should use the terminal's
  /// default background.
  RgbColor? get background {
    _ensureCurrent();
    if (_rawCellsAvailable) {
      if (!_metadataValid) _refreshMetadata();
      if (_rawCellData.hasBackgroundRgb) {
        return RgbColor(
          _rawCellData.backgroundR,
          _rawCellData.backgroundG,
          _rawCellData.backgroundB,
        );
      }
    }
    return bindings.render.rowCellsGetBgColor(_handle);
  }

  /// Resolved background as packed ARGB int, or null if unset.
  int? get backgroundArgb {
    _ensureCurrent();
    if (_rawCellsAvailable) {
      if (!_metadataValid) _refreshMetadata();
      if (_rawCellData.hasBackgroundRgb) {
        return 0xFF000000 |
            (_rawCellData.backgroundR << 16) |
            (_rawCellData.backgroundG << 8) |
            _rawCellData.backgroundB;
      }
    }
    return bindings.render.rowCellsGetBgColorArgb(_handle);
  }

  /// Primary codepoint of the current cell, or 0 if the cell has no text.
  int get codepoint {
    _ensureMetadata();
    return _rawCellData.codepoint;
  }

  /// Column index of the current cell within the row (zero-based).
  ///
  /// Undefined before the first successful [next] or [select] call.
  int get col {
    _ensureCurrent();
    return _col;
  }

  /// Full grapheme cluster of the current cell as a string, or empty if
  /// the cell has no text.
  String get content {
    _ensureMetadata();
    if (_graphemeLen == 0) return '';
    if (_graphemeLen == 1) return String.fromCharCode(_rawCellData.codepoint);
    return String.fromCharCodes(
      bindings.render.rowCellsGetGraphemes(_handle, _graphemeLen),
    );
  }

  /// Resolved foreground color of the current cell, or null when the cell
  /// has no explicit foreground. Resolves palette indices through the
  /// active palette. Bold color handling is not applied; handle bold
  /// styling separately. When null, the caller should use the terminal's
  /// default foreground.
  RgbColor? get foreground {
    _ensureCurrent();
    return bindings.render.rowCellsGetFgColor(_handle);
  }

  /// Resolved foreground as packed ARGB int, or null if unset.
  int? get foregroundArgb {
    _ensureCurrent();
    return bindings.render.rowCellsGetFgColorArgb(_handle);
  }

  /// Number of codepoints in the current cell's grapheme cluster (0 =
  /// empty).
  int get graphemeLength {
    _ensureMetadata();
    return _graphemeLen;
  }

  /// Whether the current cell has a hyperlink (OSC 8).
  bool get hasHyperlink {
    _ensureMetadata();
    if (_rawCellsAvailable) return _rawCellData.hasHyperlink;
    return bindings.render.cellGetHasHyperlink(_fallbackCell!);
  }

  /// Whether the current cell has non-default styling attributes.
  bool get hasStyling {
    _ensureCurrent();
    if (_rawCellsAvailable) {
      if (!_metadataValid) _refreshMetadata();
      return _rawCellData.styleId != 0;
    }
    return bindings.render.rowCellsGetHasStyling(_handle);
  }

  /// Whether the current cell contains any text.
  bool get hasText {
    _ensureMetadata();
    return _graphemeLen > 0;
  }

  /// Whether the current cell is protected (DECSCA).
  bool get isProtected {
    _ensureMetadata();
    if (_rawCellsAvailable) return _rawCellData.isProtected;
    return bindings.render.cellGetProtected(_fallbackCell!);
  }

  /// Whether the current cell is contained within the current selection.
  ///
  /// Returns true when the cell's column is within the current row's
  /// row-local selection range, and false otherwise. Rendering colors,
  /// inversion, etc are caller policy.
  bool get isSelected {
    _ensureCurrent();
    if (_rawCellsAvailable) return _rawCells!.isSelected(_col);
    if (!_selectedValid) {
      _isSelected = bindings.render.rowCellsGetSelected(_handle);
      _selectedValid = true;
    }
    return _isSelected;
  }

  /// Semantic content type of the current cell.
  SemanticContent get semanticContent {
    _ensureMetadata();
    if (_rawCellsAvailable) return _rawCellData.semanticContent;
    return bindings.render.cellGetSemanticContent(_fallbackCell!);
  }

  /// Style of the current cell. Cached per style id to avoid redundant
  /// lookups across cells sharing the same style.
  Style get style {
    _ensureMetadata();
    if (_rawCellData.styleId != _prevStyleId) {
      _cachedStyle = _rawCellData.styleId == 0
          ? const Style()
          : bindings.render.rowCellsGetStyle(_handle);
      _prevStyleId = _rawCellData.styleId;
    }
    return _cachedStyle;
  }

  /// Internal style identifier for the current cell. Cells with the same
  /// style id share identical styling attributes.
  int get styleId {
    _ensureMetadata();
    return _rawCellData.styleId;
  }

  /// Cell width: [CellWidth.narrow], [CellWidth.wide], or
  /// [CellWidth.spacerTail] (the second cell of a wide character).
  CellWidth get wide {
    _ensureMetadata();
    return _rawCellData.wide;
  }

  /// Releases the native iterator handle.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _rowIterator = null;
    _rawCells = null;
    _rawCellsAvailable = false;
    _invalidate();
    bindings.render.rowCellsFree(_handle);
    _finalizer.detach(this);
  }

  /// Advances to the next cell. Returns true when a cell is available and
  /// the getter properties reflect it; returns false when the row is
  /// exhausted.
  bool next() {
    _ensureCurrent();
    if (!bindings.render.rowCellsNext(_handle)) return false;
    _col++;
    _invalidate();
    return true;
  }

  /// Rebinds this iterator to the current row of [rowIterator] and
  /// rewinds to the first cell.
  ///
  /// The row iterator must be positioned on a valid row (i.e. its most
  /// recent [RowIterator.next] must have returned true). Subsequent
  /// [next] / [select] calls read cells from that row.
  void reset(RowIterator rowIterator) {
    final handle = _requireHandle();
    rowIterator._ensurePositioned();
    _rowIterator = null;
    _rawCellsAvailable = false;
    _prevStyleId = -1;
    _invalidate();
    bindings.render.rowCellsInit(handle, rowIterator._handle);
    final rawCells = _rawCells ??= RawCellsView();
    _rawCellsAvailable = bindings.render.rowIteratorGetRawCells(
      rowIterator._handle,
      rawCells,
    );
    _rowIterator = rowIterator;
    _rowPositionGeneration = rowIterator._positionGeneration;
    _col = -1;
  }

  /// Positions the iterator at column [col] within the current row so
  /// subsequent reads reflect that cell.
  ///
  /// Can be used instead of or mixed with [next] for random access.
  /// Calling [next] after [select] advances from the selected position.
  ///
  /// Throws [InvalidValueException] if [col] is out of range.
  void select(int col) {
    _ensureCurrent();
    bindings.render.rowCellsSelect(_handle, col);
    _col = col;
    _invalidate();
  }

  LibGhosttyHandle _requireHandle() {
    if (_disposed) throw StateError('CellIterator has been disposed');
    return _handle;
  }

  @pragma('vm:prefer-inline')
  void _ensureCurrent() {
    final rowIterator = _rowIterator;
    if (rowIterator == null ||
        rowIterator._positionGeneration != _rowPositionGeneration ||
        rowIterator._renderGeneration !=
            rowIterator._renderState!._generation) {
      _throwInvalidCurrent(rowIterator);
    }
  }

  Never _throwInvalidCurrent(RowIterator? rowIterator) {
    if (rowIterator == null) {
      if (_disposed) throw StateError('CellIterator has been disposed');
      throw StateError('CellIterator has not been bound to a row');
    }
    if (rowIterator._positionGeneration != _rowPositionGeneration) {
      if (rowIterator._disposed) {
        throw StateError('RowIterator has been disposed');
      }
      throw StateError('CellIterator has been invalidated by a row update');
    }
    if (rowIterator._renderState!._disposed) {
      throw StateError('RenderState has been disposed');
    }
    throw StateError('CellIterator has been invalidated by a render update');
  }

  @pragma('vm:prefer-inline')
  void _ensureMetadata() {
    _ensureCurrent();
    if (!_metadataValid) _refreshMetadata();
  }

  void _invalidate() {
    _fallbackCell = null;
    _metadataValid = false;
    _selectedValid = false;
  }

  void _refreshMetadata() {
    _fallbackCell = null;
    if (_rawCellsAvailable) {
      if (bindings.render.decodeRawCell(_rawCells!, _col, _rawCellData)) {
        _graphemeLen = _rawCellData.hasGrapheme
            ? bindings.render.rowCellsGetGraphemeLen(_handle)
            : _rawCellData.codepoint == 0
            ? 0
            : 1;
        _selectedValid = true;
        _metadataValid = true;
        return;
      }
      _rawCellsAvailable = false;
    }

    _rawCellData.hasBackgroundRgb = false;
    final rowCell = bindings.render.rowCellsGetSummary(_handle);
    final rawCell = rowCell.rawCell;
    _graphemeLen = rowCell.graphemeLen;
    _isSelected = rowCell.selected;
    _selectedValid = true;

    final cell = bindings.render.cellGetSummary(rawCell);
    _fallbackCell = rawCell;
    _rawCellData.styleId = cell.styleId;
    _rawCellData.codepoint = _graphemeLen > 0 ? cell.codepoint : 0;
    _rawCellData.wide = cell.wide;
    _metadataValid = true;
  }
}
