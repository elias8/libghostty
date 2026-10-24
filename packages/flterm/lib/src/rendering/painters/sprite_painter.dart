import 'dart:ui';

import 'package:flutter/painting.dart';

import '../atlas/atlas.dart';
import '../atlas/sprite_buffer.dart';

/// Paints built-in sprite glyphs via a batched [Canvas.drawRawAtlas] call.
///
/// Sprite glyphs live in their own atlas texture and are tinted per-sprite
/// with the resolved cell foreground.
class SpritePainter {
  final Paint _paint;
  final Atlas _atlas;
  final SpriteBuffer _sprites;

  SpritePainter(this._atlas, this._sprites) : _paint = Paint();

  void paint(Canvas canvas) {
    _sprites.sprite.paint(
      canvas,
      _atlas.spriteImage,
      1 / _atlas.devicePixelRatio,
      _paint,
    );
  }
}
