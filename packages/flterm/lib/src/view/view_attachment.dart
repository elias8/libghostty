import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:libghostty/libghostty.dart' hide Listenable;

import '../controller/terminal_controller.dart';
import '../foundation.dart';
import '../input/input_message.dart';
import '../input/keyboard_input_adapter.dart';
import '../interaction/selection_session.dart';
import '../rendering/frame_source.dart';
import 'compression_scheduler.dart';

/// Terminal modes that must be observed atomically by gesture routing.
///
/// One immutable value prevents a rebuild from combining an active screen,
/// mouse mode, and alternate-scroll flag sampled from different terminal
/// notifications.
@immutable
@internal
final class ViewInteractionState {
  /// The active primary or alternate screen governing the interaction.
  final TerminalScreen activeScreen;

  /// The active mouse tracking mode requested by terminal content.
  final MouseTracking mouseTracking;

  /// Whether DEC alternate-scroll mode is enabled.
  ///
  /// While the alternate screen is active, this mode maps wheel input to
  /// cursor keys.
  final bool alternateScroll;

  const ViewInteractionState({
    required this.activeScreen,
    required this.mouseTracking,
    required this.alternateScroll,
  });

  @override
  int get hashCode => Object.hash(activeScreen, mouseTracking, alternateScroll);

  @override
  bool operator ==(Object other) =>
      other is ViewInteractionState &&
      other.activeScreen == activeScreen &&
      other.mouseTracking == mouseTracking &&
      other.alternateScroll == alternateScroll;
}

/// Owns one Flutter view's attachment to a terminal controller.
///
/// The attachment is the only bridge that subscribes view resources to a
/// controller. It owns focus and text input, frame invalidation, scroll-aware
/// compression, theme reporting, and normalized event routing. Disposing it
/// releases the controller's single-view lease and every listener it created.
@internal
final class ViewAttachment extends ChangeNotifier {
  final Object _viewToken;
  final KeyboardInputAdapter input;
  final TerminalControllerImpl _controller;
  late final FrameSource frameSource;
  late final CompressionScheduler _compressionScheduler;
  late final ValueNotifier<ViewInteractionState> _interaction;
  ScrollController? _scrollController;
  var _disposed = false;

  factory ViewAttachment(TerminalController controller) =>
      ViewAttachment._(controller as TerminalControllerImpl);

  ViewAttachment._(this._controller)
    : _viewToken = _controller.attachView(),
      input = KeyboardInputAdapter(
        _controller,
        keyEventNormalizer: _controller.keyEventNormalizer,
      ) {
    frameSource = FrameSource(
      terminal,
      viewportChanges: _controller.viewportChanges,
    );
    _interaction = ValueNotifier(_readInteractionState());
    _compressionScheduler = CompressionScheduler(
      readActivity: () => terminal.compressionActivity,
      compress: terminal.compress,
    );
    _controller.addListener(_handleControllerChanged);
    terminal.addListener(_handleTerminalChanged);
  }

  Mods get currentMods => _physicalMods | _controller.virtualMods;

  bool get cursorBlinkEnabled {
    if (!_controller.cursorBlinking) return false;
    if (terminal.activeScreen == .alternate) return true;

    final scrollController = _scrollController;
    if (scrollController == null || !scrollController.hasClients) {
      return terminal.isViewportActive;
    }
    final position = scrollController.position;
    if (!position.hasContentDimensions) return terminal.isViewportActive;
    return position.pixels >= position.maxScrollExtent - 1.0;
  }

  ValueListenable<ViewInteractionState> get interaction => _interaction;

  MouseTracking get mouseTracking => _controller.mouseTracking;

  Terminal get terminal => _controller.terminal;

  Mods get virtualMods => _controller.virtualMods;

  Mods get _physicalMods {
    final keyboard = HardwareKeyboard.instance;
    var mods = const Mods.none();
    if (keyboard.isShiftPressed) mods |= const Mods.shift();
    if (keyboard.isControlPressed) mods |= const Mods.ctrl();
    if (keyboard.isAltPressed) mods |= const Mods.alt();
    if (keyboard.isMetaPressed) mods |= const Mods.superKey();
    return mods;
  }

  void applyTheme(TerminalTheme theme) {
    final background = _rgb(theme.background);
    final Brightness brightness = colorPerceivedLuminance(background) > 0.5
        ? .light
        : .dark;
    input.keyboardAppearance = brightness;
    _controller.setColorScheme(brightness == .light ? .light : .dark);
    terminal
      ..foreground = _rgb(theme.foreground)
      ..background = background
      ..cursorColor = theme.cursor.color?.fixedColor == null
          ? null
          : _rgb(theme.cursor.color!.fixedColor!)
      ..palette = [for (var i = 0; i < 256; i++) _rgb(theme.palette[i])];
  }

  void attach(
    FocusNode focusNode,
    ScrollController scrollController, {
    required int viewId,
  }) {
    _scrollController = scrollController;
    input.attach(focusNode, viewId: viewId);
    if (scrollController.hasClients) _compressionScheduler.schedule();
  }

  void cancelSelectionGesture() => _controller.cancelSelectionGesture();

  void detach() {
    _compressionScheduler.cancel();
    _scrollController = null;
    input.detach();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (!_controller.isDisposed) {
      _controller.removeListener(_handleControllerChanged);
      terminal.removeListener(_handleTerminalChanged);
    }
    _compressionScheduler.dispose();
    input.dispose();
    frameSource.dispose();
    _interaction.dispose();
    _controller.detachView(_viewToken);
    super.dispose();
  }

  void handleMouseEvent(MouseInput event) =>
      _controller.handleMouseEvent(event);

  void handleResize(SurfaceMeasurement measurement) =>
      _controller.handleResize(measurement);

  void handleSelectionPress(SelectionPressInput event) =>
      _controller.handleSelectionPress(event);

  void handleSelectionRelease(Position cell) =>
      _controller.handleSelectionRelease(cell);

  void handleTerminalScroll(ScrollInput event) =>
      _controller.handleTerminalScroll(event);

  void handleViewportRowChanged(int row) {
    _controller.scrollToRow(row);
    _compressionScheduler.notifyActivity();
  }

  void invalidateSelection() => _controller.invalidateSelection();

  void requestFocus() => input.requestFocus();

  void updateSelectionAutoscroll(SelectionAutoscrollInput event) {
    _controller.updateSelectionAutoscroll(event);
    _compressionScheduler.notifyActivity();
  }

  void updateSelectionDrag(SelectionDragInput event) =>
      _controller.updateSelectionDrag(event);

  void _handleControllerChanged() {
    final next = _readInteractionState();
    if (_interaction.value != next) _interaction.value = next;
    notifyListeners();
  }

  void _handleTerminalChanged() => _compressionScheduler.notifyActivity();

  ViewInteractionState _readInteractionState() {
    final activeScreen = _controller.activeScreen;
    return ViewInteractionState(
      activeScreen: activeScreen,
      mouseTracking: _controller.mouseTracking,
      alternateScroll: terminal.modeGet(const .alternateScroll()),
    );
  }

  static RgbColor _rgb(Color color) => RgbColor(
    (color.r * 255).round().clamp(0, 255),
    (color.g * 255).round().clamp(0, 255),
    (color.b * 255).round().clamp(0, 255),
  );
}
