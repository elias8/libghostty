import 'dart:math' show min;
import 'dart:ui';

import '../atlas_entry.dart';
import 'glyph_raster.dart';
import 'paragraph_lane.dart';

/// Rasterizes font-backed text glyphs into the text atlas.
class TextLane extends ParagraphLane {
  TextLane({super.initialSize, super.maxSize, super.budget})
    : super(entryLane: .text);

  /// Returns borrowed atlas pixels or caller-owned [DirectGlyph] ink.
  /// [span] gives the glyph's cell width (2 for wide/CJK text).
  Glyph rasterizeText(
    String text, {
    required bool bold,
    required bool italic,
    int span = 1,
    bool centerInFirstCell = false,
    double sourcePadding = 0.0,
    bool admit = true,
  }) {
    final pxCellWidth = (this.pxCellWidth * span).ceil().toDouble();
    final pxHeight = pxCellHeight.ceil().toDouble();

    // The sprite is positioned at the cell origin; the overhang width
    // overlaps into the adjacent cell's space without shifting the glyph.
    final overhang = italic ? pxItalicOverhang : 0.0;
    final pxWidth = pxCellWidth + overhang;

    final paragraph = buildParagraph(
      text,
      bold: bold,
      italic: italic,
      size: pxFontSize,
      width: double.infinity,
    );

    final isSingleCodepoint =
        text.length == 1 ||
        (text.length == 2 &&
            text.codeUnitAt(0) >= 0xD800 &&
            text.codeUnitAt(0) <= 0xDBFF &&
            text.codeUnitAt(1) >= 0xDC00 &&
            text.codeUnitAt(1) <= 0xDFFF);
    final textWidth = paragraph.maxIntrinsicWidth;
    final fitsConstrainedGlyph =
        span > 1 || (isSingleCodepoint && text.runes.first >= 0x80);
    final widthConstraint = fitsConstrainedGlyph && textWidth > pxCellWidth
        ? pxCellWidth / textWidth
        : 1.0;
    final heightConstraint =
        centerInFirstCell && isSingleCodepoint && paragraph.height > pxHeight
        ? pxHeight / paragraph.height
        : 1.0;
    // Oversized fallback symbols must fit without distorting their shape.
    final widthScale = isSingleCodepoint
        ? min(widthConstraint, heightConstraint)
        : widthConstraint;
    final heightScale = isSingleCodepoint ? widthScale : 1.0;
    final alignmentWidth = centerInFirstCell ? this.pxCellWidth : pxCellWidth;
    final paintedWidth = textWidth * widthScale;
    final bearingX = span > 1 && paintedWidth > 0.0
        ? ((alignmentWidth - paintedWidth) / 2).clamp(0.0, double.infinity)
        : 0.0;
    final bearingY = pxBaseline - paragraph.alphabeticBaseline * heightScale;
    final paintOffset = Offset(
      sourcePadding + bearingX,
      sourcePadding + bearingY,
    );
    return addRaster(
      ParagraphRaster(
        paragraph,
        Size(pxWidth + sourcePadding * 2, pxHeight + sourcePadding * 2),
        bearing: Offset(-sourcePadding, -sourcePadding),
        paragraphOffset: paintOffset,
        scaleX: widthScale,
        scaleY: heightScale,
      ),
      admit: admit,
    );
  }
}
