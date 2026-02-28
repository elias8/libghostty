import 'dart:ui';

import 'package:meta/meta.dart';

/// Pixel dimensions of a single terminal cell.
///
/// Computed by measuring a reference character with [CellMetrics.measure].
/// Used by the rendering layer to position glyphs and compute terminal
/// dimensions from available pixel space.
///
/// ```dart
/// final metrics = CellMetrics.measure(fontFamily: 'monospace', fontSize: 14);
/// final cols = (availableWidth / metrics.cellWidth).floor();
/// ```
@immutable
class CellMetrics {
  /// Width of one character cell in logical pixels.
  final double cellWidth;

  /// Height of one character cell in logical pixels.
  final double cellHeight;

  /// Distance from the top of the cell to the alphabetic baseline.
  final double baseline;

  const CellMetrics({
    required this.cellWidth,
    required this.cellHeight,
    required this.baseline,
  });

  /// Measures cell dimensions by laying out a reference character.
  ///
  /// Uses [fontFamily] and [fontSize] to build a paragraph containing 'M'
  /// and reads the resulting layout metrics.
  factory CellMetrics.measure({
    required String fontFamily,
    required double fontSize,
  }) {
    final style = ParagraphStyle(fontFamily: fontFamily, fontSize: fontSize);
    final paragraph = (ParagraphBuilder(style)..addText('M')).build()
      ..layout(const ParagraphConstraints(width: double.infinity));
    final metrics = CellMetrics(
      cellHeight: paragraph.height,
      cellWidth: paragraph.longestLine,
      baseline: paragraph.alphabeticBaseline,
    );

    paragraph.dispose();

    return metrics;
  }

  @override
  int get hashCode => Object.hash(CellMetrics, cellWidth, cellHeight, baseline);

  @override
  bool operator ==(Object other) =>
      other is CellMetrics &&
      other.cellWidth == cellWidth &&
      other.cellHeight == cellHeight &&
      other.baseline == baseline;

  @override
  String toString() =>
      'CellMetrics(cellWidth: $cellWidth, '
      'cellHeight: $cellHeight, baseline: $baseline)';
}
