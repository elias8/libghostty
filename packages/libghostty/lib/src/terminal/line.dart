import 'package:meta/meta.dart';

import 'cell.dart';

/// An immutable snapshot of a terminal line (row of cells).
@immutable
class Line {
  final List<Cell> _cells;

  const Line(this._cells);

  Iterable<Cell> get cells => _cells;

  @override
  int get hashCode => Object.hashAll(_cells);

  int get length => _cells.length;

  /// Trimmed text content of the line.
  String get text {
    final buffer = StringBuffer();
    var lastNonEmpty = -1;
    for (var i = 0; i < _cells.length; i++) {
      if (!_cells[i].isEmpty) lastNonEmpty = i;
    }
    for (var i = 0; i <= lastNonEmpty; i++) {
      final content = _cells[i].content;
      buffer.write(content.isEmpty ? ' ' : content);
    }
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) {
    if (other is! Line || other._cells.length != _cells.length) return false;
    for (var i = 0; i < _cells.length; i++) {
      if (_cells[i] != other._cells[i]) return false;
    }
    return true;
  }

  /// Returns the cell at [col], or [Cell.empty] for out-of-bounds indices.
  Cell cellAt(int col) {
    if (col < 0 || col >= _cells.length) return Cell.empty;
    return _cells[col];
  }

  @override
  String toString() => 'Line("$text")';
}
