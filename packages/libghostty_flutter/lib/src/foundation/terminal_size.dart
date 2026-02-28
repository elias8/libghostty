import 'package:meta/meta.dart';

/// The dimensions of a terminal screen in character cells.
///
/// ```dart
/// const size = TerminalSize(cols: 80, rows: 24);
/// print('${size.cols}×${size.rows}');
/// ```
@immutable
class TerminalSize {
  /// Number of character columns.
  final int cols;

  /// Number of character rows.
  final int rows;

  const TerminalSize({required this.cols, required this.rows});

  @override
  int get hashCode => Object.hash(TerminalSize, cols, rows);

  @override
  bool operator ==(Object other) =>
      other is TerminalSize && other.cols == cols && other.rows == rows;

  @override
  String toString() => 'TerminalSize(cols: $cols, rows: $rows)';
}
