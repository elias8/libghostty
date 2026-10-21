import 'dart:ui';

import 'package:flutter/painting.dart';

import '../atlas/atlas.dart';
import '../atlas/sprite_buffer.dart';

/// Paints regular-width and wide text glyphs via batched [Canvas.drawRawAtlas]
/// calls.
///
/// Text glyphs are pre-rendered into an [Atlas] during the update phase.
/// The atlas stores white glyph bitmaps tinted per-sprite via
/// [BlendMode.modulate] to produce colored text with zero per-glyph draw
/// calls.
class TerminalTextPainter {
  final Paint _paint;
  final Atlas _atlas;
  final AtlasSprites _wide;
  final AtlasSprites _regular;

  TerminalTextPainter(this._atlas, this._wide, this._regular)
    : _paint = Paint();

  void paint(Canvas canvas) {
    final inverseDpr = 1 / _atlas.devicePixelRatio;
    _regular.paint(canvas, _atlas.textImage, inverseDpr, _paint);
    _wide.paint(canvas, _atlas.textImage, inverseDpr, _paint);
  }
}
