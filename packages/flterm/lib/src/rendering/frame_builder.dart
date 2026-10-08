import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:libghostty/libghostty.dart';

import '../foundation/cell_metrics.dart';
import '../foundation/terminal_theme.dart';
import '../foundation/viewport_selection.dart';
import '../links/link_snapshot.dart';
import 'atlas/atlas.dart';
import 'atlas/sprite_buffer.dart';
import 'cell_content_resolver.dart';
import 'paint_state.dart';

part 'frame_cursor.dart';
part 'frame_preedit.dart';
part 'frame_row_cache.dart';
part 'frame_rows.dart';
part 'frame_style.dart';

/// Builds terminal visual layers for the current frame.
///
/// Reads terminal cells and writes [SpriteBuffer] channels for text, emoji,
/// built-in sprites, backgrounds, and decorations. The terminal surface owns
/// this builder and coordinates its lifecycle with the atlas and painters.
class FrameBuilder {
  final Atlas _atlas;
  final PaintState _state;
  final RowIterator _rows;
  final CellIterator _cells;
  final SpriteBuffer _sprites;
  final RenderState _renderState;
  final RowDirtyTracker _dirtyRows;
  final Map<RenderRowId, _DecodedRow> _decodedRows = {};
  var _slotIds = <RenderRowId?>[];
  Terminal? _terminal;
  var _blinkRows = Uint8List(0);

  late final _RowBuilder _rowBuilder;
  late final _CursorFrameBuilder _cursorBuilder;

  FrameBuilder(this._atlas, this._sprites, this._state)
    : _renderState = RenderState(),
      _rows = RowIterator(),
      _cells = CellIterator(),
      _dirtyRows = RowDirtyTracker() {
    final content = CellContentResolver(_atlas);
    _rowBuilder = _RowBuilder(
      atlas: _atlas,
      sprites: _sprites,
      state: _state,
      content: content,
    );
    _cursorBuilder = _CursorFrameBuilder(_state, content);
  }

  /// Reconfigures sprite storage for the current grid size.
  void configure(int rows, int cols) {
    _sprites.configure(rows, cols);
    _dirtyRows.resize(rows);
    _decodedRows.clear();
    _slotIds = List<RenderRowId?>.filled(rows, null);
    _blinkRows = Uint8List(rows);
  }

  /// Releases the owned libghostty iterators.
  void dispose() {
    _decodedRows.clear();
    _slotIds = [];
    _terminal = null;
    _cells.dispose();
    _rows.dispose();
    _renderState.dispose();
  }

  /// Rebuilds every visible row on the next sync.
  void markAllRowsDirty() => _dirtyRows.markAll();

  /// Rebuilds only rows containing SGR 5 blinking cells on the next sync.
  void markBlinkRowsDirty() {
    for (var row = 0; row < _blinkRows.length; row++) {
      if (_blinkRows[row] != 0) _dirtyRows.markRow(row);
    }
  }

  /// Rebuilds rows `[from, toExclusive)` on the next sync.
  void markRowsDirty(int from, int toExclusive) {
    _dirtyRows.markRange(from, toExclusive);
  }

  /// Re-resolves the cursor glyph from the last cursor cell snapshot.
  ///
  /// Used when flterm-side state changes, such as focus or blink visibility,
  /// without a new terminal render state.
  void refreshCursorGlyph() => _cursorBuilder.refreshGlyph();

  /// Syncs terminal state into paint-ready buffers.
  void sync(
    Terminal terminal, {
    required bool terminalDirty,
    bool searchDirty = false,
    List<Selection> searchMatches = const [],
    Selection? selectedSearchMatch,
    String preeditText = '',
    LinkSnapshot linkSnapshot = .empty,
  }) {
    var dirty = DirtyState.clean;
    final terminalChanged = _bindTerminal(terminal);

    if (searchDirty) {
      _rowBuilder.updateSearch(
        searchMatches,
        selectedSearchMatch,
        viewportOffset: terminal.scrollbar.offset,
        dirtyRows: _dirtyRows,
      );
    }

    if (terminalDirty || terminalChanged) {
      dirty = _renderState.update(terminal);
      if (terminalChanged) dirty = .full;
      final scrollbar = terminal.scrollbar;
      final terminalColorsChanged = _state.updateTerminalColors(
        _renderState.colors,
      );

      _state.viewportOffset = scrollbar.offset;
      // RenderState updates colors even when its dirty result is clean.
      // Since sprite buffers cache resolved ARGB values, color changes need
      // the same full rebuild as other global terminal-state changes.
      if (terminalColorsChanged) {
        _decodedRows.clear();
        dirty = .full;
      }

      _syncCursor(terminal, scrollbar);
    }

    // Preedit text is render-only state. It can dirty rows even when the
    // terminal render state is unchanged, such as a composing update over a
    // stable prompt.
    final preeditRows = _rowBuilder.updatePreedit(
      preeditText,
      cursor: _state.cursor,
    );
    if (preeditRows.previous case final row?) _dirtyRows.markRow(row);
    if (preeditRows.current case final row?) _dirtyRows.markRow(row);
    _state.preeditActive = preeditRows.active;

    if (dirty == .clean && !_dirtyRows.anyDirty) return;
    _build(dirty == .clean ? .partial : dirty, linkSnapshot);
    if (terminalDirty || terminalChanged) _renderState.clean();
  }

  void _build(DirtyState dirty, LinkSnapshot links) {
    _rowBuilder.beginFrame(links);

    final rebuildAll = dirty != DirtyState.partial;
    final useDirtyIterator =
        dirty == _renderState.dirty &&
        dirty != .clean &&
        (dirty != .partial || !_dirtyRows.anyDirty);
    _rows.reset(_renderState);

    while (useDirtyIterator ? _rows.nextDirty() : _rows.next()) {
      final row = _rows.viewportY;
      if (row < 0 || row >= _state.rows) continue;
      final id = _rows.id;
      _slotIds[row] = id;
      if (useDirtyIterator ||
          rebuildAll ||
          _rows.dirty ||
          _dirtyRows.isDirty(row)) {
        final decoded = _decodedRow(id, _rows);
        _blinkRows[row] =
            _rowBuilder.rebuildRow(row, decoded, selection: _rows.selection)
            ? 1
            : 0;
      }
    }

    final visibleIds = _slotIds.whereType<RenderRowId>().toSet();
    _decodedRows.removeWhere((id, _) => !visibleIds.contains(id));

    _dirtyRows._clear();
    _atlas.ensureImage();
    _sprites.seal();
  }

  bool _bindTerminal(Terminal terminal) {
    final changed = _terminal != null && !identical(_terminal, terminal);
    if (changed) {
      _decodedRows.clear();
      _slotIds.fillRange(0, _slotIds.length, null);
    }
    _terminal = terminal;
    return changed;
  }

  _DecodedRow _decodedRow(RenderRowId id, RowIterator rows) {
    final cached = _decodedRows[id];
    if (!rows.dirty && cached != null) return cached;

    _cells.reset(rows);
    final cells = List<_DecodedCell>.generate(
      _state.cols,
      (_) => const _DecodedCell.empty(),
      growable: false,
    );
    while (_cells.next() && _cells.col < _state.cols) {
      final col = _cells.col;
      final graphemeLength = _cells.graphemeLength;
      cells[col] = _DecodedCell(
        codepoint: _cells.codepoint,
        graphemeLength: graphemeLength,
        content: graphemeLength > 1 ? _cells.content : null,
        wide: _cells.wide,
        styleId: _cells.styleId,
        style: _cells.style,
        backgroundArgb: _cells.hasText ? null : _cells.backgroundArgb,
        hasText: _cells.hasText,
        hasStyling: _cells.hasStyling,
      );
    }
    final decoded = _DecodedRow(cells);
    _decodedRows[id] = decoded;
    return decoded;
  }

  void _syncCursor(Terminal terminal, Scrollbar scrollbar) {
    final cursor = _renderState.cursor;
    final scrollbackLen = scrollbar.total - scrollbar.visible;
    final inViewport =
        cursor.viewportHasValue &&
        cursor.visible &&
        (scrollbackLen <= 0 || scrollbar.offset >= scrollbackLen) &&
        cursor.viewportY >= 0 &&
        cursor.viewportY < _state.rows &&
        cursor.viewportX >= 0 &&
        cursor.viewportX < _state.cols;
    if (!inViewport) {
      _cursorBuilder.sync(cursor, cell: null);
      return;
    }

    final adjustedCursor = cursor.wideTail && cursor.viewportX > 0
        ? cursor.copyWith(viewportX: cursor.viewportX - 1)
        : cursor;
    final effectiveCursor = adjustedCursor.visualStyle == CursorShape.block
        ? adjustedCursor.copyWith(visualStyle: _state.theme.cursor.shape)
        : adjustedCursor;
    final ref = GridRef.at(
      terminal,
      Position(row: effectiveCursor.viewportY, col: effectiveCursor.viewportX),
    );
    _cursorBuilder.sync(
      effectiveCursor,
      cell: (content: ref.content, style: ref.style, wide: ref.isWide),
      color: terminal.cursorColor,
    );
  }
}

/// Tracks per-row dirtiness from sources outside libghostty's own row-dirty
/// flag, such as selection, blink, layout, or atlas changes.
///
/// [FrameBuilder] combines this with [RowIterator.dirty] when deciding
/// whether to re-emit each row, and clears it at the end of every build.
class RowDirtyTracker {
  var _rows = Uint8List(0);
  var _anyDirty = false;

  bool get anyDirty => _anyDirty;

  /// Whether [row] is marked dirty. Out-of-range rows read as clean.
  bool isDirty(int row) => row >= 0 && row < _rows.length && _rows[row] != 0;

  void markAll() {
    if (_rows.isEmpty) return;
    _rows.fillRange(0, _rows.length, 1);
    _anyDirty = true;
  }

  /// Marks rows `[from, toExclusive)` dirty, clamped to the current row count.
  void markRange(int from, int toExclusive) {
    final start = from < 0 ? 0 : from;
    final end = toExclusive > _rows.length ? _rows.length : toExclusive;
    if (start >= end) return;
    _rows.fillRange(start, end, 1);
    _anyDirty = true;
  }

  /// Marks a single [row] dirty. Out-of-range rows are ignored.
  void markRow(int row) {
    if (row < 0 || row >= _rows.length) return;
    _rows[row] = 1;
    _anyDirty = true;
  }

  /// Resizes to track [rowCount] rows and clears all flags.
  void resize(int rowCount) {
    if (_rows.length != rowCount) {
      _rows = Uint8List(rowCount);
    } else {
      _rows.fillRange(0, rowCount, 0);
    }
    _anyDirty = false;
  }

  void _clear() {
    if (!_anyDirty) return;
    _rows.fillRange(0, _rows.length, 0);
    _anyDirty = false;
  }
}
