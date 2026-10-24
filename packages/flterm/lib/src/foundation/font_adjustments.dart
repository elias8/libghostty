import 'package:flutter/foundation.dart';

/// Font metric adjustments, mirroring Ghostty's `adjust-*` config keys.
///
/// Percentage keys are expressed as fractions (Ghostty's `10%` → `0.10`).
/// Pixel keys are logical-pixel deltas (Ghostty's
/// `adjust-underline-thickness = -1` → `-1.0`).
///
/// ```dart
/// // adjust-cell-height = 10%, adjust-underline-position = 3%,
/// // adjust-underline-thickness = -1, adjust-cursor-thickness = 1
/// const FontAdjustments(
///   cellHeight: 0.10,
///   underlinePosition: 0.03,
///   underlineThickness: -1,
///   cursorThickness: 1,
/// )
/// ```
@immutable
final class FontAdjustments {
  /// `adjust-cell-width`: fraction added to cell width (0.0 = unchanged).
  final double cellWidth;

  /// `adjust-cell-height`: fraction added to cell height — i.e. line spacing.
  /// Glyphs stay vertically centered, so the extra height becomes leading
  /// above and below.
  final double cellHeight;

  /// `adjust-underline-position`: fraction of cell height to push the
  /// underline down (positive) or up (negative).
  final double underlinePosition;

  /// `adjust-underline-thickness`: logical-pixel delta on underline thickness.
  final double underlineThickness;

  /// `adjust-cursor-thickness`: logical-pixel delta on bar / underline cursor
  /// thickness.
  final double cursorThickness;

  const FontAdjustments({
    this.cellWidth = 0.0,
    this.cellHeight = 0.0,
    this.underlinePosition = 0.0,
    this.underlineThickness = 0.0,
    this.cursorThickness = 0.0,
  });

  @override
  int get hashCode => Object.hash(
    cellWidth,
    cellHeight,
    underlinePosition,
    underlineThickness,
    cursorThickness,
  );

  @override
  bool operator ==(Object other) =>
      other is FontAdjustments &&
      other.cellWidth == cellWidth &&
      other.cellHeight == cellHeight &&
      other.underlinePosition == underlinePosition &&
      other.underlineThickness == underlineThickness &&
      other.cursorThickness == cursorThickness;

  @override
  String toString() =>
      'FontAdjustments(cellWidth: $cellWidth, cellHeight: $cellHeight, '
      'underlinePosition: $underlinePosition, '
      'underlineThickness: $underlineThickness, '
      'cursorThickness: $cursorThickness)';
}
