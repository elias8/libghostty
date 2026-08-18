import 'dart:ui';

import 'package:libghostty/libghostty.dart';
import 'package:meta/meta.dart';

import 'kitty_image_cache.dart';
import 'paint_state.dart';

/// Caches paint-safe snapshots of Kitty graphics placements.
///
/// Libghostty generations invalidate protocol content, while terminal geometry
/// invalidates resolved placement rectangles. Unchanged inputs avoid placement
/// iteration, image lookup, sorting, and image eviction.
final class KittyPlacementCache {
  final PaintState _state;
  final KittyImageCache _images;
  final Set<int> _liveImageIds = {};
  final List<KittyPlacementSnapshot> _snapshots = [];
  _SnapshotKey? _key;

  KittyPlacementCache({required this._state, required this._images});

  /// Placement snapshots ordered by signed z-index, then image ID.
  Iterable<KittyPlacementSnapshot> get snapshots => _snapshots;

  /// Refreshes snapshots from [terminal] when protocol or geometry inputs have
  /// changed.
  ///
  /// [geometryDirty] must be true after terminal mutations that can change
  /// placement render information without changing Kitty storage generation.
  ///
  /// Returns whether callers must rebuild their paint-order buckets.
  bool sync(Terminal terminal, {required bool geometryDirty}) {
    final graphics = KittyGraphics.of(terminal);
    if (graphics == null) {
      final changed = _key != null || _snapshots.isNotEmpty;
      _clear();
      _images.evict(_liveImageIds);
      _key = null;
      return changed;
    }

    final key = _SnapshotKey(
      generation: graphics.generation,
      cellWidth: _state.metrics.cellWidth,
      cellHeight: _state.metrics.cellHeight,
      devicePixelRatio: _state.devicePixelRatio,
      viewportOffset: _state.viewportOffset,
      rows: _state.rows,
      cols: _state.cols,
    );
    if (!geometryDirty && _key == key) return false;

    final nextSnapshots = <KittyPlacementSnapshot>[];
    final nextLiveImageIds = <int>{};
    var replacementPending = false;
    var hasVirtualPlacements = false;
    for (final placement in graphics.placements()) {
      nextLiveImageIds.add(placement.imageId);
      if (placement.isVirtual) {
        hasVirtualPlacements = true;
        continue;
      }

      final info = placement.renderInfo;
      if (!info.viewportVisible) continue;
      if (info.pixelWidth == 0 || info.pixelHeight == 0) continue;

      final image = graphics.image(placement.imageId);
      if (image == null) continue;

      final imageGeneration = image.generation;
      final entry = _images.lookup(image, generation: imageGeneration);
      replacementPending |=
          entry is KittyImagePending ||
          (entry is KittyImageReady && entry.generation != imageGeneration);
      nextSnapshots.add(
        KittyPlacementSnapshot(
          imageId: placement.imageId,
          imageGeneration: imageGeneration,
          dst: Rect.fromLTWH(
            info.viewportCol * key.cellWidth +
                placement.xOffset / key.devicePixelRatio,
            info.viewportRow * key.cellHeight +
                placement.yOffset / key.devicePixelRatio,
            info.pixelWidth / key.devicePixelRatio,
            info.pixelHeight / key.devicePixelRatio,
          ),
          src: Rect.fromLTWH(
            info.sourceX.toDouble(),
            info.sourceY.toDouble(),
            info.sourceWidth.toDouble(),
            info.sourceHeight.toDouble(),
          ),
          z: placement.z,
          paintOrder: nextSnapshots.length,
        ),
      );
    }

    final unicodePlacements = hasVirtualPlacements
        ? graphics.unicodePlacements()
        : const <KittyUnicodePlacement>[];
    for (final placement in unicodePlacements) {
      nextLiveImageIds.add(placement.imageId);

      final info = placement.renderInfo;
      if (info == null || info.pixelWidth == 0 || info.pixelHeight == 0) {
        continue;
      }

      final image = graphics.image(placement.imageId);
      if (image == null) continue;

      final imageGeneration = image.generation;
      final entry = _images.lookup(image, generation: imageGeneration);
      replacementPending |=
          entry is KittyImagePending ||
          (entry is KittyImageReady && entry.generation != imageGeneration);
      nextSnapshots.add(
        KittyPlacementSnapshot(
          imageId: placement.imageId,
          imageGeneration: imageGeneration,
          dst: Rect.fromLTWH(
            info.viewportCol * key.cellWidth +
                info.cellOffsetX / key.devicePixelRatio,
            info.viewportRow * key.cellHeight +
                info.cellOffsetY / key.devicePixelRatio,
            info.pixelWidth / key.devicePixelRatio,
            info.pixelHeight / key.devicePixelRatio,
          ),
          src: Rect.fromLTWH(
            info.sourceX.toDouble(),
            info.sourceY.toDouble(),
            info.sourceWidth.toDouble(),
            info.sourceHeight.toDouble(),
          ),
          z: info.z,
          paintOrder: nextSnapshots.length,
        ),
      );
    }

    if (nextSnapshots.length > 1) nextSnapshots.sort(_compareZ);
    // Animated clients often replace every image before its decode completes.
    // Keep the last complete frame only while its placement geometry remains
    // compatible; changed geometry must wait for matching pixels instead.
    if (replacementPending && _hasCompatibleGeometry(nextSnapshots)) {
      _images.evict({..._liveImageIds, ...nextLiveImageIds});
      return false;
    }

    _snapshots
      ..clear()
      ..addAll(nextSnapshots);
    _liveImageIds
      ..clear()
      ..addAll(nextLiveImageIds);
    _images.evict(_liveImageIds);
    _key = key;
    return true;
  }

  void _clear() {
    _snapshots.clear();
    _liveImageIds.clear();
  }

  bool _hasCompatibleGeometry(List<KittyPlacementSnapshot> next) {
    if (_snapshots.isEmpty || _snapshots.length != next.length) return false;
    final remaining = <({Rect dst, Rect src, int z}), int>{};
    for (final replacement in next) {
      final geometry = (
        dst: replacement.dst,
        src: replacement.src,
        z: replacement.z,
      );
      remaining.update(geometry, (count) => count + 1, ifAbsent: () => 1);
    }
    for (final previous in _snapshots) {
      final geometry = (dst: previous.dst, src: previous.src, z: previous.z);
      final count = remaining[geometry];
      if (count == null) return false;
      if (count == 1) {
        remaining.remove(geometry);
      } else {
        remaining[geometry] = count - 1;
      }
    }
    return true;
  }

  static int _compareZ(KittyPlacementSnapshot a, KittyPlacementSnapshot b) {
    final z = a.z.compareTo(b.z);
    if (z != 0) return z;
    final imageId = a.imageId.compareTo(b.imageId);
    return imageId != 0 ? imageId : a._paintOrder.compareTo(b._paintOrder);
  }
}

/// Placement data copied from libghostty for use during paint.
///
/// The snapshot remains valid when subsequent terminal mutations invalidate
/// libghostty's borrowed placement handles.
final class KittyPlacementSnapshot {
  final int imageId;

  /// Image generation this geometry was resolved against.
  ///
  /// The painter only draws a decoded image with the same generation, keeping
  /// replacement geometry from being paired with stale pixels.
  final int imageGeneration;

  /// Destination rectangle in the same logical-pixel space as cells.
  final Rect dst;

  /// Source rectangle in the image's own pixel space.
  final Rect src;

  /// Signed z-index from the Kitty graphics protocol.
  final int z;

  final int _paintOrder;

  const KittyPlacementSnapshot({
    required this.imageId,
    this.imageGeneration = 0,
    required this.dst,
    required this.src,
    required this.z,
    this._paintOrder = 0,
  });
}

@immutable
final class _SnapshotKey {
  final int generation;
  final double cellWidth;
  final double cellHeight;
  final double devicePixelRatio;
  final int viewportOffset;
  final int rows;
  final int cols;

  const _SnapshotKey({
    required this.generation,
    required this.cellWidth,
    required this.cellHeight,
    required this.devicePixelRatio,
    required this.viewportOffset,
    required this.rows,
    required this.cols,
  });

  @override
  int get hashCode => Object.hash(
    generation,
    cellWidth,
    cellHeight,
    devicePixelRatio,
    viewportOffset,
    rows,
    cols,
  );

  @override
  bool operator ==(Object other) {
    return other is _SnapshotKey &&
        generation == other.generation &&
        cellWidth == other.cellWidth &&
        cellHeight == other.cellHeight &&
        devicePixelRatio == other.devicePixelRatio &&
        viewportOffset == other.viewportOffset &&
        rows == other.rows &&
        cols == other.cols;
  }
}
