import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../../generated/libghostty.g.dart' hide String;
import '../../generated/libghostty_enums.g.dart';
import '../../types/types.dart';
import '../formatter/ffi.dart';
import '../result_helpers.dart';
import '../types.dart';
import 'selection.dart';

final class FfiSelectionBindings implements SelectionBindings {
  final _outSize = calloc<Size>();
  final _multiKeys = calloc<UnsignedInt>(5);
  final _multiValues = calloc<Pointer<Void>>(5);
  final _multiOut = calloc<Uint64>(5);
  final _multiGridRef = calloc<GridRef>();
  late final _formatter = FfiFormatterBindings();

  FfiSelectionBindings();

  @override
  RawSelection? selectionGestureEvent(
    LibGhosttyHandle gesture,
    LibGhosttyHandle terminal,
    LibGhosttyHandle event,
  ) {
    return using((arena) {
      final out = arena<Selection>();
      final result = ghostty_selection_gesture_event(
        Pointer.fromAddress(gesture.value),
        Pointer.fromAddress(terminal.value),
        Pointer.fromAddress(event.value),
        out,
      );
      if (result == .noValue) return null;
      checkResultCode(
        result.value,
        operation: 'ghostty_selection_gesture_event',
      );
      return _readSelection(out.ref);
    });
  }

  @override
  void selectionGestureEventClear(
    LibGhosttyHandle event,
    SelectionGestureEventOption option,
  ) {
    final result = ghostty_selection_gesture_event_set(
      Pointer.fromAddress(event.value),
      option,
      nullptr,
    );
    checkResultCode(
      result.value,
      operation: 'ghostty_selection_gesture_event_set',
    );
  }

  @override
  void selectionGestureEventFree(LibGhosttyHandle event) {
    ghostty_selection_gesture_event_free(Pointer.fromAddress(event.value));
  }

  @override
  LibGhosttyHandle selectionGestureEventNew(SelectionGestureEventType type) {
    return using((arena) {
      final out = arena<Pointer<SelectionGestureEventImpl>>();
      final result = ghostty_selection_gesture_event_new(nullptr, out, type);
      checkResultCode(
        result.value,
        operation: 'ghostty_selection_gesture_event_new',
      );
      return .fromAddress(out.value.address);
    });
  }

  @override
  void selectionGestureEventSetBehaviors(
    LibGhosttyHandle event,
    SelectionGestureBehavior singleClick,
    SelectionGestureBehavior doubleClick,
    SelectionGestureBehavior tripleClick,
  ) {
    using((arena) {
      final value = SelectionGestureBehaviors.$allocate(
        arena,
        single_click: singleClick,
        double_click: doubleClick,
        triple_click: tripleClick,
      );
      final result = ghostty_selection_gesture_event_set(
        Pointer.fromAddress(event.value),
        .behaviors,
        value.cast(),
      );
      checkResultCode(
        result.value,
        operation: 'ghostty_selection_gesture_event_set',
      );
    });
  }

  @override
  void selectionGestureEventSetGeometry(
    LibGhosttyHandle event, {
    required int columns,
    required int cellWidth,
    required int paddingLeft,
    required int screenHeight,
  }) {
    using((arena) {
      final value = SelectionGestureGeometry.$allocate(
        arena,
        columns: columns,
        cell_width: cellWidth,
        padding_left: paddingLeft,
        screen_height: screenHeight,
      );
      final result = ghostty_selection_gesture_event_set(
        Pointer.fromAddress(event.value),
        .geometry,
        value.cast(),
      );
      checkResultCode(
        result.value,
        operation: 'ghostty_selection_gesture_event_set',
      );
    });
  }

  @override
  void selectionGestureEventSetPosition(
    LibGhosttyHandle event,
    double x,
    double y,
  ) {
    using((arena) {
      final value = SurfacePosition.$allocate(arena, x: x, y: y);
      final result = ghostty_selection_gesture_event_set(
        Pointer.fromAddress(event.value),
        .position,
        value.cast(),
      );
      checkResultCode(
        result.value,
        operation: 'ghostty_selection_gesture_event_set',
      );
    });
  }

  @override
  void selectionGestureEventSetRectangle(
    LibGhosttyHandle event, {
    required bool value,
  }) {
    using((arena) {
      final ptr = arena<Bool>()..value = value;
      final result = ghostty_selection_gesture_event_set(
        .fromAddress(event.value),
        .rectangle,
        ptr.cast(),
      );
      checkResultCode(
        result.value,
        operation: 'ghostty_selection_gesture_event_set',
      );
    });
  }

  @override
  void selectionGestureEventSetRef(LibGhosttyHandle event, RawGridRef ref) {
    using((arena) {
      final value = GridRef.$allocate(
        arena,
        node: Pointer<Void>.fromAddress(ref.node),
        x: ref.x,
        y: ref.y,
      );
      final result = ghostty_selection_gesture_event_set(
        .fromAddress(event.value),
        .ref,
        value.cast(),
      );
      checkResultCode(
        result.value,
        operation: 'ghostty_selection_gesture_event_set',
      );
    });
  }

  @override
  void selectionGestureEventSetRepeatDistance(
    LibGhosttyHandle event,
    double value,
  ) {
    using((arena) {
      final ptr = arena<Double>()..value = value;
      final result = ghostty_selection_gesture_event_set(
        .fromAddress(event.value),
        .repeatDistance,
        ptr.cast(),
      );
      checkResultCode(
        result.value,
        operation: 'ghostty_selection_gesture_event_set',
      );
    });
  }

  @override
  void selectionGestureEventSetRepeatIntervalNs(
    LibGhosttyHandle event,
    int value,
  ) {
    using((arena) {
      final ptr = arena<Uint64>()..value = value;
      final result = ghostty_selection_gesture_event_set(
        .fromAddress(event.value),
        .repeatIntervalNs,
        ptr.cast(),
      );
      checkResultCode(
        result.value,
        operation: 'ghostty_selection_gesture_event_set',
      );
    });
  }

  @override
  void selectionGestureEventSetTimeNs(LibGhosttyHandle event, int value) {
    using((arena) {
      final ptr = arena<Uint64>()..value = value;
      final result = ghostty_selection_gesture_event_set(
        .fromAddress(event.value),
        .timeNs,
        ptr.cast(),
      );
      checkResultCode(
        result.value,
        operation: 'ghostty_selection_gesture_event_set',
      );
    });
  }

  @override
  void selectionGestureEventSetViewport(
    LibGhosttyHandle event, {
    required Position position,
  }) {
    using((arena) {
      final value = PointCoordinate.$allocate(
        arena,
        x: position.col,
        y: position.row,
      );
      final result = ghostty_selection_gesture_event_set(
        .fromAddress(event.value),
        .viewport,
        value.cast(),
      );
      checkResultCode(
        result.value,
        operation: 'ghostty_selection_gesture_event_set',
      );
    });
  }

  @override
  void selectionGestureEventSetWordBoundaryCodepoints(
    LibGhosttyHandle event,
    List<int> codepoints,
  ) {
    using((arena) {
      final value = Codepoints.$allocate(
        arena,
        ptr: _writeCodepoints(arena, codepoints),
        len: codepoints.length,
      );
      final result = ghostty_selection_gesture_event_set(
        .fromAddress(event.value),
        .wordBoundaryCodepoints,
        value.cast(),
      );
      checkResultCode(
        result.value,
        operation: 'ghostty_selection_gesture_event_set',
      );
    });
  }

  @override
  void selectionGestureFree(
    LibGhosttyHandle gesture,
    LibGhosttyHandle terminal,
  ) {
    ghostty_selection_gesture_free(
      .fromAddress(gesture.value),
      .fromAddress(terminal.value),
    );
  }

  @override
  RawGridRef? selectionGestureGetAnchor(
    LibGhosttyHandle gesture,
    LibGhosttyHandle terminal,
  ) {
    return using((arena) {
      final out = arena<GridRef>();
      final result = ghostty_selection_gesture_get(
        .fromAddress(gesture.value),
        .fromAddress(terminal.value),
        .anchor,
        out.cast(),
      );
      if (result == .noValue) return null;
      checkResultCode(result.value, operation: 'ghostty_selection_gesture_get');
      return _readGridRef(out.ref);
    });
  }

  @override
  SelectionGestureAutoscroll selectionGestureGetAutoscroll(
    LibGhosttyHandle gesture,
    LibGhosttyHandle terminal,
  ) {
    return using((arena) {
      final out = arena<UnsignedInt>();
      final result = ghostty_selection_gesture_get(
        .fromAddress(gesture.value),
        .fromAddress(terminal.value),
        .autoscroll,
        out.cast(),
      );
      checkResultCode(result.value, operation: 'ghostty_selection_gesture_get');
      return .fromValue(out.value);
    });
  }

  @override
  SelectionGestureBehavior selectionGestureGetBehavior(
    LibGhosttyHandle gesture,
    LibGhosttyHandle terminal,
  ) {
    return using((arena) {
      final out = arena<UnsignedInt>();
      final result = ghostty_selection_gesture_get(
        .fromAddress(gesture.value),
        .fromAddress(terminal.value),
        .behavior,
        out.cast(),
      );
      checkResultCode(result.value, operation: 'ghostty_selection_gesture_get');
      return .fromValue(out.value);
    });
  }

  @override
  int selectionGestureGetClickCount(
    LibGhosttyHandle gesture,
    LibGhosttyHandle terminal,
  ) {
    return using((arena) {
      final out = arena<Uint8>();
      final result = ghostty_selection_gesture_get(
        .fromAddress(gesture.value),
        .fromAddress(terminal.value),
        .clickCount,
        out.cast(),
      );
      checkResultCode(result.value, operation: 'ghostty_selection_gesture_get');
      return out.value;
    });
  }

  @override
  bool selectionGestureGetDragged(
    LibGhosttyHandle gesture,
    LibGhosttyHandle terminal,
  ) {
    return using((arena) {
      final out = arena<Bool>();
      final result = ghostty_selection_gesture_get(
        .fromAddress(gesture.value),
        .fromAddress(terminal.value),
        .dragged,
        out.cast(),
      );
      checkResultCode(result.value, operation: 'ghostty_selection_gesture_get');
      return out.value;
    });
  }

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
      _multiKeys[i] = keys[i].value;
      _multiValues[i] = (_multiOut + i).cast();
    }
    _multiValues[4] = _multiGridRef.cast();
    final result = ghostty_selection_gesture_get_multi(
      .fromAddress(gesture.value),
      .fromAddress(terminal.value),
      keys.length,
      _multiKeys,
      _multiValues,
      _outSize,
    );
    final anchorAbsent = result == .noValue && _outSize.value == 4;
    if (result != .success && !anchorAbsent) {
      checkResultCode(
        result.value,
        operation: 'ghostty_selection_gesture_get_multi',
      );
    }
    return (
      clickCount: (_multiOut + 0).cast<Uint8>().value,
      dragged: (_multiOut + 1).cast<Bool>().value,
      autoscroll: .fromValue((_multiOut + 2).cast<Int32>().value),
      behavior: .fromValue((_multiOut + 3).cast<Int32>().value),
      anchor: anchorAbsent ? null : _readGridRef(_multiGridRef.ref),
    );
  }

  @override
  LibGhosttyHandle selectionGestureNew() {
    return using((arena) {
      final out = arena<Pointer<SelectionGestureImpl>>();
      final result = ghostty_selection_gesture_new(nullptr, out);
      checkResultCode(result.value, operation: 'ghostty_selection_gesture_new');
      return .fromAddress(out.value.address);
    });
  }

  @override
  void selectionGestureReset(
    LibGhosttyHandle gesture,
    LibGhosttyHandle terminal,
  ) {
    ghostty_selection_gesture_reset(
      .fromAddress(gesture.value),
      .fromAddress(terminal.value),
    );
  }

  @override
  RawSelection? terminalGetSelection(LibGhosttyHandle terminal) {
    return using((arena) {
      final out = arena<Selection>();
      final result = ghostty_terminal_get(
        .fromAddress(terminal.value),
        .selection,
        out.cast(),
      );
      if (result == .noValue) return null;
      checkResultCode(result.value, operation: 'ghostty_terminal_get');
      return _readSelection(out.ref);
    });
  }

  @override
  RawSelection? terminalSelectAll(LibGhosttyHandle terminal) {
    return using((arena) {
      final out = arena<Selection>();
      final result = ghostty_terminal_select_all(
        .fromAddress(terminal.value),
        out,
      );
      if (result == .noValue) return null;
      checkResultCode(result.value, operation: 'ghostty_terminal_select_all');
      return _readSelection(out.ref);
    });
  }

  @override
  RawSelection terminalSelectionAdjust(
    LibGhosttyHandle terminal,
    RawSelection selection,
    SelectionAdjust adjustment,
  ) {
    return using((arena) {
      final value = arena<Selection>();
      _writeSelection(value.ref, selection);
      final result = ghostty_terminal_selection_adjust(
        .fromAddress(terminal.value),
        value,
        adjustment,
      );
      checkResultCode(
        result.value,
        operation: 'ghostty_terminal_selection_adjust',
      );
      return _readSelection(value.ref);
    });
  }

  @override
  bool terminalSelectionContains(
    LibGhosttyHandle terminal,
    RawSelection selection,
    PointTag pointTag,
    Position position,
  ) {
    return using((arena) {
      final value = arena<Selection>();
      final point = arena<Point>();
      final out = arena<Bool>();
      _writeSelection(value.ref, selection);
      _writePoint(point.ref, pointTag, position);
      final result = ghostty_terminal_selection_contains(
        .fromAddress(terminal.value),
        value,
        point.ref,
        out,
      );
      checkResultCode(
        result.value,
        operation: 'ghostty_terminal_selection_contains',
      );
      return out.value;
    });
  }

  @override
  bool terminalSelectionEqual(
    LibGhosttyHandle terminal,
    RawSelection a,
    RawSelection b,
  ) {
    return using((arena) {
      final first = arena<Selection>();
      final second = arena<Selection>();
      final out = arena<Bool>();
      _writeSelection(first.ref, a);
      _writeSelection(second.ref, b);
      final result = ghostty_terminal_selection_equal(
        .fromAddress(terminal.value),
        first,
        second,
        out,
      );
      checkResultCode(
        result.value,
        operation: 'ghostty_terminal_selection_equal',
      );
      return out.value;
    });
  }

  @override
  String? terminalSelectionFormat(
    LibGhosttyHandle terminal,
    FormatterFormat format, {
    bool unwrap = false,
    bool trim = false,
    RawSelection? selection,
  }) {
    final selected = selection ?? terminalGetSelection(terminal);
    if (selected == null) return null;
    final formatter = _formatter.formatterTerminalNew(
      terminal,
      format,
      unwrap: unwrap,
      trim: trim,
      selection: selected,
    );
    try {
      return _formatter.formatterFormat(formatter);
    } finally {
      _formatter.formatterFree(formatter);
    }
  }

  @override
  SelectionOrder terminalSelectionOrder(
    LibGhosttyHandle terminal,
    RawSelection selection,
  ) {
    return using((arena) {
      final value = arena<Selection>();
      final out = arena<UnsignedInt>();
      _writeSelection(value.ref, selection);
      final result = ghostty_terminal_selection_order(
        .fromAddress(terminal.value),
        value,
        out.cast(),
      );
      checkResultCode(
        result.value,
        operation: 'ghostty_terminal_selection_order',
      );
      return .fromValue(out.value);
    });
  }

  @override
  RawSelection terminalSelectionOrdered(
    LibGhosttyHandle terminal,
    RawSelection selection,
    SelectionOrder desired,
  ) {
    return using((arena) {
      final value = arena<Selection>();
      final out = arena<Selection>();
      _writeSelection(value.ref, selection);
      final result = ghostty_terminal_selection_ordered(
        .fromAddress(terminal.value),
        value,
        desired,
        out,
      );
      checkResultCode(
        result.value,
        operation: 'ghostty_terminal_selection_ordered',
      );
      return _readSelection(out.ref);
    });
  }

  @override
  RawSelection? terminalSelectLine(
    LibGhosttyHandle terminal,
    RawGridRef ref, {
    List<int>? whitespace,
    bool semanticPromptBoundary = false,
  }) {
    return using((arena) {
      final options = arena<TerminalSelectLineOptions>();
      final out = arena<Selection>();
      options.ref
        ..size = sizeOf<TerminalSelectLineOptions>()
        ..whitespace = _writeCodepoints(arena, whitespace)
        ..whitespace_len = whitespace?.length ?? 0
        ..semantic_prompt_boundary = semanticPromptBoundary;
      _writeGridRef(options.ref.ref, ref);
      final result = ghostty_terminal_select_line(
        .fromAddress(terminal.value),
        options,
        out,
      );
      if (result == .noValue) return null;
      checkResultCode(result.value, operation: 'ghostty_terminal_select_line');
      return _readSelection(out.ref);
    });
  }

  @override
  RawSelection? terminalSelectOutput(
    LibGhosttyHandle terminal,
    RawGridRef ref,
  ) {
    return using((arena) {
      final gridRef = GridRef.$allocate(
        arena,
        node: Pointer<Void>.fromAddress(ref.node),
        x: ref.x,
        y: ref.y,
      );
      final out = arena<Selection>();
      final result = ghostty_terminal_select_output(
        .fromAddress(terminal.value),
        gridRef,
        out,
      );
      if (result == .noValue) return null;
      checkResultCode(
        result.value,
        operation: 'ghostty_terminal_select_output',
      );
      return _readSelection(out.ref);
    });
  }

  @override
  RawSelection? terminalSelectWord(
    LibGhosttyHandle terminal,
    RawGridRef ref, {
    List<int>? boundaryCodepoints,
  }) {
    return using((arena) {
      final options = arena<TerminalSelectWordOptions>();
      final out = arena<Selection>();
      options.ref
        ..size = sizeOf<TerminalSelectWordOptions>()
        ..boundary_codepoints = _writeCodepoints(arena, boundaryCodepoints)
        ..boundary_codepoints_len = boundaryCodepoints?.length ?? 0;
      _writeGridRef(options.ref.ref, ref);
      final result = ghostty_terminal_select_word(
        .fromAddress(terminal.value),
        options,
        out,
      );
      if (result == .noValue) return null;
      checkResultCode(result.value, operation: 'ghostty_terminal_select_word');
      return _readSelection(out.ref);
    });
  }

  @override
  RawSelection? terminalSelectWordBetween(
    LibGhosttyHandle terminal,
    RawGridRef start,
    RawGridRef end, {
    List<int>? boundaryCodepoints,
  }) {
    return using((arena) {
      final options = arena<TerminalSelectWordBetweenOptions>();
      final out = arena<Selection>();
      options.ref
        ..size = sizeOf<TerminalSelectWordBetweenOptions>()
        ..boundary_codepoints = _writeCodepoints(arena, boundaryCodepoints)
        ..boundary_codepoints_len = boundaryCodepoints?.length ?? 0;
      _writeGridRef(options.ref.start, start);
      _writeGridRef(options.ref.end, end);
      final result = ghostty_terminal_select_word_between(
        .fromAddress(terminal.value),
        options,
        out,
      );
      if (result == .noValue) return null;
      checkResultCode(
        result.value,
        operation: 'ghostty_terminal_select_word_between',
      );
      return _readSelection(out.ref);
    });
  }

  @override
  void terminalSetSelection(
    LibGhosttyHandle terminal,
    RawSelection? selection,
  ) {
    if (selection == null) {
      final result = ghostty_terminal_set(
        .fromAddress(terminal.value),
        .selection,
        nullptr,
      );
      checkResultCode(result.value, operation: 'ghostty_terminal_set');
      return;
    }
    using((arena) {
      final value = arena<Selection>();
      _writeSelection(value.ref, selection);
      final result = ghostty_terminal_set(
        .fromAddress(terminal.value),
        .selection,
        value.cast(),
      );
      checkResultCode(result.value, operation: 'ghostty_terminal_set');
    });
  }

  static RawGridRef _readGridRef(GridRef ref) =>
      (node: ref.node.address, x: ref.x, y: ref.y);

  static RawSelection _readSelection(Selection value) => (
    start: _readGridRef(value.start),
    end: _readGridRef(value.end),
    rectangle: value.rectangle,
  );

  static Pointer<Uint32> _writeCodepoints(Arena arena, List<int>? codepoints) {
    if (codepoints == null) return nullptr;
    final ptr = arena<Uint32>(codepoints.isEmpty ? 1 : codepoints.length);
    for (var i = 0; i < codepoints.length; i++) {
      ptr[i] = codepoints[i];
    }
    return ptr;
  }

  static void _writeGridRef(GridRef target, RawGridRef value) {
    target
      ..node = Pointer<Void>.fromAddress(value.node)
      ..x = value.x
      ..y = value.y;
  }

  static void _writePoint(Point target, PointTag pointTag, Position position) {
    target
      ..tagAsInt = pointTag.value
      ..value.coordinate.x = position.col
      ..value.coordinate.y = position.row;
  }

  static void _writeSelection(Selection target, RawSelection value) {
    target.rectangle = value.rectangle;
    _writeGridRef(target.start, value.start);
    _writeGridRef(target.end, value.end);
  }
}
