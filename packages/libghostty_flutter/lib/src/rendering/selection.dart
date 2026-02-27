import 'dart:math' as math;

import 'package:meta/meta.dart';

/// How a selection region is shaped.
///
/// [normal] selects contiguous runs of text across lines (the standard
/// terminal selection). Word and line selections use this mode — they
/// differ only in how coordinates are computed by the input layer.
///
/// [block] selects a rectangular column range across rows (Alt+drag in
/// most terminals).
enum SelectionMode { normal, block }

/// A selected range of terminal cells.
///
/// Stores the raw start and end positions as set by the user. Normalized
/// bounds are available via [topRow], [topCol], [botRow], [botCol].
@immutable
final class TerminalSelection {
  final int startRow;
  final int startCol;
  final int endRow;
  final int endCol;
  final SelectionMode mode;

  const TerminalSelection({
    required this.startRow,
    required this.startCol,
    required this.endRow,
    required this.endCol,
    this.mode = SelectionMode.normal,
  });

  int get botCol {
    if (startRow < endRow) return endCol;
    if (startRow > endRow) return startCol;
    return math.max(startCol, endCol);
  }

  int get botRow => startRow <= endRow ? endRow : startRow;

  @override
  int get hashCode => Object.hash(startRow, startCol, endRow, endCol, mode);

  int get topCol {
    if (startRow < endRow) return startCol;
    if (startRow > endRow) return endCol;
    return math.min(startCol, endCol);
  }

  int get topRow => startRow <= endRow ? startRow : endRow;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TerminalSelection &&
          startRow == other.startRow &&
          startCol == other.startCol &&
          endRow == other.endRow &&
          endCol == other.endCol &&
          mode == other.mode;

  /// Returns true if the cell at ([row], [col]) falls within this selection.
  bool contains(int row, int col) {
    if (row < topRow || row > botRow) return false;
    if (mode == SelectionMode.block) return col >= topCol && col < botCol;
    if (topRow == botRow) return col >= topCol && col < botCol;
    if (row == topRow) return col >= topCol;
    if (row == botRow) return col < botCol;
    return true;
  }
}
