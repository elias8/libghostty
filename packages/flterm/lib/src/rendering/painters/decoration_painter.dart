import 'dart:ui';

import 'package:flutter/painting.dart';

import '../atlas/sprite_buffer.dart';
import 'terminal_painter.dart';

/// Paints strikethrough and overline rects via batched [Canvas.drawVertices].
///
/// Drawn AFTER text so strikethrough is visibly crossing through glyphs.
/// Underlines are handled separately by [UnderlinePainter].
class DecorationPainter implements TerminalPainter {
  final Paint _paint;
  final SpriteBuffer _sprites;

  DecorationPainter(this._sprites) : _paint = Paint();

  @override
  void paint(Canvas canvas) {
    for (final vertices in _sprites.decorationVertices) {
      canvas.drawVertices(vertices, BlendMode.srcOver, _paint);
    }
  }
}
