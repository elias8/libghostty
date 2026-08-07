import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../../ffi/libghostty_enums.g.dart';
import '../../ffi/libghostty_wasm.g.dart';
import '../interface.dart';
import 'adapter.dart';
import 'layouts.dart';
import 'memory.dart';

GhosttyBindings? _instance;

GhosttyBindings get bindings {
  if (_instance == null) {
    throw StateError(
      'libghostty WASM bindings not initialized. Call initializeForWeb() '
      'first.',
    );
  }
  return _instance!;
}

/// Loads the libghostty-vt WASM module and initializes bindings for web use.
///
/// ```dart
/// await initializeForWeb(Uri.parse('assets/libghostty.wasm'));
/// ```
Future<void> initializeForWeb(Uri wasmUri) async {
  final response = await web.window.fetch(wasmUri.toString().toJS).toDart;
  final bytes = await response.arrayBuffer().toDart;
  final imports = _buildImports();
  final resultObj =
      (await _wasmInstantiate(bytes, imports).toDart)! as JSObject;
  final instance = resultObj['instance']! as JSObject;
  final exports = instance['exports']! as JSObject;
  _instance = WasmBindings._(exports);
}

JSObject _buildImports() {
  final env = newJsObject();
  env['log'] = ((JSNumber ptr, JSNumber len) {}).toJS;
  final imports = newJsObject();
  imports['env'] = env;
  return imports;
}

@JS('WebAssembly.instantiate')
external JSPromise _wasmInstantiate(JSArrayBuffer bytes, JSObject imports);

const _wasmEnumSize = 4;
const _wasmPointerSize = 4;
const _wasmSizeSize = 4;
const _wasmOutputSlotSize = 8;
const _maxMultiQueryCount = 12;

final JSString _cellGetMultiMethod = 'ghostty_cell_get_multi'.toJS;
final JSString _rowGetMultiMethod = 'ghostty_row_get_multi'.toJS;

const RawPlacement _emptyPlacement = (
  imageId: 0,
  placementId: 0,
  isVirtual: false,
  xOffset: 0,
  yOffset: 0,
  sourceX: 0,
  sourceY: 0,
  sourceWidth: 0,
  sourceHeight: 0,
  columns: 0,
  rows: 0,
  z: 0,
);

const RawPlacementRenderInfo _emptyRenderInfo = (
  pixelWidth: 0,
  pixelHeight: 0,
  gridCols: 0,
  gridRows: 0,
  viewportCol: 0,
  viewportRow: 0,
  viewportVisible: false,
  sourceX: 0,
  sourceY: 0,
  sourceWidth: 0,
  sourceHeight: 0,
);

const RawGridRef _emptyGridRef = (node: 0, x: 0, y: 0);
const TerminalGeometry _emptyTerminalGeometry = (
  cols: 0,
  rows: 0,
  widthPx: 0,
  heightPx: 0,
);
const RawRenderStateSummary _emptyRenderStateSummary = (
  cols: 0,
  rows: 0,
  dirty: .false$,
);
const RawRenderStateCursor _emptyRenderStateCursor = (
  visualStyle: .block,
  visible: false,
  blinking: false,
  passwordInput: false,
  inViewport: false,
  viewportX: 0,
  viewportY: 0,
  viewportWideTail: false,
);
const RawSelectionGestureState _emptySelectionGestureState = (
  clickCount: 0,
  dragged: false,
  autoscroll: .none,
  behavior: .cell,
  anchor: null,
);

const _rowIteratorSummaryKeys = <RenderStateRowData>[.dirty, .raw];
const _rowCellsSummaryKeys = <RenderStateRowCellsData>[
  .raw,
  .graphemesLen,
  .selected,
];
const _cellSummaryKeys = <CellData>[.codepoint, .styleId, .wide];
const _rowSummaryKeys = <RowData>[
  .wrap,
  .wrapContinuation,
  .grapheme,
  .styled,
  .hyperlink,
  .semanticPrompt,
  .kittyVirtualPlaceholder,
];
const _selectionGestureStateKeys = <SelectionGestureData>[
  .clickCount,
  .dragged,
  .autoscroll,
  .behavior,
  .anchor,
];
const _kittyImagePixelDataKeys = <KittyGraphicsImageData>[.dataPtr, .dataLen];
const _kittyPlacementKeys = <KittyGraphicsPlacementData>[
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
];
const _cursorStateKeys = <RenderStateData>[
  .cursorVisualStyle,
  .cursorVisible,
  .cursorBlinking,
  .cursorPasswordInput,
  .cursorViewportHasValue,
  .cursorViewportX,
  .cursorViewportY,
  .cursorViewportWideTail,
];
const _renderStateSummaryKeys = <RenderStateData>[.cols, .rows, .dirty];

class WasmBindings implements GhosttyBindings {
  final Mem _mem;
  final web.Table _table;
  late final Layouts _layout;
  final GhosttyExports _exports;
  final _utf8Ptrs = <int, (int ptr, int len)>{};
  final _callbacks = <int, Map<TerminalOption, (int index, Function fn)>>{};
  ({Object error, StackTrace stackTrace})? _callbackError;
  final _stringBufs = <int, Map<TerminalOption, (int ptr, int len)>>{};
  final _cellGetMultiArguments = List<JSAny?>.filled(5, null);
  final _rowGetMultiArguments = List<JSAny?>.filled(5, null);
  late final int _multiKeys;
  late final int _multiValues;
  late final int _multiOut;
  late final int _multiWritten;
  late final int _multiGridRef;
  late final int _renderStateSummaryMultiKeys;
  late final int _renderStateSummaryMultiValues;
  late final int _renderStateSummaryMultiOut;
  late final int _cursorMultiKeys;
  late final int _cursorMultiValues;
  late final int _cursorMultiOut;
  late final int _rowCellsMultiKeys;
  late final int _rowCellsMultiValues;
  late final int _rowCellsMultiOut;
  late final int _cellMultiKeys;
  late final int _cellMultiValues;
  late final int _cellMultiOut;
  late int _formatBuffer;
  late int _formatBufferCapacity;

  void _captureCallbackError(Object error, StackTrace stackTrace) {
    _callbackError ??= (error: error, stackTrace: stackTrace);
  }

  T _runNestedCallbackOperation<T>(T Function() operation) {
    final previousFailure = _callbackError!;
    _callbackError = null;
    late final T result;
    late final ({Object error, StackTrace stackTrace})? failure;
    try {
      result = operation();
    } finally {
      failure = _callbackError;
      _callbackError = previousFailure;
    }
    if (failure != null) {
      Error.throwWithStackTrace(failure.error, failure.stackTrace);
    }
    return result;
  }

  WasmBindings._(JSObject exports)
    : _exports = GhosttyExports(exports),
      _mem = Mem(GhosttyExports(exports)),
      _table =
          (exports['__indirect_function_table'] as web.Table?) ??
          (throw StateError(
            'WASM module does not export __indirect_function_table',
          )) {
    final json = jsonDecode(_mem.readCString(_exports.ghostty_type_json()));
    _layout = Layouts(json as Map<String, dynamic>);
    _multiKeys = _allocateBytes(
      _maxMultiQueryCount * _wasmEnumSize,
      alignment: _wasmEnumSize,
    );
    _multiValues = _allocateBytes(
      _maxMultiQueryCount * _wasmPointerSize,
      alignment: _wasmPointerSize,
    );
    _multiOut = _allocateBytes(
      _maxMultiQueryCount * _wasmOutputSlotSize,
      alignment: _wasmOutputSlotSize,
    );
    _multiWritten = _allocateSize();
    _multiGridRef = _allocateBytes(
      _layout.gridRefSize,
      alignment: _wasmPointerSize,
    );
    _renderStateSummaryMultiKeys = _allocateBytes(
      _renderStateSummaryKeys.length * _wasmEnumSize,
      alignment: _wasmEnumSize,
    );
    _renderStateSummaryMultiValues = _allocateBytes(
      _renderStateSummaryKeys.length * _wasmPointerSize,
      alignment: _wasmPointerSize,
    );
    _renderStateSummaryMultiOut = _allocateBytes(
      _renderStateSummaryKeys.length * _wasmOutputSlotSize,
      alignment: _wasmOutputSlotSize,
    );
    for (var i = 0; i < _renderStateSummaryKeys.length; i++) {
      _mem.writeU32(
        _renderStateSummaryMultiKeys + i * _wasmEnumSize,
        _renderStateSummaryKeys[i].value,
      );
      _mem.writeU32(
        _renderStateSummaryMultiValues + i * _wasmPointerSize,
        _renderStateSummaryMultiOut + i * _wasmOutputSlotSize,
      );
    }
    _cursorMultiKeys = _allocateBytes(
      _cursorStateKeys.length * _wasmEnumSize,
      alignment: _wasmEnumSize,
    );
    _cursorMultiValues = _allocateBytes(
      _cursorStateKeys.length * _wasmPointerSize,
      alignment: _wasmPointerSize,
    );
    _cursorMultiOut = _allocateBytes(
      _cursorStateKeys.length * _wasmOutputSlotSize,
      alignment: _wasmOutputSlotSize,
    );
    for (var i = 0; i < _cursorStateKeys.length; i++) {
      _mem.writeU32(
        _cursorMultiKeys + i * _wasmEnumSize,
        _cursorStateKeys[i].value,
      );
      _mem.writeU32(
        _cursorMultiValues + i * _wasmPointerSize,
        _cursorMultiOut + i * _wasmOutputSlotSize,
      );
    }
    _rowCellsMultiKeys = _allocateBytes(
      _rowCellsSummaryKeys.length * _wasmEnumSize,
      alignment: _wasmEnumSize,
    );
    _rowCellsMultiValues = _allocateBytes(
      _rowCellsSummaryKeys.length * _wasmPointerSize,
      alignment: _wasmPointerSize,
    );
    _rowCellsMultiOut = _allocateBytes(
      _rowCellsSummaryKeys.length * _wasmOutputSlotSize,
      alignment: _wasmOutputSlotSize,
    );
    for (var i = 0; i < _rowCellsSummaryKeys.length; i++) {
      _mem.writeU32(
        _rowCellsMultiKeys + i * _wasmEnumSize,
        _rowCellsSummaryKeys[i].value,
      );
      _mem.writeU32(
        _rowCellsMultiValues + i * _wasmPointerSize,
        _rowCellsMultiOut + i * _wasmOutputSlotSize,
      );
    }
    _cellMultiKeys = _allocateBytes(
      _cellSummaryKeys.length * _wasmEnumSize,
      alignment: _wasmEnumSize,
    );
    _cellMultiValues = _allocateBytes(
      _cellSummaryKeys.length * _wasmPointerSize,
      alignment: _wasmPointerSize,
    );
    _cellMultiOut = _allocateBytes(
      _cellSummaryKeys.length * _wasmOutputSlotSize,
      alignment: _wasmOutputSlotSize,
    );
    for (var i = 0; i < _cellSummaryKeys.length; i++) {
      _mem.writeU32(
        _cellMultiKeys + i * _wasmEnumSize,
        _cellSummaryKeys[i].value,
      );
      _mem.writeU32(
        _cellMultiValues + i * _wasmPointerSize,
        _cellMultiOut + i * _wasmOutputSlotSize,
      );
    }
    _formatBufferCapacity = 4096;
    _formatBuffer = _allocateBytes(_formatBufferCapacity);
  }

  int _allocateBytes(int size, {int alignment = 1}) {
    final pointer = _exports.ghostty_wasm_alloc_u8_array(size);
    if (pointer == 0) throw const OutOfMemoryException();
    if (pointer % alignment != 0) {
      _exports.ghostty_wasm_free_u8_array(pointer, size);
      throw StateError('libghostty WASM allocator returned misaligned memory.');
    }
    return pointer;
  }

  int _allocateSize() {
    final pointer = _exports.ghostty_wasm_alloc_usize();
    if (pointer == 0) throw const OutOfMemoryException();
    if (pointer % _wasmSizeSize != 0) {
      _exports.ghostty_wasm_free_usize(pointer);
      throw StateError('libghostty WASM allocator returned misaligned memory.');
    }
    return pointer;
  }

  int _registerCallback(
    JSFunction jsFunction,
    List<String> params, {
    List<String> results = const [],
    int? reuseIndex,
  }) {
    final wasmFunc = wrapJsAsWasmFunction(jsFunction, params, results);
    final index = reuseIndex ?? _table.grow(1);
    _table.set(index, wasmFunc);
    return index;
  }

  @override
  CResult<int> keyEventNew() {
    final outPtr = _exports.ghostty_wasm_alloc_opaque();
    final result = _exports.ghostty_key_event_new(0, outPtr);
    final handle = _mem.readPtr(outPtr);
    _exports.ghostty_wasm_free_opaque(outPtr);
    return (.fromValue(result), handle);
  }

  @override
  void keyEventFree(int handle) {
    final prev = _utf8Ptrs.remove(handle);
    if (prev != null) _exports.ghostty_wasm_free_u8_array(prev.$1, prev.$2);
    _exports.ghostty_key_event_free(handle);
  }

  @override
  void keyEventSetAction(int handle, KeyAction action) {
    _exports.ghostty_key_event_set_action(handle, action.value);
  }

  @override
  KeyAction keyEventGetAction(int handle) {
    return .fromValue(_exports.ghostty_key_event_get_action(handle));
  }

  @override
  void keyEventSetKey(int handle, Key key) {
    _exports.ghostty_key_event_set_key(handle, key.value);
  }

  @override
  Key keyEventGetKey(int handle) {
    return .fromValue(_exports.ghostty_key_event_get_key(handle));
  }

  @override
  void keyEventSetMods(int handle, int mods) {
    _exports.ghostty_key_event_set_mods(handle, mods);
  }

  @override
  int keyEventGetMods(int handle) {
    return _exports.ghostty_key_event_get_mods(handle);
  }

  @override
  void keyEventSetConsumedMods(int handle, int mods) {
    _exports.ghostty_key_event_set_consumed_mods(handle, mods);
  }

  @override
  int keyEventGetConsumedMods(int handle) {
    return _exports.ghostty_key_event_get_consumed_mods(handle);
  }

  @override
  void keyEventSetComposing(int handle, {required bool composing}) {
    _exports.ghostty_key_event_set_composing(handle, composing ? 1 : 0);
  }

  @override
  bool keyEventGetComposing(int handle) {
    return _exports.ghostty_key_event_get_composing(handle) != 0;
  }

  @override
  void keyEventSetUtf8(int handle, String? text) {
    final prev = _utf8Ptrs.remove(handle);
    if (prev != null) {
      _exports.ghostty_wasm_free_u8_array(prev.$1, prev.$2);
    }

    if (text == null) {
      _exports.ghostty_key_event_set_utf8(handle, 0, 0);
      return;
    }

    final encoded = utf8.encode(text);
    final ptr = _exports.ghostty_wasm_alloc_u8_array(encoded.length);
    _mem.writeBytes(ptr, encoded);
    _exports.ghostty_key_event_set_utf8(handle, ptr, encoded.length);
    _utf8Ptrs[handle] = (ptr, encoded.length);
  }

  @override
  String? keyEventGetUtf8(int handle) {
    final lenPtr = _exports.ghostty_wasm_alloc_usize();
    final charPtr = _exports.ghostty_key_event_get_utf8(handle, lenPtr);
    if (charPtr == 0) {
      _exports.ghostty_wasm_free_usize(lenPtr);
      return null;
    }
    final len = _mem.readU32(lenPtr);
    _exports.ghostty_wasm_free_usize(lenPtr);
    if (len == 0) return null;
    return utf8.decode(_mem.readBytes(charPtr, len));
  }

  @override
  void keyEventSetUnshiftedCodepoint(int handle, int codepoint) {
    _exports.ghostty_key_event_set_unshifted_codepoint(handle, codepoint);
  }

  @override
  int keyEventGetUnshiftedCodepoint(int handle) {
    return _exports.ghostty_key_event_get_unshifted_codepoint(handle);
  }

  @override
  CResult<int> keyEncoderNew() {
    final outPtr = _exports.ghostty_wasm_alloc_opaque();
    final result = _exports.ghostty_key_encoder_new(0, outPtr);
    final handle = _mem.readPtr(outPtr);
    _exports.ghostty_wasm_free_opaque(outPtr);
    return (.fromValue(result), handle);
  }

  @override
  void keyEncoderFree(int handle) {
    _exports.ghostty_key_encoder_free(handle);
  }

  @override
  void keyEncoderSetBoolOpt(
    int handle,
    KeyEncoderOption option, {
    required bool value,
  }) {
    final ptr = _exports.ghostty_wasm_alloc_u8();
    _mem.writeU8(ptr, value ? 1 : 0);
    _exports.ghostty_key_encoder_setopt(handle, option.value, ptr);
    _exports.ghostty_wasm_free_u8(ptr);
  }

  @override
  void keyEncoderSetKittyFlags(int handle, int flags) {
    final ptr = _exports.ghostty_wasm_alloc_u8();
    _mem.writeU8(ptr, flags);
    _exports.ghostty_key_encoder_setopt(
      handle,
      KeyEncoderOption.kittyFlags.value,
      ptr,
    );
    _exports.ghostty_wasm_free_u8(ptr);
  }

  @override
  void keyEncoderSetOptionAsAlt(int handle, OptionAsAlt value) {
    final ptr = _exports.ghostty_wasm_alloc_usize();
    _mem.writeI32(ptr, value.value);
    _exports.ghostty_key_encoder_setopt(
      handle,
      KeyEncoderOption.macosOptionAsAlt.value,
      ptr,
    );
    _exports.ghostty_wasm_free_usize(ptr);
  }

  @override
  void keyEncoderSetOptFromTerminal(int encoder, int terminal) {
    _exports.ghostty_key_encoder_setopt_from_terminal(encoder, terminal);
  }

  @override
  CResult<String> keyEncoderEncode(int encoder, int event) {
    final outLen = _exports.ghostty_wasm_alloc_usize();
    var bufSize = 128;
    var buf = _exports.ghostty_wasm_alloc_u8_array(bufSize);
    var result = Result.fromValue(
      _exports.ghostty_key_encoder_encode(encoder, event, buf, bufSize, outLen),
    );

    // Retry with the required size if the initial buffer was too small.
    if (result == .outOfSpace) {
      _exports.ghostty_wasm_free_u8_array(buf, bufSize);
      bufSize = _mem.readU32(outLen);
      buf = _exports.ghostty_wasm_alloc_u8_array(bufSize);
      result = .fromValue(
        _exports.ghostty_key_encoder_encode(
          encoder,
          event,
          buf,
          bufSize,
          outLen,
        ),
      );
    }

    final len = _mem.readU32(outLen);
    final value = utf8.decode(_mem.readBytes(buf, len));
    _exports.ghostty_wasm_free_usize(outLen);
    _exports.ghostty_wasm_free_u8_array(buf, bufSize);
    return (result, value);
  }

  @override
  CResult<int> mouseEventNew() {
    final outPtr = _exports.ghostty_wasm_alloc_opaque();
    final result = _exports.ghostty_mouse_event_new(0, outPtr);
    final handle = _mem.readPtr(outPtr);
    _exports.ghostty_wasm_free_opaque(outPtr);
    return (.fromValue(result), handle);
  }

  @override
  void mouseEventFree(int handle) => _exports.ghostty_mouse_event_free(handle);

  @override
  void mouseEventSetAction(int handle, MouseAction action) {
    _exports.ghostty_mouse_event_set_action(handle, action.value);
  }

  @override
  MouseAction mouseEventGetAction(int handle) {
    return .fromValue(_exports.ghostty_mouse_event_get_action(handle));
  }

  @override
  void mouseEventSetButton(int handle, MouseButton button) {
    _exports.ghostty_mouse_event_set_button(handle, button.value);
  }

  @override
  void mouseEventClearButton(int handle) {
    _exports.ghostty_mouse_event_clear_button(handle);
  }

  @override
  CResult<MouseButton> mouseEventGetButton(int handle) {
    final outPtr = _exports.ghostty_wasm_alloc_usize();
    final hasButton =
        _exports.ghostty_mouse_event_get_button(handle, outPtr) != 0;
    final value = hasButton ? _mem.readI32(outPtr) : 0;
    _exports.ghostty_wasm_free_usize(outPtr);
    return (hasButton ? .success : .noValue, .fromValue(value));
  }

  @override
  void mouseEventSetMods(int handle, int mods) {
    _exports.ghostty_mouse_event_set_mods(handle, mods);
  }

  @override
  int mouseEventGetMods(int handle) {
    return _exports.ghostty_mouse_event_get_mods(handle);
  }

  @override
  void mouseEventSetPosition(int handle, double x, double y) {
    final posPtr = _exports.ghostty_wasm_alloc_u8_array(_layout.mousePosSize);
    _mem.writeF32(posPtr, x);
    _mem.writeF32(posPtr + _layout.mousePosY, y);
    _exports.ghostty_mouse_event_set_position(handle, posPtr);
    _exports.ghostty_wasm_free_u8_array(posPtr, _layout.mousePosSize);
  }

  @override
  (double, double) mouseEventGetPosition(int handle) {
    final posPtr = _exports.ghostty_wasm_alloc_u8_array(_layout.mousePosSize);
    _exports.ghostty_mouse_event_get_position(posPtr, handle);
    final x = _mem.readF32(posPtr);
    final y = _mem.readF32(posPtr + _layout.mousePosY);
    _exports.ghostty_wasm_free_u8_array(posPtr, _layout.mousePosSize);
    return (x, y);
  }

  @override
  CResult<int> mouseEncoderNew() {
    final outPtr = _exports.ghostty_wasm_alloc_opaque();
    final result = _exports.ghostty_mouse_encoder_new(0, outPtr);
    final handle = _mem.readPtr(outPtr);
    _exports.ghostty_wasm_free_opaque(outPtr);
    return (.fromValue(result), handle);
  }

  @override
  void mouseEncoderFree(int handle) {
    _exports.ghostty_mouse_encoder_free(handle);
  }

  @override
  void mouseEncoderSetBoolOpt(
    int handle,
    MouseEncoderOption option, {
    required bool value,
  }) {
    final ptr = _exports.ghostty_wasm_alloc_usize();
    _mem.writeU8(ptr, value ? 1 : 0);
    _exports.ghostty_mouse_encoder_setopt(handle, option.value, ptr);
    _exports.ghostty_wasm_free_usize(ptr);
  }

  @override
  void mouseEncoderSetTrackingMode(int handle, MouseTrackingMode mode) {
    final ptr = _exports.ghostty_wasm_alloc_usize();
    _mem.writeI32(ptr, mode.value);
    _exports.ghostty_mouse_encoder_setopt(
      handle,
      MouseEncoderOption.event.value,
      ptr,
    );
    _exports.ghostty_wasm_free_usize(ptr);
  }

  @override
  void mouseEncoderSetFormat(int handle, MouseFormat format) {
    final ptr = _exports.ghostty_wasm_alloc_usize();
    _mem.writeI32(ptr, format.value);
    _exports.ghostty_mouse_encoder_setopt(
      handle,
      MouseEncoderOption.format.value,
      ptr,
    );
    _exports.ghostty_wasm_free_usize(ptr);
  }

  @override
  void mouseEncoderSetSize(int handle, MouseEncoderSize size) {
    final ptr = _exports.ghostty_wasm_alloc_u8_array(
      _layout.mouseEncoderSizeSize,
    );
    _mem.writeU32(ptr, _layout.mouseEncoderSizeSize);
    _mem.writeU32(ptr + _layout.mouseEncoderSizeScreenWidth, size.screenWidth);
    _mem.writeU32(
      ptr + _layout.mouseEncoderSizeScreenHeight,
      size.screenHeight,
    );
    _mem.writeU32(ptr + _layout.mouseEncoderSizeCellWidth, size.cellWidth);
    _mem.writeU32(ptr + _layout.mouseEncoderSizeCellHeight, size.cellHeight);
    _mem.writeU32(ptr + _layout.mouseEncoderSizePaddingTop, size.paddingTop);
    _mem.writeU32(
      ptr + _layout.mouseEncoderSizePaddingBottom,
      size.paddingBottom,
    );
    _mem.writeU32(
      ptr + _layout.mouseEncoderSizePaddingRight,
      size.paddingRight,
    );
    _mem.writeU32(ptr + _layout.mouseEncoderSizePaddingLeft, size.paddingLeft);
    _exports.ghostty_mouse_encoder_setopt(
      handle,
      MouseEncoderOption.size.value,
      ptr,
    );
    _exports.ghostty_wasm_free_u8_array(ptr, _layout.mouseEncoderSizeSize);
  }

  @override
  void mouseEncoderSetOptFromTerminal(int encoder, int terminal) {
    _exports.ghostty_mouse_encoder_setopt_from_terminal(encoder, terminal);
  }

  @override
  void mouseEncoderReset(int handle) {
    _exports.ghostty_mouse_encoder_reset(handle);
  }

  @override
  CResult<String> mouseEncoderEncode(int encoder, int event) {
    final outLen = _exports.ghostty_wasm_alloc_usize();
    var bufSize = 128;
    var buf = _exports.ghostty_wasm_alloc_u8_array(bufSize);
    var result = Result.fromValue(
      _exports.ghostty_mouse_encoder_encode(
        encoder,
        event,
        buf,
        bufSize,
        outLen,
      ),
    );

    // Retry with the required size if the initial buffer was too small.
    if (result == .outOfSpace) {
      _exports.ghostty_wasm_free_u8_array(buf, bufSize);
      bufSize = _mem.readU32(outLen);
      buf = _exports.ghostty_wasm_alloc_u8_array(bufSize);
      result = .fromValue(
        _exports.ghostty_mouse_encoder_encode(
          encoder,
          event,
          buf,
          bufSize,
          outLen,
        ),
      );
    }

    final len = _mem.readU32(outLen);
    final value = utf8.decode(_mem.readBytes(buf, len));
    _exports.ghostty_wasm_free_usize(outLen);
    _exports.ghostty_wasm_free_u8_array(buf, bufSize);
    return (result, value);
  }

  @override
  CResult<int> oscNew() {
    final outPtr = _exports.ghostty_wasm_alloc_opaque();
    final result = _exports.ghostty_osc_new(0, outPtr);
    final handle = _mem.readPtr(outPtr);
    _exports.ghostty_wasm_free_opaque(outPtr);
    return (.fromValue(result), handle);
  }

  @override
  void oscFree(int handle) => _exports.ghostty_osc_free(handle);

  @override
  void oscFeedByte(int handle, int byte) {
    _exports.ghostty_osc_next(handle, byte);
  }

  @override
  int oscEnd(int handle, int terminator) {
    return _exports.ghostty_osc_end(handle, terminator);
  }

  @override
  OscCommandType oscCommandType(int command) {
    return .fromValue(_exports.ghostty_osc_command_type(command));
  }

  @override
  String? oscCommandWindowTitle(int command) {
    final outPtr = _exports.ghostty_wasm_alloc_opaque();
    final success = _exports.ghostty_osc_command_data(
      command,
      OscCommandData.changeWindowTitleStr.value,
      outPtr,
    );
    if (success == 0) {
      _exports.ghostty_wasm_free_opaque(outPtr);
      return null;
    }
    final charPtr = _mem.readPtr(outPtr);
    _exports.ghostty_wasm_free_opaque(outPtr);
    if (charPtr == 0) return null;
    return _mem.readCString(charPtr);
  }

  @override
  void oscReset(int handle) => _exports.ghostty_osc_reset(handle);

  @override
  CResult<int> sgrNew() {
    final outPtr = _exports.ghostty_wasm_alloc_opaque();
    final result = _exports.ghostty_sgr_new(0, outPtr);
    final handle = _mem.readPtr(outPtr);
    _exports.ghostty_wasm_free_opaque(outPtr);
    return (.fromValue(result), handle);
  }

  @override
  void sgrFree(int handle) => _exports.ghostty_sgr_free(handle);

  @override
  Result sgrSetParams(int handle, List<int> params, List<String>? separators) {
    final paramsPtr = _exports.ghostty_wasm_alloc_u16_array(params.length);
    var sepsPtr = 0;

    for (var i = 0; i < params.length; i++) {
      _mem.writeU16(paramsPtr + i * 2, params[i]);
    }

    if (separators != null) {
      sepsPtr = _exports.ghostty_wasm_alloc_u8_array(separators.length);
      for (var i = 0; i < separators.length; i++) {
        _mem.writeU8(sepsPtr + i, separators[i].codeUnitAt(0));
      }
    }

    final result = _exports.ghostty_sgr_set_params(
      handle,
      paramsPtr,
      sepsPtr,
      params.length,
    );

    _exports.ghostty_wasm_free_u16_array(paramsPtr, params.length);
    if (sepsPtr != 0) {
      _exports.ghostty_wasm_free_u8_array(sepsPtr, separators!.length);
    }
    return .fromValue(result);
  }

  @override
  SgrAttribute? sgrNext(int handle) {
    final attrPtr = _exports.ghostty_wasm_alloc_sgr_attribute();
    final hasNext = _exports.ghostty_sgr_next(handle, attrPtr) != 0;
    if (!hasNext) {
      _exports.ghostty_wasm_free_sgr_attribute(attrPtr);
      return null;
    }
    final attr = _readSgrAttribute(attrPtr);
    _exports.ghostty_wasm_free_sgr_attribute(attrPtr);
    return attr;
  }

  @override
  void sgrReset(int handle) => _exports.ghostty_sgr_reset(handle);

  @override
  bool pasteIsSafe(String data) {
    final encoded = utf8.encode(data);
    if (encoded.isEmpty) return _exports.ghostty_paste_is_safe(0, 0) != 0;
    final ptr = _exports.ghostty_wasm_alloc_u8_array(encoded.length);
    _mem.writeBytes(ptr, encoded);
    final result = _exports.ghostty_paste_is_safe(ptr, encoded.length) != 0;
    _exports.ghostty_wasm_free_u8_array(ptr, encoded.length);
    return result;
  }

  @override
  double colorContrast(RgbColor a, RgbColor b) {
    final aPtr = _allocRgb(a);
    final bPtr = _allocRgb(b);
    final result = _exports.ghostty_color_contrast(aPtr, bPtr);
    _exports.ghostty_wasm_free_u8_array(aPtr, _layout.colorRgbSize);
    _exports.ghostty_wasm_free_u8_array(bPtr, _layout.colorRgbSize);
    return result;
  }

  @override
  double colorLuminance(RgbColor color) {
    final ptr = _allocRgb(color);
    final result = _exports.ghostty_color_luminance(ptr);
    _exports.ghostty_wasm_free_u8_array(ptr, _layout.colorRgbSize);
    return result;
  }

  @override
  double colorPerceivedLuminance(RgbColor color) {
    final ptr = _allocRgb(color);
    final result = _exports.ghostty_color_perceived_luminance(ptr);
    _exports.ghostty_wasm_free_u8_array(ptr, _layout.colorRgbSize);
    return result;
  }

  @override
  List<RgbColor> colorPaletteDefault() {
    final paletteSize = 256 * _layout.colorRgbSize;
    final out = _exports.ghostty_wasm_alloc_u8_array(paletteSize);
    _exports.ghostty_color_palette_default(out);
    final result = _readPalette(out);
    _exports.ghostty_wasm_free_u8_array(out, paletteSize);
    return result;
  }

  @override
  List<RgbColor> colorPaletteGenerate({
    List<RgbColor>? base,
    Set<int> skip = const {},
    required RgbColor background,
    required RgbColor foreground,
    required bool harmonious,
  }) {
    final paletteSize = 256 * _layout.colorRgbSize;
    final basePtr = base == null
        ? 0
        : _exports.ghostty_wasm_alloc_u8_array(paletteSize);
    if (base != null) {
      for (var i = 0; i < 256; i++) {
        _writeRgb(basePtr + i * _layout.colorRgbSize, base[i]);
      }
    }
    const skipSize = 32;
    final skipPtr = skip.isEmpty
        ? 0
        : _exports.ghostty_wasm_alloc_u8_array(skipSize);
    if (skip.isNotEmpty) {
      for (var i = 0; i < 4; i++) {
        _mem.writeU64(skipPtr + i * 8, 0);
      }
      for (final index in skip) {
        final offset = skipPtr + (index >> 6) * 8;
        _mem.writeU64(offset, _mem.readU64(offset) | (1 << (index & 63)));
      }
    }
    final bgPtr = _allocRgb(background);
    final fgPtr = _allocRgb(foreground);
    final out = _exports.ghostty_wasm_alloc_u8_array(paletteSize);
    _exports.ghostty_color_palette_generate(
      basePtr,
      skipPtr,
      bgPtr,
      fgPtr,
      harmonious ? 1 : 0,
      out,
    );
    final result = _readPalette(out);
    if (basePtr != 0) _exports.ghostty_wasm_free_u8_array(basePtr, paletteSize);
    if (skipPtr != 0) _exports.ghostty_wasm_free_u8_array(skipPtr, skipSize);
    _exports.ghostty_wasm_free_u8_array(bgPtr, _layout.colorRgbSize);
    _exports.ghostty_wasm_free_u8_array(fgPtr, _layout.colorRgbSize);
    _exports.ghostty_wasm_free_u8_array(out, paletteSize);
    return result;
  }

  @override
  CResult<RgbColor> colorParse(String value) {
    final (:ptr, :len, :allocLen) = _allocUtf8Bytes(value);
    final out = _exports.ghostty_wasm_alloc_u8_array(_layout.colorRgbSize);
    final result = _exports.ghostty_color_parse(ptr, len, out);
    final color = _readRgb(out);
    _exports.ghostty_wasm_free_u8_array(ptr, allocLen);
    _exports.ghostty_wasm_free_u8_array(out, _layout.colorRgbSize);
    return (.fromValue(result), color);
  }

  @override
  CResult<({int index, RgbColor color})> colorParsePaletteEntry(String value) {
    final (:ptr, :len, :allocLen) = _allocUtf8Bytes(value);
    final outIndex = _exports.ghostty_wasm_alloc_u8();
    final outRgb = _exports.ghostty_wasm_alloc_u8_array(_layout.colorRgbSize);
    final result = _exports.ghostty_color_parse_palette_entry(
      ptr,
      len,
      outIndex,
      outRgb,
    );
    final parsed = (index: _mem.readU8(outIndex), color: _readRgb(outRgb));
    _exports.ghostty_wasm_free_u8_array(ptr, allocLen);
    _exports.ghostty_wasm_free_u8(outIndex);
    _exports.ghostty_wasm_free_u8_array(outRgb, _layout.colorRgbSize);
    return (.fromValue(result), parsed);
  }

  @override
  CResult<RgbColor> colorParseX11(String name) {
    final (:ptr, :len, :allocLen) = _allocUtf8Bytes(name);
    final out = _exports.ghostty_wasm_alloc_u8_array(_layout.colorRgbSize);
    final result = _exports.ghostty_color_parse_x11(ptr, len, out);
    final color = _readRgb(out);
    _exports.ghostty_wasm_free_u8_array(ptr, allocLen);
    _exports.ghostty_wasm_free_u8_array(out, _layout.colorRgbSize);
    return (.fromValue(result), color);
  }

  @override
  List<X11ColorName> colorX11Names() {
    final names = _exports.ghostty_color_x11_names();
    final count = _exports.ghostty_color_x11_name_count();
    return <X11ColorName>[
      for (var i = 0; i < count; i++)
        (
          name: _mem.readCString(
            _mem.readPtr(
              names + i * _layout.colorX11EntrySize + _layout.colorX11EntryName,
            ),
          ),
          color: _readRgb(
            names + i * _layout.colorX11EntrySize + _layout.colorX11EntryColor,
          ),
        ),
    ];
  }

  @override
  CResult<String> colorSchemeReportEncode(ColorScheme scheme) {
    final outWritten = _exports.ghostty_wasm_alloc_usize();
    var result = Result.fromValue(
      _exports.ghostty_color_scheme_report_encode(
        scheme.value,
        0,
        0,
        outWritten,
      ),
    );
    if (result != .outOfSpace) {
      _exports.ghostty_wasm_free_usize(outWritten);
      return (result, '');
    }

    final bufLen = _mem.readU32(outWritten);
    final buf = _exports.ghostty_wasm_alloc_u8_array(bufLen);
    result = Result.fromValue(
      _exports.ghostty_color_scheme_report_encode(
        scheme.value,
        buf,
        bufLen,
        outWritten,
      ),
    );
    final written = _mem.readU32(outWritten);
    final text = utf8.decode(_mem.view.buffer.asUint8List(buf, written));
    _exports.ghostty_wasm_free_u8_array(buf, bufLen);
    _exports.ghostty_wasm_free_usize(outWritten);
    return (result, text);
  }

  @override
  int unicodeCodepointWidth(int codepoint) {
    return _exports.ghostty_unicode_codepoint_width(codepoint);
  }

  @override
  ({int consumed, int width}) unicodeGraphemeWidth(List<int> codepoints) {
    final len = codepoints.length;
    final ptr = len == 0 ? 0 : _exports.ghostty_wasm_alloc_u8_array(len * 4);
    for (var i = 0; i < len; i++) {
      _mem.writeU32(ptr + i * 4, codepoints[i]);
    }
    final outWidth = _exports.ghostty_wasm_alloc_u8();
    final consumed = _exports.ghostty_unicode_grapheme_width(
      ptr,
      len,
      outWidth,
    );
    final width = _mem.readU8(outWidth);
    if (ptr != 0) _exports.ghostty_wasm_free_u8_array(ptr, len * 4);
    _exports.ghostty_wasm_free_u8(outWidth);
    return (consumed: consumed, width: width);
  }

  @override
  CResult<int> terminalNew(int cols, int rows) {
    final outPtr = _exports.ghostty_wasm_alloc_opaque();
    final result = _exports.ghostty_terminal_new(0, outPtr, cols, rows);
    final handle = _mem.readPtr(outPtr);
    _exports.ghostty_wasm_free_opaque(outPtr);
    return (.fromValue(result), handle);
  }

  @override
  void terminalFree(int handle) => _exports.ghostty_terminal_free(handle);

  @override
  void terminalVtWrite(int handle, Uint8List data) {
    if (data.isEmpty) return;
    final ptr = _exports.ghostty_wasm_alloc_u8_array(data.length);
    _mem.writeBytes(ptr, data);
    if (_callbacks.isEmpty) {
      _exports.ghostty_terminal_vt_write(handle, ptr, data.length);
      _exports.ghostty_wasm_free_u8_array(ptr, data.length);
      return;
    }
    if (_callbackError != null) {
      _runNestedCallbackOperation<void>(() {
        _exports.ghostty_terminal_vt_write(handle, ptr, data.length);
        _exports.ghostty_wasm_free_u8_array(ptr, data.length);
      });
      return;
    }
    _exports.ghostty_terminal_vt_write(handle, ptr, data.length);
    _exports.ghostty_wasm_free_u8_array(ptr, data.length);
    final failure = _callbackError;
    if (failure != null) {
      _callbackError = null;
      Error.throwWithStackTrace(failure.error, failure.stackTrace);
    }
  }

  @override
  Result terminalResize(
    int handle,
    int cols,
    int rows,
    int cellWidthPx,
    int cellHeightPx,
  ) {
    if (_callbacks.isEmpty) {
      return .fromValue(
        _exports.ghostty_terminal_resize(
          handle,
          cols,
          rows,
          cellWidthPx,
          cellHeightPx,
        ),
      );
    }
    if (_callbackError != null) {
      return _runNestedCallbackOperation(
        () => Result.fromValue(
          _exports.ghostty_terminal_resize(
            handle,
            cols,
            rows,
            cellWidthPx,
            cellHeightPx,
          ),
        ),
      );
    }
    final result = Result.fromValue(
      _exports.ghostty_terminal_resize(
        handle,
        cols,
        rows,
        cellWidthPx,
        cellHeightPx,
      ),
    );
    final failure = _callbackError;
    if (failure != null) {
      _callbackError = null;
      Error.throwWithStackTrace(failure.error, failure.stackTrace);
    }
    return result;
  }

  @override
  void terminalReset(int handle) => _exports.ghostty_terminal_reset(handle);

  @override
  void terminalScrollViewport(
    int handle,
    TerminalScrollViewportTag tag,
    int value,
  ) {
    final svPtr = _exports.ghostty_wasm_alloc_u8_array(
      _layout.scrollViewportSize,
    );
    _mem.writeU32(svPtr, tag.value);
    switch (tag) {
      case .row:
        _mem.writeU32(svPtr + _layout.scrollViewportDelta, value);
      case .delta:
        _mem.writeI32(svPtr + _layout.scrollViewportDelta, value);
      case .top || .bottom:
        _mem.writeI32(svPtr + _layout.scrollViewportDelta, 0);
    }
    _exports.ghostty_terminal_scroll_viewport(handle, svPtr);
    _exports.ghostty_wasm_free_u8_array(svPtr, _layout.scrollViewportSize);
  }

  @override
  CResult<int> terminalCompressionActivity(int handle) {
    final outPtr = _allocateBytes(8, alignment: 8);
    _mem.writeU64(outPtr, 0);
    final result = _exports.ghostty_terminal_compression_activity(
      handle,
      outPtr,
    );
    final activity = _mem.readU64(outPtr);
    _exports.ghostty_wasm_free_u8_array(outPtr, 8);
    return (.fromValue(result), activity);
  }

  @override
  CResult<TerminalCompressionResult> terminalCompress(
    int handle,
    TerminalCompressionMode mode,
  ) {
    final outPtr = _allocateBytes(_wasmEnumSize, alignment: _wasmEnumSize);
    _mem.writeU32(outPtr, TerminalCompressionResult.unsupported.value);
    final result = _exports.ghostty_terminal_compress(
      handle,
      mode.value,
      outPtr,
    );
    final compression = TerminalCompressionResult.fromValue(
      _mem.readU32(outPtr),
    );
    _exports.ghostty_wasm_free_u8_array(outPtr, _wasmEnumSize);
    return (.fromValue(result), compression);
  }

  @override
  CResult<int> terminalGetCols(int handle) => _terminalGetU16(handle, .cols);

  @override
  CResult<int> terminalGetRows(int handle) => _terminalGetU16(handle, .rows);

  @override
  CResult<int> terminalGetCursorX(int handle) {
    return _terminalGetU16(handle, .cursorX);
  }

  @override
  CResult<int> terminalGetCursorY(int handle) {
    return _terminalGetU16(handle, .cursorY);
  }

  @override
  CResult<bool> terminalGetCursorVisible(int handle) {
    return _terminalGetBool(handle, .cursorVisible);
  }

  @override
  CResult<bool> terminalGetCursorPendingWrap(int handle) {
    return _terminalGetBool(handle, .cursorPendingWrap);
  }

  @override
  CResult<TerminalScreen> terminalGetActiveScreen(int handle) {
    final raw = _terminalGetI32(handle, .activeScreen);
    return (raw.$1, TerminalScreen.fromValue(raw.$2));
  }

  @override
  CResult<int> terminalGetKittyKeyboardFlags(int handle) {
    final outPtr = _exports.ghostty_wasm_alloc_u8();
    final result = _exports.ghostty_terminal_get(
      handle,
      TerminalData.kittyKeyboardFlags.value,
      outPtr,
    );
    final value = _mem.readU8(outPtr);
    _exports.ghostty_wasm_free_u8(outPtr);
    return (.fromValue(result), value);
  }

  @override
  CResult<Scrollbar> terminalGetScrollbar(int handle) {
    final sbPtr = _exports.ghostty_wasm_alloc_u8_array(_layout.scrollbarSize);
    final result = _exports.ghostty_terminal_get(
      handle,
      TerminalData.scrollbar.value,
      sbPtr,
    );
    final total = _mem.readU32(sbPtr);
    final offset = _mem.readU32(sbPtr + _layout.scrollbarOffset);
    final visible = _mem.readU32(sbPtr + _layout.scrollbarVisible);
    _exports.ghostty_wasm_free_u8_array(sbPtr, _layout.scrollbarSize);
    return (
      .fromValue(result),
      Scrollbar(total: total, offset: offset, visible: visible),
    );
  }

  @override
  CResult<bool> terminalModeGet(int handle, int mode) {
    final modePtr = _exports.ghostty_wasm_alloc_u8_array(
      _layout.terminalModeConfigSize,
    );
    _mem.writeU16(modePtr + _layout.terminalModeConfigMode, mode);
    final result = _exports.ghostty_terminal_get(
      handle,
      TerminalData.mode.value,
      modePtr,
    );
    final value = _mem.readU8(modePtr + _layout.terminalModeConfigValue) != 0;
    _exports.ghostty_wasm_free_u8_array(
      modePtr,
      _layout.terminalModeConfigSize,
    );
    return (.fromValue(result), value);
  }

  @override
  Result terminalModeSet(int handle, int mode, {required bool value}) {
    final modePtr = _exports.ghostty_wasm_alloc_u8_array(
      _layout.terminalModeConfigSize,
    );
    _mem.writeU16(modePtr + _layout.terminalModeConfigMode, mode);
    _mem.writeU8(modePtr + _layout.terminalModeConfigValue, value ? 1 : 0);
    final result = _exports.ghostty_terminal_set(
      handle,
      TerminalOption.mode.value,
      modePtr,
    );
    _exports.ghostty_wasm_free_u8_array(
      modePtr,
      _layout.terminalModeConfigSize,
    );
    return .fromValue(result);
  }

  @override
  Result terminalModeSetDefault(int handle, int mode, {required bool value}) {
    final modePtr = _exports.ghostty_wasm_alloc_u8_array(
      _layout.terminalModeConfigSize,
    );
    _mem.writeU16(modePtr + _layout.terminalModeConfigMode, mode);
    _mem.writeU8(modePtr + _layout.terminalModeConfigValue, value ? 1 : 0);
    final result = _exports.ghostty_terminal_set(
      handle,
      TerminalOption.modeDefault.value,
      modePtr,
    );
    _exports.ghostty_wasm_free_u8_array(
      modePtr,
      _layout.terminalModeConfigSize,
    );
    return .fromValue(result);
  }

  @override
  Result terminalSetTitleReport(int handle, {required bool enabled}) {
    return _terminalSetBool(handle, TerminalOption.titleReport, enabled);
  }

  @override
  CResult<String> terminalGetTitle(int handle) {
    return _terminalGetString(handle, .title);
  }

  @override
  CResult<String> terminalGetPwd(int handle) {
    return _terminalGetString(handle, .pwd);
  }

  @override
  CResult<int> terminalGetTotalRows(int handle) {
    return _terminalGetU32(handle, .totalRows);
  }

  @override
  CResult<int> terminalGetScrollbackRows(int handle) {
    return _terminalGetU32(handle, .scrollbackRows);
  }

  @override
  CResult<int> terminalGetWidthPx(int handle) {
    return _terminalGetU32(handle, .widthPx);
  }

  @override
  CResult<int> terminalGetHeightPx(int handle) {
    return _terminalGetU32(handle, .heightPx);
  }

  @override
  CResult<TerminalGeometry> terminalGetGeometry(int handle) {
    const keys = <TerminalData>[.cols, .rows, .widthPx, .heightPx];
    final result = _terminalGetMulti(handle, keys);
    if (result != .success) return (result, _emptyTerminalGeometry);
    return (
      result,
      (
        cols: _mem.readU16(_multiOut),
        rows: _mem.readU16(_multiOut + _wasmOutputSlotSize),
        widthPx: _mem.readU32(_multiOut + 2 * _wasmOutputSlotSize),
        heightPx: _mem.readU32(_multiOut + 3 * _wasmOutputSlotSize),
      ),
    );
  }

  @override
  CResult<bool> terminalGetViewportActive(int handle) {
    return _terminalGetBool(handle, .viewportActive);
  }

  @override
  CResult<bool> terminalGetVtProcessingError(int handle) {
    return _terminalGetBool(handle, .vtProcessingError);
  }

  @override
  CResult<Uint8List> terminalContinuationGet(int handle) {
    final outWritten = _allocateSize();
    try {
      var result = Result.fromValue(
        _exports.ghostty_terminal_continuation_buf(handle, 0, 0, outWritten),
      );
      if (result != .outOfSpace) return (result, Uint8List(0));

      final capacity = _mem.readU32(outWritten);
      if (capacity == 0) return (Result.success, Uint8List(0));
      final buffer = _allocateBytes(capacity);
      try {
        result = Result.fromValue(
          _exports.ghostty_terminal_continuation_buf(
            handle,
            buffer,
            capacity,
            outWritten,
          ),
        );
        final written = _mem.readU32(outWritten);
        final continuation = result == .success
            ? Uint8List.fromList(_mem.readBytes(buffer, written))
            : Uint8List(0);
        return (result, continuation);
      } finally {
        _exports.ghostty_wasm_free_u8_array(buffer, capacity);
      }
    } finally {
      _exports.ghostty_wasm_free_usize(outWritten);
    }
  }

  @override
  CResult<int> terminalGetContinuationMaxBytes(int handle) {
    return _terminalGetU32(handle, .continuationMaxBytes);
  }

  @override
  Result terminalSetContinuationMaxBytes(int handle, int? bytes) {
    return _terminalSetSize(handle, .continuationMaxBytes, bytes);
  }

  @override
  Result terminalSetTitle(int handle, String? title) {
    return _terminalSetString(handle, TerminalOption.title, title);
  }

  @override
  Result terminalSetPwd(int handle, String? pwd) {
    return _terminalSetString(handle, TerminalOption.pwd, pwd);
  }

  @override
  Result terminalSetDefaultCursorShape(int handle, CursorShape? shape) {
    return _terminalSetI32(handle, .defaultCursorStyle, shape?.value);
  }

  @override
  Result terminalSetDefaultCursorBlink(int handle, {bool? blinking}) {
    return _terminalSetBool(handle, .defaultCursorBlink, blinking);
  }

  @override
  Result terminalSetGlyphProtocol(int handle, {required bool enabled}) {
    return _terminalSetBool(handle, .glyphProtocol, enabled);
  }

  @override
  Result terminalSetColorForeground(int handle, RgbColor? color) {
    return _terminalSetColor(handle, TerminalOption.colorForeground, color);
  }

  @override
  Result terminalSetColorBackground(int handle, RgbColor? color) {
    return _terminalSetColor(handle, TerminalOption.colorBackground, color);
  }

  @override
  Result terminalSetColorCursor(int handle, RgbColor? color) {
    return _terminalSetColor(handle, TerminalOption.colorCursor, color);
  }

  @override
  Result terminalSetColorPalette(int handle, List<RgbColor>? palette) {
    if (palette == null) {
      return Result.fromValue(
        _exports.ghostty_terminal_set(
          handle,
          TerminalOption.colorPalette.value,
          0,
        ),
      );
    }

    final paletteSize = 256 * _layout.colorRgbSize;
    final ptr = _exports.ghostty_wasm_alloc_u8_array(paletteSize);
    for (var i = 0; i < 256; i++) {
      final offset = i * _layout.colorRgbSize;
      _mem.writeU8(ptr + offset, palette[i].r);
      _mem.writeU8(ptr + offset + _layout.colorRgbG, palette[i].g);
      _mem.writeU8(ptr + offset + _layout.colorRgbB, palette[i].b);
    }
    final result = _exports.ghostty_terminal_set(
      handle,
      TerminalOption.colorPalette.value,
      ptr,
    );
    _exports.ghostty_wasm_free_u8_array(ptr, paletteSize);
    return Result.fromValue(result);
  }

  @override
  CResult<RgbColor> terminalGetColorForeground(int handle) {
    return _terminalGetColor(handle, .colorForeground);
  }

  @override
  CResult<RgbColor> terminalGetColorBackground(int handle) {
    return _terminalGetColor(handle, .colorBackground);
  }

  @override
  CResult<RgbColor> terminalGetColorCursor(int handle) {
    return _terminalGetColor(handle, .colorCursor);
  }

  @override
  CResult<List<RgbColor>> terminalGetColorPalette(int handle) {
    return _terminalGetPalette(handle, .colorPalette);
  }

  @override
  CResult<RgbColor> terminalGetColorForegroundDefault(int handle) {
    return _terminalGetColor(handle, .colorForegroundDefault);
  }

  @override
  CResult<RgbColor> terminalGetColorBackgroundDefault(int handle) {
    return _terminalGetColor(handle, .colorBackgroundDefault);
  }

  @override
  CResult<RgbColor> terminalGetColorCursorDefault(int handle) {
    return _terminalGetColor(handle, .colorCursorDefault);
  }

  @override
  CResult<List<RgbColor>> terminalGetColorPaletteDefault(int handle) {
    return _terminalGetPalette(handle, .colorPaletteDefault);
  }

  @override
  CResult<Style> terminalGetCursorStyle(int handle) {
    return _terminalGetStyle(handle, .cursorStyle);
  }

  @override
  CResult<bool> terminalGetMouseTracking(int handle) {
    return _terminalGetBool(handle, .mouseTracking);
  }

  @override
  CResult<int> terminalGetKittyImageStorageLimit(int handle) {
    return _terminalGetU64(handle, .kittyImageStorageLimit);
  }

  @override
  CResult<int> terminalGetScrollbackMaxBytes(int handle) {
    return _terminalGetU64(handle, .scrollbackMaxBytes);
  }

  @override
  CResult<int> terminalGetScrollbackMaxLines(int handle) {
    return _terminalGetU64(handle, .scrollbackMaxLines);
  }

  @override
  CResult<bool> terminalGetKittyImageMediumFile(int handle) {
    return _terminalGetBool(handle, .kittyImageMediumFile);
  }

  @override
  CResult<String> terminalGetKittyImageMediumTempFile(int handle) {
    return _terminalGetString(handle, .kittyImageMediumTempFile);
  }

  @override
  CResult<bool> terminalGetKittyImageMediumSharedMem(int handle) {
    return _terminalGetBool(handle, .kittyImageMediumSharedMem);
  }

  @override
  Result terminalSetKittyImageStorageLimit(int handle, int? limit) {
    return _terminalSetU64(handle, .kittyImageStorageLimit, limit);
  }

  @override
  Result terminalSetKittyImageMediumFile(int handle, {bool? enabled}) {
    return _terminalSetBool(handle, .kittyImageMediumFile, enabled);
  }

  @override
  Result terminalSetKittyImageMediumTempFile(int handle, String? directory) {
    return _terminalSetString(handle, .kittyImageMediumTempFile, directory);
  }

  @override
  Result terminalSetKittyImageMediumSharedMem(int handle, {bool? enabled}) {
    return _terminalSetBool(handle, .kittyImageMediumSharedMem, enabled);
  }

  @override
  Result terminalSetApcBufferLimit(int handle, int? bytes) {
    return _terminalSetSize(handle, .apcMaxBytes, bytes);
  }

  @override
  Result terminalSetKittyApcBufferLimit(int handle, int? bytes) {
    return _terminalSetSize(handle, .apcMaxBytesKitty, bytes);
  }

  @override
  Result terminalSetScrollbackMaxBytes(int handle, int? bytes) {
    return _terminalSetSize(handle, .scrollbackMaxBytes, bytes);
  }

  @override
  Result terminalSetScrollbackMaxLines(int handle, int? lines) {
    return _terminalSetSize(handle, .scrollbackMaxLines, lines);
  }

  @override
  CResult<Uint8List> pasteEncode(String data, {required bool bracketed}) {
    final encoded = utf8.encode(data);
    final dataPtr = _exports.ghostty_wasm_alloc_u8_array(encoded.length);
    _mem.writeBytes(dataPtr, encoded);
    final outWrittenPtr = _exports.ghostty_wasm_alloc_usize();

    // First call to get the required buffer size.
    var result = Result.fromValue(
      _exports.ghostty_paste_encode(
        dataPtr,
        encoded.length,
        bracketed ? 1 : 0,
        0,
        0,
        outWrittenPtr,
      ),
    );

    if (result != .outOfSpace) {
      _exports.ghostty_wasm_free_usize(outWrittenPtr);
      _exports.ghostty_wasm_free_u8_array(dataPtr, encoded.length);
      return (result, Uint8List(0));
    }

    final bufLen = _mem.readU32(outWrittenPtr);
    final bufPtr = _exports.ghostty_wasm_alloc_u8_array(bufLen);

    // Re-encode the data since the first call modified it in place.
    _mem.writeBytes(dataPtr, encoded);

    result = .fromValue(
      _exports.ghostty_paste_encode(
        dataPtr,
        encoded.length,
        bracketed ? 1 : 0,
        bufPtr,
        bufLen,
        outWrittenPtr,
      ),
    );

    final written = _mem.readU32(outWrittenPtr);
    final bytes = Uint8List.fromList(_mem.readBytes(bufPtr, written));
    _exports.ghostty_wasm_free_u8_array(bufPtr, bufLen);
    _exports.ghostty_wasm_free_usize(outWrittenPtr);
    _exports.ghostty_wasm_free_u8_array(dataPtr, encoded.length);
    return (result, bytes);
  }

  @override
  void terminalSetOnWritePty(int handle, ValueSetter<Uint8List>? callback) {
    final map = _callbacks.putIfAbsent(handle, () => {});
    const option = TerminalOption.writePty;

    if (callback == null) {
      final existing = map.remove(option);
      if (existing != null) _table.set(existing.$1);
      _exports.ghostty_terminal_set(handle, option.value, 0);
      return;
    }

    final reuseIndex = map[option]?.$1;
    final index = _registerCallback(
      ((int terminal, int userdata, int dataPtr, int len) {
        try {
          callback(Uint8List.fromList(_mem.readBytes(dataPtr, len)));
        } on Object catch (error, stackTrace) {
          _captureCallbackError(error, stackTrace);
        }
      }).toJS,
      ['i32', 'i32', 'i32', 'i32'],
      reuseIndex: reuseIndex,
    );
    map[option] = (index, callback);
    _exports.ghostty_terminal_set(handle, option.value, index);
  }

  @override
  void terminalSetOnBell(int handle, VoidCallback? callback) {
    final map = _callbacks.putIfAbsent(handle, () => {});
    const option = TerminalOption.bell;

    if (callback == null) {
      final existing = map.remove(option);
      if (existing != null) _table.set(existing.$1);
      _exports.ghostty_terminal_set(handle, option.value, 0);
      return;
    }

    final reuseIndex = map[option]?.$1;
    final index = _registerCallback(
      ((int terminal, int userdata) {
        try {
          callback();
        } on Object catch (error, stackTrace) {
          _captureCallbackError(error, stackTrace);
        }
      }).toJS,
      ['i32', 'i32'],
      reuseIndex: reuseIndex,
    );
    map[option] = (index, callback);
    _exports.ghostty_terminal_set(handle, option.value, index);
  }

  @override
  void terminalSetOnClipboardWrite(
    int handle,
    ClipboardWriteCallback? callback,
  ) {
    final map = _callbacks.putIfAbsent(handle, () => {});
    const option = TerminalOption.clipboardWrite;

    if (callback == null) {
      final existing = map.remove(option);
      if (existing != null) _table.set(existing.$1);
      _exports.ghostty_terminal_set(handle, option.value, 0);
      return;
    }

    final reuseIndex = map[option]?.$1;
    final index = _registerCallback(
      ((int terminal, int userdata, int writePtr) {
        try {
          final contentsPtr = _mem.readPtr(
            writePtr + _layout.clipboardWriteContents,
          );
          final contentsLen = _mem.readU32(
            writePtr + _layout.clipboardWriteContentsLen,
          );
          final contents = <ClipboardContent>[
            for (var i = 0; i < contentsLen; i++)
              _readClipboardContent(
                contentsPtr + i * _layout.clipboardContentSize,
              ),
          ];
          return callback((
            location: .fromValue(
              _mem.readU32(writePtr + _layout.clipboardWriteLocation),
            ),
            contents: List.unmodifiable(contents),
          )).value;
        } on Object catch (error, stackTrace) {
          _captureCallbackError(error, stackTrace);
          return ClipboardWriteResult.ioError.value;
        }
      }).toJS,
      ['i32', 'i32', 'i32'],
      results: ['i32'],
      reuseIndex: reuseIndex,
    );
    map[option] = (index, callback);
    _exports.ghostty_terminal_set(handle, option.value, index);
  }

  @override
  void terminalSetOnDesktopNotification(
    int handle,
    DesktopNotificationCallback? callback,
  ) {
    final map = _callbacks.putIfAbsent(handle, () => {});
    const option = TerminalOption.desktopNotification;
    if (callback == null) {
      final existing = map.remove(option);
      if (existing != null) _table.set(existing.$1);
      _exports.ghostty_terminal_set(handle, option.value, 0);
      return;
    }
    final reuseIndex = map[option]?.$1;
    final index = _registerCallback(
      ((int terminal, int userdata, int notificationPtr) {
        try {
          if (_mem.readU32(notificationPtr) < _layout.desktopNotificationSize) {
            return;
          }
          callback((
            title: _readString(
              notificationPtr + _layout.desktopNotificationTitle,
            ),
            body: _readString(
              notificationPtr + _layout.desktopNotificationBody,
            ),
          ));
        } on Object catch (error, stackTrace) {
          _captureCallbackError(error, stackTrace);
        }
      }).toJS,
      ['i32', 'i32', 'i32'],
      reuseIndex: reuseIndex,
    );
    map[option] = (index, callback);
    _exports.ghostty_terminal_set(handle, option.value, index);
  }

  @override
  void terminalSetOnProgressReport(
    int handle,
    TerminalProgressCallback? callback,
  ) {
    final map = _callbacks.putIfAbsent(handle, () => {});
    const option = TerminalOption.progressReport;
    if (callback == null) {
      final existing = map.remove(option);
      if (existing != null) _table.set(existing.$1);
      _exports.ghostty_terminal_set(handle, option.value, 0);
      return;
    }
    final reuseIndex = map[option]?.$1;
    final index = _registerCallback(
      ((int terminal, int userdata, int reportPtr) {
        try {
          if (_mem.readU32(reportPtr) < _layout.terminalProgressReportSize) {
            return;
          }
          final rawProgress = _mem.readU8(
            reportPtr + _layout.terminalProgressReportProgress,
          );
          callback((
            state: TerminalProgressState.fromValue(
              _mem.readU32(reportPtr + _layout.terminalProgressReportState),
            ),
            progress: rawProgress == 0xff ? null : rawProgress,
          ));
        } on Object catch (error, stackTrace) {
          _captureCallbackError(error, stackTrace);
        }
      }).toJS,
      ['i32', 'i32', 'i32'],
      reuseIndex: reuseIndex,
    );
    map[option] = (index, callback);
    _exports.ghostty_terminal_set(handle, option.value, index);
  }

  @override
  void terminalSetOnTitleChanged(int handle, VoidCallback? callback) {
    final map = _callbacks.putIfAbsent(handle, () => {});
    const option = TerminalOption.titleChanged;

    if (callback == null) {
      final existing = map.remove(option);
      if (existing != null) _table.set(existing.$1);
      _exports.ghostty_terminal_set(handle, option.value, 0);
      return;
    }

    final reuseIndex = map[option]?.$1;
    final index = _registerCallback(
      ((int terminal, int userdata) {
        try {
          callback();
        } on Object catch (error, stackTrace) {
          _captureCallbackError(error, stackTrace);
        }
      }).toJS,
      ['i32', 'i32'],
      reuseIndex: reuseIndex,
    );
    map[option] = (index, callback);
    _exports.ghostty_terminal_set(handle, option.value, index);
  }

  @override
  void terminalSetOnPwdChanged(int handle, VoidCallback? callback) {
    final map = _callbacks.putIfAbsent(handle, () => {});
    const option = TerminalOption.pwdChanged;

    if (callback == null) {
      final existing = map.remove(option);
      if (existing != null) _table.set(existing.$1);
      _exports.ghostty_terminal_set(handle, option.value, 0);
      return;
    }

    final reuseIndex = map[option]?.$1;
    final index = _registerCallback(
      ((int terminal, int userdata) {
        try {
          callback();
        } on Object catch (error, stackTrace) {
          _captureCallbackError(error, stackTrace);
        }
      }).toJS,
      ['i32', 'i32'],
      reuseIndex: reuseIndex,
    );
    map[option] = (index, callback);
    _exports.ghostty_terminal_set(handle, option.value, index);
  }

  @override
  void terminalSetOnEnquiry(int handle, ValueGetter<Uint8List>? callback) {
    final map = _callbacks.putIfAbsent(handle, () => {});
    const option = TerminalOption.enquiry;

    if (callback == null) {
      final existing = map.remove(option);
      if (existing != null) _table.set(existing.$1);
      _freeStringBuf(handle, option);
      _exports.ghostty_terminal_set(handle, option.value, 0);
      return;
    }

    final bufMap = _stringBufs.putIfAbsent(handle, () => {});
    final reuseIndex = map[option]?.$1;
    final index = _registerCallback(
      ((int sretPtr, int terminal, int userdata) {
        try {
          final data = callback();
          final prev = bufMap[option];
          if (prev != null) {
            _exports.ghostty_wasm_free_u8_array(prev.$1, prev.$2);
          }
          final ptr = _exports.ghostty_wasm_alloc_u8_array(data.length);
          _mem.writeBytes(ptr, data);
          bufMap[option] = (ptr, data.length);
          _mem.writeU32(sretPtr, ptr);
          _mem.writeU32(sretPtr + _layout.stringLen, data.length);
        } on Object catch (error, stackTrace) {
          _captureCallbackError(error, stackTrace);
          _mem.writeU32(sretPtr, 0);
          _mem.writeU32(sretPtr + _layout.stringLen, 0);
        }
      }).toJS,
      ['i32', 'i32', 'i32'],
      reuseIndex: reuseIndex,
    );
    map[option] = (index, callback);
    _exports.ghostty_terminal_set(handle, option.value, index);
  }

  @override
  void terminalSetOnXtversion(int handle, ValueGetter<String>? callback) {
    final map = _callbacks.putIfAbsent(handle, () => {});
    const option = TerminalOption.xtversion;

    if (callback == null) {
      final existing = map.remove(option);
      if (existing != null) _table.set(existing.$1);
      _freeStringBuf(handle, option);
      _exports.ghostty_terminal_set(handle, option.value, 0);
      return;
    }

    final bufMap = _stringBufs.putIfAbsent(handle, () => {});
    final reuseIndex = map[option]?.$1;
    final index = _registerCallback(
      ((int sretPtr, int terminal, int userdata) {
        try {
          final result = callback();
          final bytes = utf8.encode(result);
          final prev = bufMap[option];
          if (prev != null) {
            _exports.ghostty_wasm_free_u8_array(prev.$1, prev.$2);
          }
          final ptr = _exports.ghostty_wasm_alloc_u8_array(bytes.length);
          _mem.writeBytes(ptr, bytes);
          bufMap[option] = (ptr, bytes.length);
          _mem.writeU32(sretPtr, ptr);
          _mem.writeU32(sretPtr + _layout.stringLen, bytes.length);
        } on Object catch (error, stackTrace) {
          _captureCallbackError(error, stackTrace);
          _mem.writeU32(sretPtr, 0);
          _mem.writeU32(sretPtr + _layout.stringLen, 0);
        }
      }).toJS,
      ['i32', 'i32', 'i32'],
      reuseIndex: reuseIndex,
    );
    map[option] = (index, callback);
    _exports.ghostty_terminal_set(handle, option.value, index);
  }

  @override
  void terminalSetOnColorScheme(
    int handle,
    ValueGetter<ColorScheme?>? callback,
  ) {
    final map = _callbacks.putIfAbsent(handle, () => {});
    const option = TerminalOption.colorScheme;

    if (callback == null) {
      final existing = map.remove(option);
      if (existing != null) _table.set(existing.$1);
      _exports.ghostty_terminal_set(handle, option.value, 0);
      return;
    }

    final reuseIndex = map[option]?.$1;
    final index = _registerCallback(
      ((int terminal, int userdata, int outPtr) {
        try {
          final result = callback();
          if (result == null) return 0;
          _mem.writeU32(outPtr, result.value);
          return 1;
        } on Object catch (error, stackTrace) {
          _captureCallbackError(error, stackTrace);
          return 0;
        }
      }).toJS,
      ['i32', 'i32', 'i32'],
      results: ['i32'],
      reuseIndex: reuseIndex,
    );
    map[option] = (index, callback);
    _exports.ghostty_terminal_set(handle, option.value, index);
  }

  @override
  void terminalSetOnSize(int handle, ValueGetter<TerminalSizeInfo?>? callback) {
    final map = _callbacks.putIfAbsent(handle, () => {});
    const option = TerminalOption.size;

    if (callback == null) {
      final existing = map.remove(option);
      if (existing != null) _table.set(existing.$1);
      _exports.ghostty_terminal_set(handle, option.value, 0);
      return;
    }

    final reuseIndex = map[option]?.$1;
    final index = _registerCallback(
      ((int terminal, int userdata, int outPtr) {
        try {
          final result = callback();
          if (result == null) return 0;
          _mem.writeU16(outPtr, result.rows);
          _mem.writeU16(outPtr + _layout.sizeReportColumns, result.columns);
          _mem.writeU32(outPtr + _layout.sizeReportCellWidth, result.cellWidth);
          _mem.writeU32(
            outPtr + _layout.sizeReportCellHeight,
            result.cellHeight,
          );
          return 1;
        } on Object catch (error, stackTrace) {
          _captureCallbackError(error, stackTrace);
          return 0;
        }
      }).toJS,
      ['i32', 'i32', 'i32'],
      results: ['i32'],
      reuseIndex: reuseIndex,
    );
    map[option] = (index, callback);
    _exports.ghostty_terminal_set(handle, option.value, index);
  }

  @override
  void terminalSetOnDeviceAttributes(
    int handle,
    ValueGetter<DeviceAttributesResponse?>? callback,
  ) {
    final map = _callbacks.putIfAbsent(handle, () => {});
    const option = TerminalOption.deviceAttributes;

    if (callback == null) {
      final existing = map.remove(option);
      if (existing != null) _table.set(existing.$1);
      _exports.ghostty_terminal_set(handle, option.value, 0);
      return;
    }

    final reuseIndex = map[option]?.$1;
    final index = _registerCallback(
      ((int terminal, int userdata, int outPtr) {
        try {
          final result = callback();
          if (result == null) return 0;
          _mem.writeU16(outPtr, result.primary.conformanceLevel);
          final featureCount = result.primary.features.length > 64
              ? 64
              : result.primary.features.length;
          for (var i = 0; i < featureCount; i++) {
            _mem.writeU16(
              outPtr + _layout.deviceAttrsFeatures + i * 2,
              result.primary.features[i],
            );
          }
          _mem.writeU32(outPtr + _layout.deviceAttrsNumFeatures, featureCount);
          _mem.writeU16(
            outPtr + _layout.deviceAttrsDeviceType,
            result.secondary.deviceType,
          );
          _mem.writeU16(
            outPtr + _layout.deviceAttrsFirmwareVersion,
            result.secondary.firmwareVersion,
          );
          _mem.writeU16(
            outPtr + _layout.deviceAttrsRomCartridge,
            result.secondary.romCartridge,
          );
          _mem.writeU32(
            outPtr + _layout.deviceAttrsUnitId,
            result.tertiary.unitId,
          );
          return 1;
        } on Object catch (error, stackTrace) {
          _captureCallbackError(error, stackTrace);
          return 0;
        }
      }).toJS,
      ['i32', 'i32', 'i32'],
      results: ['i32'],
      reuseIndex: reuseIndex,
    );
    map[option] = (index, callback);
    _exports.ghostty_terminal_set(handle, option.value, index);
  }

  int? _sysLogIndex;

  @override
  void sysSetLogCallback(SysLogCallback callback) {
    _installSysLog((userdata, level, scopePtr, scopeLen, msgPtr, msgLen) {
      try {
        callback(
          SysLogLevel.fromValue(level),
          utf8.decode(_mem.readBytes(scopePtr, scopeLen), allowMalformed: true),
          utf8.decode(_mem.readBytes(msgPtr, msgLen), allowMalformed: true),
        );
      } on Object catch (_) {}
    });
  }

  @override
  void sysSetLogToStderr() {
    // ignore: unnecessary_lambdas
    _installSysLog((userdata, level, scopePtr, scopeLen, msgPtr, msgLen) {
      _exports.ghostty_sys_log_stderr(
        userdata,
        level,
        scopePtr,
        scopeLen,
        msgPtr,
        msgLen,
      );
    });
  }

  @override
  void sysClearLogCallback() {
    _exports.ghostty_sys_set(SysOption.log.value, 0);
    if (_sysLogIndex case final index?) _table.set(index);
    // _sysLogIndex is retained so a later sysSetLogCallback reuses the
    // same table slot instead of growing the indirect function table.
  }

  int? _sysDecodePngIndex;

  @override
  void sysSetPngDecoder(PngDecoder decoder) {
    int trampoline(
      int userdata,
      int allocator,
      int pngPtr,
      int pngLen,
      int outPtr,
    ) {
      try {
        final bytes = Uint8List.fromList(_mem.readBytes(pngPtr, pngLen));
        final decoded = decoder(bytes);
        if (decoded == null) return 0;
        final rgba = decoded.rgba;
        final buf = _exports.ghostty_alloc(allocator, rgba.length);
        if (buf == 0) return 0;
        _mem.writeBytes(buf, rgba);
        // SysImage { u32 width; u32 height; ptr data; size data_len }
        _mem.writeU32(outPtr, decoded.width);
        _mem.writeU32(outPtr + 4, decoded.height);
        _mem.writeU32(outPtr + 8, buf);
        _mem.writeU32(outPtr + 12, rgba.length);
        return 1;
      } on Object catch (_) {
        return 0;
      }
    }

    final index = _registerCallback(
      trampoline.toJS,
      ['i32', 'i32', 'i32', 'i32', 'i32'],
      results: ['i32'],
      reuseIndex: _sysDecodePngIndex,
    );
    _sysDecodePngIndex = index;
    _exports.ghostty_sys_set(SysOption.decodePng.value, index);
  }

  @override
  void sysClearPngDecoder() {
    _exports.ghostty_sys_set(SysOption.decodePng.value, 0);
    if (_sysDecodePngIndex case final index?) _table.set(index);
    // _sysDecodePngIndex is retained so a subsequent sysSetPngDecoder
    // reuses the same table slot via `reuseIndex` instead of growing
    // the WASM indirect function table. Matches the log callback path.
  }

  @override
  int kittyGraphicsGet(int handle) {
    final outPtr = _exports.ghostty_wasm_alloc_opaque();
    final code = _exports.ghostty_terminal_get(
      handle,
      TerminalData.kittyGraphics.value,
      outPtr,
    );
    final graphics = _mem.readPtr(outPtr);
    _exports.ghostty_wasm_free_opaque(outPtr);
    return code == Result.success.value ? graphics : 0;
  }

  @override
  int kittyGraphicsImage(int graphics, int imageId) {
    if (graphics == 0) return 0;
    return _exports.ghostty_kitty_graphics_image(graphics, imageId);
  }

  @override
  CResult<int> kittyGraphicsImageGetId(int image) =>
      _kittyImageGetU32(image, KittyGraphicsImageData.id);

  @override
  CResult<int> kittyGraphicsImageGetNumber(int image) =>
      _kittyImageGetU32(image, KittyGraphicsImageData.number);

  @override
  CResult<int> kittyGraphicsImageGetWidth(int image) =>
      _kittyImageGetU32(image, KittyGraphicsImageData.width);

  @override
  CResult<int> kittyGraphicsImageGetHeight(int image) =>
      _kittyImageGetU32(image, KittyGraphicsImageData.height);

  @override
  CResult<KittyImageFormat> kittyGraphicsImageGetFormat(int image) {
    final (code, value) = _kittyImageGetU32(
      image,
      KittyGraphicsImageData.format,
    );
    return (code, KittyImageFormat.fromValue(value));
  }

  @override
  CResult<KittyImageCompression> kittyGraphicsImageGetCompression(int image) {
    final (code, value) = _kittyImageGetU32(
      image,
      KittyGraphicsImageData.compression,
    );
    return (code, KittyImageCompression.fromValue(value));
  }

  @override
  CResult<int> kittyGraphicsImageGetGeneration(int image) {
    return _kittyImageGetU64(image, KittyGraphicsImageData.generation);
  }

  @override
  CResult<int> kittyGraphicsGetGeneration(int graphics) {
    if (graphics == 0) return (Result.invalidValue, 0);
    final outPtr = _exports.ghostty_wasm_alloc_u8_array(8);
    final code = _exports.ghostty_kitty_graphics_get(
      graphics,
      KittyGraphicsData.generation.value,
      outPtr,
    );
    final value = _mem.readU64(outPtr);
    _exports.ghostty_wasm_free_u8_array(outPtr, 8);
    return (Result.fromValue(code), value);
  }

  @override
  CResult<Uint8List> kittyGraphicsImageGetPixelData(int image) {
    if (image == 0) return (Result.invalidValue, Uint8List(0));
    const keys = _kittyImagePixelDataKeys;
    for (var i = 0; i < keys.length; i++) {
      _mem.writeU32(_multiKeys + i * 4, keys[i].value);
      _mem.writeU32(_multiValues + i * 4, _multiOut + i * 8);
    }
    final result = Result.fromValue(
      _exports.ghostty_kitty_graphics_image_get_multi(
        image,
        keys.length,
        _multiKeys,
        _multiValues,
        _multiWritten,
      ),
    );
    if (result != .success) return (result, Uint8List(0));
    final dataPtr = _mem.readPtr(_multiOut);
    final dataLen = _mem.readU32(_multiOut + 8);
    if (dataPtr == 0 || dataLen == 0) {
      return (Result.success, Uint8List(0));
    }
    return (
      Result.success,
      Uint8List.fromList(_mem.readBytes(dataPtr, dataLen)),
    );
  }

  CResult<int> _kittyImageGetU32(int image, KittyGraphicsImageData data) {
    if (image == 0) return (Result.invalidValue, 0);
    final outPtr = _exports.ghostty_wasm_alloc_usize();
    final code = _exports.ghostty_kitty_graphics_image_get(
      image,
      data.value,
      outPtr,
    );
    final value = _mem.readU32(outPtr);
    _exports.ghostty_wasm_free_usize(outPtr);
    return (Result.fromValue(code), value);
  }

  CResult<int> _kittyImageGetU64(int image, KittyGraphicsImageData data) {
    if (image == 0) return (Result.invalidValue, 0);
    final outPtr = _exports.ghostty_wasm_alloc_u8_array(8);
    final code = _exports.ghostty_kitty_graphics_image_get(
      image,
      data.value,
      outPtr,
    );
    final value = _mem.readU64(outPtr);
    _exports.ghostty_wasm_free_u8_array(outPtr, 8);
    return (Result.fromValue(code), value);
  }

  @override
  CResult<int> kittyGraphicsPlacementIteratorNew() {
    final out = _exports.ghostty_wasm_alloc_opaque();
    final code = _exports.ghostty_kitty_graphics_placement_iterator_new(0, out);
    final handle = _mem.readPtr(out);
    _exports.ghostty_wasm_free_opaque(out);
    return (Result.fromValue(code), handle);
  }

  @override
  void kittyGraphicsPlacementIteratorFree(int iterator) {
    if (iterator == 0) return;
    _exports.ghostty_kitty_graphics_placement_iterator_free(iterator);
  }

  @override
  Result kittyGraphicsGetPlacements(int graphics, int iterator) {
    if (graphics == 0 || iterator == 0) return Result.invalidValue;
    final out = _exports.ghostty_wasm_alloc_opaque();
    _mem.writeU32(out, iterator);
    final code = _exports.ghostty_kitty_graphics_get(
      graphics,
      KittyGraphicsData.placementIterator.value,
      out,
    );
    _exports.ghostty_wasm_free_opaque(out);
    return Result.fromValue(code);
  }

  @override
  Result kittyGraphicsPlacementIteratorSetLayer(
    int iterator,
    KittyPlacementLayer layer,
  ) {
    if (iterator == 0) return Result.invalidValue;
    final ptr = _exports.ghostty_wasm_alloc_usize();
    _mem.writeU32(ptr, layer.value);
    final code = _exports.ghostty_kitty_graphics_placement_iterator_set(
      iterator,
      KittyGraphicsPlacementIteratorOption.layer.value,
      ptr,
    );
    _exports.ghostty_wasm_free_usize(ptr);
    return Result.fromValue(code);
  }

  @override
  bool kittyGraphicsPlacementNext(int iterator) {
    if (iterator == 0) return false;
    return _exports.ghostty_kitty_graphics_placement_next(iterator) != 0;
  }

  @override
  CResult<RawPlacement> kittyGraphicsPlacementGet(int iterator) {
    if (iterator == 0) return (Result.invalidValue, _emptyPlacement);
    const keys = _kittyPlacementKeys;
    for (var i = 0; i < keys.length; i++) {
      _mem.writeU32(_multiKeys + i * 4, keys[i].value);
      _mem.writeU32(_multiValues + i * 4, _multiOut + i * 8);
    }
    final result = Result.fromValue(
      _exports.ghostty_kitty_graphics_placement_get_multi(
        iterator,
        keys.length,
        _multiKeys,
        _multiValues,
        _multiWritten,
      ),
    );
    if (result != .success) return (result, _emptyPlacement);
    final placement = (
      imageId: _mem.readU32(_multiOut),
      placementId: _mem.readU32(_multiOut + 8),
      isVirtual: _mem.readU8(_multiOut + 16) != 0,
      xOffset: _mem.readU32(_multiOut + 24),
      yOffset: _mem.readU32(_multiOut + 32),
      sourceX: _mem.readU32(_multiOut + 40),
      sourceY: _mem.readU32(_multiOut + 48),
      sourceWidth: _mem.readU32(_multiOut + 56),
      sourceHeight: _mem.readU32(_multiOut + 64),
      columns: _mem.readU32(_multiOut + 72),
      rows: _mem.readU32(_multiOut + 80),
      z: _mem.readI32(_multiOut + 88),
    );
    return (result, placement);
  }

  @override
  CResult<RawPlacementRenderInfo> kittyGraphicsPlacementRenderInfo(
    int iterator,
    int image,
    int terminal,
  ) {
    if (iterator == 0 || image == 0 || terminal == 0) {
      return (Result.invalidValue, _emptyRenderInfo);
    }
    final size = _layout.kittyRenderInfoSize;
    final ptr = _exports.ghostty_wasm_alloc_u8_array(size);
    _mem.writeU32(ptr, size);
    final code = _exports.ghostty_kitty_graphics_placement_render_info(
      iterator,
      image,
      terminal,
      ptr,
    );
    if (code != Result.success.value) {
      _exports.ghostty_wasm_free_u8_array(ptr, size);
      return (Result.fromValue(code), _emptyRenderInfo);
    }
    final info = (
      pixelWidth: _mem.readU32(ptr + _layout.kittyRenderInfoPixelWidth),
      pixelHeight: _mem.readU32(ptr + _layout.kittyRenderInfoPixelHeight),
      gridCols: _mem.readU32(ptr + _layout.kittyRenderInfoGridCols),
      gridRows: _mem.readU32(ptr + _layout.kittyRenderInfoGridRows),
      viewportCol: _mem.readI32(ptr + _layout.kittyRenderInfoViewportCol),
      viewportRow: _mem.readI32(ptr + _layout.kittyRenderInfoViewportRow),
      viewportVisible:
          _mem.readU8(ptr + _layout.kittyRenderInfoViewportVisible) != 0,
      sourceX: _mem.readU32(ptr + _layout.kittyRenderInfoSourceX),
      sourceY: _mem.readU32(ptr + _layout.kittyRenderInfoSourceY),
      sourceWidth: _mem.readU32(ptr + _layout.kittyRenderInfoSourceWidth),
      sourceHeight: _mem.readU32(ptr + _layout.kittyRenderInfoSourceHeight),
    );
    _exports.ghostty_wasm_free_u8_array(ptr, size);
    return (Result.success, info);
  }

  void _installSysLog(void Function(int, int, int, int, int, int) fn) {
    final index = _registerCallback(fn.toJS, [
      'i32',
      'i32',
      'i32',
      'i32',
      'i32',
      'i32',
    ], reuseIndex: _sysLogIndex);
    _sysLogIndex = index;
    _exports.ghostty_sys_set(SysOption.log.value, index);
  }

  @override
  void terminalDisposeCallbacks(int handle) {
    final map = _callbacks.remove(handle);
    if (map case Map(:final keys, :final values)) {
      for (final option in keys) {
        _exports.ghostty_terminal_set(handle, option.value, 0);
      }
      for (final (index, _) in values) {
        _table.set(index);
      }
    }
    final bufs = _stringBufs.remove(handle);
    if (bufs case Map(:final values)) {
      for (final (ptr, len) in values) {
        _exports.ghostty_wasm_free_u8_array(ptr, len);
      }
    }
  }

  void _freeStringBuf(int handle, TerminalOption option) {
    final bufs = _stringBufs[handle];
    if (bufs == null) return;
    final buf = bufs.remove(option);
    if (buf != null) _exports.ghostty_wasm_free_u8_array(buf.$1, buf.$2);
  }

  ClipboardContent _readClipboardContent(int ptr) {
    final mime = ptr + _layout.clipboardContentMime;
    final data = ptr + _layout.clipboardContentData;
    final mimePtr = _mem.readPtr(mime);
    final mimeLen = _mem.readU32(mime + _layout.stringLen);
    final dataPtr = _mem.readPtr(data);
    final dataLen = _mem.readU32(data + _layout.stringLen);
    return (
      mime: utf8.decode(_mem.readBytes(mimePtr, mimeLen)),
      data: Uint8List.fromList(_mem.readBytes(dataPtr, dataLen)),
    );
  }

  @override
  CResult<int> renderStateNew() {
    final outPtr = _exports.ghostty_wasm_alloc_opaque();
    final result = _exports.ghostty_render_state_new(0, outPtr);
    final handle = _mem.readPtr(outPtr);
    _exports.ghostty_wasm_free_opaque(outPtr);
    return (.fromValue(result), handle);
  }

  @override
  void renderStateFree(int handle) {
    _exports.ghostty_render_state_free(handle);
  }

  @override
  Result renderStateBeginUpdate(int state, int terminal) {
    return .fromValue(
      _exports.ghostty_render_state_begin_update(state, terminal),
    );
  }

  @override
  Result renderStateEndUpdate(int state) {
    return .fromValue(_exports.ghostty_render_state_end_update(state));
  }

  @override
  Result renderStateUpdate(int state, int terminal) {
    return .fromValue(_exports.ghostty_render_state_update(state, terminal));
  }

  @override
  CResult<int> renderStateGetCols(int state) {
    return _renderStateGetU16(state, .cols);
  }

  @override
  CResult<int> renderStateGetRows(int state) {
    return _renderStateGetU16(state, .rows);
  }

  @override
  CResult<RenderStateDirty> renderStateGetDirty(int state) {
    final raw = _renderStateGetI32(state, .dirty);
    return (raw.$1, RenderStateDirty.fromValue(raw.$2));
  }

  @override
  CResult<RawRenderStateSummary> renderStateGetSummary(int state) {
    final result = Result.fromValue(
      _exports.ghostty_render_state_get_multi(
        state,
        _renderStateSummaryKeys.length,
        _renderStateSummaryMultiKeys,
        _renderStateSummaryMultiValues,
        _multiWritten,
      ),
    );
    if (result != .success) return (result, _emptyRenderStateSummary);
    return (
      result,
      (
        cols: _mem.readU16(_renderStateSummaryMultiOut),
        rows: _mem.readU16(_renderStateSummaryMultiOut + _wasmOutputSlotSize),
        dirty: .fromValue(
          _mem.readI32(_renderStateSummaryMultiOut + 2 * _wasmOutputSlotSize),
        ),
      ),
    );
  }

  @override
  Result renderStateSetDirty(int state, RenderStateDirty dirty) {
    final valPtr = _exports.ghostty_wasm_alloc_usize();
    _mem.writeI32(valPtr, dirty.value);
    final result = _exports.ghostty_render_state_set(
      state,
      RenderStateOption.dirty.value,
      valPtr,
    );
    _exports.ghostty_wasm_free_usize(valPtr);
    return Result.fromValue(result);
  }

  @override
  CResult<TerminalColors> renderStateGetColors(int state) {
    final colorsPtr = _exports.ghostty_wasm_alloc_u8_array(_layout.colorsSize);
    _mem.writeU32(colorsPtr, _layout.colorsSize);
    final result = Result.fromValue(
      _exports.ghostty_render_state_colors_get(state, colorsPtr),
    );

    RgbColor rgbAt(int offset) => RgbColor(
      _mem.readU8(colorsPtr + offset),
      _mem.readU8(colorsPtr + offset + 1),
      _mem.readU8(colorsPtr + offset + 2),
    );

    final bg = rgbAt(_layout.colorsBg);
    final fg = rgbAt(_layout.colorsFg);
    final cursorHasValue =
        _mem.readU8(colorsPtr + _layout.colorsCursorHasValue) != 0;
    final cursor = cursorHasValue ? rgbAt(_layout.colorsCursor) : null;

    final palette = <RgbColor>[
      for (var i = 0; i < 256; i++)
        rgbAt(_layout.colorsPalette + i * _layout.colorRgbSize),
    ];

    _exports.ghostty_wasm_free_u8_array(colorsPtr, _layout.colorsSize);
    return (
      result,
      TerminalColors(
        foreground: fg,
        background: bg,
        cursor: cursor,
        palette: palette,
      ),
    );
  }

  @override
  CResult<RenderStateCursorVisualStyle> renderStateGetCursorVisualStyle(
    int state,
  ) {
    final raw = _renderStateGetI32(state, .cursorVisualStyle);
    return (raw.$1, RenderStateCursorVisualStyle.fromValue(raw.$2));
  }

  @override
  CResult<bool> renderStateGetCursorVisible(int state) {
    return _renderStateGetBool(state, .cursorVisible);
  }

  @override
  CResult<bool> renderStateGetCursorBlinking(int state) {
    return _renderStateGetBool(state, .cursorBlinking);
  }

  @override
  CResult<bool> renderStateGetCursorPasswordInput(int state) {
    return _renderStateGetBool(state, .cursorPasswordInput);
  }

  @override
  CResult<bool> renderStateGetCursorInViewport(int state) {
    return _renderStateGetBool(state, .cursorViewportHasValue);
  }

  @override
  CResult<int> renderStateGetCursorViewportX(int state) {
    return _renderStateGetU16(state, .cursorViewportX);
  }

  @override
  CResult<int> renderStateGetCursorViewportY(int state) {
    return _renderStateGetU16(state, .cursorViewportY);
  }

  @override
  CResult<bool> renderStateGetCursorViewportWideTail(int state) {
    return _renderStateGetBool(state, .cursorViewportWideTail);
  }

  @override
  CResult<RawRenderStateCursor> renderStateGetCursor(int state) {
    final result = Result.fromValue(
      _exports.ghostty_render_state_get_multi(
        state,
        _cursorStateKeys.length,
        _cursorMultiKeys,
        _cursorMultiValues,
        _multiWritten,
      ),
    );
    final written = _mem.readU32(_multiWritten);
    final cursorOffscreen = result == .invalidValue && written == 5;
    if (result != .success && !cursorOffscreen) {
      return (result, _emptyRenderStateCursor);
    }
    final visualStyle = RenderStateCursorVisualStyle.fromValue(
      _mem.readI32(_cursorMultiOut),
    );
    final visible = _mem.readU8(_cursorMultiOut + _wasmOutputSlotSize) != 0;
    final blinking =
        _mem.readU8(_cursorMultiOut + 2 * _wasmOutputSlotSize) != 0;
    final passwordInput =
        _mem.readU8(_cursorMultiOut + 3 * _wasmOutputSlotSize) != 0;
    final inViewport =
        _mem.readU8(_cursorMultiOut + 4 * _wasmOutputSlotSize) != 0;
    if (!inViewport) {
      return (
        .success,
        (
          visualStyle: visualStyle,
          visible: visible,
          blinking: blinking,
          passwordInput: passwordInput,
          inViewport: false,
          viewportX: 0,
          viewportY: 0,
          viewportWideTail: false,
        ),
      );
    }

    return (
      result,
      (
        visualStyle: visualStyle,
        visible: visible,
        blinking: blinking,
        passwordInput: passwordInput,
        inViewport: true,
        viewportX: _mem.readU16(_cursorMultiOut + 5 * _wasmOutputSlotSize),
        viewportY: _mem.readU16(_cursorMultiOut + 6 * _wasmOutputSlotSize),
        viewportWideTail:
            _mem.readU8(_cursorMultiOut + 7 * _wasmOutputSlotSize) != 0,
      ),
    );
  }

  @override
  CResult<int> rowIteratorNew() {
    final outPtr = _exports.ghostty_wasm_alloc_opaque();
    final result = Result.fromValue(
      _exports.ghostty_render_state_row_iterator_new(0, outPtr),
    );
    final handle = _mem.readPtr(outPtr);
    _exports.ghostty_wasm_free_opaque(outPtr);
    return (result, handle);
  }

  @override
  void rowIteratorFree(int handle) {
    _exports.ghostty_render_state_row_iterator_free(handle);
  }

  @override
  Result rowIteratorInit(int iterator, int renderState) {
    final ptrPtr = _exports.ghostty_wasm_alloc_opaque();
    _mem.writeU32(ptrPtr, iterator);
    final result = _exports.ghostty_render_state_get(
      renderState,
      RenderStateData.rowIterator.value,
      ptrPtr,
    );
    _exports.ghostty_wasm_free_opaque(ptrPtr);
    return Result.fromValue(result);
  }

  @override
  bool rowIteratorNext(int iterator) {
    return _exports.ghostty_render_state_row_iterator_next(iterator) != 0;
  }

  @override
  CResult<bool> rowIteratorGetDirty(int iterator) {
    final outPtr = _exports.ghostty_wasm_alloc_u8();
    final result = Result.fromValue(
      _exports.ghostty_render_state_row_get(
        iterator,
        RenderStateRowData.dirty.value,
        outPtr,
      ),
    );
    final value = _mem.readU8(outPtr) != 0;
    _exports.ghostty_wasm_free_u8(outPtr);
    return (result, value);
  }

  @override
  CResult<RawRowIteratorSummary> rowIteratorGetSummary(int iterator) {
    const keys = _rowIteratorSummaryKeys;
    for (var i = 0; i < keys.length; i++) {
      _mem.writeU32(_multiKeys + i * _wasmEnumSize, keys[i].value);
      _mem.writeU32(
        _multiValues + i * _wasmPointerSize,
        _multiOut + i * _wasmOutputSlotSize,
      );
    }
    final result = Result.fromValue(
      _exports.ghostty_render_state_row_get_multi(
        iterator,
        keys.length,
        _multiKeys,
        _multiValues,
        _multiWritten,
      ),
    );
    return (
      result,
      (
        dirty: _mem.readU8(_multiOut) != 0,
        rawRow: _mem.readU64(_multiOut + _wasmOutputSlotSize),
      ),
    );
  }

  @override
  Result rowIteratorSetDirty(int iterator, {required bool dirty}) {
    final valPtr = _exports.ghostty_wasm_alloc_u8();
    _mem.writeU8(valPtr, dirty ? 1 : 0);
    final result = _exports.ghostty_render_state_row_set(
      iterator,
      RenderStateRowOption.dirty.value,
      valPtr,
    );
    _exports.ghostty_wasm_free_u8(valPtr);
    return Result.fromValue(result);
  }

  @override
  CResult<int> rowIteratorGetRawRow(int iterator) {
    const u64Size = 8;
    final outPtr = _exports.ghostty_wasm_alloc_u8_array(u64Size);
    final result = Result.fromValue(
      _exports.ghostty_render_state_row_get(
        iterator,
        RenderStateRowData.raw.value,
        outPtr,
      ),
    );
    final value = _mem.readU64(outPtr);
    _exports.ghostty_wasm_free_u8_array(outPtr, u64Size);
    return (result, value);
  }

  @override
  CResult<({int startCol, int endCol})> rowIteratorGetSelection(int iterator) {
    final size = _layout.renderRowSelectionSize;
    final outPtr = _exports.ghostty_wasm_alloc_u8_array(size);
    _zero(outPtr, size);
    _mem.writeU32(outPtr, size);
    final result = Result.fromValue(
      _exports.ghostty_render_state_row_get(
        iterator,
        RenderStateRowData.selection.value,
        outPtr,
      ),
    );
    final value = (
      startCol: _mem.readU16(outPtr + _layout.renderRowSelectionStartX),
      endCol: _mem.readU16(outPtr + _layout.renderRowSelectionEndX),
    );
    _exports.ghostty_wasm_free_u8_array(outPtr, size);
    return (result, value);
  }

  @override
  CResult<int> rowCellsNew() {
    final outPtr = _exports.ghostty_wasm_alloc_opaque();
    final result = Result.fromValue(
      _exports.ghostty_render_state_row_cells_new(0, outPtr),
    );
    final handle = _mem.readPtr(outPtr);
    _exports.ghostty_wasm_free_opaque(outPtr);
    return (result, handle);
  }

  @override
  void rowCellsFree(int handle) {
    _exports.ghostty_render_state_row_cells_free(handle);
  }

  @override
  Result rowCellsInit(int cells, int iterator) {
    final ptrPtr = _exports.ghostty_wasm_alloc_opaque();
    _mem.writeU32(ptrPtr, cells);
    final result = _exports.ghostty_render_state_row_get(
      iterator,
      RenderStateRowData.cells.value,
      ptrPtr,
    );
    _exports.ghostty_wasm_free_opaque(ptrPtr);
    return Result.fromValue(result);
  }

  @override
  bool rowCellsNext(int cells) =>
      _exports.ghostty_render_state_row_cells_next(cells) != 0;

  @override
  Result rowCellsSelect(int cells, int x) {
    return Result.fromValue(
      _exports.ghostty_render_state_row_cells_select(cells, x),
    );
  }

  @override
  CResult<int> rowCellsGetRawCell(int cells) {
    const u64Size = 8;
    final outPtr = _exports.ghostty_wasm_alloc_u8_array(u64Size);
    final result = Result.fromValue(
      _exports.ghostty_render_state_row_cells_get(
        cells,
        RenderStateRowCellsData.raw.value,
        outPtr,
      ),
    );
    final value = _mem.readU64(outPtr);
    _exports.ghostty_wasm_free_u8_array(outPtr, u64Size);
    return (result, value);
  }

  @override
  CResult<RawRowCellsSummary> rowCellsGetSummary(int cells) {
    final result = Result.fromValue(
      _exports.ghostty_render_state_row_cells_get_multi(
        cells,
        _rowCellsSummaryKeys.length,
        _rowCellsMultiKeys,
        _rowCellsMultiValues,
        _multiWritten,
      ),
    );
    return (
      result,
      (
        rawCell: _mem.readU64(_rowCellsMultiOut),
        graphemeLen: _mem.readU32(_rowCellsMultiOut + _wasmOutputSlotSize),
        selected: _mem.readU8(_rowCellsMultiOut + 2 * _wasmOutputSlotSize) != 0,
      ),
    );
  }

  @override
  CResult<Style> rowCellsGetStyle(int cells) {
    final size = _layout.styleSize;
    final stylePtr = _exports.ghostty_wasm_alloc_u8_array(size);
    _mem.writeU32(stylePtr, size);
    final result = Result.fromValue(
      _exports.ghostty_render_state_row_cells_get(
        cells,
        RenderStateRowCellsData.style.value,
        stylePtr,
      ),
    );
    final value = _readStyle(stylePtr);
    _exports.ghostty_wasm_free_u8_array(stylePtr, size);
    return (result, value);
  }

  @override
  CResult<int> rowCellsGetGraphemeLen(int cells) {
    final outPtr = _exports.ghostty_wasm_alloc_usize();
    final result = Result.fromValue(
      _exports.ghostty_render_state_row_cells_get(
        cells,
        RenderStateRowCellsData.graphemesLen.value,
        outPtr,
      ),
    );
    final value = _mem.readU32(outPtr);
    _exports.ghostty_wasm_free_usize(outPtr);
    return (result, value);
  }

  @override
  CResult<List<int>> rowCellsGetGraphemes(int cells, int len) {
    if (len <= 0) return (Result.success, const []);
    final bufSize = len * 4;
    final buf = _exports.ghostty_wasm_alloc_u8_array(bufSize);
    final result = Result.fromValue(
      _exports.ghostty_render_state_row_cells_get(
        cells,
        RenderStateRowCellsData.graphemesBuf.value,
        buf,
      ),
    );
    final value = [for (var i = 0; i < len; i++) _mem.readU32(buf + i * 4)];
    _exports.ghostty_wasm_free_u8_array(buf, bufSize);
    return (result, value);
  }

  @override
  CResult<String> rowCellsGetGraphemesUtf8(int cells) {
    const inlineCap = 64;
    final bufferPtr = _exports.ghostty_wasm_alloc_u8_array(_layout.bufferSize);
    var dataPtr = _exports.ghostty_wasm_alloc_u8_array(inlineCap);
    var dataCap = inlineCap;

    void writeBuffer() {
      _mem.writeU32(bufferPtr + _layout.bufferPtr, dataPtr);
      _mem.writeU32(bufferPtr + _layout.bufferCap, dataCap);
      _mem.writeU32(bufferPtr + _layout.bufferLen, 0);
    }

    writeBuffer();
    var result = Result.fromValue(
      _exports.ghostty_render_state_row_cells_get(
        cells,
        RenderStateRowCellsData.graphemesUtf8.value,
        bufferPtr,
      ),
    );
    var len = _mem.readU32(bufferPtr + _layout.bufferLen);

    if (result == .outOfSpace) {
      _exports.ghostty_wasm_free_u8_array(dataPtr, dataCap);
      dataCap = len;
      dataPtr = _exports.ghostty_wasm_alloc_u8_array(dataCap);
      writeBuffer();
      result = Result.fromValue(
        _exports.ghostty_render_state_row_cells_get(
          cells,
          RenderStateRowCellsData.graphemesUtf8.value,
          bufferPtr,
        ),
      );
      len = _mem.readU32(bufferPtr + _layout.bufferLen);
    }

    final value = result == .success && len > 0
        ? utf8.decode(_mem.readBytes(dataPtr, len))
        : '';
    _exports.ghostty_wasm_free_u8_array(dataPtr, dataCap);
    _exports.ghostty_wasm_free_u8_array(bufferPtr, _layout.bufferSize);
    return (result, value);
  }

  @override
  CResult<bool> rowCellsGetHasStyling(int cells) {
    final outPtr = _exports.ghostty_wasm_alloc_u8();
    final result = Result.fromValue(
      _exports.ghostty_render_state_row_cells_get(
        cells,
        RenderStateRowCellsData.hasStyling.value,
        outPtr,
      ),
    );
    final value = _mem.readU8(outPtr) != 0;
    _exports.ghostty_wasm_free_u8(outPtr);
    return (result, value);
  }

  @override
  CResult<bool> rowCellsGetSelected(int cells) {
    final outPtr = _exports.ghostty_wasm_alloc_u8();
    final result = Result.fromValue(
      _exports.ghostty_render_state_row_cells_get(
        cells,
        RenderStateRowCellsData.selected.value,
        outPtr,
      ),
    );
    final value = _mem.readU8(outPtr) != 0;
    _exports.ghostty_wasm_free_u8(outPtr);
    return (result, value);
  }

  @override
  CResult<RgbColor> rowCellsGetBgColor(int cells) {
    final outPtr = _exports.ghostty_wasm_alloc_u8_array(3);
    final result = Result.fromValue(
      _exports.ghostty_render_state_row_cells_get(
        cells,
        RenderStateRowCellsData.bgColor.value,
        outPtr,
      ),
    );
    final rgb = RgbColor(
      _mem.readU8(outPtr),
      _mem.readU8(outPtr + _layout.colorRgbG),
      _mem.readU8(outPtr + _layout.colorRgbB),
    );
    _exports.ghostty_wasm_free_u8_array(outPtr, 3);
    return (result, rgb);
  }

  @override
  CResult<RgbColor> rowCellsGetFgColor(int cells) {
    final outPtr = _exports.ghostty_wasm_alloc_u8_array(3);
    final result = Result.fromValue(
      _exports.ghostty_render_state_row_cells_get(
        cells,
        RenderStateRowCellsData.fgColor.value,
        outPtr,
      ),
    );
    final rgb = RgbColor(
      _mem.readU8(outPtr),
      _mem.readU8(outPtr + _layout.colorRgbG),
      _mem.readU8(outPtr + _layout.colorRgbB),
    );
    _exports.ghostty_wasm_free_u8_array(outPtr, 3);
    return (result, rgb);
  }

  @override
  CResult<int> rowCellsGetBgColorArgb(int cells) {
    final outPtr = _exports.ghostty_wasm_alloc_u8_array(3);
    final result = Result.fromValue(
      _exports.ghostty_render_state_row_cells_get(
        cells,
        RenderStateRowCellsData.bgColor.value,
        outPtr,
      ),
    );
    final argb =
        0xFF000000 |
        (_mem.readU8(outPtr) << 16) |
        (_mem.readU8(outPtr + _layout.colorRgbG) << 8) |
        _mem.readU8(outPtr + _layout.colorRgbB);
    _exports.ghostty_wasm_free_u8_array(outPtr, 3);
    return (result, argb);
  }

  @override
  CResult<int> rowCellsGetFgColorArgb(int cells) {
    final outPtr = _exports.ghostty_wasm_alloc_u8_array(3);
    final result = Result.fromValue(
      _exports.ghostty_render_state_row_cells_get(
        cells,
        RenderStateRowCellsData.fgColor.value,
        outPtr,
      ),
    );
    final argb =
        0xFF000000 |
        (_mem.readU8(outPtr) << 16) |
        (_mem.readU8(outPtr + _layout.colorRgbG) << 8) |
        _mem.readU8(outPtr + _layout.colorRgbB);
    _exports.ghostty_wasm_free_u8_array(outPtr, 3);
    return (result, argb);
  }

  @override
  CResult<int> cellGetCodepoint(int cell) => _cellGetU32(cell, .codepoint);

  @override
  CResult<RawCellSummary> cellGetSummary(int cell) {
    final result = Result.fromValue(
      _callCellGetMulti(
        cell,
        _cellSummaryKeys.length,
        _cellMultiKeys,
        _cellMultiValues,
        _multiWritten,
      ),
    );
    return (
      result,
      (
        codepoint: _mem.readU32(_cellMultiOut),
        styleId: _mem.readU16(_cellMultiOut + _wasmOutputSlotSize),
        wide: .fromValue(_mem.readI32(_cellMultiOut + 2 * _wasmOutputSlotSize)),
      ),
    );
  }

  @override
  CResult<CellContentTag> cellGetContentTag(int cell) {
    final raw = _cellGetI32(cell, .contentTag);
    return (raw.$1, CellContentTag.fromValue(raw.$2));
  }

  @override
  CResult<CellWide> cellGetWide(int cell) {
    final raw = _cellGetI32(cell, .wide);
    return (raw.$1, CellWide.fromValue(raw.$2));
  }

  @override
  CResult<bool> cellGetHasText(int cell) => _cellGetBool(cell, .hasText);

  @override
  CResult<bool> cellGetHasStyling(int cell) => _cellGetBool(cell, .hasStyling);

  @override
  CResult<int> cellGetStyleId(int cell) => _cellGetU16(cell, .styleId);

  @override
  CResult<bool> cellGetHasHyperlink(int cell) =>
      _cellGetBool(cell, .hasHyperlink);

  @override
  CResult<bool> cellGetProtected(int cell) => _cellGetBool(cell, .protected);

  @override
  CResult<CellSemanticContent> cellGetSemanticContent(int cell) {
    final raw = _cellGetI32(cell, .semanticContent);
    return (raw.$1, CellSemanticContent.fromValue(raw.$2));
  }

  @override
  CResult<int> cellGetColorPalette(int cell) {
    final outPtr = _exports.ghostty_wasm_alloc_u8();
    final result = Result.fromValue(_callCellGet(cell, .colorPalette, outPtr));
    final value = _mem.readU8(outPtr);
    _exports.ghostty_wasm_free_u8(outPtr);
    return (result, value);
  }

  @override
  CResult<RgbColor> cellGetColorRgb(int cell) {
    final outPtr = _exports.ghostty_wasm_alloc_u8_array(3);
    final result = Result.fromValue(
      _callCellGet(cell, CellData.colorRgb, outPtr),
    );
    final rgb = RgbColor(
      _mem.readU8(outPtr),
      _mem.readU8(outPtr + _layout.colorRgbG),
      _mem.readU8(outPtr + _layout.colorRgbB),
    );
    _exports.ghostty_wasm_free_u8_array(outPtr, 3);
    return (result, rgb);
  }

  @override
  CResult<bool> rowGetWrap(int row) => _rowGetBool(row, .wrap);

  @override
  CResult<bool> rowGetWrapContinuation(int row) =>
      _rowGetBool(row, .wrapContinuation);

  @override
  CResult<bool> rowGetGrapheme(int row) => _rowGetBool(row, .grapheme);

  @override
  CResult<bool> rowGetStyled(int row) => _rowGetBool(row, .styled);

  @override
  CResult<bool> rowGetHyperlink(int row) => _rowGetBool(row, .hyperlink);

  @override
  CResult<RowSemanticPrompt> rowGetSemanticPrompt(int row) {
    final outPtr = _exports.ghostty_wasm_alloc_usize();
    final result = _callRowGet(row, .semanticPrompt, outPtr);
    final value = _mem.readI32(outPtr);
    _exports.ghostty_wasm_free_usize(outPtr);
    return (.fromValue(result), .fromValue(value));
  }

  @override
  CResult<bool> rowGetKittyVirtualPlaceholder(int row) {
    return _rowGetBool(row, .kittyVirtualPlaceholder);
  }

  @override
  CResult<bool> rowGetDirty(int row) => _rowGetBool(row, .dirty);

  @override
  CResult<RawRowSummary> rowGetSummary(int row) {
    const keys = _rowSummaryKeys;
    for (var i = 0; i < keys.length; i++) {
      _mem.writeU32(_multiKeys + i * _wasmEnumSize, keys[i].value);
      _mem.writeU32(
        _multiValues + i * _wasmPointerSize,
        _multiOut + i * _wasmOutputSlotSize,
      );
    }
    final result = Result.fromValue(
      _callRowGetMulti(
        row,
        keys.length,
        _multiKeys,
        _multiValues,
        _multiWritten,
      ),
    );
    return (
      result,
      (
        wrap: _mem.readU8(_multiOut) != 0,
        wrapContinuation: _mem.readU8(_multiOut + _wasmOutputSlotSize) != 0,
        grapheme: _mem.readU8(_multiOut + 2 * _wasmOutputSlotSize) != 0,
        styled: _mem.readU8(_multiOut + 3 * _wasmOutputSlotSize) != 0,
        hyperlink: _mem.readU8(_multiOut + 4 * _wasmOutputSlotSize) != 0,
        semanticPrompt: .fromValue(
          _mem.readI32(_multiOut + 5 * _wasmOutputSlotSize),
        ),
        kittyVirtualPlaceholder:
            _mem.readU8(_multiOut + 6 * _wasmOutputSlotSize) != 0,
      ),
    );
  }

  @override
  CResult<String> focusEncode(FocusEvent event) {
    final outLen = _exports.ghostty_wasm_alloc_usize();
    const bufSize = 8;
    final buf = _exports.ghostty_wasm_alloc_u8_array(bufSize);
    final result = _exports.ghostty_focus_encode(
      event.value,
      buf,
      bufSize,
      outLen,
    );
    final len = _mem.readU32(outLen);
    final value = (len == 0) ? '' : utf8.decode(_mem.readBytes(buf, len));
    _exports.ghostty_wasm_free_usize(outLen);
    _exports.ghostty_wasm_free_u8_array(buf, bufSize);
    return (.fromValue(result), value);
  }

  @override
  CResult<int> buildInfo(BuildInfo data) {
    final outPtr = _exports.ghostty_wasm_alloc_usize();
    final result = _exports.ghostty_build_info(data.value, outPtr);
    final value = _mem.readI32(outPtr);
    _exports.ghostty_wasm_free_usize(outPtr);
    return (.fromValue(result), value);
  }

  @override
  CResult<bool> buildInfoBool(BuildInfo data) {
    final outPtr = _exports.ghostty_wasm_alloc_u8();
    final result = _exports.ghostty_build_info(data.value, outPtr);
    final value = _mem.readU8(outPtr) != 0;
    _exports.ghostty_wasm_free_u8(outPtr);
    return (.fromValue(result), value);
  }

  @override
  CResult<String> buildInfoString(BuildInfo data) {
    final strSize = _layout.stringSize;
    final strPtr = _exports.ghostty_wasm_alloc_u8_array(strSize);
    final result = _exports.ghostty_build_info(data.value, strPtr);
    final ptr = _mem.readU32(strPtr);
    final len = _mem.readU32(strPtr + _layout.stringLen);
    _exports.ghostty_wasm_free_u8_array(strPtr, strSize);
    if (len == 0 || ptr == 0) return (.fromValue(result), '');
    return (.fromValue(result), utf8.decode(_mem.readBytes(ptr, len)));
  }

  @override
  CResult<String> modeReportEncode(int mode, ModeReportState state) {
    final outLen = _exports.ghostty_wasm_alloc_usize();
    const bufSize = 64;
    final buf = _exports.ghostty_wasm_alloc_u8_array(bufSize);
    final result = _exports.ghostty_mode_report_encode(
      mode,
      state.value,
      buf,
      bufSize,
      outLen,
    );
    final len = _mem.readU32(outLen);
    final value = (len == 0) ? '' : utf8.decode(_mem.readBytes(buf, len));
    _exports.ghostty_wasm_free_usize(outLen);
    _exports.ghostty_wasm_free_u8_array(buf, bufSize);
    return (.fromValue(result), value);
  }

  @override
  CResult<String> sizeReportEncode(
    SizeReportStyle style,
    int rows,
    int columns,
    int cellWidth,
    int cellHeight,
  ) {
    final sizeStructSize = _layout.sizeReportSize;
    final sizePtr = _exports.ghostty_wasm_alloc_u8_array(sizeStructSize);
    final outLen = _exports.ghostty_wasm_alloc_usize();
    const bufSize = 64;
    final buf = _exports.ghostty_wasm_alloc_u8_array(bufSize);
    _mem.writeU16(sizePtr, rows);
    _mem.writeU16(sizePtr + _layout.sizeReportColumns, columns);
    _mem.writeU32(sizePtr + _layout.sizeReportCellWidth, cellWidth);
    _mem.writeU32(sizePtr + _layout.sizeReportCellHeight, cellHeight);
    final result = _exports.ghostty_size_report_encode(
      style.value,
      sizePtr,
      buf,
      bufSize,
      outLen,
    );
    final len = _mem.readU32(outLen);
    final value = (len == 0) ? '' : utf8.decode(_mem.readBytes(buf, len));
    _exports.ghostty_wasm_free_u8_array(sizePtr, sizeStructSize);
    _exports.ghostty_wasm_free_usize(outLen);
    _exports.ghostty_wasm_free_u8_array(buf, bufSize);
    return (.fromValue(result), value);
  }

  @override
  Style styleDefault() {
    final stylePtr = _exports.ghostty_wasm_alloc_u8_array(_layout.styleSize);
    _mem.writeU32(stylePtr, _layout.styleSize);
    _exports.ghostty_style_default(stylePtr);
    final value = _readStyle(stylePtr);
    _exports.ghostty_wasm_free_u8_array(stylePtr, _layout.styleSize);
    return value;
  }

  @override
  bool styleIsDefault(Style style) {
    final stylePtr = _exports.ghostty_wasm_alloc_u8_array(_layout.styleSize);
    _mem.writeU32(stylePtr, _layout.styleSize);
    _writeStyle(stylePtr, style);
    final value = _exports.ghostty_style_is_default(stylePtr) != 0;
    _exports.ghostty_wasm_free_u8_array(stylePtr, _layout.styleSize);
    return value;
  }

  @override
  CResult<RawGridRef> terminalGridRef(
    int terminal,
    PointTag pointTag,
    Position position,
  ) {
    final pointPtr = _exports.ghostty_wasm_alloc_u8_array(_layout.pointSize);
    final gridRefPtr = _exports.ghostty_wasm_alloc_u8_array(
      _layout.gridRefSize,
    );
    _writePoint(pointPtr, pointTag, position);
    _mem.writeU32(gridRefPtr, _layout.gridRefSize);
    final result = _exports.ghostty_terminal_grid_ref(
      terminal,
      pointPtr,
      gridRefPtr,
    );
    final value = _readGridRef(gridRefPtr);
    _exports.ghostty_wasm_free_u8_array(pointPtr, _layout.pointSize);
    _exports.ghostty_wasm_free_u8_array(gridRefPtr, _layout.gridRefSize);
    return (.fromValue(result), value);
  }

  @override
  CResult<int> terminalGridRefTrack(
    int terminal,
    PointTag pointTag,
    Position position,
  ) {
    final pointPtr = _exports.ghostty_wasm_alloc_u8_array(_layout.pointSize);
    final outPtr = _exports.ghostty_wasm_alloc_opaque();
    _writePoint(pointPtr, pointTag, position);
    final result = _exports.ghostty_terminal_grid_ref_track(
      terminal,
      pointPtr,
      outPtr,
    );
    final handle = _mem.readPtr(outPtr);
    _exports.ghostty_wasm_free_opaque(outPtr);
    _exports.ghostty_wasm_free_u8_array(pointPtr, _layout.pointSize);
    return (.fromValue(result), handle);
  }

  @override
  CResult<int> gridRefCell(RawGridRef ref) {
    const u64Size = 8;
    final refPtr = _allocGridRef(ref);
    final outPtr = _exports.ghostty_wasm_alloc_u8_array(u64Size);
    final result = _exports.ghostty_grid_ref_cell(refPtr, outPtr);
    final value = _mem.readU64(outPtr);
    _freeGridRef(refPtr);
    _exports.ghostty_wasm_free_u8_array(outPtr, u64Size);
    return (.fromValue(result), value);
  }

  @override
  CResult<int> gridRefRow(RawGridRef ref) {
    const u64Size = 8;
    final refPtr = _allocGridRef(ref);
    final outPtr = _exports.ghostty_wasm_alloc_u8_array(u64Size);
    final result = _exports.ghostty_grid_ref_row(refPtr, outPtr);
    final value = _mem.readU64(outPtr);
    _freeGridRef(refPtr);
    _exports.ghostty_wasm_free_u8_array(outPtr, u64Size);
    return (.fromValue(result), value);
  }

  @override
  CResult<Style> gridRefStyle(RawGridRef ref) {
    final refPtr = _allocGridRef(ref);
    final stylePtr = _exports.ghostty_wasm_alloc_u8_array(_layout.styleSize);
    _mem.writeU32(stylePtr, _layout.styleSize);
    final result = _exports.ghostty_grid_ref_style(refPtr, stylePtr);
    final value = _readStyle(stylePtr);
    _freeGridRef(refPtr);
    _exports.ghostty_wasm_free_u8_array(stylePtr, _layout.styleSize);
    return (.fromValue(result), value);
  }

  @override
  CResult<List<int>> gridRefGraphemes(RawGridRef ref) {
    const bufCount = 32;
    const bufSize = bufCount * 4;
    final refPtr = _allocGridRef(ref);
    final outLen = _exports.ghostty_wasm_alloc_usize();
    var buf = _exports.ghostty_wasm_alloc_u8_array(bufSize);
    var result = Result.fromValue(
      _exports.ghostty_grid_ref_graphemes(refPtr, buf, bufCount, outLen),
    );
    var len = _mem.readU32(outLen);

    if (result == .outOfSpace) {
      _exports.ghostty_wasm_free_u8_array(buf, bufSize);
      final bigSize = len * 4;
      buf = _exports.ghostty_wasm_alloc_u8_array(bigSize);
      result = Result.fromValue(
        _exports.ghostty_grid_ref_graphemes(refPtr, buf, len, outLen),
      );
      len = _mem.readU32(outLen);
      final value = [for (var i = 0; i < len; i++) _mem.readU32(buf + i * 4)];
      _freeGridRef(refPtr);
      _exports.ghostty_wasm_free_usize(outLen);
      _exports.ghostty_wasm_free_u8_array(buf, bigSize);
      return (result, value);
    }

    final value = switch (len == 0) {
      true => const <int>[],
      false => [for (var i = 0; i < len; i++) _mem.readU32(buf + i * 4)],
    };
    _freeGridRef(refPtr);
    _exports.ghostty_wasm_free_usize(outLen);
    _exports.ghostty_wasm_free_u8_array(buf, bufSize);
    return (result, value);
  }

  @override
  CResult<String> gridRefHyperlinkUri(RawGridRef ref) {
    const initSize = 256;
    final refPtr = _allocGridRef(ref);
    final outLen = _exports.ghostty_wasm_alloc_usize();
    var buf = _exports.ghostty_wasm_alloc_u8_array(initSize);
    var result = Result.fromValue(
      _exports.ghostty_grid_ref_hyperlink_uri(refPtr, buf, initSize, outLen),
    );
    var len = _mem.readU32(outLen);

    if (result == .outOfSpace) {
      _exports.ghostty_wasm_free_u8_array(buf, initSize);
      buf = _exports.ghostty_wasm_alloc_u8_array(len);
      result = Result.fromValue(
        _exports.ghostty_grid_ref_hyperlink_uri(refPtr, buf, len, outLen),
      );
      len = _mem.readU32(outLen);
      final value = len == 0 ? '' : utf8.decode(_mem.readBytes(buf, len));
      _freeGridRef(refPtr);
      _exports.ghostty_wasm_free_usize(outLen);
      _exports.ghostty_wasm_free_u8_array(buf, len);
      return (result, value);
    }

    final value = len == 0 ? '' : utf8.decode(_mem.readBytes(buf, len));
    _freeGridRef(refPtr);
    _exports.ghostty_wasm_free_usize(outLen);
    _exports.ghostty_wasm_free_u8_array(buf, initSize);
    return (result, value);
  }

  @override
  void trackedGridRefFree(int ref) {
    _exports.ghostty_tracked_grid_ref_free(ref);
  }

  @override
  bool trackedGridRefHasValue(int ref) {
    return _exports.ghostty_tracked_grid_ref_has_value(ref) != 0;
  }

  @override
  CResult<Position> trackedGridRefPoint(int ref, PointTag pointTag) {
    final size = _layout.pointCoordinateSize;
    final outPtr = _exports.ghostty_wasm_alloc_u8_array(size);
    final result = Result.fromValue(
      _exports.ghostty_tracked_grid_ref_point(ref, pointTag.value, outPtr),
    );
    final col = _mem.readU16(outPtr + _layout.pointCoordinateX);
    final row = _mem.readU32(outPtr + _layout.pointCoordinateY);
    _exports.ghostty_wasm_free_u8_array(outPtr, size);
    return (result, Position(row: row, col: col));
  }

  @override
  Result trackedGridRefSet(
    int ref,
    int terminal,
    PointTag pointTag,
    Position position,
  ) {
    final pointPtr = _exports.ghostty_wasm_alloc_u8_array(_layout.pointSize);
    _writePoint(pointPtr, pointTag, position);
    final result = _exports.ghostty_tracked_grid_ref_set(
      ref,
      terminal,
      pointPtr,
    );
    _exports.ghostty_wasm_free_u8_array(pointPtr, _layout.pointSize);
    return .fromValue(result);
  }

  @override
  CResult<RawGridRef> trackedGridRefSnapshot(int ref) {
    final gridRefPtr = _exports.ghostty_wasm_alloc_u8_array(
      _layout.gridRefSize,
    );
    _mem.writeU32(gridRefPtr, _layout.gridRefSize);
    final result = Result.fromValue(
      _exports.ghostty_tracked_grid_ref_snapshot(ref, gridRefPtr),
    );
    final value = _readGridRef(gridRefPtr);
    _exports.ghostty_wasm_free_u8_array(gridRefPtr, _layout.gridRefSize);
    return (result, value);
  }

  @override
  CResult<Position> terminalPointFromGridRef(
    int terminal,
    RawGridRef ref,
    PointTag pointTag,
  ) {
    final size = _layout.pointCoordinateSize;
    final refPtr = _allocGridRef(ref);
    final outPtr = _exports.ghostty_wasm_alloc_u8_array(size);
    final result = Result.fromValue(
      _exports.ghostty_terminal_point_from_grid_ref(
        terminal,
        refPtr,
        pointTag.value,
        outPtr,
      ),
    );
    final col = _mem.readU16(outPtr + _layout.pointCoordinateX);
    final row = _mem.readU32(outPtr + _layout.pointCoordinateY);
    _freeGridRef(refPtr);
    _exports.ghostty_wasm_free_u8_array(outPtr, size);
    return (result, Position(row: row, col: col));
  }

  @override
  CResult<RawSelection?> terminalGetSelection(int handle) {
    final ptr = _allocSelection();
    final result = Result.fromValue(
      _exports.ghostty_terminal_get(handle, TerminalData.selection.value, ptr),
    );
    final value = result == .success ? _readSelection(ptr) : null;
    _exports.ghostty_wasm_free_u8_array(ptr, _layout.selectionSize);
    return (result, value);
  }

  @override
  Result terminalSetSelection(int handle, RawSelection? selection) {
    if (selection == null) {
      return .fromValue(
        _exports.ghostty_terminal_set(
          handle,
          TerminalOption.selection.value,
          0,
        ),
      );
    }
    final ptr = _allocSelection(selection);
    final result = Result.fromValue(
      _exports.ghostty_terminal_set(
        handle,
        TerminalOption.selection.value,
        ptr,
      ),
    );
    _exports.ghostty_wasm_free_u8_array(ptr, _layout.selectionSize);
    return result;
  }

  @override
  CResult<RawSelection?> terminalSelectAll(int terminal) {
    final outPtr = _allocSelection();
    final result = Result.fromValue(
      _exports.ghostty_terminal_select_all(terminal, outPtr),
    );
    final value = result == .success ? _readSelection(outPtr) : null;
    _exports.ghostty_wasm_free_u8_array(outPtr, _layout.selectionSize);
    return (result, value);
  }

  @override
  CResult<RawSelection?> terminalSelectWord(
    int terminal,
    RawGridRef ref, {
    List<int>? boundaryCodepoints,
  }) {
    final optsPtr = _exports.ghostty_wasm_alloc_u8_array(
      _layout.selectWordSize,
    );
    final outPtr = _allocSelection();
    final codepoints = _allocCodepoints(boundaryCodepoints);
    _zero(optsPtr, _layout.selectWordSize);
    _mem.writeU32(optsPtr, _layout.selectWordSize);
    _writeGridRef(optsPtr + _layout.selectWordRef, ref);
    _mem.writeU32(
      optsPtr + _layout.selectWordBoundaryCodepoints,
      codepoints.ptr,
    );
    _mem.writeU32(
      optsPtr + _layout.selectWordBoundaryCodepointsLen,
      boundaryCodepoints?.length ?? 0,
    );
    final result = Result.fromValue(
      _exports.ghostty_terminal_select_word(terminal, optsPtr, outPtr),
    );
    final value = result == .success ? _readSelection(outPtr) : null;
    _freeCodepoints(codepoints);
    _exports.ghostty_wasm_free_u8_array(optsPtr, _layout.selectWordSize);
    _exports.ghostty_wasm_free_u8_array(outPtr, _layout.selectionSize);
    return (result, value);
  }

  @override
  CResult<RawSelection?> terminalSelectWordBetween(
    int terminal,
    RawGridRef start,
    RawGridRef end, {
    List<int>? boundaryCodepoints,
  }) {
    final optsPtr = _exports.ghostty_wasm_alloc_u8_array(
      _layout.selectWordBetweenSize,
    );
    final outPtr = _allocSelection();
    final codepoints = _allocCodepoints(boundaryCodepoints);
    _zero(optsPtr, _layout.selectWordBetweenSize);
    _mem.writeU32(optsPtr, _layout.selectWordBetweenSize);
    _writeGridRef(optsPtr + _layout.selectWordBetweenStart, start);
    _writeGridRef(optsPtr + _layout.selectWordBetweenEnd, end);
    _mem.writeU32(
      optsPtr + _layout.selectWordBetweenBoundaryCodepoints,
      codepoints.ptr,
    );
    _mem.writeU32(
      optsPtr + _layout.selectWordBetweenBoundaryCodepointsLen,
      boundaryCodepoints?.length ?? 0,
    );
    final result = Result.fromValue(
      _exports.ghostty_terminal_select_word_between(terminal, optsPtr, outPtr),
    );
    final value = result == .success ? _readSelection(outPtr) : null;
    _freeCodepoints(codepoints);
    _exports.ghostty_wasm_free_u8_array(optsPtr, _layout.selectWordBetweenSize);
    _exports.ghostty_wasm_free_u8_array(outPtr, _layout.selectionSize);
    return (result, value);
  }

  @override
  CResult<RawSelection?> terminalSelectLine(
    int terminal,
    RawGridRef ref, {
    List<int>? whitespace,
    bool semanticPromptBoundary = false,
  }) {
    final optsPtr = _exports.ghostty_wasm_alloc_u8_array(
      _layout.selectLineSize,
    );
    final outPtr = _allocSelection();
    final codepoints = _allocCodepoints(whitespace);
    _zero(optsPtr, _layout.selectLineSize);
    _mem.writeU32(optsPtr, _layout.selectLineSize);
    _writeGridRef(optsPtr + _layout.selectLineRef, ref);
    _mem.writeU32(optsPtr + _layout.selectLineWhitespace, codepoints.ptr);
    _mem.writeU32(
      optsPtr + _layout.selectLineWhitespaceLen,
      whitespace?.length ?? 0,
    );
    _mem.writeU8(
      optsPtr + _layout.selectLineSemanticPromptBoundary,
      semanticPromptBoundary ? 1 : 0,
    );
    final result = Result.fromValue(
      _exports.ghostty_terminal_select_line(terminal, optsPtr, outPtr),
    );
    final value = result == .success ? _readSelection(outPtr) : null;
    _freeCodepoints(codepoints);
    _exports.ghostty_wasm_free_u8_array(optsPtr, _layout.selectLineSize);
    _exports.ghostty_wasm_free_u8_array(outPtr, _layout.selectionSize);
    return (result, value);
  }

  @override
  CResult<RawSelection?> terminalSelectOutput(int terminal, RawGridRef ref) {
    final refPtr = _allocGridRef(ref);
    final outPtr = _allocSelection();
    final result = Result.fromValue(
      _exports.ghostty_terminal_select_output(terminal, refPtr, outPtr),
    );
    final value = result == .success ? _readSelection(outPtr) : null;
    _freeGridRef(refPtr);
    _exports.ghostty_wasm_free_u8_array(outPtr, _layout.selectionSize);
    return (result, value);
  }

  @override
  CResult<RawSelection?> terminalSelectionAdjust(
    int terminal,
    RawSelection selection,
    SelectionAdjust adjustment,
  ) {
    final selPtr = _allocSelection(selection);
    final result = Result.fromValue(
      _exports.ghostty_terminal_selection_adjust(
        terminal,
        selPtr,
        adjustment.value,
      ),
    );
    final value = result == .success ? _readSelection(selPtr) : null;
    _exports.ghostty_wasm_free_u8_array(selPtr, _layout.selectionSize);
    return (result, value);
  }

  @override
  CResult<SelectionOrder> terminalSelectionOrder(
    int terminal,
    RawSelection selection,
  ) {
    const u32Size = 4;
    final selPtr = _allocSelection(selection);
    final outPtr = _exports.ghostty_wasm_alloc_u8_array(u32Size);
    final result = Result.fromValue(
      _exports.ghostty_terminal_selection_order(terminal, selPtr, outPtr),
    );
    final value = result == .success
        ? SelectionOrder.fromValue(_mem.readU32(outPtr))
        : SelectionOrder.forward;
    _exports.ghostty_wasm_free_u8_array(selPtr, _layout.selectionSize);
    _exports.ghostty_wasm_free_u8_array(outPtr, u32Size);
    return (result, value);
  }

  @override
  CResult<RawSelection?> terminalSelectionOrdered(
    int terminal,
    RawSelection selection,
    SelectionOrder desired,
  ) {
    final selPtr = _allocSelection(selection);
    final outPtr = _allocSelection();
    final result = Result.fromValue(
      _exports.ghostty_terminal_selection_ordered(
        terminal,
        selPtr,
        desired.value,
        outPtr,
      ),
    );
    final value = result == .success ? _readSelection(outPtr) : null;
    _exports.ghostty_wasm_free_u8_array(selPtr, _layout.selectionSize);
    _exports.ghostty_wasm_free_u8_array(outPtr, _layout.selectionSize);
    return (result, value);
  }

  @override
  CResult<bool> terminalSelectionContains(
    int terminal,
    RawSelection selection,
    PointTag pointTag,
    Position position,
  ) {
    final selPtr = _allocSelection(selection);
    final pointPtr = _exports.ghostty_wasm_alloc_u8_array(_layout.pointSize);
    final outPtr = _exports.ghostty_wasm_alloc_u8_array(1);
    _writePoint(pointPtr, pointTag, position);
    final result = Result.fromValue(
      _exports.ghostty_terminal_selection_contains(
        terminal,
        selPtr,
        pointPtr,
        outPtr,
      ),
    );
    final value = _mem.readU8(outPtr) != 0;
    _exports.ghostty_wasm_free_u8_array(selPtr, _layout.selectionSize);
    _exports.ghostty_wasm_free_u8_array(pointPtr, _layout.pointSize);
    _exports.ghostty_wasm_free_u8_array(outPtr, 1);
    return (result, value);
  }

  @override
  CResult<bool> terminalSelectionEqual(
    int terminal,
    RawSelection a,
    RawSelection b,
  ) {
    final aPtr = _allocSelection(a);
    final bPtr = _allocSelection(b);
    final outPtr = _exports.ghostty_wasm_alloc_u8_array(1);
    final result = Result.fromValue(
      _exports.ghostty_terminal_selection_equal(terminal, aPtr, bPtr, outPtr),
    );
    final value = _mem.readU8(outPtr) != 0;
    _exports.ghostty_wasm_free_u8_array(aPtr, _layout.selectionSize);
    _exports.ghostty_wasm_free_u8_array(bPtr, _layout.selectionSize);
    _exports.ghostty_wasm_free_u8_array(outPtr, 1);
    return (result, value);
  }

  @override
  CResult<String> terminalSelectionFormat(
    int terminal,
    FormatterFormat format, {
    bool unwrap = false,
    bool trim = false,
    RawSelection? selection,
  }) {
    final optsPtr = _exports.ghostty_wasm_alloc_u8_array(
      _layout.selectionFormatSize,
    );
    _zero(optsPtr, _layout.selectionFormatSize);
    _mem.writeU32(optsPtr, _layout.selectionFormatSize);
    _mem.writeU32(optsPtr + _layout.selectionFormatEmit, format.value);
    _mem.writeU8(optsPtr + _layout.selectionFormatUnwrap, unwrap ? 1 : 0);
    _mem.writeU8(optsPtr + _layout.selectionFormatTrim, trim ? 1 : 0);
    var selPtr = 0;
    if (selection != null) {
      selPtr = _allocSelection(selection);
    }
    _mem.writeU32(optsPtr + _layout.selectionFormatSelection, selPtr);
    var result = Result.fromValue(
      _exports.ghostty_terminal_selection_format_buf(
        terminal,
        optsPtr,
        _formatBuffer,
        _formatBufferCapacity,
        _multiWritten,
      ),
    );
    if (result == .outOfSpace) {
      _growFormatBuffer(_mem.readU32(_multiWritten));
      result = Result.fromValue(
        _exports.ghostty_terminal_selection_format_buf(
          terminal,
          optsPtr,
          _formatBuffer,
          _formatBufferCapacity,
          _multiWritten,
        ),
      );
    }
    final len = _mem.readU32(_multiWritten);
    final value = result == .success && len > 0
        ? utf8.decode(_mem.readBytes(_formatBuffer, len))
        : '';
    if (selPtr != 0) {
      _exports.ghostty_wasm_free_u8_array(selPtr, _layout.selectionSize);
    }
    _exports.ghostty_wasm_free_u8_array(optsPtr, _layout.selectionFormatSize);
    return (result, value);
  }

  @override
  CResult<int> selectionGestureNew() {
    final outPtr = _exports.ghostty_wasm_alloc_opaque();
    final result = Result.fromValue(
      _exports.ghostty_selection_gesture_new(0, outPtr),
    );
    final handle = _mem.readPtr(outPtr);
    _exports.ghostty_wasm_free_opaque(outPtr);
    return (result, handle);
  }

  @override
  void selectionGestureFree(int gesture, int terminal) {
    _exports.ghostty_selection_gesture_free(gesture, terminal);
  }

  @override
  void selectionGestureReset(int gesture, int terminal) {
    _exports.ghostty_selection_gesture_reset(gesture, terminal);
  }

  @override
  CResult<RawSelection?> selectionGestureEvent(
    int gesture,
    int terminal,
    int event,
  ) {
    final outPtr = _allocSelection();
    final result = Result.fromValue(
      _exports.ghostty_selection_gesture_event(
        gesture,
        terminal,
        event,
        outPtr,
      ),
    );
    final value = result == .success ? _readSelection(outPtr) : null;
    _exports.ghostty_wasm_free_u8_array(outPtr, _layout.selectionSize);
    return (result, value);
  }

  @override
  CResult<int> selectionGestureEventNew(SelectionGestureEventType type) {
    final outPtr = _exports.ghostty_wasm_alloc_opaque();
    final result = Result.fromValue(
      _exports.ghostty_selection_gesture_event_new(0, outPtr, type.value),
    );
    final handle = _mem.readPtr(outPtr);
    _exports.ghostty_wasm_free_opaque(outPtr);
    return (result, handle);
  }

  @override
  void selectionGestureEventFree(int event) {
    _exports.ghostty_selection_gesture_event_free(event);
  }

  @override
  Result selectionGestureEventClear(
    int event,
    SelectionGestureEventOption option,
  ) {
    return .fromValue(
      _exports.ghostty_selection_gesture_event_set(event, option.value, 0),
    );
  }

  @override
  Result selectionGestureEventSetRef(int event, RawGridRef ref) {
    final ptr = _allocGridRef(ref);
    final result = Result.fromValue(
      _exports.ghostty_selection_gesture_event_set(
        event,
        SelectionGestureEventOption.ref.value,
        ptr,
      ),
    );
    _freeGridRef(ptr);
    return result;
  }

  @override
  Result selectionGestureEventSetPosition(int event, double x, double y) {
    final ptr = _exports.ghostty_wasm_alloc_u8_array(
      _layout.surfacePositionSize,
    );
    _mem.writeF64(ptr + _layout.surfacePositionX, x);
    _mem.writeF64(ptr + _layout.surfacePositionY, y);
    final result = Result.fromValue(
      _exports.ghostty_selection_gesture_event_set(
        event,
        SelectionGestureEventOption.position.value,
        ptr,
      ),
    );
    _exports.ghostty_wasm_free_u8_array(ptr, _layout.surfacePositionSize);
    return result;
  }

  @override
  Result selectionGestureEventSetRepeatDistance(int event, double value) {
    const size = 8;
    final ptr = _exports.ghostty_wasm_alloc_u8_array(size);
    _mem.writeF64(ptr, value);
    final result = Result.fromValue(
      _exports.ghostty_selection_gesture_event_set(
        event,
        SelectionGestureEventOption.repeatDistance.value,
        ptr,
      ),
    );
    _exports.ghostty_wasm_free_u8_array(ptr, size);
    return result;
  }

  @override
  Result selectionGestureEventSetTimeNs(int event, int value) {
    const size = 8;
    final ptr = _exports.ghostty_wasm_alloc_u8_array(size);
    _mem.writeU64(ptr, value);
    final result = Result.fromValue(
      _exports.ghostty_selection_gesture_event_set(
        event,
        SelectionGestureEventOption.timeNs.value,
        ptr,
      ),
    );
    _exports.ghostty_wasm_free_u8_array(ptr, size);
    return result;
  }

  @override
  Result selectionGestureEventSetRepeatIntervalNs(int event, int value) {
    const size = 8;
    final ptr = _exports.ghostty_wasm_alloc_u8_array(size);
    _mem.writeU64(ptr, value);
    final result = Result.fromValue(
      _exports.ghostty_selection_gesture_event_set(
        event,
        SelectionGestureEventOption.repeatIntervalNs.value,
        ptr,
      ),
    );
    _exports.ghostty_wasm_free_u8_array(ptr, size);
    return result;
  }

  @override
  Result selectionGestureEventSetWordBoundaryCodepoints(
    int event,
    List<int> codepoints,
  ) {
    final values = _allocCodepoints(codepoints);
    final ptr = _exports.ghostty_wasm_alloc_u8_array(_layout.codepointsSize);
    _zero(ptr, _layout.codepointsSize);
    _mem.writeU32(ptr + _layout.codepointsPtr, values.ptr);
    _mem.writeU32(ptr + _layout.codepointsLen, codepoints.length);
    final result = Result.fromValue(
      _exports.ghostty_selection_gesture_event_set(
        event,
        SelectionGestureEventOption.wordBoundaryCodepoints.value,
        ptr,
      ),
    );
    _freeCodepoints(values);
    _exports.ghostty_wasm_free_u8_array(ptr, _layout.codepointsSize);
    return result;
  }

  @override
  Result selectionGestureEventSetBehaviors(
    int event,
    SelectionGestureBehavior singleClick,
    SelectionGestureBehavior doubleClick,
    SelectionGestureBehavior tripleClick,
  ) {
    final ptr = _exports.ghostty_wasm_alloc_u8_array(
      _layout.gestureBehaviorsSize,
    );
    _mem.writeU32(ptr + _layout.gestureBehaviorsSingleClick, singleClick.value);
    _mem.writeU32(ptr + _layout.gestureBehaviorsDoubleClick, doubleClick.value);
    _mem.writeU32(ptr + _layout.gestureBehaviorsTripleClick, tripleClick.value);
    final result = Result.fromValue(
      _exports.ghostty_selection_gesture_event_set(
        event,
        SelectionGestureEventOption.behaviors.value,
        ptr,
      ),
    );
    _exports.ghostty_wasm_free_u8_array(ptr, _layout.gestureBehaviorsSize);
    return result;
  }

  @override
  Result selectionGestureEventSetRectangle(int event, {required bool value}) {
    final ptr = _exports.ghostty_wasm_alloc_u8_array(1);
    _mem.writeU8(ptr, value ? 1 : 0);
    final result = Result.fromValue(
      _exports.ghostty_selection_gesture_event_set(
        event,
        SelectionGestureEventOption.rectangle.value,
        ptr,
      ),
    );
    _exports.ghostty_wasm_free_u8_array(ptr, 1);
    return result;
  }

  @override
  Result selectionGestureEventSetGeometry(
    int event, {
    required int columns,
    required int cellWidth,
    required int paddingLeft,
    required int screenHeight,
  }) {
    final ptr = _exports.ghostty_wasm_alloc_u8_array(
      _layout.gestureGeometrySize,
    );
    _mem.writeU32(ptr + _layout.gestureGeometryColumns, columns);
    _mem.writeU32(ptr + _layout.gestureGeometryCellWidth, cellWidth);
    _mem.writeU32(ptr + _layout.gestureGeometryPaddingLeft, paddingLeft);
    _mem.writeU32(ptr + _layout.gestureGeometryScreenHeight, screenHeight);
    final result = Result.fromValue(
      _exports.ghostty_selection_gesture_event_set(
        event,
        SelectionGestureEventOption.geometry.value,
        ptr,
      ),
    );
    _exports.ghostty_wasm_free_u8_array(ptr, _layout.gestureGeometrySize);
    return result;
  }

  @override
  Result selectionGestureEventSetViewport(
    int event, {
    required Position position,
  }) {
    final ptr = _exports.ghostty_wasm_alloc_u8_array(
      _layout.pointCoordinateSize,
    );
    _mem.writeU16(ptr + _layout.pointCoordinateX, position.col);
    _mem.writeU32(ptr + _layout.pointCoordinateY, position.row);
    final result = Result.fromValue(
      _exports.ghostty_selection_gesture_event_set(
        event,
        SelectionGestureEventOption.viewport.value,
        ptr,
      ),
    );
    _exports.ghostty_wasm_free_u8_array(ptr, _layout.pointCoordinateSize);
    return result;
  }

  @override
  CResult<int> selectionGestureGetClickCount(int gesture, int terminal) {
    final ptr = _exports.ghostty_wasm_alloc_u8_array(1);
    final result = Result.fromValue(
      _exports.ghostty_selection_gesture_get(
        gesture,
        terminal,
        SelectionGestureData.clickCount.value,
        ptr,
      ),
    );
    final value = _mem.readU8(ptr);
    _exports.ghostty_wasm_free_u8_array(ptr, 1);
    return (result, value);
  }

  @override
  CResult<bool> selectionGestureGetDragged(int gesture, int terminal) {
    final ptr = _exports.ghostty_wasm_alloc_u8_array(1);
    final result = Result.fromValue(
      _exports.ghostty_selection_gesture_get(
        gesture,
        terminal,
        SelectionGestureData.dragged.value,
        ptr,
      ),
    );
    final value = _mem.readU8(ptr) != 0;
    _exports.ghostty_wasm_free_u8_array(ptr, 1);
    return (result, value);
  }

  @override
  CResult<SelectionGestureAutoscroll> selectionGestureGetAutoscroll(
    int gesture,
    int terminal,
  ) {
    const size = 4;
    final ptr = _exports.ghostty_wasm_alloc_u8_array(size);
    final result = Result.fromValue(
      _exports.ghostty_selection_gesture_get(
        gesture,
        terminal,
        SelectionGestureData.autoscroll.value,
        ptr,
      ),
    );
    final value = result == .success
        ? SelectionGestureAutoscroll.fromValue(_mem.readU32(ptr))
        : SelectionGestureAutoscroll.none;
    _exports.ghostty_wasm_free_u8_array(ptr, size);
    return (result, value);
  }

  @override
  CResult<SelectionGestureBehavior> selectionGestureGetBehavior(
    int gesture,
    int terminal,
  ) {
    const size = 4;
    final ptr = _exports.ghostty_wasm_alloc_u8_array(size);
    final result = Result.fromValue(
      _exports.ghostty_selection_gesture_get(
        gesture,
        terminal,
        SelectionGestureData.behavior.value,
        ptr,
      ),
    );
    final value = result == .success
        ? SelectionGestureBehavior.fromValue(_mem.readU32(ptr))
        : SelectionGestureBehavior.cell;
    _exports.ghostty_wasm_free_u8_array(ptr, size);
    return (result, value);
  }

  @override
  CResult<RawGridRef> selectionGestureGetAnchor(int gesture, int terminal) {
    final ptr = _allocGridRef(_emptyGridRef);
    final result = Result.fromValue(
      _exports.ghostty_selection_gesture_get(
        gesture,
        terminal,
        SelectionGestureData.anchor.value,
        ptr,
      ),
    );
    final value = result == .success ? _readGridRef(ptr) : _emptyGridRef;
    _freeGridRef(ptr);
    return (result, value);
  }

  @override
  CResult<RawSelectionGestureState> selectionGestureGetState(
    int gesture,
    int terminal,
  ) {
    const keys = _selectionGestureStateKeys;
    for (var i = 0; i < keys.length; i++) {
      _mem.writeU32(_multiKeys + i * _wasmEnumSize, keys[i].value);
      _mem.writeU32(
        _multiValues + i * _wasmPointerSize,
        _multiOut + i * _wasmOutputSlotSize,
      );
    }
    _writeGridRef(_multiGridRef, _emptyGridRef);
    _mem.writeU32(_multiValues + 4 * _wasmPointerSize, _multiGridRef);
    final result = Result.fromValue(
      _exports.ghostty_selection_gesture_get_multi(
        gesture,
        terminal,
        keys.length,
        _multiKeys,
        _multiValues,
        _multiWritten,
      ),
    );
    final anchorAbsent = result == .noValue && _mem.readU32(_multiWritten) == 4;
    if (result != .success && !anchorAbsent) {
      return (result, _emptySelectionGestureState);
    }
    return (
      anchorAbsent ? .success : result,
      (
        clickCount: _mem.readU8(_multiOut),
        dragged: _mem.readU8(_multiOut + _wasmOutputSlotSize) != 0,
        autoscroll: .fromValue(
          _mem.readI32(_multiOut + 2 * _wasmOutputSlotSize),
        ),
        behavior: .fromValue(_mem.readI32(_multiOut + 3 * _wasmOutputSlotSize)),
        anchor: anchorAbsent ? null : _readGridRef(_multiGridRef),
      ),
    );
  }

  @override
  CResult<int> formatterTerminalNew(
    int terminal,
    FormatterFormat format, {
    bool unwrap = false,
    bool trim = false,
    FormatterExtra extra = const FormatterExtra(),
    RawSelection? selection,
  }) {
    final optsSize = _layout.formatterOptsSize;
    final outPtr = _exports.ghostty_wasm_alloc_opaque();
    final optsPtr = _exports.ghostty_wasm_alloc_u8_array(optsSize);

    // Zero the entire struct first, then populate fields.
    for (var i = 0; i < optsSize; i++) {
      _mem.writeU8(optsPtr + i, 0);
    }

    _mem.writeU32(optsPtr, optsSize);
    _mem.writeU32(optsPtr + _layout.formatterOptsFormat, format.value);
    _mem.writeU8(optsPtr + _layout.formatterOptsUnwrap, unwrap ? 1 : 0);
    _mem.writeU8(optsPtr + _layout.formatterOptsTrim, trim ? 1 : 0);

    final extraBase = optsPtr + _layout.formatterOptsExtra;
    _mem.writeU32(extraBase, _layout.formatterTermExtraSize);
    _mem.writeU8(
      extraBase + _layout.formatterTermExtraPalette,
      extra.palette ? 1 : 0,
    );
    _mem.writeU8(
      extraBase + _layout.formatterTermExtraModes,
      extra.modes ? 1 : 0,
    );
    _mem.writeU8(
      extraBase + _layout.formatterTermExtraScrollingRegion,
      extra.scrollingRegion ? 1 : 0,
    );
    _mem.writeU8(
      extraBase + _layout.formatterTermExtraTabstops,
      extra.tabstops ? 1 : 0,
    );
    _mem.writeU8(extraBase + _layout.formatterTermExtraPwd, extra.pwd ? 1 : 0);
    _mem.writeU8(
      extraBase + _layout.formatterTermExtraKeyboard,
      extra.keyboard ? 1 : 0,
    );

    final screenBase = extraBase + _layout.formatterTermExtraScreen;
    _mem.writeU32(screenBase, _layout.formatterScreenExtraSize);
    _mem.writeU8(
      screenBase + _layout.formatterScreenExtraCursor,
      extra.cursor ? 1 : 0,
    );
    _mem.writeU8(
      screenBase + _layout.formatterScreenExtraStyle,
      extra.style ? 1 : 0,
    );
    _mem.writeU8(
      screenBase + _layout.formatterScreenExtraHyperlink,
      extra.hyperlink ? 1 : 0,
    );
    _mem.writeU8(
      screenBase + _layout.formatterScreenExtraProtection,
      extra.protection ? 1 : 0,
    );
    _mem.writeU8(
      screenBase + _layout.formatterScreenExtraKittyKeyboard,
      extra.kittyKeyboard ? 1 : 0,
    );
    _mem.writeU8(
      screenBase + _layout.formatterScreenExtraCharsets,
      extra.charsets ? 1 : 0,
    );

    var selPtr = 0;
    if (selection != null) {
      selPtr = _exports.ghostty_wasm_alloc_u8_array(_layout.selectionSize);
      _mem.writeU32(selPtr, _layout.selectionSize);
      final startDst = selPtr + _layout.selectionStart;
      final endDst = selPtr + _layout.selectionEnd;
      _writeGridRef(startDst, selection.start);
      _writeGridRef(endDst, selection.end);
      _mem.writeU8(
        selPtr + _layout.selectionRectangle,
        selection.rectangle ? 1 : 0,
      );
    }
    _mem.writeU32(optsPtr + _layout.formatterOptsSelection, selPtr);

    final result = _exports.ghostty_formatter_terminal_new(
      0,
      outPtr,
      terminal,
      optsPtr,
    );
    final handle = _mem.readPtr(outPtr);
    _exports.ghostty_wasm_free_opaque(outPtr);
    _exports.ghostty_wasm_free_u8_array(optsPtr, optsSize);
    if (selPtr != 0) {
      _exports.ghostty_wasm_free_u8_array(selPtr, _layout.selectionSize);
    }
    return (.fromValue(result), handle);
  }

  @override
  void formatterFree(int formatter) {
    _exports.ghostty_formatter_free(formatter);
  }

  @override
  CResult<String> formatterFormat(int formatter) {
    var result = Result.fromValue(
      _exports.ghostty_formatter_format_buf(
        formatter,
        _formatBuffer,
        _formatBufferCapacity,
        _multiWritten,
      ),
    );
    if (result == .outOfSpace) {
      _growFormatBuffer(_mem.readU32(_multiWritten));
      result = Result.fromValue(
        _exports.ghostty_formatter_format_buf(
          formatter,
          _formatBuffer,
          _formatBufferCapacity,
          _multiWritten,
        ),
      );
    }
    final len = _mem.readU32(_multiWritten);
    if (result != .success || len == 0) return (result, '');
    return (result, utf8.decode(_mem.readBytes(_formatBuffer, len)));
  }

  CResult<int> _terminalGetU16(int handle, TerminalData data) {
    final outPtr = _exports.ghostty_wasm_alloc_usize();
    final result = Result.fromValue(
      _exports.ghostty_terminal_get(handle, data.value, outPtr),
    );
    final value = _mem.readU16(outPtr);
    _exports.ghostty_wasm_free_usize(outPtr);
    return (result, value);
  }

  CResult<bool> _terminalGetBool(int handle, TerminalData data) {
    final outPtr = _exports.ghostty_wasm_alloc_u8();
    final result = _exports.ghostty_terminal_get(handle, data.value, outPtr);
    final value = _mem.readU8(outPtr) != 0;
    _exports.ghostty_wasm_free_u8(outPtr);
    return (.fromValue(result), value);
  }

  CResult<int> _terminalGetU32(int handle, TerminalData data) {
    final outPtr = _exports.ghostty_wasm_alloc_usize();
    final result = _exports.ghostty_terminal_get(handle, data.value, outPtr);
    final value = _mem.readU32(outPtr);
    _exports.ghostty_wasm_free_usize(outPtr);
    return (.fromValue(result), value);
  }

  CResult<int> _terminalGetU64(int handle, TerminalData data) {
    final outPtr = _exports.ghostty_wasm_alloc_u8_array(8);
    final result = _exports.ghostty_terminal_get(handle, data.value, outPtr);
    final value = _mem.readU64(outPtr);
    _exports.ghostty_wasm_free_u8_array(outPtr, 8);
    return (.fromValue(result), value);
  }

  String _readString(int pointer) {
    final data = _mem.readPtr(pointer);
    final length = _mem.readU32(pointer + _layout.stringLen);
    return length == 0 ? '' : utf8.decode(_mem.readBytes(data, length));
  }

  CResult<Style> _terminalGetStyle(int handle, TerminalData data) {
    final stylePtr = _exports.ghostty_wasm_alloc_u8_array(_layout.styleSize);
    _mem.writeU32(stylePtr, _layout.styleSize);
    final result = _exports.ghostty_terminal_get(handle, data.value, stylePtr);
    final value = _readStyle(stylePtr);
    _exports.ghostty_wasm_free_u8_array(stylePtr, _layout.styleSize);
    return (.fromValue(result), value);
  }

  Result _terminalSetBool(int handle, TerminalOption option, bool? value) {
    if (value == null) {
      return .fromValue(_exports.ghostty_terminal_set(handle, option.value, 0));
    }
    final ptr = _exports.ghostty_wasm_alloc_u8();
    _mem.writeU8(ptr, value ? 1 : 0);
    final result = _exports.ghostty_terminal_set(handle, option.value, ptr);
    _exports.ghostty_wasm_free_u8(ptr);
    return .fromValue(result);
  }

  Result _terminalSetI32(int handle, TerminalOption option, int? value) {
    if (value == null) {
      return .fromValue(_exports.ghostty_terminal_set(handle, option.value, 0));
    }
    final ptr = _exports.ghostty_wasm_alloc_usize();
    _mem.writeI32(ptr, value);
    final result = _exports.ghostty_terminal_set(handle, option.value, ptr);
    _exports.ghostty_wasm_free_usize(ptr);
    return .fromValue(result);
  }

  Result _terminalSetU64(int handle, TerminalOption option, int? value) {
    if (value == null) {
      return .fromValue(_exports.ghostty_terminal_set(handle, option.value, 0));
    }
    final ptr = _exports.ghostty_wasm_alloc_u8_array(8);
    _mem.writeU32(ptr, value & 0xFFFFFFFF);
    _mem.writeU32(ptr + 4, value >> 32);
    final result = _exports.ghostty_terminal_set(handle, option.value, ptr);
    _exports.ghostty_wasm_free_u8_array(ptr, 8);
    return .fromValue(result);
  }

  Result _terminalSetSize(int handle, TerminalOption option, int? value) {
    if (value == null) {
      return .fromValue(_exports.ghostty_terminal_set(handle, option.value, 0));
    }
    final ptr = _exports.ghostty_wasm_alloc_usize();
    _mem.writeU32(ptr, value);
    final result = _exports.ghostty_terminal_set(handle, option.value, ptr);
    _exports.ghostty_wasm_free_usize(ptr);
    return .fromValue(result);
  }

  CResult<String> _terminalGetString(int handle, TerminalData data) {
    final strSize = _layout.stringSize;
    final strPtr = _exports.ghostty_wasm_alloc_u8_array(strSize);
    final result = Result.fromValue(
      _exports.ghostty_terminal_get(handle, data.value, strPtr),
    );
    if (result != .success) {
      _exports.ghostty_wasm_free_u8_array(strPtr, strSize);
      return (result, '');
    }
    final ptr = _mem.readU32(strPtr);
    final len = _mem.readU32(strPtr + _layout.stringLen);
    _exports.ghostty_wasm_free_u8_array(strPtr, strSize);
    if (len == 0 || ptr == 0) return (result, '');
    return (result, utf8.decode(_mem.readBytes(ptr, len)));
  }

  Result _terminalSetString(int handle, TerminalOption option, String? value) {
    if (value == null) {
      return .fromValue(_exports.ghostty_terminal_set(handle, option.value, 0));
    }
    final encoded = utf8.encode(value);
    final strSize = _layout.stringSize;
    final strPtr = _exports.ghostty_wasm_alloc_u8_array(strSize);
    final bytesPtr = _exports.ghostty_wasm_alloc_u8_array(encoded.length);
    _mem.writeBytes(bytesPtr, encoded);
    _mem.writeU32(strPtr, bytesPtr);
    _mem.writeU32(strPtr + _layout.stringLen, encoded.length);
    final result = _exports.ghostty_terminal_set(handle, option.value, strPtr);
    _exports.ghostty_wasm_free_u8_array(bytesPtr, encoded.length);
    _exports.ghostty_wasm_free_u8_array(strPtr, strSize);
    return .fromValue(result);
  }

  CResult<RgbColor> _terminalGetColor(int handle, TerminalData data) {
    final rgbSize = _layout.colorRgbSize;
    final ptr = _exports.ghostty_wasm_alloc_u8_array(rgbSize);
    final result = _exports.ghostty_terminal_get(handle, data.value, ptr);
    final rgb = RgbColor(
      _mem.readU8(ptr),
      _mem.readU8(ptr + _layout.colorRgbG),
      _mem.readU8(ptr + _layout.colorRgbB),
    );
    _exports.ghostty_wasm_free_u8_array(ptr, rgbSize);
    return (.fromValue(result), rgb);
  }

  CResult<List<RgbColor>> _terminalGetPalette(int handle, TerminalData data) {
    final paletteSize = 256 * _layout.colorRgbSize;
    final ptr = _exports.ghostty_wasm_alloc_u8_array(paletteSize);
    final result = Result.fromValue(
      _exports.ghostty_terminal_get(handle, data.value, ptr),
    );

    if (result != .success) {
      _exports.ghostty_wasm_free_u8_array(ptr, paletteSize);
      return (result, const []);
    }

    final palette = <RgbColor>[
      for (var i = 0; i < 256; i++)
        RgbColor(
          _mem.readU8(ptr + i * _layout.colorRgbSize),
          _mem.readU8(ptr + i * _layout.colorRgbSize + _layout.colorRgbG),
          _mem.readU8(ptr + i * _layout.colorRgbSize + _layout.colorRgbB),
        ),
    ];
    _exports.ghostty_wasm_free_u8_array(ptr, paletteSize);
    return (result, palette);
  }

  Result _terminalSetColor(int handle, TerminalOption option, RgbColor? color) {
    if (color == null) {
      return .fromValue(_exports.ghostty_terminal_set(handle, option.value, 0));
    }
    final rgbSize = _layout.colorRgbSize;
    final ptr = _exports.ghostty_wasm_alloc_u8_array(rgbSize);
    _mem.writeU8(ptr, color.r);
    _mem.writeU8(ptr + _layout.colorRgbG, color.g);
    _mem.writeU8(ptr + _layout.colorRgbB, color.b);
    final result = _exports.ghostty_terminal_set(handle, option.value, ptr);
    _exports.ghostty_wasm_free_u8_array(ptr, rgbSize);
    return .fromValue(result);
  }

  CResult<int> _terminalGetI32(int handle, TerminalData data) {
    final outPtr = _exports.ghostty_wasm_alloc_usize();
    final result = _exports.ghostty_terminal_get(handle, data.value, outPtr);
    final value = _mem.readI32(outPtr);
    _exports.ghostty_wasm_free_usize(outPtr);
    return (.fromValue(result), value);
  }

  CResult<int> _renderStateGetU16(int state, RenderStateData data) {
    final outPtr = _exports.ghostty_wasm_alloc_usize();
    final result = _exports.ghostty_render_state_get(state, data.value, outPtr);
    final value = _mem.readU16(outPtr);
    _exports.ghostty_wasm_free_usize(outPtr);
    return (.fromValue(result), value);
  }

  CResult<bool> _renderStateGetBool(int state, RenderStateData data) {
    final outPtr = _exports.ghostty_wasm_alloc_u8();
    final result = _exports.ghostty_render_state_get(state, data.value, outPtr);
    final value = _mem.readU8(outPtr) != 0;
    _exports.ghostty_wasm_free_u8(outPtr);
    return (.fromValue(result), value);
  }

  Result _terminalGetMulti(int handle, List<TerminalData> keys) {
    for (var i = 0; i < keys.length; i++) {
      _mem.writeU32(_multiKeys + i * _wasmEnumSize, keys[i].value);
      _mem.writeU32(
        _multiValues + i * _wasmPointerSize,
        _multiOut + i * _wasmOutputSlotSize,
      );
    }
    return .fromValue(
      _exports.ghostty_terminal_get_multi(
        handle,
        keys.length,
        _multiKeys,
        _multiValues,
        _multiWritten,
      ),
    );
  }

  void _growFormatBuffer(int capacity) {
    if (capacity <= _formatBufferCapacity) return;
    final replacement = _allocateBytes(capacity);
    _exports.ghostty_wasm_free_u8_array(_formatBuffer, _formatBufferCapacity);
    _formatBuffer = replacement;
    _formatBufferCapacity = capacity;
  }

  CResult<int> _renderStateGetI32(int state, RenderStateData data) {
    final outPtr = _exports.ghostty_wasm_alloc_usize();
    final result = _exports.ghostty_render_state_get(state, data.value, outPtr);
    final value = _mem.readI32(outPtr);
    _exports.ghostty_wasm_free_usize(outPtr);
    return (.fromValue(result), value);
  }

  CResult<int> _cellGetU16(int cell, CellData data) {
    final outPtr = _exports.ghostty_wasm_alloc_usize();
    final result = _callCellGet(cell, data, outPtr);
    final value = _mem.readU16(outPtr);
    _exports.ghostty_wasm_free_usize(outPtr);
    return (.fromValue(result), value);
  }

  CResult<int> _cellGetU32(int cell, CellData data) {
    final outPtr = _exports.ghostty_wasm_alloc_usize();
    final result = _callCellGet(cell, data, outPtr);
    final value = _mem.readU32(outPtr);
    _exports.ghostty_wasm_free_usize(outPtr);
    return (.fromValue(result), value);
  }

  CResult<int> _cellGetI32(int cell, CellData data) {
    final outPtr = _exports.ghostty_wasm_alloc_usize();
    final result = _callCellGet(cell, data, outPtr);
    final value = _mem.readI32(outPtr);
    _exports.ghostty_wasm_free_usize(outPtr);
    return (.fromValue(result), value);
  }

  CResult<bool> _cellGetBool(int cell, CellData data) {
    final outPtr = _exports.ghostty_wasm_alloc_u8();
    final result = _callCellGet(cell, data, outPtr);
    final value = _mem.readU8(outPtr) != 0;
    _exports.ghostty_wasm_free_u8(outPtr);
    return (.fromValue(result), value);
  }

  CResult<bool> _rowGetBool(int row, RowData data) {
    final outPtr = _exports.ghostty_wasm_alloc_u8();
    final result = _callRowGet(row, data, outPtr);
    final value = _mem.readU8(outPtr) != 0;
    _exports.ghostty_wasm_free_u8(outPtr);
    return (.fromValue(result), value);
  }

  int _callCellGet(int cell, CellData data, int outPtr) {
    final fn = (_exports as JSObject)['ghostty_cell_get']! as JSFunction;
    return (fn.callAsFunction(
              null,
              _toBigInt(cell),
              data.value.toJS,
              outPtr.toJS,
            )!
            as JSNumber)
        .toDartInt;
  }

  int _callCellGetMulti(
    int cell,
    int count,
    int keys,
    int values,
    int outWritten,
  ) {
    // WebAssembly exposes i64 parameters as JavaScript BigInt values, while
    // Dart's typed callAsFunction overload accepts only four arguments. These
    // C functions take five, so callMethodVarArgs is the supported bridge. The
    // argument lists are reused because this path runs for every cell and row.
    // https://api.dart.dev/dart-js_interop_unsafe/JSObjectUnsafeUtilExtension/callMethodVarArgs.html
    final arguments = _cellGetMultiArguments;
    arguments[0] = _toBigInt(cell);
    arguments[1] = count.toJS;
    arguments[2] = keys.toJS;
    arguments[3] = values.toJS;
    arguments[4] = outWritten.toJS;
    return (_exports as JSObject)
        .callMethodVarArgs<JSNumber>(_cellGetMultiMethod, arguments)
        .toDartInt;
  }

  int _callRowGet(int row, RowData data, int outPtr) {
    final fn = (_exports as JSObject)['ghostty_row_get']! as JSFunction;
    return (fn.callAsFunction(
              null,
              _toBigInt(row),
              data.value.toJS,
              outPtr.toJS,
            )!
            as JSNumber)
        .toDartInt;
  }

  int _callRowGetMulti(
    int row,
    int count,
    int keys,
    int values,
    int outWritten,
  ) {
    final arguments = _rowGetMultiArguments;
    arguments[0] = _toBigInt(row);
    arguments[1] = count.toJS;
    arguments[2] = keys.toJS;
    arguments[3] = values.toJS;
    arguments[4] = outWritten.toJS;
    return (_exports as JSObject)
        .callMethodVarArgs<JSNumber>(_rowGetMultiMethod, arguments)
        .toDartInt;
  }

  Style _readStyle(int stylePtr) {
    final ulRaw = _readRawColor(stylePtr + _layout.styleUnderlineColor);
    return Style(
      foreground: cellColorFromRaw(_readRawColor(stylePtr + _layout.styleFg)),
      background: cellColorFromRaw(_readRawColor(stylePtr + _layout.styleBg)),
      underlineColor: switch (ulRaw.tag) {
        .rgb || .palette => cellColorFromRaw(ulRaw),
        .none => null,
      },
      bold: _mem.readU8(stylePtr + _layout.styleBold) != 0,
      italic: _mem.readU8(stylePtr + _layout.styleItalic) != 0,
      faint: _mem.readU8(stylePtr + _layout.styleFaint) != 0,
      blink: _mem.readU8(stylePtr + _layout.styleBlink) != 0,
      inverse: _mem.readU8(stylePtr + _layout.styleInverse) != 0,
      invisible: _mem.readU8(stylePtr + _layout.styleInvisible) != 0,
      strikethrough: _mem.readU8(stylePtr + _layout.styleStrikethrough) != 0,
      overline: _mem.readU8(stylePtr + _layout.styleOverline) != 0,
      underline: .fromValue(_mem.readI32(stylePtr + _layout.styleUnderline)),
    );
  }

  RawColor _readRawColor(int addr) {
    return (
      tag: StyleColorTag.fromValue(_mem.readU32(addr)),
      palette: _mem.readU8(addr + _layout.styleColorR),
      r: _mem.readU8(addr + _layout.styleColorR),
      g: _mem.readU8(addr + _layout.styleColorG),
      b: _mem.readU8(addr + _layout.styleColorB),
    );
  }

  void _writeStyle(int stylePtr, Style style) {
    _writeStyleColor(stylePtr + _layout.styleFg, style.foreground);
    _writeStyleColor(stylePtr + _layout.styleBg, style.background);
    _writeStyleColor(
      stylePtr + _layout.styleUnderlineColor,
      style.underlineColor,
    );
    _mem.writeU8(stylePtr + _layout.styleBold, style.bold ? 1 : 0);
    _mem.writeU8(stylePtr + _layout.styleItalic, style.italic ? 1 : 0);
    _mem.writeU8(stylePtr + _layout.styleFaint, style.faint ? 1 : 0);
    _mem.writeU8(stylePtr + _layout.styleBlink, style.blink ? 1 : 0);
    _mem.writeU8(stylePtr + _layout.styleInverse, style.inverse ? 1 : 0);
    _mem.writeU8(stylePtr + _layout.styleInvisible, style.invisible ? 1 : 0);
    _mem.writeU8(
      stylePtr + _layout.styleStrikethrough,
      style.strikethrough ? 1 : 0,
    );
    _mem.writeU8(stylePtr + _layout.styleOverline, style.overline ? 1 : 0);
    _mem.writeI32(stylePtr + _layout.styleUnderline, style.underline.value);
  }

  void _writeStyleColor(int addr, CellColor? color) {
    switch (color) {
      case RgbColor(:final r, :final g, :final b):
        _mem.writeU32(addr, StyleColorTag.rgb.value);
        _mem.writeU8(addr + _layout.styleColorR, r);
        _mem.writeU8(addr + _layout.styleColorG, g);
        _mem.writeU8(addr + _layout.styleColorB, b);
      case PaletteColor(:final index):
        _mem.writeU32(addr, StyleColorTag.palette.value);
        _mem.writeU8(addr + _layout.styleColorR, index);
        _mem.writeU8(addr + _layout.styleColorG, 0);
        _mem.writeU8(addr + _layout.styleColorB, 0);
      case DefaultColor() || null:
        _mem.writeU32(addr, StyleColorTag.none.value);
        _mem.writeU8(addr + _layout.styleColorR, 0);
        _mem.writeU8(addr + _layout.styleColorG, 0);
        _mem.writeU8(addr + _layout.styleColorB, 0);
    }
  }

  void _writePoint(int pointPtr, PointTag pointTag, Position position) {
    _mem.writeU32(pointPtr, pointTag.value);
    _mem.writeU16(pointPtr + _layout.pointX, position.col);
    _mem.writeU32(pointPtr + _layout.pointY, position.row);
  }

  void _zero(int ptr, int len) {
    for (var i = 0; i < len; i++) {
      _mem.writeU8(ptr + i, 0);
    }
  }

  int _allocGridRef(RawGridRef ref) {
    final ptr = _exports.ghostty_wasm_alloc_u8_array(_layout.gridRefSize);
    _writeGridRef(ptr, ref);
    return ptr;
  }

  void _freeGridRef(int ptr) {
    _exports.ghostty_wasm_free_u8_array(ptr, _layout.gridRefSize);
  }

  RawGridRef _readGridRef(int ptr) {
    return (
      node: _mem.readPtr(ptr + _layout.gridRefNode),
      x: _mem.readU16(ptr + _layout.gridRefX),
      y: _mem.readU16(ptr + _layout.gridRefY),
    );
  }

  void _writeGridRef(int ptr, RawGridRef ref) {
    _mem.writeU32(ptr, _layout.gridRefSize);
    _mem.writeU32(ptr + _layout.gridRefNode, ref.node);
    _mem.writeU16(ptr + _layout.gridRefX, ref.x);
    _mem.writeU16(ptr + _layout.gridRefY, ref.y);
  }

  int _allocSelection([RawSelection? selection]) {
    final ptr = _exports.ghostty_wasm_alloc_u8_array(_layout.selectionSize);
    _zero(ptr, _layout.selectionSize);
    _mem.writeU32(ptr, _layout.selectionSize);
    if (selection != null) _writeSelection(ptr, selection);
    return ptr;
  }

  RawSelection _readSelection(int ptr) {
    return (
      start: _readGridRef(ptr + _layout.selectionStart),
      end: _readGridRef(ptr + _layout.selectionEnd),
      rectangle: _mem.readU8(ptr + _layout.selectionRectangle) != 0,
    );
  }

  void _writeSelection(int ptr, RawSelection selection) {
    _mem.writeU32(ptr, _layout.selectionSize);
    _writeGridRef(ptr + _layout.selectionStart, selection.start);
    _writeGridRef(ptr + _layout.selectionEnd, selection.end);
    _mem.writeU8(ptr + _layout.selectionRectangle, selection.rectangle ? 1 : 0);
  }

  ({int ptr, int bytes}) _allocCodepoints(List<int>? codepoints) {
    if (codepoints == null) return (ptr: 0, bytes: 0);
    final bytes = (codepoints.isEmpty ? 1 : codepoints.length) * 4;
    final ptr = _exports.ghostty_wasm_alloc_u8_array(bytes);
    for (var i = 0; i < codepoints.length; i++) {
      _mem.writeU32(ptr + i * 4, codepoints[i]);
    }
    return (ptr: ptr, bytes: bytes);
  }

  void _freeCodepoints(({int ptr, int bytes}) codepoints) {
    if (codepoints.ptr == 0) return;
    _exports.ghostty_wasm_free_u8_array(codepoints.ptr, codepoints.bytes);
  }

  ({int ptr, int len, int allocLen}) _allocUtf8Bytes(String value) {
    final encoded = utf8.encode(value);
    final allocLen = encoded.isEmpty ? 1 : encoded.length;
    final ptr = _exports.ghostty_wasm_alloc_u8_array(allocLen);
    _mem.writeBytes(ptr, encoded);
    return (ptr: ptr, len: encoded.length, allocLen: allocLen);
  }

  int _allocRgb(RgbColor color) {
    final ptr = _exports.ghostty_wasm_alloc_u8_array(_layout.colorRgbSize);
    _writeRgb(ptr, color);
    return ptr;
  }

  RgbColor _readRgb(int ptr) {
    return RgbColor(
      _mem.readU8(ptr),
      _mem.readU8(ptr + _layout.colorRgbG),
      _mem.readU8(ptr + _layout.colorRgbB),
    );
  }

  List<RgbColor> _readPalette(int ptr) {
    return <RgbColor>[
      for (var i = 0; i < 256; i++) _readRgb(ptr + i * _layout.colorRgbSize),
    ];
  }

  void _writeRgb(int ptr, RgbColor color) {
    _mem.writeU8(ptr, color.r);
    _mem.writeU8(ptr + _layout.colorRgbG, color.g);
    _mem.writeU8(ptr + _layout.colorRgbB, color.b);
  }

  SgrAttribute _readSgrAttribute(int attrPtr) {
    final tag = _exports.ghostty_sgr_attribute_tag(attrPtr);
    final valuePtr = _exports.ghostty_sgr_attribute_value(attrPtr);
    final tagEnum = SgrAttributeTag.fromValue(tag);
    return switch (tagEnum) {
      .unknown => _readSgrUnknown(valuePtr),
      .underline => SgrAttribute(
        underlineStyle: .fromValue(_mem.readI32(valuePtr)),
        tag: tagEnum,
      ),
      .underlineColor ||
      .directColorFg ||
      .directColorBg => _readSgrRgb(tagEnum, valuePtr),
      .underlineColor256 ||
      .fg8 ||
      .bg8 ||
      .brightFg8 ||
      .brightBg8 ||
      .fg256 ||
      .bg256 => SgrAttribute(tag: tagEnum, paletteIndex: _mem.readU8(valuePtr)),
      _ => SgrAttribute(tag: tagEnum),
    };
  }

  SgrAttribute _readSgrRgb(SgrAttributeTag tag, int valuePtr) {
    final rPtr = _exports.ghostty_wasm_alloc_u8();
    final gPtr = _exports.ghostty_wasm_alloc_u8();
    final bPtr = _exports.ghostty_wasm_alloc_u8();
    _exports.ghostty_color_rgb_get(valuePtr, rPtr, gPtr, bPtr);
    final result = SgrAttribute(
      tag: tag,
      color: RgbColor(_mem.readU8(rPtr), _mem.readU8(gPtr), _mem.readU8(bPtr)),
    );
    _exports.ghostty_wasm_free_u8(rPtr);
    _exports.ghostty_wasm_free_u8(gPtr);
    _exports.ghostty_wasm_free_u8(bPtr);
    return result;
  }

  static final _jsBigInt = globalContext['BigInt']! as JSFunction;

  static JSAny _toBigInt(int value) {
    return _jsBigInt.callAsFunction(null, value.toJS)!;
  }

  SgrAttribute _readSgrUnknown(int valuePtr) {
    final fullOutPtr = _exports.ghostty_wasm_alloc_opaque();
    final partialOutPtr = _exports.ghostty_wasm_alloc_opaque();
    final fullLen = _exports.ghostty_sgr_unknown_full(valuePtr, fullOutPtr);
    final partialLen = _exports.ghostty_sgr_unknown_partial(
      valuePtr,
      partialOutPtr,
    );

    final fullPtrAddr = _mem.readPtr(fullOutPtr);
    final partialPtrAddr = _mem.readPtr(partialOutPtr);

    final full = <int>[];
    for (var i = 0; i < fullLen; i++) {
      full.add(_mem.readU16(fullPtrAddr + i * 2));
    }

    final partial = <int>[];
    for (var i = 0; i < partialLen; i++) {
      partial.add(_mem.readU16(partialPtrAddr + i * 2));
    }

    _exports.ghostty_wasm_free_opaque(fullOutPtr);
    _exports.ghostty_wasm_free_opaque(partialOutPtr);
    return SgrAttribute(
      tag: .unknown,
      unknownFull: full,
      unknownPartial: partial,
    );
  }
}
