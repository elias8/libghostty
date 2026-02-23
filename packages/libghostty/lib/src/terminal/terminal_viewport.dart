import 'cell.dart';
import 'line.dart';
import 'screen.dart';
import 'scrollback.dart';

/// A read-only snapshot that merges scrollback history and the live screen
/// for a given scroll offset.
///
/// All data is fetched eagerly at construction time. Subsequent reads
/// (`cellAt`, `lineAt`, coordinate methods) are pure Dart list lookups
/// with zero FFI calls.
///
/// ```dart
/// final viewport = TerminalViewport(
///   screen: terminal.screen,
///   scrollback: terminal.scrollback,
///   scrollOffset: controller.scrollOffset,
/// );
/// for (var row = 0; row < viewport.rows; row++) {
///   final cell = viewport.cellAt(row, 0);
/// }
/// ```
class TerminalViewport {
  final int cols;
  final int rows;
  final int scrollOffset;
  final List<Line> _lines;
  final int scrollbackLength;

  factory TerminalViewport({
    required Screen screen,
    required int scrollOffset,
    required Scrollback scrollback,
  }) {
    final cols = screen.cols;
    final rows = screen.rows;
    final scrollbackLength = scrollback.length;
    final firstAbsolute = scrollbackLength - scrollOffset;

    // Batch-fetch visible scrollback lines in a single call.
    final sbStart = firstAbsolute.clamp(0, scrollbackLength);
    final sbEnd = (firstAbsolute + rows).clamp(0, scrollbackLength);
    final sbCount = sbEnd - sbStart;
    final sbLines = sbCount > 0
        ? scrollback.linesInRange(sbStart, sbCount)
        : const <Line>[];

    final lines = List<Line>.generate(rows, (viewportRow) {
      final absoluteRow = firstAbsolute + viewportRow;
      if (absoluteRow < 0) return const Line([]);
      if (absoluteRow < scrollbackLength) {
        return sbLines[absoluteRow - sbStart];
      }
      final screenRow = absoluteRow - scrollbackLength;
      if (screenRow >= rows) return const Line([]);
      return screen.lineAt(screenRow);
    });

    return TerminalViewport._(
      cols: cols,
      rows: rows,
      scrollOffset: scrollOffset,
      scrollbackLength: scrollbackLength,
      lines: lines,
    );
  }

  TerminalViewport._({
    required this.cols,
    required this.rows,
    required this.scrollOffset,
    required this.scrollbackLength,
    required List<Line> lines,
  }) : _lines = lines;

  bool get isScrolledBack => scrollOffset > 0;

  int absoluteRowToViewport(int absoluteRow) {
    return absoluteRow - scrollbackLength + scrollOffset;
  }

  Cell cellAt(int viewportRow, int col) {
    if (viewportRow < 0 || viewportRow >= rows) return Cell.empty;
    return _lines[viewportRow].cellAt(col);
  }

  bool isAbsoluteRowVisible(int absoluteRow) {
    final viewportRow = absoluteRowToViewport(absoluteRow);
    return viewportRow >= 0 && viewportRow < rows;
  }

  Line lineAt(int viewportRow) {
    if (viewportRow < 0 || viewportRow >= rows) return const Line([]);
    return _lines[viewportRow];
  }

  int viewportRowToAbsolute(int viewportRow) {
    return scrollbackLength - scrollOffset + viewportRow;
  }
}
