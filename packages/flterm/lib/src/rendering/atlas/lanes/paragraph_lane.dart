import 'dart:math';
import 'dart:ui';

import '../atlas_config.dart';
import 'atlas_lane.dart';

/// Shared paragraph setup for font-backed atlas lanes.
abstract class ParagraphLane extends AtlasLane {
  var _fontFamily = '';
  var _fontWeight = FontWeight.normal;
  var _fontFamilyFallback = const <String>[];
  var _pxCellWidth = 0.0;
  var _pxCellHeight = 0.0;
  var _pxFontSize = 0.0;
  var _pxBaseline = 0.0;
  var _pxItalicOverhang = 0.0;

  ParagraphLane({
    required super.entryLane,
    super.initialSize,
    super.maxSize,
    super.budget,
  });

  double get pxBaseline => _pxBaseline;

  double get pxCellHeight => _pxCellHeight;

  double get pxCellWidth => _pxCellWidth;

  double get pxFontSize => _pxFontSize;

  double get pxItalicOverhang => _pxItalicOverhang;

  Paragraph buildParagraph(
    String text, {
    required bool bold,
    required bool italic,
    required double size,
    required double width,
    double? height,
    String? fontFamily,
    List<String>? fontFamilyFallback,
  }) {
    final resolvedFontFamily = fontFamily ?? _fontFamily;
    final resolvedFontFamilyFallback =
        fontFamilyFallback ?? _fontFamilyFallback;

    // All glyphs use textAlign: .start. Centering is handled by the
    // individual lanes so CJK text and emoji do not double-center.
    return (ParagraphBuilder(
            ParagraphStyle(
              fontSize: size,
              fontFamily: resolvedFontFamily,
              height: height,
              textAlign: .start,
            ),
          )
          ..pushStyle(
            TextStyle(
              color: const Color(0xFFFFFFFF),
              fontSize: size,
              fontFamily: resolvedFontFamily,
              height: height,
              decoration: TextDecoration.none,
              fontWeight: bold ? .bold : _fontWeight,
              fontStyle: italic ? .italic : .normal,
              fontFamilyFallback: resolvedFontFamilyFallback,
            ),
          )
          ..addText(text)
          ..pop())
        .build()
      ..layout(ParagraphConstraints(width: width));
  }

  @override
  void configure(AtlasConfig config) {
    _fontFamily = config.fontFamily;
    _fontWeight = config.fontWeight;
    _fontFamilyFallback = config.fontFamilyFallback;
    _pxCellWidth = config.metrics.cellWidth * config.devicePixelRatio;
    _pxCellHeight = config.metrics.cellHeight * config.devicePixelRatio;
    _pxBaseline = config.metrics.baseline * config.devicePixelRatio;
    _pxFontSize = config.fontSize * config.devicePixelRatio;
    _pxItalicOverhang = max(1.0, (_pxFontSize * 0.15).ceilToDouble());
  }
}
