import 'dart:ui';

import '../../sprite/sprite_face.dart';
import '../atlas_config.dart';
import '../atlas_entry.dart';
import 'atlas_lane.dart';
import 'glyph_raster.dart';

/// Rasterizes built-in geometry glyphs into the sprite atlas.
class SpriteLane extends AtlasLane {
  // Extra atlas pixels outside the sampled source rect. The sampled source
  // may itself extend beyond the cell so sprites can draw cell-overflowing
  // geometry while keeping cell coordinates stable.
  static const _sourceGutter = 1.0;

  var _pxCellWidth = 0.0;
  var _pxCellHeight = 0.0;

  SpriteLane({super.initialSize, super.maxSize, super.budget})
    : super(entryLane: .sprite);

  @override
  void configure(AtlasConfig config) {
    _pxCellWidth = config.metrics.cellWidth * config.devicePixelRatio;
    _pxCellHeight = config.metrics.cellHeight * config.devicePixelRatio;
  }

  Glyph rasterizeSprite(SpriteGlyph glyph, {int span = 1, bool admit = true}) {
    final width = (_pxCellWidth * span).ceilToDouble();
    final height = _pxCellHeight.ceilToDouble();
    final cell = Rect.fromLTWH(0, 0, width, height);
    final padding = (SpriteContext().thickness(cell) * 1.5).ceilToDouble();
    return addRaster(
      _SpriteRaster(glyph, Size(width, height), padding),
      admit: admit,
    );
  }
}

final class _SpriteRaster extends GlyphRaster {
  final SpriteGlyph glyph;
  final Rect cell;
  final _spriteContext = SpriteContext();
  static const _sourceGutter = SpriteLane._sourceGutter;

  _SpriteRaster(this.glyph, Size cellExtent, double padding)
    : cell = Rect.fromLTWH(
        padding,
        padding,
        cellExtent.width,
        cellExtent.height,
      ),
      super(
        Size(cellExtent.width + padding * 2, cellExtent.height + padding * 2),
        bearing: Offset(-padding, -padding),
        gutter: _sourceGutter,
      );

  @override
  void paintSource(Canvas canvas) {
    final source = Offset.zero & extent;
    canvas.save();
    canvas.clipRect(source.inflate(gutter), doAntiAlias: false);
    _paintGlyph(canvas, glyph, cell);
    _paintSourceGutter(canvas, glyph, cell, source);
    canvas.restore();
  }

  void _copyGutter(
    Canvas canvas,
    SpriteGlyph glyph,
    Rect cell,
    Rect clip,
    double dx,
    double dy,
  ) {
    canvas.save();
    canvas.clipRect(clip, doAntiAlias: false);
    canvas.translate(dx, dy);
    _paintGlyph(canvas, glyph, cell);
    canvas.restore();
  }

  void _paintGlyph(Canvas canvas, SpriteGlyph glyph, Rect cell) {
    _spriteContext.reset();
    glyph.paint(canvas, cell, _spriteContext);
  }

  void _paintSourceGutter(
    Canvas canvas,
    SpriteGlyph glyph,
    Rect cell,
    Rect source,
  ) {
    const g = _sourceGutter;
    final l = source.left;
    final t = source.top;
    final r = source.right;
    final b = source.bottom;
    final w = source.width;
    final h = source.height;

    // Keep sprite geometry tied to the sampled cell. Painting once into an
    // inflated cell would move fractional block and mosaic boundaries.
    _copyGutter(canvas, glyph, cell, .fromLTWH(l - g, t, g, h), -g, 0);
    _copyGutter(canvas, glyph, cell, .fromLTWH(r, t, g, h), g, 0);
    _copyGutter(canvas, glyph, cell, .fromLTWH(l, t - g, w, g), 0, -g);
    _copyGutter(canvas, glyph, cell, .fromLTWH(l, b, w, g), 0, g);
    _copyGutter(canvas, glyph, cell, .fromLTWH(l - g, t - g, g, g), -g, -g);
    _copyGutter(canvas, glyph, cell, .fromLTWH(r, t - g, g, g), g, -g);
    _copyGutter(canvas, glyph, cell, .fromLTWH(l - g, b, g, g), -g, g);
    _copyGutter(canvas, glyph, cell, .fromLTWH(r, b, g, g), g, g);
  }
}
