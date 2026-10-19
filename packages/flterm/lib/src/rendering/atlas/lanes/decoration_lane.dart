import 'dart:math';
import 'dart:ui';

import 'package:libghostty/libghostty.dart' show UnderlineStyle;

import '../atlas_config.dart';
import '../atlas_entry.dart';
import 'atlas_lane.dart';
import 'glyph_raster.dart';

/// Rasterizes underline decoration geometry into the decoration atlas.
class DecorationLane extends AtlasLane {
  var _pxCellWidth = 0.0;
  var _pxCellHeight = 0.0;
  var _pxUnderlinePosition = 0.0;
  var _pxUnderlineThickness = 1.0;

  // Bottom padding for decoration sprites (cell height / 4). Allows
  // curly and double underlines to extend below the cell boundary.
  var _pxDecorationPadding = 0.0;

  DecorationLane({super.initialSize, super.maxSize, super.budget})
    : super(entryLane: .decoration);

  @override
  void configure(AtlasConfig config) {
    _pxCellWidth = config.metrics.cellWidth * config.devicePixelRatio;
    _pxCellHeight = config.metrics.cellHeight * config.devicePixelRatio;
    _pxUnderlinePosition =
        config.metrics.underlinePosition * config.devicePixelRatio;
    _pxUnderlineThickness = max(
      1.0,
      (config.metrics.underlineThickness * config.devicePixelRatio)
          .ceilToDouble(),
    );
    _pxDecorationPadding = (_pxCellHeight / 4).ceilToDouble();
  }

  Glyph rasterizeDecoration(UnderlineStyle style, {bool admit = true}) {
    return addRaster(
      _DecorationRaster(
        style,
        Size(
          _pxCellWidth.ceilToDouble(),
          (_pxCellHeight + _pxDecorationPadding).ceilToDouble(),
        ),
        _pxCellHeight,
        _pxUnderlinePosition,
        _pxUnderlineThickness,
        _pxDecorationPadding,
      ),
      admit: admit,
    );
  }
}

final class _DecorationRaster extends GlyphRaster {
  final UnderlineStyle style;
  final double cellHeight;
  final double underlinePosition;
  final double thickness;
  final double padding;

  _DecorationRaster(
    this.style,
    super.extent,
    this.cellHeight,
    this.underlinePosition,
    this.thickness,
    this.padding,
  );

  @override
  void paintSource(Canvas canvas) {
    final width = extent.width;
    const ox = 0.0;
    const oy = 0.0;
    switch (style) {
      case UnderlineStyle.none:
        break;

      case UnderlineStyle.single:
        // Clamp underline to stay within the sprite (cell + padding).
        final underlineY = min(
          underlinePosition,
          cellHeight + padding - thickness,
        );
        canvas.drawRect(
          Rect.fromLTWH(ox, oy + underlineY, width, thickness),
          Paint()..color = const Color(0xFFFFFFFF),
        );

      case UnderlineStyle.double:
        // Place both lines symmetrically around the underline position,
        // clamped so the lower line stays within the padded sprite.
        final underlineY = min(
          underlinePosition,
          cellHeight + padding - 2 * thickness,
        );
        final upperLineY = max(0.0, underlineY - thickness);
        final lowerLineY = underlineY + thickness;
        final paint = Paint()..color = const Color(0xFFFFFFFF);
        canvas.drawRect(
          Rect.fromLTWH(ox, oy + upperLineY, width, thickness),
          paint,
        );
        canvas.drawRect(
          Rect.fromLTWH(ox, oy + lowerLineY, width, thickness),
          paint,
        );

      case UnderlineStyle.dotted:
        // Dot radius derived from line thickness (sqrt(1/2) gives area-
        // equivalent circle). Dot count is bounded: at least 1 dot,
        // at most enough to fit with 2-radius spacing, and at least
        // 1-radius gaps between dots so they don't merge.
        final radius = sqrt1_2 * thickness;
        final centerY = min(
          underlinePosition + 0.5 * thickness,
          cellHeight + padding - radius.ceilToDouble(),
        );
        final dotCount = max(
          1.0,
          min(
            (width / (4 * radius)).ceilToDouble(),
            min(
              (width / (3 * radius)).floorToDouble(),
              (width / (2 * radius + 1)).floorToDouble(),
            ),
          ),
        );
        final spacing = width / dotCount;
        final paint = Paint()..color = const Color(0xFFFFFFFF);
        for (var i = 0; i < dotCount.toInt(); i++) {
          canvas.drawCircle(
            Offset(ox + spacing / 2 + spacing * i, oy + centerY),
            radius,
            paint,
          );
        }

      case UnderlineStyle.dashed:
        final underlineY = min(
          underlinePosition,
          cellHeight + padding - thickness,
        );
        final intWidth = width.toInt();
        final dashWidth = intWidth ~/ 3 + 1;
        final dashCount = intWidth ~/ dashWidth + 1;
        final paint = Paint()..color = const Color(0xFFFFFFFF);
        for (var i = 0; i < dashCount; i += 2) {
          canvas.drawRect(
            Rect.fromLTWH(
              ox + (i * dashWidth).toDouble(),
              oy + underlineY,
              dashWidth.toDouble(),
              thickness,
            ),
            paint,
          );
        }

      case UnderlineStyle.curly:
        // S-shaped cubic Bezier: starts at bottom-left, curves up to center,
        // then back down to bottom-right. controlRatio (0.4) flattens the
        // curve slightly for a smooth wave that tiles seamlessly across
        // adjacent cells (butt stroke caps prevent overlap at seams).
        final amplitude = width / pi;
        final top = min(
          underlinePosition,
          cellHeight + padding - amplitude - thickness,
        );
        final bottom = top + amplitude;
        final center = width / 2;
        const controlRatio = 0.4;

        final path = Path()
          ..moveTo(ox, oy + bottom)
          ..cubicTo(
            ox + center * controlRatio,
            oy + bottom,
            ox + center - center * controlRatio,
            oy + top,
            ox + center,
            oy + top,
          )
          ..cubicTo(
            ox + center + center * controlRatio,
            oy + top,
            ox + width - center * controlRatio,
            oy + bottom,
            ox + width,
            oy + bottom,
          );
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFFFFFFFF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = thickness
            ..strokeCap = StrokeCap.butt
            ..strokeJoin = StrokeJoin.round,
        );
    }
  }
}
