import 'dart:typed_data';

import '../../generated/libghostty_enums.g.dart';
import '../../generated/libghostty_wasm.g.dart';
import '../../types/types.dart';
import '../types.dart';
import '../wasm/allocator.dart';
import '../wasm/layouts.dart';
import '../wasm/memory.dart';
import '../wasm/scratch.dart';
import 'kitty_graphics.dart';

const _wasmOutputSlotSize = 8;

final class WasmKittyGraphicsBindings implements KittyGraphicsBindings {
  final Memory _memory;
  final Layouts _layout;
  final GhosttyExports _exports;
  final WasmScratchPool _scratch;
  late final int _keys;
  late final int _values;
  late final int _multi;
  late final int _multiGridRef;
  late final int _written;

  WasmKittyGraphicsBindings(this._exports, this._layout)
    : _memory = Memory(_exports),
      _scratch = WasmScratchPool(
        WasmExportScratchAllocator(_exports),
        maxVariableLength: WasmScratchPool.defaultMaxVariableLength,
      ) {
    _keys = _allocate(12 * 4, alignment: 4);
    _values = _allocate(12 * 4, alignment: 4);
    _multi = _allocate(12 * _wasmOutputSlotSize, alignment: 8);
    _multiGridRef = _allocate(
      _layout.gridRefSize,
      alignment: wasm32PointerSize,
    );
    _written = _allocate(4, alignment: 4);
  }

  @override
  LibGhosttyHandle kittyGraphicsGet(LibGhosttyHandle terminal) {
    final frame = _scratch.acquire(const []);
    try {
      final out = frame.variableAddress(
        0,
        wasm32PointerSize,
        alignment: wasm32PointerSize,
      );
      final result = _exports.ghostty_terminal_get(
        terminal.value,
        TerminalData.kittyGraphics.value,
        out,
      );
      if (result != Result.success.value) return const .fromAddress(0);
      return .fromAddress(_memory.readPtr(out));
    } finally {
      frame.release();
    }
  }

  @override
  int kittyGraphicsGetGeneration(LibGhosttyHandle graphics) {
    if (graphics.value == 0) throw const InvalidValueException();
    final frame = _scratch.acquire(const []);
    try {
      final out = frame.variableAddress(0, 8, alignment: 8);
      final result = Result.fromValue(
        _exports.ghostty_kitty_graphics_get(
          graphics.value,
          KittyGraphicsData.generation.value,
          out,
        ),
      );
      checkCode(result, operation: 'ghostty_kitty_graphics_get');
      return _memory.readU64(out);
    } finally {
      frame.release();
    }
  }

  @override
  void kittyGraphicsGetPlacements(
    LibGhosttyHandle graphics,
    LibGhosttyHandle iterator,
  ) {
    if (graphics.value == 0 || iterator.value == 0) {
      throw const InvalidValueException();
    }
    final frame = _scratch.acquire(const []);
    try {
      final out = frame.variableAddress(
        0,
        wasm32PointerSize,
        alignment: wasm32PointerSize,
      );
      _memory.writeU32(out, iterator.value);
      final result = Result.fromValue(
        _exports.ghostty_kitty_graphics_get(
          graphics.value,
          KittyGraphicsData.placementIterator.value,
          out,
        ),
      );
      checkCode(result, operation: 'ghostty_kitty_graphics_get');
    } finally {
      frame.release();
    }
  }

  @override
  LibGhosttyHandle kittyGraphicsImage(LibGhosttyHandle graphics, int imageId) {
    if (graphics.value == 0) return const .fromAddress(0);
    return .fromAddress(
      _exports.ghostty_kitty_graphics_image(graphics.value, imageId),
    );
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
      throw const InvalidValueException();
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
    final result = Result.fromValue(
      _exports.ghostty_kitty_graphics_placement_get_multi(
        iterator.value,
        12,
        _keys,
        _values,
        _written,
      ),
    );
    checkCode(result, operation: 'ghostty_kitty_graphics_placement_get_multi');
    final imageId = _memory.readU32(_multi);
    final image = kittyGraphicsImage(graphics, imageId);
    final renderInfo = image.value == 0
        ? const KittyPlacementRenderInfo.offscreen()
        : kittyGraphicsPlacementRenderInfo(iterator, image, terminal) ??
              const KittyPlacementRenderInfo.offscreen();
    return KittyPlacement(
      imageId: imageId,
      placementId: _memory.readU32(_multi + 8),
      isVirtual: _memory.readU8(_multi + 16) != 0,
      xOffset: _memory.readU32(_multi + 24),
      yOffset: _memory.readU32(_multi + 32),
      sourceX: _memory.readU32(_multi + 40),
      sourceY: _memory.readU32(_multi + 48),
      sourceWidth: _memory.readU32(_multi + 56),
      sourceHeight: _memory.readU32(_multi + 64),
      columns: _memory.readU32(_multi + 72),
      rows: _memory.readU32(_multi + 80),
      z: _memory.readI32(_multi + 88),
      renderInfo: renderInfo,
    );
  }

  @override
  void kittyGraphicsPlacementIteratorFree(LibGhosttyHandle iterator) {
    if (iterator.value == 0) return;
    _exports.ghostty_kitty_graphics_placement_iterator_free(iterator.value);
  }

  @override
  LibGhosttyHandle kittyGraphicsPlacementIteratorNew() {
    final frame = _scratch.acquire(const []);
    try {
      final out = frame.variableAddress(
        0,
        wasm32PointerSize,
        alignment: wasm32PointerSize,
      );
      final result = Result.fromValue(
        _exports.ghostty_kitty_graphics_placement_iterator_new(0, out),
      );
      checkCode(
        result,
        operation: 'ghostty_kitty_graphics_placement_iterator_new',
      );
      return .fromAddress(_exports.ghostty_wasm_take_opaque(out));
    } finally {
      frame.release();
    }
  }

  @override
  void kittyGraphicsPlacementIteratorSetLayer(
    LibGhosttyHandle iterator,
    KittyPlacementLayer layer,
  ) {
    if (iterator.value == 0) throw const InvalidValueException();
    final frame = _scratch.acquire(const []);
    try {
      final value = frame.variableAddress(
        0,
        wasm32PointerSize,
        alignment: wasm32PointerSize,
      );
      _memory.writeU32(value, layer.value);
      final result = Result.fromValue(
        _exports.ghostty_kitty_graphics_placement_iterator_set(
          iterator.value,
          KittyGraphicsPlacementIteratorOption.layer.value,
          value,
        ),
      );
      checkCode(
        result,
        operation: 'ghostty_kitty_graphics_placement_iterator_set',
      );
    } finally {
      frame.release();
    }
  }

  @override
  bool kittyGraphicsPlacementNext(LibGhosttyHandle iterator) {
    if (iterator.value == 0) return false;
    return _exports.ghostty_kitty_graphics_placement_next(iterator.value) != 0;
  }

  @override
  void terminalGetKittyGraphicsUnicodePlacementIterator(
    LibGhosttyHandle terminal,
    LibGhosttyHandle iterator,
  ) {
    if (terminal.value == 0 || iterator.value == 0) {
      throw const InvalidValueException();
    }
    final frame = _scratch.acquire(const []);
    try {
      final out = frame.variableAddress(
        0,
        wasm32PointerSize,
        alignment: wasm32PointerSize,
      );
      _memory.writeU32(out, iterator.value);
      final result = Result.fromValue(
        _exports.ghostty_terminal_get(
          terminal.value,
          TerminalData.kittyGraphicsUnicodePlacementIterator.value,
          out,
        ),
      );
      checkCode(result, operation: 'ghostty_terminal_get');
    } finally {
      frame.release();
    }
  }

  @override
  RawKittyUnicodePlacement kittyGraphicsUnicodePlacementGet(
    LibGhosttyHandle iterator,
    LibGhosttyHandle terminal,
  ) {
    if (iterator.value == 0 || terminal.value == 0) {
      throw const InvalidValueException();
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
    final result = Result.fromValue(
      _exports.ghostty_kitty_graphics_unicode_placement_get_multi(
        iterator.value,
        7,
        _keys,
        _values,
        _written,
      ),
    );
    checkCode(
      result,
      operation: 'ghostty_kitty_graphics_unicode_placement_get_multi',
    );
    final renderInfo = kittyGraphicsUnicodePlacementRenderInfo(
      iterator,
      terminal,
    );
    int u32(int index) => _memory.readU32(_multi + index * _wasmOutputSlotSize);
    return (
      topLeft: _readGridRef(_multiGridRef),
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
    _exports.ghostty_kitty_graphics_unicode_placement_iterator_free(
      iterator.value,
    );
  }

  @override
  LibGhosttyHandle kittyGraphicsUnicodePlacementIteratorNew() {
    final frame = _scratch.acquire(const []);
    try {
      final out = frame.variableAddress(
        0,
        wasm32PointerSize,
        alignment: wasm32PointerSize,
      );
      final result = Result.fromValue(
        _exports.ghostty_kitty_graphics_unicode_placement_iterator_new(0, out),
      );
      checkCode(
        result,
        operation: 'ghostty_kitty_graphics_unicode_placement_iterator_new',
      );
      return .fromAddress(_exports.ghostty_wasm_take_opaque(out));
    } finally {
      frame.release();
    }
  }

  @override
  bool kittyGraphicsUnicodePlacementNext(LibGhosttyHandle iterator) {
    if (iterator.value == 0) return false;
    return _exports.ghostty_kitty_graphics_unicode_placement_next(
          iterator.value,
        ) !=
        0;
  }

  KittyPlacementRenderInfo? kittyGraphicsPlacementRenderInfo(
    LibGhosttyHandle iterator,
    LibGhosttyHandle image,
    LibGhosttyHandle terminal,
  ) {
    if (iterator.value == 0 || image.value == 0 || terminal.value == 0) {
      throw const InvalidValueException();
    }
    final size = _layout.kittyRenderInfoSize;
    final frame = _scratch.acquire(const []);
    try {
      final out = frame.variableAddress(0, size, alignment: wasm32PointerSize);
      _memory.writeU32(out, size);
      final result = Result.fromValue(
        _exports.ghostty_kitty_graphics_placement_render_info(
          iterator.value,
          image.value,
          terminal.value,
          out,
        ),
      );
      if (result == .noValue) return null;
      checkCode(
        result,
        operation: 'ghostty_kitty_graphics_placement_render_info',
      );
      return KittyPlacementRenderInfo(
        pixelWidth: _memory.readU32(out + _layout.kittyRenderInfoPixelWidth),
        pixelHeight: _memory.readU32(out + _layout.kittyRenderInfoPixelHeight),
        gridCols: _memory.readU32(out + _layout.kittyRenderInfoGridCols),
        gridRows: _memory.readU32(out + _layout.kittyRenderInfoGridRows),
        viewportCol: _memory.readI32(out + _layout.kittyRenderInfoViewportCol),
        viewportRow: _memory.readI32(out + _layout.kittyRenderInfoViewportRow),
        viewportVisible:
            _memory.readU8(out + _layout.kittyRenderInfoViewportVisible) != 0,
        sourceX: _memory.readU32(out + _layout.kittyRenderInfoSourceX),
        sourceY: _memory.readU32(out + _layout.kittyRenderInfoSourceY),
        sourceWidth: _memory.readU32(out + _layout.kittyRenderInfoSourceWidth),
        sourceHeight: _memory.readU32(
          out + _layout.kittyRenderInfoSourceHeight,
        ),
      );
    } finally {
      frame.release();
    }
  }

  KittyUnicodePlacementRenderInfo? kittyGraphicsUnicodePlacementRenderInfo(
    LibGhosttyHandle iterator,
    LibGhosttyHandle terminal,
  ) {
    if (iterator.value == 0 || terminal.value == 0) {
      throw const InvalidValueException();
    }
    final size = _layout.kittyUnicodeRenderInfoSize;
    final frame = _scratch.acquire(const []);
    try {
      final out = frame.variableAddress(0, size, alignment: wasm32PointerSize);
      _memory.writeU32(out, size);
      final result = Result.fromValue(
        _exports.ghostty_kitty_graphics_unicode_placement_render_info(
          iterator.value,
          terminal.value,
          out,
        ),
      );
      if (result == .noValue) return null;
      checkCode(
        result,
        operation: 'ghostty_kitty_graphics_unicode_placement_render_info',
      );
      return KittyUnicodePlacementRenderInfo(
        viewportCol: _memory.readI32(
          out + _layout.kittyUnicodeRenderInfoViewportCol,
        ),
        viewportRow: _memory.readI32(
          out + _layout.kittyUnicodeRenderInfoViewportRow,
        ),
        z: _memory.readI32(out + _layout.kittyUnicodeRenderInfoZ),
        cellOffsetX: _memory.readU32(
          out + _layout.kittyUnicodeRenderInfoCellOffsetX,
        ),
        cellOffsetY: _memory.readU32(
          out + _layout.kittyUnicodeRenderInfoCellOffsetY,
        ),
        pixelWidth: _memory.readU32(
          out + _layout.kittyUnicodeRenderInfoPixelWidth,
        ),
        pixelHeight: _memory.readU32(
          out + _layout.kittyUnicodeRenderInfoPixelHeight,
        ),
        sourceX: _memory.readU32(out + _layout.kittyUnicodeRenderInfoSourceX),
        sourceY: _memory.readU32(out + _layout.kittyUnicodeRenderInfoSourceY),
        sourceWidth: _memory.readU32(
          out + _layout.kittyUnicodeRenderInfoSourceWidth,
        ),
        sourceHeight: _memory.readU32(
          out + _layout.kittyUnicodeRenderInfoSourceHeight,
        ),
      );
    } finally {
      frame.release();
    }
  }

  int _allocate(int size, {int alignment = 1}) {
    final pointer = _require(_exports.allocateBytes(size));
    if (pointer % alignment != 0) {
      _exports.freeBytes(pointer, size);
      throw StateError('libghostty WASM allocator returned misaligned memory.');
    }
    return pointer;
  }

  int _imageGetU32(LibGhosttyHandle image, KittyGraphicsImageData data) {
    if (image.value == 0) throw const InvalidValueException();
    final frame = _scratch.acquire(const []);
    try {
      final out = frame.variableAddress(
        0,
        wasm32PointerSize,
        alignment: wasm32PointerSize,
      );
      final result = Result.fromValue(
        _exports.ghostty_kitty_graphics_image_get(image.value, data.value, out),
      );
      checkCode(result, operation: 'ghostty_kitty_graphics_image_get');
      return _memory.readU32(out);
    } finally {
      frame.release();
    }
  }

  int _imageGetU64(LibGhosttyHandle image, KittyGraphicsImageData data) {
    if (image.value == 0) throw const InvalidValueException();
    final frame = _scratch.acquire(const []);
    try {
      final out = frame.variableAddress(0, 8, alignment: 8);
      final result = Result.fromValue(
        _exports.ghostty_kitty_graphics_image_get(image.value, data.value, out),
      );
      checkCode(result, operation: 'ghostty_kitty_graphics_image_get');
      return _memory.readU64(out);
    } finally {
      frame.release();
    }
  }

  Uint8List _imagePixelDataView(LibGhosttyHandle image) {
    if (image.value == 0) throw const InvalidValueException();
    _setImageMulti([.dataPtr, .dataLen]);
    final result = Result.fromValue(
      _exports.ghostty_kitty_graphics_image_get_multi(
        image.value,
        2,
        _keys,
        _values,
        _written,
      ),
    );
    checkCode(result, operation: 'ghostty_kitty_graphics_image_get_multi');
    final pointer = _memory.readPtr(_multi);
    final length = _memory.readU32(_multi + _wasmOutputSlotSize);
    if (pointer == 0 || length == 0) return Uint8List(0);
    return _memory.readBytes(pointer, length);
  }

  int _require(int pointer) {
    if (pointer == 0) throw const OutOfMemoryException();
    return pointer;
  }

  void _setImageMulti(List<KittyGraphicsImageData> keys) {
    for (var i = 0; i < keys.length; i++) {
      _memory.writeU32(_keys + i * 4, keys[i].value);
      _memory.writeU32(_values + i * 4, _multi + i * _wasmOutputSlotSize);
    }
  }

  void _setPlacementMulti(List<KittyGraphicsPlacementData> keys) {
    for (var i = 0; i < keys.length; i++) {
      _memory.writeU32(_keys + i * 4, keys[i].value);
      _memory.writeU32(_values + i * 4, _multi + i * _wasmOutputSlotSize);
    }
  }

  void _setUnicodePlacementMulti(List<KittyGraphicsUnicodePlacementData> keys) {
    _memory.writeU32(_multiGridRef, _layout.gridRefSize);
    for (var i = 0; i < keys.length; i++) {
      _memory.writeU32(_keys + i * 4, keys[i].value);
      _memory.writeU32(
        _values + i * 4,
        keys[i] == .topLeft ? _multiGridRef : _multi + i * _wasmOutputSlotSize,
      );
    }
  }

  RawGridRef _readGridRef(int pointer) => (
    node: _memory.readPtr(pointer + _layout.gridRefNode),
    x: _memory.readU16(pointer + _layout.gridRefX),
    y: _memory.readU16(pointer + _layout.gridRefY),
  );
}
