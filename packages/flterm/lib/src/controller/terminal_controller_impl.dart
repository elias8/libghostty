part of 'terminal_controller.dart';

typedef _Observation = ({
  TerminalScreen activeScreen,
  MouseTracking mouseTracking,
  bool cursorKeyApplication,
  bool cursorBlinking,
});

/// Owns one terminal session and its renderer-neutral behavior.
///
/// Flutter lifecycle and device events reach this implementation only after
/// view-side adapters normalize them into terminal values. Native encoders,
/// terminal selection resources, geometry commitment, and public callback
/// effects remain inside this session boundary.
final class TerminalControllerImpl extends TerminalController {
  static const _cr = 0x0d;
  static const _formFeed = 0x0c;

  static final _appCursorDown = Uint8List.fromList([0x1b, 0x4f, 0x42]);
  static final _appCursorUp = Uint8List.fromList([0x1b, 0x4f, 0x41]);
  static final _clearScrollback = utf8.encode('\x1b[3J');
  static final _crBytes = Uint8List.fromList([_cr]);
  static final _cursorDown = Uint8List.fromList([0x1b, 0x5b, 0x42]);
  static final _cursorUp = Uint8List.fromList([0x1b, 0x5b, 0x41]);
  static final _formFeedBytes = Uint8List.fromList([_formFeed]);

  final Terminal _terminal;
  final _viewportChanges = ChangeNotifier();
  late final InputEncoder _inputEncoder;
  late final SelectionSession _selection;

  ColorScheme _colorScheme = .dark;
  SurfaceGeometry? _committedGeometry;
  TerminalConfig _config;
  var _disposed = false;
  late _Observation _observation;
  ClipboardWriteCallback? _onClipboardWrite;
  ValueChanged<Uint8List>? _onOutput;
  VoidCallback? _onPwdChanged;
  OnResize? _onResize;
  var _pwd = '';
  var _pwdChanged = false;
  Object? _viewToken;
  Mods _virtualMods = const .none();
  final TerminalKeyEventNormalizer? keyEventNormalizer;

  TerminalControllerImpl({
    TerminalConfig config = const TerminalConfig(),
    this.keyEventNormalizer,
  }) : _config = config,
       _terminal = Terminal(cols: config.cols, rows: config.rows),
       super.base() {
    _inputEncoder = InputEncoder(_terminal);
    _selection = SelectionSession(_terminal, notifyListeners);
    installDefaultKittyPngDecoder();
    _wireTerminalCallbacks();
    _applyModes();
    _applyTerminalOptions();
    _observation = _readObservation();
    _terminal.addListener(_onTerminalChanged);
  }

  @override
  TerminalScreen get activeScreen {
    _checkNotDisposed();
    return _terminal.activeScreen;
  }

  @override
  TerminalConfig get config {
    _checkNotDisposed();
    return _config;
  }

  @override
  set config(TerminalConfig value) {
    _checkNotDisposed();
    if (_config == value) return;
    _config = value;
    _applyModes();
    _applyTerminalOptions();
    _wireTerminalCallbacks();
    _observation = _readObservation();
    notifyListeners();
  }

  bool get cursorBlinking {
    _checkNotDisposed();
    return _observation.cursorBlinking;
  }

  @override
  bool get hasSelection {
    _checkNotDisposed();
    return _selection.hasSelection;
  }

  bool get isDisposed => _disposed;

  @override
  MouseTracking get mouseTracking {
    _checkNotDisposed();
    return _observation.mouseTracking;
  }

  @override
  set onBell(VoidCallback? value) {
    _checkNotDisposed();
    _terminal.onBell = value;
  }

  @override
  set onClipboardWrite(ClipboardWriteCallback? value) {
    _checkNotDisposed();
    if (identical(_onClipboardWrite, value)) return;
    _onClipboardWrite = value;
    _terminal.onClipboardWrite = value;
  }

  @override
  set onDesktopNotification(ValueChanged<DesktopNotification>? value) {
    _checkNotDisposed();
    _terminal.onDesktopNotification = value;
  }

  @override
  set onOutput(ValueChanged<Uint8List>? value) {
    _checkNotDisposed();
    _onOutput = value;
    _terminal.onWritePty = value;
  }

  @override
  set onProgressReport(ValueChanged<TerminalProgress>? value) {
    _checkNotDisposed();
    _terminal.onProgressReport = value;
  }

  @override
  set onPwdChanged(VoidCallback? value) {
    _checkNotDisposed();
    _onPwdChanged = value;
  }

  @override
  set onResize(OnResize? value) {
    _checkNotDisposed();
    _onResize = value;
    if (value == null) return;

    final geometry = _committedGeometry;
    if (geometry != null) value(geometry.cols, geometry.rows);
  }

  @override
  set onTitleChanged(VoidCallback? value) {
    _checkNotDisposed();
    _terminal.onTitleChanged = value;
  }

  @override
  String get pwd {
    _checkNotDisposed();
    return _pwd;
  }

  @override
  int get scrollbackRows {
    _checkNotDisposed();
    return _terminal.scrollbackRows;
  }

  @override
  Scrollbar get scrollbar {
    _checkNotDisposed();
    return _terminal.scrollbar;
  }

  Terminal get terminal {
    _checkNotDisposed();
    return _terminal;
  }

  @override
  String get title {
    _checkNotDisposed();
    return _terminal.title;
  }

  @override
  int get totalRows {
    _checkNotDisposed();
    return _terminal.totalRows;
  }

  Listenable get viewportChanges {
    _checkNotDisposed();
    return _viewportChanges;
  }

  @override
  Mods get virtualMods {
    _checkNotDisposed();
    return _virtualMods;
  }

  Object attachView() {
    _checkNotDisposed();
    if (_viewToken != null) {
      throw StateError('TerminalController already has an active view.');
    }
    final token = Object();
    _viewToken = token;
    return token;
  }

  void cancelSelectionGesture() {
    _checkNotDisposed();
    _selection.cancelGesture();
  }

  @override
  void clear() {
    _checkNotDisposed();
    if (_observation.activeScreen == .alternate) return;
    clearSelection();
    _terminal.write(_clearScrollback);
    _emitOutput(_formFeedBytes);
  }

  @override
  void clearSelection() {
    _checkNotDisposed();
    _selection.clear(notify: true);
  }

  @override
  void clearVirtualMods() {
    _checkNotDisposed();
    if (_virtualMods.isEmpty) return;
    _virtualMods = const .none();
    notifyListeners();
  }

  @override
  Formatter createFormatter({
    required FormatterFormat format,
    bool unwrap = false,
    bool trim = false,
    FormatterExtra extra = const FormatterExtra(),
  }) {
    _checkNotDisposed();
    return Formatter(
      terminal: _terminal,
      format: format,
      unwrap: unwrap,
      trim: trim,
      extra: extra,
    );
  }

  void detachView(Object token) {
    if (_disposed) return;
    if (identical(_viewToken, token)) _viewToken = null;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _viewToken = null;
    _terminal.removeListener(_onTerminalChanged);
    _viewportChanges.dispose();
    _inputEncoder.dispose();
    _selection.dispose();
    _terminal.dispose();
    super.dispose();
  }

  void handleFocusChanged({required bool focused}) {
    _checkNotDisposed();
    if (!focused) clearVirtualMods();

    if (_terminal.modeGet(const TerminalMode.focusEvent())) {
      final event = focused ? FocusEvent.gained : FocusEvent.lost;
      _emitOutput(utf8.encode(event.encode()));
    }
  }

  void handleMouseEvent(MouseInput input) {
    _checkNotDisposed();
    final result = _inputEncoder.encodeMouse(
      input,
      geometry: _committedGeometry,
    );
    if (result.isEmpty) return;
    _emitOutput(utf8.encode(result));
  }

  void handleResize(SurfaceMeasurement measurement) {
    _checkNotDisposed();
    final geometry = SurfaceGeometry.tryFrom(measurement);
    if (geometry == null || geometry == _committedGeometry) return;

    final previous = _committedGeometry;
    _commitGeometry(geometry);
    if (previous == null ||
        previous.cols != geometry.cols ||
        previous.rows != geometry.rows) {
      _onResize?.call(geometry.cols, geometry.rows);
    }
  }

  void handleSelectionPress(SelectionPressInput event) {
    _checkNotDisposed();
    _selection.handlePress(event);
  }

  void handleSelectionRelease(Position cell) {
    _checkNotDisposed();
    _selection.handleRelease(cell);
  }

  KeyDisposition handleTerminalKey(
    KeyInput input, {
    required bool routeToTextInput,
    required bool forwardDeletionToTextInput,
  }) {
    _checkNotDisposed();
    if (!input.composing &&
        (input.action == .press || input.action == .repeat) &&
        input.mods.hasShift &&
        _terminal.selection != null) {
      if (_selection.extend(input.key)) return .handled;
    }

    final result = _inputEncoder.encodeKey(input);
    if (result.isEmpty) return input.composing ? .handled : .ignored;

    if (routeToTextInput && result == input.character) {
      _onTextInput();
      return .skipRemainingHandlers;
    }

    clearVirtualMods();
    _emitOutput(utf8.encode(result));
    _onTextInput();

    return forwardDeletionToTextInput ? .skipRemainingHandlers : .handled;
  }

  void handleTerminalScroll(ScrollInput input) {
    _checkNotDisposed();
    if (input.horizontal == 0 && input.vertical == 0) return;

    if (input.reportMouse) {
      if (_terminal.mouseTracking == .none) return;
      _sendScrollButtons(
        input.vertical,
        negativeButton: .four,
        positiveButton: .five,
        input: input,
      );
      _sendScrollButtons(
        input.horizontal,
        negativeButton: .six,
        positiveButton: .seven,
        input: input,
      );
      return;
    }

    if (_terminal.mouseTracking != .none ||
        _terminal.activeScreen != .alternate ||
        !_terminal.modeGet(const .alternateScroll()) ||
        input.vertical == 0) {
      return;
    }

    final up = _observation.cursorKeyApplication ? _appCursorUp : _cursorUp;
    final down = _observation.cursorKeyApplication
        ? _appCursorDown
        : _cursorDown;
    final key = input.vertical < 0 ? up : down;
    final count = input.vertical.abs();
    _emitOutput(_repeatBytes(key, count));
  }

  void handleTextCommitted(String text) {
    _checkNotDisposed();
    if (_virtualMods.isEmpty) {
      _emitOutput(utf8.encode(text));
      _onTextInput();
      return;
    }

    if (text.length == 1) {
      final key = keyFromCodepoint(text.codeUnitAt(0));
      if (key != null) {
        sendKey(key);
        return;
      }
    }

    _emitOutput(utf8.encode(text));
    clearVirtualMods();
    _onTextInput();
  }

  void handleTextCompositionChanged({required bool active}) {
    _checkNotDisposed();
    if (active) _onTextInput();
  }

  void handleTextDeleted(int count) {
    _checkNotDisposed();
    if (count <= 0) return;

    var emitted = false;
    for (var i = 0; i < count; i++) {
      emitted =
          _emitKeyPress(.backspace, mods: _virtualMods, clearMods: false) ||
          emitted;
    }
    if (!emitted) return;

    clearVirtualMods();
    _onTextInput();
  }

  void handleTextNewline() {
    _checkNotDisposed();
    _emitOutput(_crBytes);
    clearVirtualMods();
    _onTextInput();
  }

  void invalidateSelection() {
    _checkNotDisposed();
    _selection.invalidate();
  }

  @override
  bool modeGet(TerminalMode mode) {
    _checkNotDisposed();
    return _terminal.modeGet(mode);
  }

  @override
  void modeSet(TerminalMode mode, {required bool value}) {
    _checkNotDisposed();
    _terminal.modeSet(mode, value: value);
  }

  @override
  void paste(String text) {
    _checkNotDisposed();
    if (text.isEmpty) return;
    final bracketed = _terminal.modeGet(const .bracketedPaste());
    _emitOutput(pasteEncode(text, bracketed: bracketed));
    _scrollToBottomOnInput();
  }

  @override
  void scrollToBottom() {
    _checkNotDisposed();
    if (_observation.activeScreen == .alternate) return;
    final previousOffset = _terminal.scrollbar.offset;
    _terminal.scrollToBottom();
    if (_terminal.scrollbar.offset != previousOffset) {
      _viewportChanges.notifyListeners();
    }
  }

  void scrollToRow(int row) {
    _checkNotDisposed();
    final previousOffset = _terminal.scrollbar.offset;
    _terminal.scrollToRow(row);
    if (_terminal.scrollbar.offset != previousOffset) {
      _viewportChanges.notifyListeners();
    }
  }

  @override
  void scrollToTop() {
    _checkNotDisposed();
    if (_observation.activeScreen == .alternate) return;
    final previousOffset = _terminal.scrollbar.offset;
    _terminal.scrollToTop();
    if (_terminal.scrollbar.offset != previousOffset) {
      _viewportChanges.notifyListeners();
    }
  }

  @override
  void selectAll() {
    _checkNotDisposed();
    _selection.selectAll();
  }

  @override
  String selectedText({FormatterFormat format = .plain}) {
    _checkNotDisposed();
    return _selection.selectedText(format: format);
  }

  @override
  void selectRange({
    required Position start,
    required Position end,
    PointTag pointTag = .screen,
    bool rectangle = false,
  }) {
    _checkNotDisposed();
    _selection.selectRange(
      start: start,
      end: end,
      pointTag: pointTag,
      rectangle: rectangle,
    );
  }

  @override
  void sendKey(Key key, {Mods mods = const .none()}) {
    _checkNotDisposed();
    final effectiveMods = mods | _virtualMods;
    final result = _inputEncoder.encodeKeyPress(key, mods: effectiveMods);
    if (result.isEmpty) return;
    _emitOutput(utf8.encode(result));
    clearVirtualMods();
  }

  @override
  void sendText(String text) {
    _checkNotDisposed();
    if (text.isEmpty) return;
    _emitOutput(utf8.encode(text));
    clearVirtualMods();
  }

  void setColorScheme(ColorScheme value) {
    _checkNotDisposed();
    if (_colorScheme == value) return;
    _colorScheme = value;
  }

  @override
  void toggleMod(Mods mod) {
    _checkNotDisposed();
    _virtualMods = _virtualMods ^ mod;
    notifyListeners();
  }

  void updateSelectionAutoscroll(SelectionAutoscrollInput event) {
    _checkNotDisposed();
    _selection.handleAutoscroll(event);
  }

  void updateSelectionDrag(SelectionDragInput event) {
    _checkNotDisposed();
    _selection.handleDrag(event);
  }

  @override
  void write(Uint8List data) {
    _checkNotDisposed();
    _terminal.write(data);
    _scrollToBottomOnOutput();
  }

  void _applyModes() {
    _checkNotDisposed();
    for (final entry in _config.modes.entries) {
      _terminal.modeSet(entry.key, value: entry.value);
    }
  }

  void _applyTerminalOptions() {
    _terminal.scrollbackMaxBytes = _config.scrollbackMaxBytes;
    _terminal.scrollbackMaxLines = _config.scrollbackMaxLines;
    _terminal.kittyImageStorageLimit = _config.kittyImageStorageLimit;
    _terminal.setApcBufferLimit(_config.apcBufferLimit);
    _terminal.setGlyphProtocol(enabled: _config.glyphProtocol);
    _terminal.defaultCursorShape = .fromValue(_config.cursorStyle.value);
    _terminal.defaultCursorBlink = _config.cursorBlink;
  }

  void _checkNotDisposed() {
    if (_disposed) throw StateError('TerminalController is disposed.');
  }

  void _commitGeometry(SurfaceGeometry geometry) {
    final current = _terminal.geometry;
    final gridChanged =
        current.cols != geometry.cols || current.rows != geometry.rows;
    final pixelGeometryChanged =
        current.widthPx != geometry.cols * geometry.cellWidthPx ||
        current.heightPx != geometry.rows * geometry.cellHeightPx;
    if (gridChanged || pixelGeometryChanged) {
      _terminal.resize(
        cols: geometry.cols,
        rows: geometry.rows,
        cellWidthPx: geometry.cellWidthPx,
        cellHeightPx: geometry.cellHeightPx,
      );
    }

    _inputEncoder.updateGeometry(geometry);
    _selection.updateGeometry(geometry);

    _committedGeometry = geometry;
  }

  bool _effectiveCursorBlinking() {
    return _config.cursorBlink ?? _terminal.modeGet(const .cursorBlinking());
  }

  bool _emitKeyPress(
    Key key, {
    Mods mods = const .none(),
    bool clearMods = true,
  }) {
    final result = _inputEncoder.encodeKeyPress(key, mods: mods);
    if (result.isEmpty) return false;

    _emitOutput(utf8.encode(result));
    if (clearMods) clearVirtualMods();
    return true;
  }

  void _emitOutput(Uint8List bytes) => _onOutput?.call(bytes);

  void _handlePwdChanged() {
    // The terminal listener publishes the final state after the write ends.
    _pwd = _terminal.pwd;
    _pwdChanged = true;
    _onPwdChanged?.call();
  }

  TerminalSizeInfo _handleSizeQuery() {
    _checkNotDisposed();
    final geometry = _terminal.geometry;
    final committed = _committedGeometry;
    final cellWidth = geometry.cols > 0 && geometry.widthPx > 0
        ? geometry.widthPx ~/ geometry.cols
        : committed?.cellWidthPx ?? 0;
    final cellHeight = geometry.rows > 0 && geometry.heightPx > 0
        ? geometry.heightPx ~/ geometry.rows
        : committed?.cellHeightPx ?? 0;
    return TerminalSizeInfo(
      rows: geometry.rows,
      columns: geometry.cols,
      cellWidth: cellWidth,
      cellHeight: cellHeight,
    );
  }

  void _onTerminalChanged() {
    if (_disposed) return;
    final pwdChanged = _pwdChanged;
    _pwdChanged = false;
    final previous = _observation;
    final next = _readObservation();
    _observation = next;
    if (previous.activeScreen != next.activeScreen &&
        next.activeScreen == .primary) {
      _applyModes();
    }

    if (pwdChanged || previous != next) notifyListeners();
  }

  void _onTextInput() {
    if (_config.selectionClearOnTyping) clearSelection();
    _scrollToBottomOnInput();
  }

  _Observation _readObservation() => (
    activeScreen: _terminal.activeScreen,
    mouseTracking: _terminal.mouseTracking,
    cursorKeyApplication: _terminal.modeGet(const .cursorKeys()),
    cursorBlinking: _effectiveCursorBlinking(),
  );

  Uint8List _repeatBytes(List<int> value, int count) {
    final bytes = Uint8List(value.length * count);
    for (var i = 0; i < count; i++) {
      bytes.setRange(i * value.length, (i + 1) * value.length, value);
    }
    return bytes;
  }

  void _scrollToBottomOnInput() {
    if (_observation.activeScreen == .alternate) return;
    final policy = _config.scrollToBottom;
    if (policy == .onKeystroke || policy == .both) scrollToBottom();
  }

  void _scrollToBottomOnOutput() {
    if (_observation.activeScreen == .alternate) return;
    final policy = _config.scrollToBottom;
    if (policy == .onOutput || policy == .both) scrollToBottom();
  }

  void _sendScrollButtons(
    int steps, {
    required MouseButton negativeButton,
    required MouseButton positiveButton,
    required ScrollInput input,
  }) {
    if (steps == 0) return;
    final button = steps < 0 ? negativeButton : positiveButton;
    final result = _inputEncoder.encodeScrollButton(
      input,
      button: button,
      geometry: _committedGeometry,
    );
    if (result.isEmpty) return;
    _emitOutput(_repeatBytes(utf8.encode(result), steps.abs()));
  }

  void _wireTerminalCallbacks() {
    _terminal.onColorScheme = () => _colorScheme;
    _terminal.onSize = _handleSizeQuery;
    _terminal.onPwdChanged = _handlePwdChanged;
    _terminal.onDeviceAttributes = () => _config.deviceAttributes;
    final enquiry = _config.enquiryResponse;
    _terminal.onEnquiry = enquiry.isEmpty
        ? null
        : () => .fromList(utf8.encode(enquiry));
  }
}
