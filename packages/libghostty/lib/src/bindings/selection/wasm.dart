import 'dart:convert';

import '../../generated/libghostty_enums.g.dart';
import '../../generated/libghostty_wasm.g.dart';
import '../../types/types.dart';
import '../result_helpers.dart';
import '../types.dart';
import '../wasm/allocation_owner.dart';
import '../wasm/allocator.dart';
import '../wasm/layouts.dart';
import '../wasm/memory.dart';
import '../wasm/scratch.dart';
import 'selection.dart';

const RawGridRef _emptyGridRef = (node: 0, x: 0, y: 0);
const _formatBufferInitialCapacity = 4096;
const _wasmEnumSize = 4;
const _wasmOutputSlotSize = 8;

const _wasmPointerSize = 4;

final class WasmSelectionBindings implements SelectionBindings {
  final Memory _memory;
  final Layouts _layout;
  final GhosttyExports _exports;
  final WasmScratchPool _scratch;
  late int _formatBuffer;
  var _formatBufferCapacity = _formatBufferInitialCapacity;
  late final int _outSize;
  late final int _multiKeys;
  late final int _multiValues;
  late final int _multiOut;
  late final int _multiGridRef;

  factory WasmSelectionBindings(GhosttyExports exports, Layouts layout) {
    final owner = WasmAllocationOwner(exports);
    try {
      final bindings = WasmSelectionBindings._(exports, layout, owner);
      owner.commit();
      return bindings;
    } on Object {
      owner.rollback();
      rethrow;
    }
  }

  WasmSelectionBindings._(
    this._exports,
    this._layout,
    WasmAllocationOwner owner,
  ) : _memory = Memory(_exports),
      _scratch = WasmScratchPool(
        WasmExportScratchAllocator(_exports),
        maxVariableLength: WasmScratchPool.defaultMaxVariableLength,
      ) {
    _formatBuffer = owner.allocate(_formatBufferCapacity);
    _outSize = _allocatePersistentSize(owner);
    _multiKeys = owner.allocate(5 * _wasmEnumSize);
    _multiValues = owner.allocate(5 * _wasmPointerSize);
    _multiOut = owner.allocate(5 * _wasmOutputSlotSize);
    _multiGridRef = owner.allocate(_layout.gridRefSize);
  }

  @override
  RawSelection? selectionGestureEvent(
    LibGhosttyHandle gesture,
    LibGhosttyHandle terminal,
    LibGhosttyHandle event,
  ) {
    final out = _allocSelection();
    try {
      final result = Result.fromValue(
        _exports.ghostty_selection_gesture_event(
          gesture.value,
          terminal.value,
          event.value,
          out,
        ),
      );
      if (result == .noValue) return null;
      _check(result, 'ghostty_selection_gesture_event');
      return _readSelection(out);
    } finally {
      _freeBytes(out, _layout.selectionSize);
    }
  }

  @override
  void selectionGestureEventClear(
    LibGhosttyHandle event,
    SelectionGestureEventOption option,
  ) => _setEvent(event, option, 0);

  @override
  void selectionGestureEventFree(LibGhosttyHandle event) =>
      _exports.ghostty_selection_gesture_event_free(event.value);

  @override
  LibGhosttyHandle selectionGestureEventNew(SelectionGestureEventType type) {
    final out = _exports.allocateOpaque();
    if (out == 0) throw const OutOfMemoryException();
    try {
      final result = Result.fromValue(
        _exports.ghostty_selection_gesture_event_new(0, out, type.value),
      );
      _check(result, 'ghostty_selection_gesture_event_new');
      return .fromAddress(_exports.ghostty_wasm_take_opaque(out));
    } finally {
      _exports.freeOpaque(out);
    }
  }

  @override
  void selectionGestureEventSetBehaviors(
    LibGhosttyHandle event,
    SelectionGestureBehavior singleClick,
    SelectionGestureBehavior doubleClick,
    SelectionGestureBehavior tripleClick,
  ) {
    final ptr = _allocateBytes(_layout.gestureBehaviorsSize);
    try {
      _memory.writeU32(
        ptr + _layout.gestureBehaviorsSingleClick,
        singleClick.value,
      );
      _memory.writeU32(
        ptr + _layout.gestureBehaviorsDoubleClick,
        doubleClick.value,
      );
      _memory.writeU32(
        ptr + _layout.gestureBehaviorsTripleClick,
        tripleClick.value,
      );
      _setEvent(event, .behaviors, ptr);
    } finally {
      _freeBytes(ptr, _layout.gestureBehaviorsSize);
    }
  }

  @override
  void selectionGestureEventSetGeometry(
    LibGhosttyHandle event, {
    required int columns,
    required int cellWidth,
    required int paddingLeft,
    required int screenHeight,
  }) {
    final ptr = _allocateBytes(_layout.gestureGeometrySize);
    try {
      _memory.writeU32(ptr + _layout.gestureGeometryColumns, columns);
      _memory.writeU32(ptr + _layout.gestureGeometryCellWidth, cellWidth);
      _memory.writeU32(ptr + _layout.gestureGeometryPaddingLeft, paddingLeft);
      _memory.writeU32(ptr + _layout.gestureGeometryScreenHeight, screenHeight);
      _setEvent(event, .geometry, ptr);
    } finally {
      _freeBytes(ptr, _layout.gestureGeometrySize);
    }
  }

  @override
  void selectionGestureEventSetPosition(
    LibGhosttyHandle event,
    double x,
    double y,
  ) {
    final ptr = _allocateBytes(_layout.surfacePositionSize);
    try {
      _memory.writeF64(ptr + _layout.surfacePositionX, x);
      _memory.writeF64(ptr + _layout.surfacePositionY, y);
      _setEvent(event, .position, ptr);
    } finally {
      _freeBytes(ptr, _layout.surfacePositionSize);
    }
  }

  @override
  void selectionGestureEventSetRectangle(
    LibGhosttyHandle event, {
    required bool value,
  }) => _setByteEvent(event, .rectangle, value ? 1 : 0);

  @override
  void selectionGestureEventSetRef(LibGhosttyHandle event, RawGridRef ref) {
    final ptr = _allocGridRef(ref);
    try {
      _setEvent(event, .ref, ptr);
    } finally {
      _freeGridRef(ptr);
    }
  }

  @override
  void selectionGestureEventSetRepeatDistance(
    LibGhosttyHandle event,
    double value,
  ) => _setScalarEvent(event, .repeatDistance, value, integer: false);

  @override
  void selectionGestureEventSetRepeatIntervalNs(
    LibGhosttyHandle event,
    int value,
  ) => _setScalarEvent(event, .repeatIntervalNs, value, integer: true);

  @override
  void selectionGestureEventSetTimeNs(LibGhosttyHandle event, int value) =>
      _setScalarEvent(event, .timeNs, value, integer: true);

  @override
  void selectionGestureEventSetViewport(
    LibGhosttyHandle event, {
    required Position position,
  }) {
    final ptr = _allocateBytes(_layout.pointCoordinateSize);
    try {
      _memory.writeU16(ptr + _layout.pointCoordinateX, position.col);
      _memory.writeU32(ptr + _layout.pointCoordinateY, position.row);
      _setEvent(event, .viewport, ptr);
    } finally {
      _freeBytes(ptr, _layout.pointCoordinateSize);
    }
  }

  @override
  void selectionGestureEventSetWordBoundaryCodepoints(
    LibGhosttyHandle event,
    List<int> codepoints,
  ) {
    final frame = _scratch.acquire(const []);
    try {
      final values = frame.variableAddress(
        0,
        (codepoints.isEmpty ? 1 : codepoints.length) * 4,
      );
      final pointer = frame.variableAddress(1, _layout.codepointsSize);
      for (var i = 0; i < codepoints.length; i++) {
        _memory.writeU32(values + i * 4, codepoints[i]);
      }
      _zero(pointer, _layout.codepointsSize);
      _memory.writeU32(pointer + _layout.codepointsPtr, values);
      _memory.writeU32(pointer + _layout.codepointsLen, codepoints.length);
      _setEvent(event, .wordBoundaryCodepoints, pointer);
    } finally {
      frame.release();
    }
  }

  @override
  void selectionGestureFree(
    LibGhosttyHandle gesture,
    LibGhosttyHandle terminal,
  ) => _exports.ghostty_selection_gesture_free(gesture.value, terminal.value);

  @override
  RawGridRef? selectionGestureGetAnchor(
    LibGhosttyHandle gesture,
    LibGhosttyHandle terminal,
  ) {
    final ptr = _allocGridRef(_emptyGridRef);
    try {
      final result = Result.fromValue(
        _exports.ghostty_selection_gesture_get(
          gesture.value,
          terminal.value,
          SelectionGestureData.anchor.value,
          ptr,
        ),
      );
      if (result == .noValue) return null;
      _check(result, 'ghostty_selection_gesture_get');
      return _readGridRef(ptr);
    } finally {
      _freeGridRef(ptr);
    }
  }

  @override
  SelectionGestureAutoscroll selectionGestureGetAutoscroll(
    LibGhosttyHandle gesture,
    LibGhosttyHandle terminal,
  ) {
    final value = _getU32(gesture, terminal, .autoscroll);
    return SelectionGestureAutoscroll.fromValue(value);
  }

  @override
  SelectionGestureBehavior selectionGestureGetBehavior(
    LibGhosttyHandle gesture,
    LibGhosttyHandle terminal,
  ) {
    final value = _getU32(gesture, terminal, .behavior);
    return SelectionGestureBehavior.fromValue(value);
  }

  @override
  int selectionGestureGetClickCount(
    LibGhosttyHandle gesture,
    LibGhosttyHandle terminal,
  ) => _getByte(gesture, terminal, .clickCount);

  @override
  bool selectionGestureGetDragged(
    LibGhosttyHandle gesture,
    LibGhosttyHandle terminal,
  ) => _getByte(gesture, terminal, .dragged) != 0;

  @override
  RawSelectionGestureState selectionGestureGetState(
    LibGhosttyHandle gesture,
    LibGhosttyHandle terminal,
  ) {
    const keys = <SelectionGestureData>[
      .clickCount,
      .dragged,
      .autoscroll,
      .behavior,
      .anchor,
    ];
    for (var i = 0; i < keys.length; i++) {
      _memory.writeU32(_multiKeys + i * _wasmEnumSize, keys[i].value);
      _memory.writeU32(
        _multiValues + i * _wasmPointerSize,
        _multiOut + i * _wasmOutputSlotSize,
      );
    }
    _writeGridRef(_multiGridRef, _emptyGridRef);
    _memory.writeU32(_multiValues + 4 * _wasmPointerSize, _multiGridRef);
    final result = Result.fromValue(
      _exports.ghostty_selection_gesture_get_multi(
        gesture.value,
        terminal.value,
        keys.length,
        _multiKeys,
        _multiValues,
        _outSize,
      ),
    );
    final anchorAbsent = result == .noValue && _memory.readU32(_outSize) == 4;
    if (result != .success && !anchorAbsent) {
      _check(result, 'ghostty_selection_gesture_get_multi');
    }
    return (
      clickCount: _memory.readU8(_multiOut),
      dragged: _memory.readU8(_multiOut + _wasmOutputSlotSize) != 0,
      autoscroll: SelectionGestureAutoscroll.fromValue(
        _memory.readI32(_multiOut + 2 * _wasmOutputSlotSize),
      ),
      behavior: SelectionGestureBehavior.fromValue(
        _memory.readI32(_multiOut + 3 * _wasmOutputSlotSize),
      ),
      anchor: anchorAbsent ? null : _readGridRef(_multiGridRef),
    );
  }

  @override
  LibGhosttyHandle selectionGestureNew() {
    final out = _exports.allocateOpaque();
    if (out == 0) throw const OutOfMemoryException();
    try {
      final result = Result.fromValue(
        _exports.ghostty_selection_gesture_new(0, out),
      );
      _check(result, 'ghostty_selection_gesture_new');
      return .fromAddress(_exports.ghostty_wasm_take_opaque(out));
    } finally {
      _exports.freeOpaque(out);
    }
  }

  @override
  void selectionGestureReset(
    LibGhosttyHandle gesture,
    LibGhosttyHandle terminal,
  ) => _exports.ghostty_selection_gesture_reset(gesture.value, terminal.value);

  @override
  RawSelection? terminalGetSelection(LibGhosttyHandle terminal) {
    final ptr = _allocSelection();
    try {
      final result = Result.fromValue(
        _exports.ghostty_terminal_get(
          terminal.value,
          TerminalData.selection.value,
          ptr,
        ),
      );
      if (result == .noValue) return null;
      _check(result, 'ghostty_terminal_get');
      return _readSelection(ptr);
    } finally {
      _freeBytes(ptr, _layout.selectionSize);
    }
  }

  @override
  RawSelection? terminalSelectAll(LibGhosttyHandle terminal) {
    final ptr = _allocSelection();
    try {
      final result = Result.fromValue(
        _exports.ghostty_terminal_select_all(terminal.value, ptr),
      );
      if (result == .noValue) return null;
      _check(result, 'ghostty_terminal_select_all');
      return _readSelection(ptr);
    } finally {
      _freeBytes(ptr, _layout.selectionSize);
    }
  }

  @override
  RawSelection terminalSelectionAdjust(
    LibGhosttyHandle terminal,
    RawSelection selection,
    SelectionAdjust adjustment,
  ) {
    final ptr = _allocSelection(selection);
    try {
      final result = Result.fromValue(
        _exports.ghostty_terminal_selection_adjust(
          terminal.value,
          ptr,
          adjustment.value,
        ),
      );
      _check(result, 'ghostty_terminal_selection_adjust');
      return _readSelection(ptr);
    } finally {
      _freeBytes(ptr, _layout.selectionSize);
    }
  }

  @override
  bool terminalSelectionContains(
    LibGhosttyHandle terminal,
    RawSelection selection,
    PointTag pointTag,
    Position position,
  ) {
    final frame = _scratch.acquire(const []);
    try {
      final sel = frame.variableAddress(0, _layout.selectionSize);
      final point = frame.variableAddress(1, _layout.pointSize);
      final out = frame.variableAddress(2, 1);
      _zero(sel, _layout.selectionSize);
      _writeSelection(sel, selection);
      _writePoint(point, pointTag, position);
      final result = Result.fromValue(
        _exports.ghostty_terminal_selection_contains(
          terminal.value,
          sel,
          point,
          out,
        ),
      );
      _check(result, 'ghostty_terminal_selection_contains');
      return _memory.readU8(out) != 0;
    } finally {
      frame.release();
    }
  }

  @override
  bool terminalSelectionEqual(
    LibGhosttyHandle terminal,
    RawSelection a,
    RawSelection b,
  ) {
    final frame = _scratch.acquire(const []);
    try {
      final first = frame.variableAddress(0, _layout.selectionSize);
      final second = frame.variableAddress(1, _layout.selectionSize);
      final out = frame.variableAddress(2, 1);
      _zero(first, _layout.selectionSize);
      _writeSelection(first, a);
      _zero(second, _layout.selectionSize);
      _writeSelection(second, b);
      final result = Result.fromValue(
        _exports.ghostty_terminal_selection_equal(
          terminal.value,
          first,
          second,
          out,
        ),
      );
      _check(result, 'ghostty_terminal_selection_equal');
      return _memory.readU8(out) != 0;
    } finally {
      frame.release();
    }
  }

  @override
  String? terminalSelectionFormat(
    LibGhosttyHandle terminal,
    FormatterFormat format, {
    bool unwrap = false,
    bool trim = false,
    RawSelection? selection,
  }) {
    final frame = _scratch.acquire(const []);
    try {
      final options = frame.variableAddress(0, _layout.selectionFormatSize);
      final selected = selection == null
          ? 0
          : frame.variableAddress(1, _layout.selectionSize);
      _zero(options, _layout.selectionFormatSize);
      _memory.writeU32(options, _layout.selectionFormatSize);
      _memory.writeU32(options + _layout.selectionFormatEmit, format.value);
      _memory.writeU8(options + _layout.selectionFormatUnwrap, unwrap ? 1 : 0);
      _memory.writeU8(options + _layout.selectionFormatTrim, trim ? 1 : 0);
      if (selection != null) {
        _zero(selected, _layout.selectionSize);
        _writeSelection(selected, selection);
      }
      _memory.writeU32(options + _layout.selectionFormatSelection, selected);
      var result = Result.fromValue(
        _exports.ghostty_terminal_selection_format_buf(
          terminal.value,
          options,
          _formatBuffer,
          _formatBufferCapacity,
          _outSize,
        ),
      );
      if (result == .outOfSpace) {
        _growFormatBuffer(_memory.readU32(_outSize));
        result = Result.fromValue(
          _exports.ghostty_terminal_selection_format_buf(
            terminal.value,
            options,
            _formatBuffer,
            _formatBufferCapacity,
            _outSize,
          ),
        );
      }
      if (result == .noValue) return null;
      _check(result, 'ghostty_terminal_selection_format_buf');
      final length = _memory.readU32(_outSize);
      return length == 0
          ? ''
          : utf8.decode(_memory.readBytes(_formatBuffer, length));
    } finally {
      frame.release();
    }
  }

  @override
  SelectionOrder terminalSelectionOrder(
    LibGhosttyHandle terminal,
    RawSelection selection,
  ) {
    final frame = _scratch.acquire(const []);
    try {
      final sel = frame.variableAddress(0, _layout.selectionSize);
      final out = frame.variableAddress(1, 4);
      _zero(sel, _layout.selectionSize);
      _writeSelection(sel, selection);
      final result = Result.fromValue(
        _exports.ghostty_terminal_selection_order(terminal.value, sel, out),
      );
      _check(result, 'ghostty_terminal_selection_order');
      return SelectionOrder.fromValue(_memory.readU32(out));
    } finally {
      frame.release();
    }
  }

  @override
  RawSelection terminalSelectionOrdered(
    LibGhosttyHandle terminal,
    RawSelection selection,
    SelectionOrder desired,
  ) {
    final frame = _scratch.acquire(const []);
    try {
      final sel = frame.variableAddress(0, _layout.selectionSize);
      final out = frame.variableAddress(1, _layout.selectionSize);
      _zero(sel, _layout.selectionSize);
      _writeSelection(sel, selection);
      _zero(out, _layout.selectionSize);
      final result = Result.fromValue(
        _exports.ghostty_terminal_selection_ordered(
          terminal.value,
          sel,
          desired.value,
          out,
        ),
      );
      _check(result, 'ghostty_terminal_selection_ordered');
      return _readSelection(out);
    } finally {
      frame.release();
    }
  }

  @override
  RawSelection? terminalSelectLine(
    LibGhosttyHandle terminal,
    RawGridRef ref, {
    List<int>? whitespace,
    bool semanticPromptBoundary = false,
  }) {
    final codepoints = whitespace ?? const <int>[];
    final frame = _scratch.acquire(const []);
    try {
      final options = frame.variableAddress(0, _layout.selectLineSize);
      final out = frame.variableAddress(1, _layout.selectionSize);
      final whitespaceBytes = whitespace != null
          ? frame.variableAddress(
              2,
              (codepoints.isEmpty ? 1 : codepoints.length) * 4,
            )
          : 0;
      for (var i = 0; i < codepoints.length; i++) {
        _memory.writeU32(whitespaceBytes + i * 4, codepoints[i]);
      }
      _zero(options, _layout.selectLineSize);
      _memory.writeU32(options, _layout.selectLineSize);
      _writeGridRef(options + _layout.selectLineRef, ref);
      _memory.writeU32(options + _layout.selectLineWhitespace, whitespaceBytes);
      _memory.writeU32(
        options + _layout.selectLineWhitespaceLen,
        codepoints.length,
      );
      _memory.writeU8(
        options + _layout.selectLineSemanticPromptBoundary,
        semanticPromptBoundary ? 1 : 0,
      );
      final result = Result.fromValue(
        _exports.ghostty_terminal_select_line(terminal.value, options, out),
      );
      if (result == .noValue) return null;
      _check(result, 'ghostty_terminal_select_line');
      return _readSelection(out);
    } finally {
      frame.release();
    }
  }

  @override
  RawSelection? terminalSelectOutput(
    LibGhosttyHandle terminal,
    RawGridRef ref,
  ) {
    final refPtr = _allocGridRef(ref);
    final out = _allocSelection();
    try {
      final result = Result.fromValue(
        _exports.ghostty_terminal_select_output(terminal.value, refPtr, out),
      );
      if (result == .noValue) return null;
      _check(result, 'ghostty_terminal_select_output');
      return _readSelection(out);
    } finally {
      _freeGridRef(refPtr);
      _freeBytes(out, _layout.selectionSize);
    }
  }

  @override
  RawSelection? terminalSelectWord(
    LibGhosttyHandle terminal,
    RawGridRef ref, {
    List<int>? boundaryCodepoints,
  }) {
    final boundaries = boundaryCodepoints ?? const <int>[];
    final frame = _scratch.acquire(const []);
    try {
      final options = frame.variableAddress(0, _layout.selectWordSize);
      final out = frame.variableAddress(1, _layout.selectionSize);
      final codepoints = boundaryCodepoints != null
          ? frame.variableAddress(
              2,
              (boundaries.isEmpty ? 1 : boundaries.length) * 4,
            )
          : 0;
      for (var i = 0; i < boundaries.length; i++) {
        _memory.writeU32(codepoints + i * 4, boundaries[i]);
      }
      _zero(options, _layout.selectWordSize);
      _memory.writeU32(options, _layout.selectWordSize);
      _writeGridRef(options + _layout.selectWordRef, ref);
      _memory.writeU32(
        options + _layout.selectWordBoundaryCodepoints,
        codepoints,
      );
      _memory.writeU32(
        options + _layout.selectWordBoundaryCodepointsLen,
        boundaries.length,
      );
      final result = Result.fromValue(
        _exports.ghostty_terminal_select_word(terminal.value, options, out),
      );
      if (result == .noValue) return null;
      _check(result, 'ghostty_terminal_select_word');
      return _readSelection(out);
    } finally {
      frame.release();
    }
  }

  @override
  RawSelection? terminalSelectWordBetween(
    LibGhosttyHandle terminal,
    RawGridRef start,
    RawGridRef end, {
    List<int>? boundaryCodepoints,
  }) {
    final boundaries = boundaryCodepoints ?? const <int>[];
    final frame = _scratch.acquire(const []);
    try {
      final options = frame.variableAddress(0, _layout.selectWordBetweenSize);
      final out = frame.variableAddress(1, _layout.selectionSize);
      final codepoints = boundaryCodepoints != null
          ? frame.variableAddress(
              2,
              (boundaries.isEmpty ? 1 : boundaries.length) * 4,
            )
          : 0;
      for (var i = 0; i < boundaries.length; i++) {
        _memory.writeU32(codepoints + i * 4, boundaries[i]);
      }
      _zero(options, _layout.selectWordBetweenSize);
      _memory.writeU32(options, _layout.selectWordBetweenSize);
      _writeGridRef(options + _layout.selectWordBetweenStart, start);
      _writeGridRef(options + _layout.selectWordBetweenEnd, end);
      _memory.writeU32(
        options + _layout.selectWordBetweenBoundaryCodepoints,
        codepoints,
      );
      _memory.writeU32(
        options + _layout.selectWordBetweenBoundaryCodepointsLen,
        boundaries.length,
      );
      final result = Result.fromValue(
        _exports.ghostty_terminal_select_word_between(
          terminal.value,
          options,
          out,
        ),
      );
      if (result == .noValue) return null;
      _check(result, 'ghostty_terminal_select_word_between');
      return _readSelection(out);
    } finally {
      frame.release();
    }
  }

  @override
  void terminalSetSelection(
    LibGhosttyHandle terminal,
    RawSelection? selection,
  ) {
    if (selection == null) {
      _check(
        .fromValue(
          _exports.ghostty_terminal_set(
            terminal.value,
            TerminalOption.selection.value,
            0,
          ),
        ),
        'ghostty_terminal_set',
      );
      return;
    }
    final ptr = _allocSelection(selection);
    try {
      _check(
        .fromValue(
          _exports.ghostty_terminal_set(
            terminal.value,
            TerminalOption.selection.value,
            ptr,
          ),
        ),
        'ghostty_terminal_set',
      );
    } finally {
      _freeBytes(ptr, _layout.selectionSize);
    }
  }

  int _allocateBytes(int size) {
    final ptr = _exports.allocateBytes(size);
    if (ptr == 0) throw const OutOfMemoryException();
    return ptr;
  }

  int _allocatePersistentSize(WasmAllocationOwner owner) {
    final ptr = owner.allocate(4);
    if (ptr % 4 != 0) {
      throw StateError('libghostty WASM allocator returned misaligned memory.');
    }
    return ptr;
  }

  int _allocGridRef(RawGridRef ref) {
    final ptr = _allocateBytes(_layout.gridRefSize);
    _writeGridRef(ptr, ref);
    return ptr;
  }

  int _allocSelection([RawSelection? selection]) {
    final ptr = _allocateBytes(_layout.selectionSize);
    _zero(ptr, _layout.selectionSize);
    _memory.writeU32(ptr, _layout.selectionSize);
    if (selection != null) _writeSelection(ptr, selection);
    return ptr;
  }

  void _check(Result result, String operation) {
    checkResultCode(result.value, operation: operation);
  }

  void _freeBytes(int ptr, int size) {
    if (ptr != 0) _exports.freeBytes(ptr, size);
  }

  void _freeGridRef(int ptr) => _freeBytes(ptr, _layout.gridRefSize);

  int _getByte(
    LibGhosttyHandle gesture,
    LibGhosttyHandle terminal,
    SelectionGestureData data,
  ) {
    final frame = _scratch.acquire(const []);
    try {
      final ptr = frame.variableAddress(0, 1);
      final result = Result.fromValue(
        _exports.ghostty_selection_gesture_get(
          gesture.value,
          terminal.value,
          data.value,
          ptr,
        ),
      );
      _check(result, 'ghostty_selection_gesture_get');
      return _memory.readU8(ptr);
    } finally {
      frame.release();
    }
  }

  int _getU32(
    LibGhosttyHandle gesture,
    LibGhosttyHandle terminal,
    SelectionGestureData data,
  ) {
    final frame = _scratch.acquire(const []);
    try {
      final ptr = frame.variableAddress(
        0,
        wasm32PointerSize,
        alignment: wasm32PointerSize,
      );
      final result = Result.fromValue(
        _exports.ghostty_selection_gesture_get(
          gesture.value,
          terminal.value,
          data.value,
          ptr,
        ),
      );
      _check(result, 'ghostty_selection_gesture_get');
      return _memory.readU32(ptr);
    } finally {
      frame.release();
    }
  }

  void _growFormatBuffer(int required) {
    if (required <= _formatBufferCapacity) return;
    final replacement = _allocateBytes(required);
    _exports.freeBytes(_formatBuffer, _formatBufferCapacity);
    _formatBuffer = replacement;
    _formatBufferCapacity = required;
  }

  RawGridRef _readGridRef(int ptr) => (
    node: _memory.readPtr(ptr + _layout.gridRefNode),
    x: _memory.readU16(ptr + _layout.gridRefX),
    y: _memory.readU16(ptr + _layout.gridRefY),
  );

  RawSelection _readSelection(int ptr) => (
    start: _readGridRef(ptr + _layout.selectionStart),
    end: _readGridRef(ptr + _layout.selectionEnd),
    rectangle: _memory.readU8(ptr + _layout.selectionRectangle) != 0,
  );

  void _setByteEvent(
    LibGhosttyHandle event,
    SelectionGestureEventOption option,
    int value,
  ) {
    final frame = _scratch.acquire(const []);
    try {
      final ptr = frame.variableAddress(0, 1);
      _memory.writeU8(ptr, value);
      _setEvent(event, option, ptr);
    } finally {
      frame.release();
    }
  }

  void _setEvent(
    LibGhosttyHandle event,
    SelectionGestureEventOption option,
    int value,
  ) {
    _check(
      .fromValue(
        _exports.ghostty_selection_gesture_event_set(
          event.value,
          option.value,
          value,
        ),
      ),
      'ghostty_selection_gesture_event_set',
    );
  }

  void _setScalarEvent(
    LibGhosttyHandle event,
    SelectionGestureEventOption option,
    num value, {
    required bool integer,
  }) {
    const size = 8;
    final frame = _scratch.acquire(const []);
    try {
      final ptr = frame.variableAddress(0, size, alignment: 8);
      if (integer) {
        _memory.writeU64(ptr, value.toInt());
      } else {
        _memory.writeF64(ptr, value.toDouble());
      }
      _setEvent(event, option, ptr);
    } finally {
      frame.release();
    }
  }

  void _writeGridRef(int ptr, RawGridRef ref) {
    _memory.writeU32(ptr, _layout.gridRefSize);
    _memory.writeU32(ptr + _layout.gridRefNode, ref.node);
    _memory.writeU16(ptr + _layout.gridRefX, ref.x);
    _memory.writeU16(ptr + _layout.gridRefY, ref.y);
  }

  void _writePoint(int ptr, PointTag tag, Position position) {
    _memory.writeU32(ptr, tag.value);
    _memory.writeU16(ptr + _layout.pointX, position.col);
    _memory.writeU32(ptr + _layout.pointY, position.row);
  }

  void _writeSelection(int ptr, RawSelection selection) {
    _memory.writeU32(ptr, _layout.selectionSize);
    _writeGridRef(ptr + _layout.selectionStart, selection.start);
    _writeGridRef(ptr + _layout.selectionEnd, selection.end);
    _memory.writeU8(
      ptr + _layout.selectionRectangle,
      selection.rectangle ? 1 : 0,
    );
  }

  void _zero(int ptr, int length) {
    for (var i = 0; i < length; i++) {
      _memory.writeU8(ptr + i, 0);
    }
  }
}
