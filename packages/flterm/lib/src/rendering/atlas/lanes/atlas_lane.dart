import 'dart:ui';

import '../atlas_budget.dart';
import '../atlas_config.dart';
import '../atlas_entry.dart';
import '../atlas_texture.dart';
import 'glyph_raster.dart';

abstract class AtlasLane {
  final AtlasTexture _texture;
  final AtlasEntryLane entryLane;
  final List<(GlyphRaster, AtlasEntry)> _pending = [];

  AtlasLane({
    required this.entryLane,
    int initialSize = AtlasTexture.defaultInitialSize,
    int maxSize = AtlasTexture.defaultMaxSize,
    AtlasBudget? budget,
  }) : _texture = AtlasTexture(
         initialSize: initialSize,
         maxSize: maxSize,
         budget: budget,
       );

  bool get hasPending => _pending.isNotEmpty;

  Image? get image => _texture.image;

  Glyph addRaster(GlyphRaster raster, {bool admit = true}) {
    final gutter = raster.gutter;
    final slot = admit
        ? _texture.allocate(
            width: raster.extent.width + gutter * 2,
            height: raster.extent.height + gutter * 2,
            bearingX: raster.bearing.dx,
            bearingY: raster.bearing.dy,
            lane: entryLane,
          )
        : null;
    if (slot == null) return raster.record(entryLane);
    final entry = gutter == 0
        ? slot
        : AtlasEntry(
            srcLeft: slot.srcLeft + gutter,
            srcTop: slot.srcTop + gutter,
            srcRight: slot.srcRight - gutter,
            srcBottom: slot.srcBottom - gutter,
            bearingX: slot.bearingX,
            bearingY: slot.bearingY,
            lane: entryLane,
          );
    _pending.add((raster, entry));
    return entry;
  }

  void clear() {
    clearPending();
    _texture.clear();
  }

  void clearPending() {
    for (final (raster, _) in _pending) {
      raster.dispose();
    }
    _pending.clear();
  }

  void configure(AtlasConfig config);

  void dispose() {
    clearPending();
    _texture.dispose();
  }

  void ensureImage() {
    if (_pending.isEmpty) return;
    _texture.replaceImage((canvas) {
      for (final (raster, entry) in _pending) {
        canvas.save();
        canvas.translate(entry.srcLeft, entry.srcTop);
        canvas.clipRect(
          (Offset.zero & raster.extent).inflate(raster.gutter),
          doAntiAlias: false,
        );
        raster.paintSource(canvas);
        canvas.restore();
      }
    });
    clearPending();
  }
}
