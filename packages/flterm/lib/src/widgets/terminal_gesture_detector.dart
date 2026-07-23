import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:libghostty/libghostty.dart'
    show MouseAction, MouseButton, MouseTracking, Position;
import 'package:meta/meta.dart';

import '../foundation.dart';
import '../links/link_settings.dart';
import 'link_interaction.dart';
import 'terminal_raw_gesture_detector.dart';
import 'terminal_view_binding.dart';

/// Interprets gestures as terminal actions: selection, mouse tracking
/// reports, and focus requests.
///
/// Reports all gestures to [TerminalViewBinding] which handles
/// snapping, scroll offset, and encoding.
@internal
class TerminalGestureDetector extends StatefulWidget {
  final Widget child;
  final int visibleRows;
  final CellMetrics metrics;
  final TerminalViewBinding binding;
  final TerminalGestureSettings settings;
  final LinkInteraction links;
  final ValueChanged<ActivatedLink>? onLinkActivate;
  final ScrollController? scrollController;

  const TerminalGestureDetector({
    super.key,
    required this.child,
    this.visibleRows = 0,
    required this.metrics,
    required this.binding,
    required this.links,
    this.onLinkActivate,
    this.scrollController,
    this.settings = const TerminalGestureSettings(),
  });

  @override
  State<TerminalGestureDetector> createState() =>
      _TerminalGestureDetectorState();
}

class _TerminalGestureDetectorState extends State<TerminalGestureDetector> {
  _DragState? _drag;
  Position? _pressCell;
  var _linkPressActive = false;
  Timer? _autoScrollTimer;

  TerminalViewBinding get _binding => widget.binding;

  @override
  Widget build(BuildContext context) {
    final tracked = _binding.mouseTracking != MouseTracking.none;

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: tracked ? _handleTrackedDown : null,
      onPointerMove: tracked ? _handleTrackedMove : null,
      onPointerUp: tracked ? _handleTrackedUp : null,
      // Wheel com mouse tracking ligado (TUIs como claude/vim no alt-buffer) tem
      // que virar reporte de mouse pro app, não rolar o scrollback do viewport.
      // Sem isso o `Scrollable` filho engole o wheel (e no alt-buffer não há
      // scrollback), então o scroll interno do app não funciona. O `Scrollable`
      // é neutralizado (`NeverScrollableScrollPhysics`) nesse modo no
      // `TerminalView`, evitando dois consumidores disputando o pointer signal.
      onPointerSignal: tracked ? _handlePointerSignal : null,
      child: TerminalRawGestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onDragStart: _handleDragStart,
        onDragUpdate: _handleDragUpdate,
        onDragEnd: _handleDragEnd,
        onLongPressStart: _handleLongPressStart,
        onLongPressMoveUpdate: _handleLongPressMoveUpdate,
        onLongPressUp: _handleLongPressUp,
        child: widget.child,
      ),
    );
  }

  @override
  void didUpdateWidget(TerminalGestureDetector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.metrics != oldWidget.metrics ||
        widget.binding != oldWidget.binding) {
      _binding.clearSelection();
      _stopAutoScroll();
      _drag = null;
      _pressCell = null;
      _cancelLinkPress();
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  void _autoScrollTick(Timer timer) {
    final scrollController = widget.scrollController;
    if (scrollController == null || !scrollController.hasClients) return;

    final drag = _drag;
    if (drag == null) {
      _stopAutoScroll();
      return;
    }

    _binding.updateSelectionAutoscroll(
      cell: drag.cell,
      localPosition: drag.localPosition,
      rectangle: drag.lastRectangle,
    );
  }

  void _cancelLinkPress() {
    if (!_linkPressActive) return;
    _linkPressActive = false;
    widget.links.cancel();
  }

  void _cancelSelectionPress() {
    if (_pressCell == null) return;
    _binding.cancelSelectionGesture();
    _pressCell = null;
  }

  int _clampInt(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  void _endDrag() {
    final drag = _drag;
    if (drag != null) {
      _releaseSelectionPress(drag.cell);
    } else {
      _releaseSelectionPress();
    }
    _stopAutoScroll();
    _drag = null;
    _cancelLinkPress();
  }

  void _handleDragEnd() => _endDrag();

  void _handleDragStart(DragStartDetails details) {
    _binding.requestFocus();
    _cancelLinkPress();
    if (_isMouseTracked(HardwareKeyboard.instance.isShiftPressed)) return;
    if (!widget.settings.dragSelection) {
      _cancelSelectionPress();
      return;
    }

    _startDrag(details.localPosition, beginPress: _pressCell == null);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_isMouseTracked(HardwareKeyboard.instance.isShiftPressed)) return;
    if (_drag != null) _updateDrag(details.localPosition);
  }

  void _handleLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (_drag != null) _updateDrag(details.localPosition);
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    _binding.requestFocus();
    if (!widget.settings.longPressSelection) {
      _cancelSelectionPress();
      return;
    }
    _startDrag(
      details.localPosition,
      rectangle: widget.settings.longPressSelectionShape == .rectangle,
      beginPress: _pressCell == null,
    );
  }

  void _handleLongPressUp() => _endDrag();

  void _handleSelectionPress(Offset position) {
    final cell = widget.metrics.cellAt(position);
    _binding.handleSelectionPress(
      cell: cell,
      localPosition: position,
      settings: widget.settings,
    );
    _pressCell = cell;
  }

  void _handleTapDown(TapDownDetails details) {
    _binding.requestFocus();
    if (_isMouseTracked(HardwareKeyboard.instance.isShiftPressed)) return;
    if (widget.links.handlePress(
      localPosition: details.localPosition,
      metrics: widget.metrics,
      pointerKind: details.kind ?? .mouse,
      virtualMods: _binding.virtualMods,
    )) {
      _linkPressActive = true;
      _cancelSelectionPress();
      return;
    }
    _handleSelectionPress(details.localPosition);
  }

  void _handleTapUp(TapUpDetails details) {
    if (_linkPressActive) {
      _linkPressActive = false;
      final link = widget.links.handleRelease(
        localPosition: details.localPosition,
        metrics: widget.metrics,
      );
      if (link != null) widget.onLinkActivate?.call(link);
      return;
    }
    if (_pressCell == null &&
        _isMouseTracked(HardwareKeyboard.instance.isShiftPressed)) {
      return;
    }
    _releaseSelectionPress(widget.metrics.cellAt(details.localPosition));
  }

  void _handleTrackedDown(PointerDownEvent event) {
    final shift =
        event.buttons & kSecondaryButton != 0 ||
        HardwareKeyboard.instance.isShiftPressed;
    if (!_isMouseTracked(shift)) return;
    _sendMouseEvent(.press, event.localPosition);
  }

  void _handleTrackedMove(PointerMoveEvent event) {
    if (!_isMouseTracked(HardwareKeyboard.instance.isShiftPressed)) return;
    _sendMouseEvent(.motion, event.localPosition);
  }

  void _handleTrackedUp(PointerUpEvent event) {
    if (!_isMouseTracked(HardwareKeyboard.instance.isShiftPressed)) return;
    _sendMouseEvent(.release, event.localPosition);
  }

  bool _isBlockModifierPressed() {
    final modifier = widget.settings.blockSelectionModifier;
    if (modifier == null) return false;
    final keyboard = HardwareKeyboard.instance;
    final mods = _binding.virtualMods;
    return switch (modifier) {
      .alt => keyboard.isAltPressed || mods.hasAlt,
      .meta => keyboard.isMetaPressed || mods.hasSuper,
      .shift => keyboard.isShiftPressed || mods.hasShift,
      .control => keyboard.isControlPressed || mods.hasCtrl,
    };
  }

  bool _isMouseTracked(bool shift) {
    return _binding.mouseTracking != .none &&
        !shift &&
        !_binding.virtualMods.hasShift;
  }

  void _releaseSelectionPress([Position? cell]) {
    cell ??= _pressCell;
    if (cell == null) return;
    _binding.handleSelectionRelease(cell);
    _pressCell = null;
  }

  void _sendMouseEvent(MouseAction action, Offset position) {
    _binding.handleMouseEvent((
      action: action,
      button: .left,
      pixelX: position.dx,
      pixelY: position.dy,
    ));
  }

  /// Resíduo fracionário de linha ao encaminhar o wheel (trackpad manda deltas
  /// pequenos e frequentes; acumulamos pra não rolar rápido demais).
  double _wheelAccum = 0;

  /// Encaminha o wheel pro app como reporte de mouse (botão 4 = cima,
  /// 5 = baixo) quando o mouse tracking está ligado. Segurando Shift o app não
  /// recebe (o terminal deixa o Shift+wheel pro scroll local), como o resto.
  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (!_isMouseTracked(HardwareKeyboard.instance.isShiftPressed)) return;
    final cellHeight = widget.metrics.cellHeight;
    if (cellHeight <= 0) return;
    final lines = event.scrollDelta.dy / cellHeight;
    if (lines == 0) return;

    final int steps;
    if (event.kind == PointerDeviceKind.mouse) {
      // Wheel de mouse é discreto (um notch por evento): garante ao menos 1
      // linha no sentido; notches maiores rolam proporcional.
      final mag = lines.abs().round();
      steps = (mag < 1 ? 1 : mag) * (lines.isNegative ? -1 : 1);
    } else {
      // Trackpad (contínuo): acumula a fração e só dispara em linhas inteiras.
      _wheelAccum += lines;
      steps = _wheelAccum.truncate();
      if (steps == 0) return;
      _wheelAccum -= steps;
    }

    // scrollDelta.dy < 0 = rolar pra cima = botão 4; > 0 = baixo = botão 5.
    final button = steps < 0 ? MouseButton.four : MouseButton.five;
    for (var i = 0; i < steps.abs(); i++) {
      _binding.handleMouseEvent((
        action: MouseAction.press,
        button: button,
        pixelX: event.localPosition.dx,
        pixelY: event.localPosition.dy,
      ));
    }
  }

  void _startAutoScroll() {
    if (_autoScrollTimer != null) return;
    _autoScrollTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      _autoScrollTick,
    );
  }

  void _startDrag(
    Offset position, {
    bool rectangle = false,
    bool beginPress = false,
  }) {
    final cell = widget.metrics.cellAt(position);
    final block = rectangle || _isBlockModifierPressed();
    _drag = _DragState(cell, position, baseRectangle: block);
    if (beginPress) _handleSelectionPress(position);
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  void _updateDrag(Offset position) {
    final drag = _drag;
    if (drag == null) return;
    final cell = widget.metrics.cellAt(position);
    drag.cell = cell;
    drag.localPosition = position;

    final visibleRows = widget.visibleRows;
    if (visibleRows > 0) {
      if (cell.row < 0) {
        _startAutoScroll();
      } else if (cell.row >= visibleRows) {
        _startAutoScroll();
      } else {
        _stopAutoScroll();
      }
    }

    final clampedRow = visibleRows > 0
        ? _clampInt(cell.row, 0, visibleRows - 1)
        : cell.row;
    final clampedCell = Position(row: clampedRow, col: cell.col);
    final rectangle = drag.baseRectangle || _isBlockModifierPressed();
    if (clampedCell == drag.lastCell && rectangle == drag.lastRectangle) {
      return;
    }
    drag.lastCell = clampedCell;
    drag.lastRectangle = rectangle;

    _binding.updateSelectionDrag(
      cell: clampedCell,
      localPosition: position,
      rectangle: rectangle,
    );
  }
}

class _DragState {
  Position cell;
  Offset localPosition;
  final bool baseRectangle;
  bool lastRectangle;
  Position? lastCell;

  _DragState(this.cell, this.localPosition, {required this.baseRectangle})
    : lastRectangle = baseRectangle;
}
