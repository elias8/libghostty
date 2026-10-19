import 'dart:ui';

import 'package:flutter/painting.dart';

import '../atlas/atlas.dart';
import '../atlas/sprite_buffer.dart';

/// Paints underline decoration sprites via [Canvas.drawRawAtlas].
///
/// Underlines are rasterized as white glyphs in the atlas (one per style)
/// and tinted per-sprite with the underline color via [BlendMode.modulate].
/// Drawn BEFORE text so that descender glyphs cover the underline at
/// intersections.
class UnderlinePainter {
  final Paint _paint;
  final Atlas _atlas;
  final SpriteBuffer _sprites;

  UnderlinePainter(this._atlas, this._sprites) : _paint = Paint();

  void paint(Canvas canvas) {
    _sprites.underline.paint(
      canvas,
      _atlas.decorationImage,
      1 / _atlas.devicePixelRatio,
      _paint,
    );
  }
}
