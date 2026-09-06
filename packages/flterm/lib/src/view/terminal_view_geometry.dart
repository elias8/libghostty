part of 'terminal_view.dart';

/// Builds content layered over the complete [TerminalView] surface.
///
/// The builder is laid out over [TerminalViewGeometry.surfaceBounds] and
/// receives geometry in that local coordinate system. The application owns
/// the returned widget's layout, hit testing, semantics, and visual design.
typedef TerminalOverlayBuilder =
    Widget Function(BuildContext context, TerminalViewGeometry geometry);

/// Converts terminal cells and selections to [TerminalView] coordinates.
///
/// All rectangles use logical pixels with the top-left of the complete view
/// as their origin, including terminal padding. Geometry is a build-time
/// snapshot; use the latest value supplied to [TerminalOverlayBuilder] after
/// the view changes size, padding, font metrics, or viewport position.
///
/// ```dart
/// final match = controller.search.selectedMatch;
/// final rects = match == null
///     ? const <Rect>[]
///     : geometry.selectionRects(match);
/// ```
@immutable
final class TerminalViewGeometry {
  /// Bounds of the complete terminal view in overlay coordinates.
  final Rect surfaceBounds;

  /// Bounds occupied by whole terminal cells in overlay coordinates.
  ///
  /// This excludes terminal padding and any remaining space smaller than a
  /// complete cell.
  final Rect gridBounds;

  final CellMetrics _metrics;
  final int _cols;
  final int _rows;
  final int _viewportOffset;

  const TerminalViewGeometry._({
    required this.surfaceBounds,
    required this.gridBounds,
    required this._metrics,
    required this._cols,
    required this._rows,
    required this._viewportOffset,
  });

  /// Returns the visible cell containing [offset], or null outside the grid.
  ///
  /// [offset] uses the overlay coordinate system, including terminal padding.
  ///
  /// ```dart
  /// final position = geometry.cellAt(pointerEvent.localPosition);
  /// if (position != null) {
  ///   showCellMenu(position);
  /// }
  /// ```
  Position? cellAt(Offset offset) {
    if (!gridBounds.contains(offset)) return null;
    final position = _metrics.cellAt(offset - gridBounds.topLeft);
    return _contains(position) ? position : null;
  }

  /// Returns the rectangle of a visible viewport [position], or null.
  ///
  /// ```dart
  /// final rect = geometry.cellRect(const Position(row: 2, col: 4));
  /// if (rect != null) {
  ///   showMarker(rect.center);
  /// }
  /// ```
  Rect? cellRect(Position position) {
    if (!_contains(position)) return null;
    return _metrics.cellRect(position, gridBounds.topLeft);
  }

  /// Returns the visible rectangle for [ref], or null when it is off-screen.
  ///
  /// Grid references are short-lived libghostty snapshots and must be
  /// converted before the terminal mutates.
  ///
  /// ```dart
  /// final match = controller.search.selectedMatch;
  /// final rect = match == null ? null : geometry.gridRefRect(match.start);
  /// if (rect != null) avoidOverlayRect(rect);
  /// ```
  Rect? gridRefRect(GridRef ref) {
    final position = _positionInViewport(ref);
    return position == null ? null : cellRect(position);
  }

  /// Returns visible rectangles covering [selection].
  ///
  /// Multi-row contiguous selections produce one rectangle per visible row.
  /// Rectangular and reversed selections are normalized. A selection outside
  /// the visible rows returns an empty list. As with other [Selection]
  /// operations, the snapshot must not have been invalidated by a terminal
  /// mutation.
  ///
  /// ```dart
  /// return Stack(
  ///   children: [
  ///     for (final rect in geometry.selectionRects(match))
  ///       Positioned.fromRect(rect: rect, child: const SearchMarker()),
  ///   ],
  /// );
  /// ```
  List<Rect> selectionRects(Selection selection) {
    var start = _positionInViewport(selection.start);
    var end = _positionInViewport(selection.end);
    if (start == null || end == null || _rows == 0 || _cols == 0) {
      return const [];
    }

    if (_after(start, end)) (start, end) = (end, start);
    final firstRow = start.row.clamp(0, _rows - 1);
    final lastRow = end.row.clamp(0, _rows - 1);
    if (end.row < 0 || start.row >= _rows || firstRow > lastRow) {
      return const [];
    }

    if (selection.rectangle) {
      final firstCol = start.col < end.col ? start.col : end.col;
      final lastCol = start.col > end.col ? start.col : end.col;
      return [
        for (var row = firstRow; row <= lastRow; row++)
          ?_clippedRect(row, firstCol, lastCol + 1),
      ];
    }

    return [
      for (var row = firstRow; row <= lastRow; row++)
        ?_clippedRect(
          row,
          row == start.row ? start.col : 0,
          row == end.row ? end.col + 1 : _cols,
        ),
    ];
  }

  bool _contains(Position position) =>
      position.row >= 0 &&
      position.row < _rows &&
      position.col >= 0 &&
      position.col < _cols;

  Rect? _clippedRect(int row, int startCol, int endCol) {
    final clippedStart = startCol.clamp(0, _cols);
    final clippedEnd = endCol.clamp(0, _cols);
    if (clippedStart >= clippedEnd) return null;
    return _metrics.cellRangeRect(
      row,
      clippedStart,
      clippedEnd,
      gridBounds.topLeft,
    );
  }

  Position? _positionInViewport(GridRef ref) {
    final viewport = ref.positionIn(.viewport);
    if (viewport != null) return viewport;
    final screen = ref.positionIn(.screen);
    if (screen == null) return null;
    return Position(row: screen.row - _viewportOffset, col: screen.col);
  }

  static bool _after(Position first, Position second) =>
      first.row > second.row ||
      (first.row == second.row && first.col > second.col);
}
