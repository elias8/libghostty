part of 'terminal.dart';

/// Image storage associated with a terminal's active screen, exposing the
/// images and placements stored via the
/// [Kitty graphics protocol](https://sw.kovidgoyal.net/kitty/graphics-protocol/).
///
/// Obtained via [KittyGraphics.of]. The handle is borrowed from the
/// terminal and is invalidated by any mutating terminal call
/// ([Terminal.write], [Terminal.reset], [Terminal.resize]); re-read via
/// [of] after such operations rather than retaining the previous value.
///
/// Before any images are stored, Kitty graphics must be enabled on the
/// terminal by setting a non-zero [Terminal.kittyImageStorageLimit]. PNG
/// payloads additionally require a decoder installed via
/// [LibGhostty.setPngDecoder].
///
/// ```dart
/// final kitty = KittyGraphics.of(terminal);
/// if (kitty == null) return;
/// for (final placement in kitty.placements()) {
///   if (!placement.renderInfo.viewportVisible) continue;
///   final image = kitty.image(placement.imageId);
///   if (image == null) continue;
///   if (image.format != KittyImageFormat.rgba) continue;
///   final pixels = Uint8List(image.width * image.height * 4);
///   image.copyPixelDataInto(pixels);
///   // Draw `pixels` cropped to `placement.renderInfo.source*`
///   // at grid cell (renderInfo.viewportCol, renderInfo.viewportRow).
/// }
/// ```
@immutable
final class KittyGraphics {
  final Terminal _terminal;
  final LibGhosttyHandle _handle;

  const KittyGraphics._(this._handle, this._terminal);

  /// Storage-wide generation stamp for image content and placement changes.
  ///
  /// A changed value means the placement set or image data may be stale. If
  /// the value is unchanged since a previous query, the placement set and all
  /// image data are identical, so placement iteration and image staleness
  /// checks can be skipped.
  ///
  /// Geometry can still change when this value is unchanged, for example when
  /// scrolling or resizing moves placements through the viewport. Recompute
  /// placement [KittyPlacementRenderInfo] on frames where terminal geometry or
  /// scroll state
  /// may have changed.
  ///
  /// Generation stamps are unique and monotonically increasing process-wide.
  /// Zero means the storage has never been mutated and is empty.
  int get generation =>
      bindings.kittyGraphics.kittyGraphicsGetGeneration(_requireHandle());

  /// Looks up an image by its Kitty graphics [imageId].
  ///
  /// Returns null when no image with that id is stored or when Kitty
  /// graphics are disabled in the native library build. The returned
  /// [KittyImage] handle is borrowed from the storage and is invalidated
  /// by any mutating terminal call. Reacquire both this storage handle and the
  /// image after a mutation.
  KittyImage? image(int imageId) {
    final handle = bindings.kittyGraphics.kittyGraphicsImage(
      _requireHandle(),
      imageId,
    );
    if (handle == null) return null;
    return KittyImage._(handle, _terminal);
  }

  /// Snapshots every placement currently stored, optionally filtered by
  /// z-layer.
  ///
  /// Each [KittyPlacement] captures placement metadata and resolved render
  /// geometry at the time of this call. The snapshot data is stable
  /// across subsequent terminal mutations, but the image referenced via
  /// [KittyPlacement.imageId] is not; resolve it with [image] afresh when you
  /// need pixel bytes after a mutation.
  ///
  /// Passing a [layer] other than [KittyPlacementLayer.all] installs a
  /// z-layer filter on the iterator so placements outside the requested
  /// layer are skipped. See [KittyPlacementLayer] for the bucket
  /// boundaries.
  ///
  /// Throws [OutOfMemoryException] if the iterator allocation fails.
  List<KittyPlacement> placements({KittyPlacementLayer layer = .all}) {
    final handle = _requireHandle();
    final terminalHandle = _terminal._requireHandle();
    final iterator = bindings.kittyGraphics.kittyGraphicsPlacementIteratorNew();
    try {
      bindings.kittyGraphics.kittyGraphicsGetPlacements(handle, iterator);
      if (layer != KittyPlacementLayer.all) {
        bindings.kittyGraphics.kittyGraphicsPlacementIteratorSetLayer(
          iterator,
          layer,
        );
      }
      final out = <KittyPlacement>[];
      while (bindings.kittyGraphics.kittyGraphicsPlacementNext(iterator)) {
        out.add(
          bindings.kittyGraphics.kittyGraphicsPlacementGet(
            iterator,
            handle,
            terminalHandle,
          ),
        );
      }
      return out;
    } finally {
      bindings.kittyGraphics.kittyGraphicsPlacementIteratorFree(iterator);
    }
  }

  LibGhosttyHandle _requireHandle() {
    if (_terminal._disposed) {
      throw StateError('KittyGraphics terminal is disposed');
    }
    return _handle;
  }

  /// Returns the Kitty graphics image storage for [terminal]'s active
  /// screen, or null when Kitty graphics are disabled in the native
  /// library build.
  static KittyGraphics? of(Terminal terminal) {
    final handle = bindings.kittyGraphics.kittyGraphicsGet(
      terminal._requireHandle(),
    );
    return handle == null ? null : KittyGraphics._(handle, terminal);
  }
}

/// A single image stored under the Kitty graphics protocol.
///
/// Obtained via [KittyGraphics.image]. The handle is borrowed from the
/// terminal's image storage: every accessor reads live data and is
/// invalidated by any mutating terminal call ([Terminal.write],
/// [Terminal.reset], [Terminal.resize]). Read the values you need
/// immediately. Do not access a [KittyImage] after mutating the terminal;
/// reacquire it through [KittyGraphics.image] first.
///
/// [copyPixelDataInto] is the exception. It copies the bytes into Dart-owned
/// storage that remains valid after mutations.
@immutable
final class KittyImage {
  final Terminal _owner;

  final LibGhosttyHandle _handle;

  const KittyImage._(this._handle, this._owner);

  /// Compression of the stored pixel data.
  KittyImageCompression get compression {
    return bindings.kittyGraphics.kittyGraphicsImageGetCompression(
      _requireHandle(),
    );
  }

  /// Format of the stored pixel data.
  KittyImageFormat get format {
    return bindings.kittyGraphics.kittyGraphicsImageGetFormat(_requireHandle());
  }

  /// Generation stamp for this image's pixel contents.
  ///
  /// A changed value means cached texture data for this image id is stale, even
  /// when dimensions, format, and byte length are unchanged. This catches
  /// same-sized retransmissions that size heuristics cannot detect.
  ///
  /// Generation stamps are unique and monotonically increasing process-wide and
  /// use the same sequence as [KittyGraphics.generation]. Stored images never
  /// have generation zero, so zero can be used as an empty cache sentinel.
  int get generation {
    return bindings.kittyGraphics.kittyGraphicsImageGetGeneration(
      _requireHandle(),
    );
  }

  /// Image height in pixels.
  int get height =>
      bindings.kittyGraphics.kittyGraphicsImageGetHeight(_requireHandle());

  /// Image id assigned by the Kitty graphics protocol.
  int get id =>
      bindings.kittyGraphics.kittyGraphicsImageGetId(_requireHandle());

  /// Image number assigned by the protocol, or zero when unset.
  int get number =>
      bindings.kittyGraphics.kittyGraphicsImageGetNumber(_requireHandle());

  /// Image width in pixels.
  int get width =>
      bindings.kittyGraphics.kittyGraphicsImageGetWidth(_requireHandle());

  /// Copies the raw pixel bytes into [destination] and returns the byte count.
  ///
  /// Stored images are already decoded and decompressed. PNG payloads are
  /// decoded through the callback installed via [LibGhostty.setPngDecoder]
  /// and copied as RGBA. The destination must be large enough for the complete
  /// payload; otherwise a [RangeError] is thrown. The copy completes
  /// synchronously, so the written bytes remain valid after subsequent
  /// terminal mutations.
  int copyPixelDataInto(Uint8List destination) {
    return bindings.kittyGraphics.kittyGraphicsImageGetPixelData(
      _requireHandle(),
      destination,
    );
  }

  LibGhosttyHandle _requireHandle() {
    if (_owner._disposed) throw StateError('KittyImage terminal is disposed');
    return _handle;
  }
}
