part of 'terminal.dart';

/// A resolved reference to a specific cell position in the terminal grid.
///
/// Created via [GridRef.at]. A grid reference is only valid until the next
/// mutating operation on the terminal instance, including seemingly unrelated
/// operations. Read or copy the needed information before mutating the
/// terminal, then create a new reference afterward.
///
/// Not intended for render loops. Use [RenderState] with [RowIterator] and
/// [CellIterator] for performance-critical rendering.
///
/// ```dart
/// final ref = GridRef.at(terminal, const Position(row: 0, col: 0));
/// print(ref.content);
/// print(ref.style);
/// ```
@immutable
final class GridRef {
  final RawGridRef _value;
  final Terminal _terminal;

  /// Resolves the grid cell at [position] in the coordinate space
  /// identified by [pointTag].
  ///
  /// [PointTag.active] and [PointTag.viewport] are fast lookups;
  /// [PointTag.screen] and [PointTag.history] may be expensive for large
  /// scrollback buffers because they traverse the full scrollback page
  /// list.
  ///
  /// Throws [InvalidValueException] if the coordinates are out of range.
  factory GridRef.at(
    Terminal terminal,
    Position position, {
    PointTag pointTag = .active,
  }) => GridRef._(terminal, position, pointTag: pointTag);

  GridRef._(Terminal terminal, Position position, {PointTag pointTag = .active})
    : _terminal = terminal,
      _value = bindings.render.terminalGridRef(
        terminal._requireHandle(),
        pointTag,
        position,
      );

  const GridRef._fromValue(this._terminal, this._value);

  /// The cell's full grapheme cluster as a string, or empty if the cell
  /// has no text.
  String get content {
    final codepoints = graphemes;
    return codepoints.isEmpty ? '' : String.fromCharCodes(codepoints);
  }

  /// The cell's grapheme cluster as a list of Unicode codepoints. The
  /// primary codepoint is first, followed by any combining codepoints.
  /// Empty if the cell has no text.
  List<int> get graphemes {
    _terminal._requireHandle();
    return bindings.render.gridRefGraphemes(_value);
  }

  @override
  int get hashCode => Object.hash(GridRef, _terminal, _value);

  /// The hyperlink URI at this position, or null if the cell has no
  /// hyperlink.
  String? get hyperlinkUri {
    _terminal._requireHandle();
    final uri = bindings.render.gridRefHyperlinkUri(_value);
    return uri?.isEmpty ?? true ? null : uri;
  }

  /// Whether the cell is the first cell of a wide character.
  bool get isWide => wide == CellWidth.wide;

  /// Whether this row is soft-wrapped to the next row.
  bool get rowWrap => bindings.render.rowGetWrap(_row);

  /// The [Style] of the cell at this position.
  Style get style {
    _terminal._requireHandle();
    return bindings.render.gridRefStyle(_value);
  }

  /// The cell's width: [CellWidth.narrow], [CellWidth.wide], or
  /// [CellWidth.spacerTail].
  CellWidth get wide => bindings.render.cellGetWide(_cell);

  RawCell get _cell {
    _terminal._requireHandle();
    return bindings.render.gridRefCell(_value);
  }

  RawRow get _row {
    _terminal._requireHandle();
    return bindings.render.gridRefRow(_value);
  }

  @override
  bool operator ==(Object other) =>
      other is GridRef &&
      identical(other._terminal, _terminal) &&
      other._value == _value;

  /// Converts this grid reference to coordinates in the given coordinate
  /// space. Returns null if the reference falls outside the requested
  /// system (e.g. a scrollback row cannot be expressed in active
  /// coordinates).
  Position? positionIn(PointTag pointTag) {
    final position = bindings.render.terminalPointFromGridRef(
      _terminal._requireHandle(),
      _value,
      pointTag,
    );
    return position;
  }

  @override
  String toString() => 'GridRef(${_value.x},${_value.y})';
}
