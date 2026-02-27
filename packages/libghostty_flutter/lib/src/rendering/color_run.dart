import 'package:flutter/painting.dart';

/// A horizontal run of cells sharing the same background color.
final class ColorRun {
  /// Inclusive start column.
  final int startCol;

  /// Exclusive end column.
  final int endCol;

  /// Background color for this run.
  final Color color;

  const ColorRun(this.startCol, this.endCol, this.color);
}
