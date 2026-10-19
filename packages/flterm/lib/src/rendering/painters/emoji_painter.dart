import 'dart:ui';

import 'package:flutter/painting.dart';

import '../atlas/atlas.dart';
import '../atlas/sprite_buffer.dart';

/// Paints emoji glyphs via a batched [Canvas.drawRawAtlas] call.
///
/// Emoji use [BlendMode.src] instead of modulate because emoji glyphs are
/// full-color bitmaps in the atlas that should render with their original
/// colors, not tinted by a per-sprite color.
class EmojiPainter {
  final Paint _paint;
  final Atlas _atlas;
  final SpriteBuffer _sprites;

  EmojiPainter(this._atlas, this._sprites) : _paint = Paint();

  void paint(Canvas canvas) {
    _sprites.emoji.paint(
      canvas,
      _atlas.emojiImage,
      1 / _atlas.devicePixelRatio,
      _paint,
      tinted: false,
    );
  }
}
