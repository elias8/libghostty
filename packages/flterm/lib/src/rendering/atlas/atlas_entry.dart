import 'dart:ui';

enum AtlasEntryLane { text, emoji, sprite, decoration }

/// Resolved ink: atlas entries are borrowed; direct glyphs transfer ownership.
sealed class Glyph {
  const Glyph();
  AtlasEntryLane get lane;
  double get bearingX;
  double get bearingY;
}

/// Row- or cursor-owned ink for a glyph that was not admitted to an atlas.
final class DirectGlyph extends Glyph {
  final Picture _picture;
  final Rect _source;
  @override
  final AtlasEntryLane lane;
  @override
  final double bearingX;
  @override
  final double bearingY;
  final _tintPaint = Paint();
  var _tintArgb = 0xFFFFFFFF;

  DirectGlyph(
    this._picture,
    Size extent,
    this.lane,
    this.bearingX,
    this.bearingY,
  ) : _source = Offset.zero & extent;

  void configureTint(int? argb) {
    _tintArgb = argb ?? 0xFFFFFFFF;
    _tintPaint.colorFilter = argb == null || argb == 0xFFFFFFFF
        ? null
        : ColorFilter.mode(Color(argb), BlendMode.modulate);
  }

  int get tintArgb => _tintArgb;

  Rect boundsAt(double x, double y, double inverseDpr) => Rect.fromLTWH(
    x + bearingX * inverseDpr,
    y + bearingY * inverseDpr,
    _source.width * inverseDpr,
    _source.height * inverseDpr,
  );

  void paint(
    Canvas canvas,
    double x,
    double y,
    double inverseDpr, {
    Paint? tint,
  }) {
    canvas.save();
    canvas.translate(x + bearingX * inverseDpr, y + bearingY * inverseDpr);
    canvas.scale(inverseDpr);
    canvas.clipRect(_source, doAntiAlias: false);
    final paint = tint ?? _tintPaint;
    if (paint.colorFilter == null) {
      canvas.drawPicture(_picture);
    } else {
      final bounds = _source.intersect(canvas.getLocalClipBounds());
      if (bounds.isEmpty) {
        canvas.restore();
        return;
      }
      // Tint the completed glyph mask once: overlapping sprite primitives
      // must not compound a translucent foreground's opacity.
      canvas.saveLayer(bounds, paint);
      canvas.drawPicture(_picture);
      canvas.restore();
    }
    canvas.restore();
  }

  void dispose() => _picture.dispose();
}

/// Position and metadata of a rendered glyph in an atlas texture.
///
/// Coordinates are in physical pixels (logical pixels * device pixel ratio).
/// The source rectangle ([srcLeft], [srcTop], [srcRight], [srcBottom]) maps
/// directly to the [Canvas.drawRawAtlas] source rect parameter.
final class AtlasEntry extends Glyph {
  /// Left edge of the glyph region in the atlas, in physical pixels.
  final double srcLeft;

  /// Top edge of the glyph region in the atlas, in physical pixels.
  final double srcTop;

  /// Right edge of the glyph region in the atlas, in physical pixels.
  final double srcRight;

  /// Bottom edge of the glyph region in the atlas, in physical pixels.
  final double srcBottom;

  /// Vertical offset associated with the glyph's source pixels.
  ///
  /// Text and sprite glyphs use this as a draw offset when their source rect
  /// includes pixels outside the cell.
  @override
  final double bearingY;

  /// Horizontal offset associated with the glyph's source pixels.
  ///
  /// Text and sprite glyphs use this as a draw offset when their source rect
  /// includes pixels outside the cell.
  @override
  final double bearingX;

  /// Atlas lane that owns this entry's source pixels.
  @override
  final AtlasEntryLane lane;

  const AtlasEntry({
    required this.srcLeft,
    required this.srcTop,
    required this.srcRight,
    required this.srcBottom,
    required this.bearingY,
    this.bearingX = 0.0,
    required this.lane,
  });
}
