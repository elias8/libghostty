import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../../generated/libghostty.g.dart';
import '../../generated/libghostty_enums.g.dart';
import '../../types/types.dart';
import '../result_helpers.dart';
import '../types.dart';
import 'kitty_graphics.dart';

final class FfiKittyGraphicsBindings implements KittyGraphicsBindings {
  final _keys = calloc<UnsignedInt>(12);
  final _values = calloc<Pointer<Void>>(12);
  final _multi = calloc<Uint64>(12);
  final _multiGridRef = calloc<GridRef>();
  final _written = calloc<Size>();

  FfiKittyGraphicsBindings();

  @override
  LibGhosttyHandle kittyGraphicsGet(LibGhosttyHandle terminal) {
    return using((arena) {
      final out = arena<Pointer<KittyGraphicsImpl>>();
      final result = ghostty_terminal_get(
        Pointer.fromAddress(terminal.value),
        .kittyGraphics,
        out.cast(),
      );
      if (result != .success) return const .fromAddress(0);
      return .fromAddress(out.value.address);
    });
  }

  @override
  int kittyGraphicsGetGeneration(LibGhosttyHandle graphics) {
    if (graphics.value == 0) checkResultCode(Result.invalidValue.value);
    return using((arena) {
      final out = arena<Uint64>();
      final code = ghostty_kitty_graphics_get(
        Pointer.fromAddress(graphics.value),
        .generation,
        out.cast(),
      );
      checkResultCode(code.value, operation: 'ghostty_kitty_graphics_get');
      return out.value;
    });
  }

  @override
  void kittyGraphicsGetPlacements(
    LibGhosttyHandle graphics,
    LibGhosttyHandle iterator,
  ) {
    if (graphics.value == 0 || iterator.value == 0) {
      checkResultCode(Result.invalidValue.value);
    }
    return using((arena) {
      final out = arena<KittyGraphicsPlacementIterator>()
        ..value = Pointer.fromAddress(iterator.value);
      final result = ghostty_kitty_graphics_get(
        Pointer.fromAddress(graphics.value),
        .placementIterator,
        out.cast(),
      );
      checkResultCode(result.value, operation: 'ghostty_kitty_graphics_get');
    });
  }

  @override
  LibGhosttyHandle kittyGraphicsImage(LibGhosttyHandle graphics, int imageId) {
    if (graphics.value == 0) return const .fromAddress(0);
    final image = ghostty_kitty_graphics_image(
      Pointer.fromAddress(graphics.value),
      imageId,
    );
    return .fromAddress(image.address);
  }

  @override
  KittyImageCompression kittyGraphicsImageGetCompression(
    LibGhosttyHandle image,
  ) {
    return .fromValue(_imageGetU32(image, .compression));
  }

  @override
  KittyImageFormat kittyGraphicsImageGetFormat(LibGhosttyHandle image) {
    return .fromValue(_imageGetU32(image, .format));
  }

  @override
  int kittyGraphicsImageGetGeneration(LibGhosttyHandle image) =>
      _imageGetU64(image, .generation);

  @override
  int kittyGraphicsImageGetHeight(LibGhosttyHandle image) =>
      _imageGetU32(image, .height);

  @override
  int kittyGraphicsImageGetId(LibGhosttyHandle image) =>
      _imageGetU32(image, .id);

  @override
  int kittyGraphicsImageGetNumber(LibGhosttyHandle image) =>
      _imageGetU32(image, .number);

  @override
  int kittyGraphicsImageGetPixelData(
    LibGhosttyHandle image,
    Uint8List destination,
  ) {
    final source = _imagePixelDataView(image);
    if (destination.length < source.length) {
      throw RangeError.range(
        destination.length,
        source.length,
        null,
        'destination.length',
      );
    }
    destination.setRange(0, source.length, source);
    return source.length;
  }

  @override
  int kittyGraphicsImageGetWidth(LibGhosttyHandle image) =>
      _imageGetU32(image, .width);

  @override
  KittyPlacement kittyGraphicsPlacementGet(
    LibGhosttyHandle iterator,
    LibGhosttyHandle graphics,
    LibGhosttyHandle terminal,
  ) {
    if (iterator.value == 0 || graphics.value == 0 || terminal.value == 0) {
      checkResultCode(Result.invalidValue.value);
    }
    _setPlacementMulti([
      .imageId,
      .placementId,
      .isVirtual,
      .xOffset,
      .yOffset,
      .sourceX,
      .sourceY,
      .sourceWidth,
      .sourceHeight,
      .columns,
      .rows,
      .z,
    ]);
    final result = ghostty_kitty_graphics_placement_get_multi(
      Pointer.fromAddress(iterator.value),
      12,
      _keys,
      _values,
      _written,
    );
    checkResultCode(
      result.value,
      operation: 'ghostty_kitty_graphics_placement_get_multi',
    );
    int u32(int index) => (_multi + index).cast<Uint32>().value;
    final imageId = u32(0);
    final image = ghostty_kitty_graphics_image(
      Pointer.fromAddress(graphics.value),
      imageId,
    );
    final renderInfo = image == nullptr
        ? const KittyPlacementRenderInfo.offscreen()
        : kittyGraphicsPlacementRenderInfo(
                iterator,
                .fromAddress(image.address),
                terminal,
              ) ??
              const KittyPlacementRenderInfo.offscreen();
    return KittyPlacement(
      imageId: imageId,
      placementId: u32(1),
      isVirtual: (_multi + 2).cast<Bool>().value,
      xOffset: u32(3),
      yOffset: u32(4),
      sourceX: u32(5),
      sourceY: u32(6),
      sourceWidth: u32(7),
      sourceHeight: u32(8),
      columns: u32(9),
      rows: u32(10),
      z: (_multi + 11).cast<Int32>().value,
      renderInfo: renderInfo,
    );
  }

  @override
  void kittyGraphicsPlacementIteratorFree(LibGhosttyHandle iterator) {
    if (iterator.value == 0) return;
    ghostty_kitty_graphics_placement_iterator_free(
      Pointer.fromAddress(iterator.value),
    );
  }

  @override
  LibGhosttyHandle kittyGraphicsPlacementIteratorNew() {
    return using((arena) {
      final out = arena<Pointer<KittyGraphicsPlacementIteratorImpl>>();
      final code = ghostty_kitty_graphics_placement_iterator_new(nullptr, out);
      checkRequiredCode(
        code.value,
        operation: 'ghostty_kitty_graphics_placement_iterator_new',
      );
      return .fromAddress(out.value.address);
    });
  }

  @override
  void kittyGraphicsPlacementIteratorSetLayer(
    LibGhosttyHandle iterator,
    KittyPlacementLayer layer,
  ) {
    if (iterator.value == 0) checkResultCode(Result.invalidValue.value);
    return using((arena) {
      final value = arena<UnsignedInt>()..value = layer.value;
      final result = ghostty_kitty_graphics_placement_iterator_set(
        Pointer.fromAddress(iterator.value),
        .layer,
        value.cast(),
      );
      checkResultCode(
        result.value,
        operation: 'ghostty_kitty_graphics_placement_iterator_set',
      );
    });
  }

  @override
  bool kittyGraphicsPlacementNext(LibGhosttyHandle iterator) {
    if (iterator.value == 0) return false;
    return ghostty_kitty_graphics_placement_next(
      Pointer.fromAddress(iterator.value),
    );
  }

  @override
  void terminalGetKittyGraphicsUnicodePlacementIterator(
    LibGhosttyHandle terminal,
    LibGhosttyHandle iterator,
  ) {
    if (terminal.value == 0 || iterator.value == 0) {
      checkResultCode(Result.invalidValue.value);
    }
    return using((arena) {
      final out = arena<KittyGraphicsUnicodePlacementIterator>()
        ..value = Pointer.fromAddress(iterator.value);
      final result = ghostty_terminal_get(
        Pointer.fromAddress(terminal.value),
        .kittyGraphicsUnicodePlacementIterator,
        out.cast(),
      );
      checkResultCode(result.value, operation: 'ghostty_terminal_get');
    });
  }

  @override
  RawKittyUnicodePlacement kittyGraphicsUnicodePlacementGet(
    LibGhosttyHandle iterator,
    LibGhosttyHandle terminal,
  ) {
    if (iterator.value == 0 || terminal.value == 0) {
      checkResultCode(Result.invalidValue.value);
    }
    _setUnicodePlacementMulti([
      .topLeft,
      .imageId,
      .placementId,
      .column,
      .row,
      .columns,
      .rows,
    ]);
    final result = ghostty_kitty_graphics_unicode_placement_get_multi(
      Pointer.fromAddress(iterator.value),
      7,
      _keys,
      _values,
      _written,
    );
    checkResultCode(
      result.value,
      operation: 'ghostty_kitty_graphics_unicode_placement_get_multi',
    );
    final renderInfo = kittyGraphicsUnicodePlacementRenderInfo(
      iterator,
      terminal,
    );
    int u32(int index) => (_multi + index).cast<Uint32>().value;
    return (
      topLeft: _readGridRef(_multiGridRef.ref),
      imageId: u32(1),
      placementId: u32(2),
      column: u32(3),
      row: u32(4),
      columns: u32(5),
      rows: u32(6),
      renderInfo: renderInfo,
    );
  }

  @override
  void kittyGraphicsUnicodePlacementIteratorFree(LibGhosttyHandle iterator) {
    if (iterator.value == 0) return;
    ghostty_kitty_graphics_unicode_placement_iterator_free(
      Pointer.fromAddress(iterator.value),
    );
  }

  @override
  LibGhosttyHandle kittyGraphicsUnicodePlacementIteratorNew() {
    return using((arena) {
      final out = arena<Pointer<KittyGraphicsUnicodePlacementIteratorImpl>>();
      final code = ghostty_kitty_graphics_unicode_placement_iterator_new(
        nullptr,
        out,
      );
      checkRequiredCode(
        code.value,
        operation: 'ghostty_kitty_graphics_unicode_placement_iterator_new',
      );
      return .fromAddress(out.value.address);
    });
  }

  @override
  bool kittyGraphicsUnicodePlacementNext(LibGhosttyHandle iterator) {
    if (iterator.value == 0) return false;
    return ghostty_kitty_graphics_unicode_placement_next(
      Pointer.fromAddress(iterator.value),
    );
  }

  KittyPlacementRenderInfo? kittyGraphicsPlacementRenderInfo(
    LibGhosttyHandle iterator,
    LibGhosttyHandle image,
    LibGhosttyHandle terminal,
  ) {
    if (iterator.value == 0 || image.value == 0 || terminal.value == 0) {
      checkResultCode(Result.invalidValue.value);
    }
    return using((arena) {
      final out = KittyGraphicsPlacementRenderInfo.$allocate(
        arena,
        size: sizeOf<KittyGraphicsPlacementRenderInfo>(),
        pixel_width: 0,
        pixel_height: 0,
        grid_cols: 0,
        grid_rows: 0,
        viewport_col: 0,
        viewport_row: 0,
        viewport_visible: false,
        source_x: 0,
        source_y: 0,
        source_width: 0,
        source_height: 0,
      );
      final result = ghostty_kitty_graphics_placement_render_info(
        Pointer.fromAddress(iterator.value),
        Pointer.fromAddress(image.value),
        Pointer.fromAddress(terminal.value),
        out,
      );
      if (result == .noValue) return null;
      checkResultCode(
        result.value,
        operation: 'ghostty_kitty_graphics_placement_render_info',
      );
      return KittyPlacementRenderInfo(
        pixelWidth: out.ref.pixel_width,
        pixelHeight: out.ref.pixel_height,
        gridCols: out.ref.grid_cols,
        gridRows: out.ref.grid_rows,
        viewportCol: out.ref.viewport_col,
        viewportRow: out.ref.viewport_row,
        viewportVisible: out.ref.viewport_visible,
        sourceX: out.ref.source_x,
        sourceY: out.ref.source_y,
        sourceWidth: out.ref.source_width,
        sourceHeight: out.ref.source_height,
      );
    });
  }

  KittyUnicodePlacementRenderInfo? kittyGraphicsUnicodePlacementRenderInfo(
    LibGhosttyHandle iterator,
    LibGhosttyHandle terminal,
  ) {
    if (iterator.value == 0 || terminal.value == 0) {
      checkResultCode(Result.invalidValue.value);
    }
    return using((arena) {
      final out = KittyGraphicsUnicodePlacementRenderInfo.$allocate(
        arena,
        size: sizeOf<KittyGraphicsUnicodePlacementRenderInfo>(),
        viewport_col: 0,
        viewport_row: 0,
        z: -1,
        cell_offset_x: 0,
        cell_offset_y: 0,
        pixel_width: 0,
        pixel_height: 0,
        source_x: 0,
        source_y: 0,
        source_width: 0,
        source_height: 0,
      );
      final result = ghostty_kitty_graphics_unicode_placement_render_info(
        Pointer.fromAddress(iterator.value),
        Pointer.fromAddress(terminal.value),
        out,
      );
      if (result == .noValue) return null;
      checkResultCode(
        result.value,
        operation: 'ghostty_kitty_graphics_unicode_placement_render_info',
      );
      return KittyUnicodePlacementRenderInfo(
        viewportCol: out.ref.viewport_col,
        viewportRow: out.ref.viewport_row,
        z: out.ref.z,
        cellOffsetX: out.ref.cell_offset_x,
        cellOffsetY: out.ref.cell_offset_y,
        pixelWidth: out.ref.pixel_width,
        pixelHeight: out.ref.pixel_height,
        sourceX: out.ref.source_x,
        sourceY: out.ref.source_y,
        sourceWidth: out.ref.source_width,
        sourceHeight: out.ref.source_height,
      );
    });
  }

  int _imageGetU32(LibGhosttyHandle image, KittyGraphicsImageData data) {
    if (image.value == 0) checkResultCode(Result.invalidValue.value);
    return using((arena) {
      final out = arena<UnsignedInt>();
      final result = ghostty_kitty_graphics_image_get(
        Pointer.fromAddress(image.value),
        data,
        out.cast(),
      );
      checkResultCode(
        result.value,
        operation: 'ghostty_kitty_graphics_image_get',
      );
      return out.value;
    });
  }

  int _imageGetU64(LibGhosttyHandle image, KittyGraphicsImageData data) {
    if (image.value == 0) checkResultCode(Result.invalidValue.value);
    return using((arena) {
      final out = arena<Uint64>();
      final result = ghostty_kitty_graphics_image_get(
        Pointer.fromAddress(image.value),
        data,
        out.cast(),
      );
      checkResultCode(
        result.value,
        operation: 'ghostty_kitty_graphics_image_get',
      );
      return out.value;
    });
  }

  Uint8List _imagePixelDataView(LibGhosttyHandle image) {
    if (image.value == 0) checkResultCode(Result.invalidValue.value);
    _setImageMulti([.dataPtr, .dataLen]);
    final result = ghostty_kitty_graphics_image_get_multi(
      Pointer.fromAddress(image.value),
      2,
      _keys,
      _values,
      _written,
    );
    checkResultCode(
      result.value,
      operation: 'ghostty_kitty_graphics_image_get_multi',
    );
    final pointer = (_multi + 0).cast<Pointer<Uint8>>().value;
    final length = (_multi + 1).cast<Size>().value;
    if (pointer == nullptr || length == 0) return Uint8List(0);
    return pointer.asTypedList(length);
  }

  void _setImageMulti(List<KittyGraphicsImageData> keys) {
    for (var i = 0; i < keys.length; i++) {
      _keys[i] = keys[i].value;
      _values[i] = (_multi + i).cast();
    }
  }

  void _setPlacementMulti(List<KittyGraphicsPlacementData> keys) {
    for (var i = 0; i < keys.length; i++) {
      _keys[i] = keys[i].value;
      _values[i] = (_multi + i).cast();
    }
  }

  void _setUnicodePlacementMulti(List<KittyGraphicsUnicodePlacementData> keys) {
    _multiGridRef.ref.size = sizeOf<GridRef>();
    for (var i = 0; i < keys.length; i++) {
      _keys[i] = keys[i].value;
      _values[i] = keys[i] == .topLeft
          ? _multiGridRef.cast()
          : (_multi + i).cast();
    }
  }

  static RawGridRef _readGridRef(GridRef ref) =>
      (node: ref.node.address, x: ref.x, y: ref.y);
}
