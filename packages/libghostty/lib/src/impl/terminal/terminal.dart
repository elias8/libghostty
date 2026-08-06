import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../bindings/bindings.dart';
import '../../ffi/libghostty_enums.g.dart';
import '../../listenable.dart';
import '../key/kitty_key_flags.dart';
import '../key/mods.dart';
import 'terminal_mode.dart';

part '../key/key_encoder.dart';
part '../key/key_event.dart';
part '../mouse/mouse_encoder.dart';
part '../mouse/mouse_event.dart';
part 'cell_iterator.dart';
part 'cursor.dart';
part 'formatter.dart';
part 'grid_ref.dart';
part 'kitty_graphics.dart';
part 'render_state.dart';
part 'row_iterator.dart';
part 'selection.dart';
part 'selection_gesture.dart';
part 'tracked_grid_ref.dart';

/// Complete terminal emulator managing screen state, scrollback, cursor,
/// styles, modes, and VT stream processing.
///
/// By default, VT sequence processing via [write] only handles sequences that
/// directly affect terminal state. Sequences with side effects (bell, title
/// changes, device queries) are silently ignored unless the corresponding
/// callback is registered. See the "Effects" section below.
///
/// ## Companion types
///
/// [Terminal] is the VT state machine and effect dispatcher. Rendering,
/// coordinate queries, encoding, and formatting are handled by independent,
/// disposable companion types that take a [Terminal] when they need one:
///
/// - [RenderState] with [RowIterator] / [CellIterator] for rendering
/// - [GridRef.at] for one-off cell lookups
/// - [TrackedGridRef.at] for grid references that survive terminal mutations
/// - [KittyGraphics.of] for Kitty graphics storage access
/// - [Formatter] for extracting terminal content
/// - [KeyEncoder] / [MouseEncoder] for encoding input events
///
/// ## Effects
///
/// Effects are callbacks invoked synchronously by terminal operations. Most
/// respond to VT sequences during [write], while [onWritePty] can also fire
/// during a callback-emitting [resize]. Register them by assigning the callback
/// setters ([onWritePty], [onBell], [onTitleChanged], etc.). Set to null to
/// disable.
///
/// Callbacks run synchronously. Callers **must not** call [write] from within a
/// callback (no reentrancy), and callbacks should avoid blocking or expensive
/// operations since they block further I/O processing. Callback exceptions do
/// not interrupt terminal processing. After the initiating operation finishes,
/// the first exception is rethrown with its original stack trace.
///
/// ## Color Theme
///
/// The terminal maintains two color layers for foreground, background, cursor,
/// and the 256-color palette: **defaults** set by the embedder and
/// **overrides** set by programs running in the terminal via OSC sequences (OSC
/// 10/11/12 for foreground/background/cursor, OSC 4 for palette entries).
///
/// The effective color getters ([foreground], [background], [cursorColor],
/// [palette]) return the OSC override if one is active, otherwise the default.
/// The default-only getters ([foregroundDefault], [backgroundDefault],
/// [cursorColorDefault], [paletteDefault]) ignore OSC overrides.
///
/// ```dart
/// final terminal = Terminal(cols: 80, rows: 24);
///
/// terminal.onWritePty = (data) => pty.write(data);
/// terminal.onBell = () => playSound();
///
/// terminal.write(vtData);
/// terminal.resize(cols: 120, rows: 40, cellWidthPx: 8, cellHeightPx: 16);
///
/// terminal.dispose();
/// ```
final class Terminal with Listenable {
  static final _finalizer = Finalizer<int>((handle) {
    bindings.terminalDisposeCallbacks(handle);
    bindings.terminalFree(handle);
  });

  final int _handle;
  bool _disposed;

  /// Creates a terminal with the given grid dimensions.
  ///
  /// Both [cols] and [rows] must be greater than zero.
  ///
  /// Throws [OutOfMemoryException] if the native allocation fails.
  ///
  /// ```dart
  /// final terminal = Terminal(cols: 80, rows: 24);
  /// ```
  Terminal({required int cols, required int rows})
    : _handle = check(bindings.terminalNew(cols, rows)),
      _disposed = false {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// The active screen buffer (primary or alternate).
  ///
  /// Programs switch screens via DEC private mode 1049 (e.g. when entering
  /// full-screen editors like vim).
  TerminalScreen get activeScreen {
    return check(bindings.terminalGetActiveScreen(_handle));
  }

  /// Effective background color (OSC override if active, otherwise default).
  ///
  /// Returns null if no color is configured (neither a default nor an OSC
  /// override).
  RgbColor? get background {
    return _optionalValue(bindings.terminalGetColorBackground(_handle));
  }

  /// Sets the default background color, or clears it if null.
  ///
  /// This sets the embedder default. Programs running in the terminal can
  /// still override it via OSC 11.
  set background(RgbColor? color) {
    checkCode(bindings.terminalSetColorBackground(_handle, color));
  }

  /// Default background color, ignoring any OSC override.
  ///
  /// Returns null if no default has been configured.
  RgbColor? get backgroundDefault {
    return _optionalValue(bindings.terminalGetColorBackgroundDefault(_handle));
  }

  /// Opaque token that changes when scrollback compression may have new work.
  ///
  /// Terminal operations such as writes, resizing, and viewport movement may
  /// change the token. Cache it and restart an idle delay whenever it changes.
  /// Only equality comparisons are meaningful, and compression itself does not
  /// change the token.
  ///
  /// ```dart
  /// final previous = terminal.compressionActivity;
  /// terminal.write(data);
  /// if (terminal.compressionActivity != previous) scheduleCompression();
  /// ```
  int get compressionActivity {
    return check(bindings.terminalCompressionActivity(_handle));
  }

  /// Effective cursor color (OSC override if active, otherwise default).
  ///
  /// Returns null if no color is configured.
  RgbColor? get cursorColor {
    return _optionalValue(bindings.terminalGetColorCursor(_handle));
  }

  /// Sets the default cursor color, or clears it if null.
  ///
  /// Programs running in the terminal can override this via OSC 12.
  set cursorColor(RgbColor? color) {
    checkCode(bindings.terminalSetColorCursor(_handle, color));
  }

  /// Default cursor color, ignoring any OSC override.
  ///
  /// Returns null if no default has been configured.
  RgbColor? get cursorColorDefault {
    return _optionalValue(bindings.terminalGetColorCursorDefault(_handle));
  }

  /// The cursor's current SGR style (applied to newly printed characters).
  Style get cursorStyle => check(bindings.terminalGetCursorStyle(_handle));

  /// Sets whether DECSCUSR reset (CSI 0 q) restores a blinking cursor.
  set defaultCursorBlink(bool? value) {
    checkCode(bindings.terminalSetDefaultCursorBlink(_handle, blinking: value));
  }

  /// Sets the cursor shape restored by DECSCUSR reset (CSI 0 q).
  set defaultCursorShape(CursorShape? value) {
    checkCode(bindings.terminalSetDefaultCursorShape(_handle, value));
  }

  /// Effective foreground color (OSC override if active, otherwise default).
  ///
  /// Returns null if no color is configured (neither a default nor an OSC
  /// override).
  RgbColor? get foreground {
    return _optionalValue(bindings.terminalGetColorForeground(_handle));
  }

  /// Sets the default foreground color, or clears it if null.
  ///
  /// Programs running in the terminal can override this via OSC 10.
  set foreground(RgbColor? color) {
    checkCode(bindings.terminalSetColorForeground(_handle, color));
  }

  /// Default foreground color, ignoring any OSC override.
  ///
  /// Returns null if no default has been configured.
  RgbColor? get foregroundDefault {
    return _optionalValue(bindings.terminalGetColorForegroundDefault(_handle));
  }

  /// Current terminal dimensions in cells and pixels.
  ///
  /// Pixel dimensions are zero when no cell pixel size has been configured.
  ///
  /// ```dart
  /// final geometry = terminal.geometry;
  /// final cellWidth = geometry.widthPx ~/ geometry.cols;
  /// ```
  TerminalGeometry get geometry => check(bindings.terminalGetGeometry(_handle));

  /// Whether VT processing encountered a non-gracefully handled error.
  ///
  /// The flag is informational and remains set for this terminal's lifetime,
  /// including after [reset]. Gracefully handled protocol errors, configured
  /// limits, malformed input, and unsupported input do not set it.
  ///
  /// ```dart
  /// if (terminal.hasVtProcessingError) {
  ///   reportDegradedTerminalState();
  /// }
  /// ```
  bool get hasVtProcessingError {
    return check(bindings.terminalGetVtProcessingError(_handle));
  }

  /// Total terminal height in pixels (rows * cell height).
  int get heightPx => check(bindings.terminalGetHeightPx(_handle));

  /// Whether the file medium is enabled for Kitty image loading.
  /// Returns null when Kitty graphics are not compiled in.
  bool? get isKittyFileMedium {
    final (code, value) = bindings.terminalGetKittyImageMediumFile(_handle);
    return code == .noValue ? null : check((code, value));
  }

  /// Whether the shared memory medium is enabled for Kitty image loading.
  /// Returns null when Kitty graphics are not compiled in.
  bool? get isKittySharedMemMedium {
    final (code, value) = bindings.terminalGetKittyImageMediumSharedMem(
      _handle,
    );
    return code == .noValue ? null : check((code, value));
  }

  /// Whether any mouse tracking mode is currently active.
  bool get isMouseTracking => check(bindings.terminalGetMouseTracking(_handle));

  /// Whether the viewport is at the active terminal area instead of scrollback.
  bool get isViewportActive {
    return check(bindings.terminalGetViewportActive(_handle));
  }

  /// Kitty image storage limit in bytes for the active screen.
  ///
  /// Zero means the Kitty graphics protocol is disabled. Returns null when
  /// Kitty graphics support is not compiled into the library.
  int? get kittyImageStorageLimit {
    final (code, value) = bindings.terminalGetKittyImageStorageLimit(_handle);
    return code == .noValue ? null : check((code, value));
  }

  /// Sets the Kitty image storage limit in bytes. Zero or null disables
  /// the Kitty graphics protocol entirely.
  set kittyImageStorageLimit(int? value) {
    checkCode(bindings.terminalSetKittyImageStorageLimit(_handle, value));
  }

  /// Current Kitty keyboard protocol flags.
  ///
  /// Reflects the flags set by the program running in the terminal via the
  /// Kitty keyboard protocol. Use [KeyEncoder] to encode key events according
  /// to these flags.
  KittyKeyFlags get kittyKeyboardFlags => KittyKeyFlags.fromValue(
    check(bindings.terminalGetKittyKeyboardFlags(_handle)),
  );

  /// Directory allowed for Kitty image loading through temporary files.
  ///
  /// An empty string means the medium is disabled. Returns null when Kitty
  /// graphics support is not compiled into the library.
  ///
  /// ```dart
  /// final directory = terminal.kittyTempFileDirectory;
  /// ```
  String? get kittyTempFileDirectory {
    final (code, value) = bindings.terminalGetKittyImageMediumTempFile(_handle);
    return code == .noValue ? null : check((code, value));
  }

  /// Active mouse tracking mode derived from the current terminal modes.
  ///
  /// Returns [MouseTracking.none] if no mouse tracking mode is enabled.
  /// Programs enable mouse tracking via DEC private modes (9, 1000, 1002,
  /// 1003).
  MouseTracking get mouseTracking {
    if (modeGet(const .anyMouse())) return .any;
    if (modeGet(const .buttonMouse())) return .button;
    if (modeGet(const .normalMouse())) return .normal;
    if (modeGet(const .x10Mouse())) return .x10;
    return MouseTracking.none;
  }

  /// Registers a callback for BEL character (0x07).
  ///
  /// Fires synchronously during [write]. Set to null to ignore bell events.
  set onBell(VoidCallback? value) => bindings.terminalSetOnBell(_handle, value);

  /// Registers a callback for clipboard writes requested by terminal content.
  ///
  /// OSC 52 and iTerm2 Copy requests are decoded into protocol-neutral,
  /// binary-safe [ClipboardWrite] values. Return the result of committing the
  /// complete request. Fires synchronously during [write]. Set to null to
  /// ignore clipboard writes.
  ///
  /// ```dart
  /// terminal.onClipboardWrite = (request) {
  ///   if (!trustedSession) return .denied;
  ///   clipboard.replace(request);
  ///   return .success;
  /// };
  /// ```
  set onClipboardWrite(ClipboardWriteCallback? value) {
    bindings.terminalSetOnClipboardWrite(_handle, value);
  }

  /// Registers a callback for OSC 9 and OSC 777 desktop notifications.
  ///
  /// Requests are untrusted terminal content. The callback decides whether and
  /// how to display them. Fires synchronously during [write]. Set to null to
  /// ignore notifications.
  set onDesktopNotification(DesktopNotificationCallback? value) {
    bindings.terminalSetOnDesktopNotification(_handle, value);
  }

  /// Registers a callback for OSC 9;4 progress reports.
  ///
  /// Fires synchronously during [write]. Set to null to ignore reports.
  set onProgressReport(TerminalProgressCallback? value) {
    bindings.terminalSetOnProgressReport(_handle, value);
  }

  /// Registers a callback for color scheme queries (CSI ? 996 n).
  ///
  /// Return the current [ColorScheme], or null to silently ignore the query.
  /// Fires synchronously during [write].
  set onColorScheme(ValueGetter<ColorScheme?>? value) {
    bindings.terminalSetOnColorScheme(_handle, value);
  }

  /// Registers a callback for device attributes queries (CSI c / > c / = c).
  ///
  /// Return a [DeviceAttributesResponse], or null to silently ignore the query.
  /// Fires synchronously during [write].
  set onDeviceAttributes(ValueGetter<DeviceAttributesResponse?>? value) {
    bindings.terminalSetOnDeviceAttributes(_handle, value);
  }

  /// Registers a callback for ENQ character (0x05).
  ///
  /// Return the response bytes to write back to the PTY. Return an empty list
  /// to send no response. Fires synchronously during [write].
  set onEnquiry(ValueGetter<Uint8List>? value) {
    bindings.terminalSetOnEnquiry(_handle, value);
  }

  /// Registers a callback for working-directory changes via OSC 7/9/1337.
  ///
  /// Query the new [pwd] after the callback returns. Fires synchronously
  /// during [write].
  set onPwdChanged(VoidCallback? value) {
    bindings.terminalSetOnPwdChanged(_handle, value);
  }

  /// Registers a callback for XTWINOPS size queries (CSI 14/16/18 t).
  ///
  /// Return a [TerminalSizeInfo] with the current geometry, or null to
  /// silently ignore the query. Fires synchronously during [write].
  set onSize(ValueGetter<TerminalSizeInfo?>? value) {
    bindings.terminalSetOnSize(_handle, value);
  }

  /// Registers a callback for title changes via OSC 0 or OSC 2.
  ///
  /// Query the new [title] after the callback returns. Fires synchronously
  /// during [write].
  set onTitleChanged(VoidCallback? value) {
    bindings.terminalSetOnTitleChanged(_handle, value);
  }

  /// Registers a callback for PTY write-back data.
  ///
  /// Invoked when the terminal needs to send data back to the PTY, for
  /// example in response to device status reports or mode queries. The data is
  /// owned by Dart and remains valid after the callback returns. Fires
  /// synchronously during [write].
  set onWritePty(ValueSetter<Uint8List>? value) {
    bindings.terminalSetOnWritePty(_handle, value);
  }

  /// Registers a callback for XTVERSION queries (CSI > q).
  ///
  /// Return the version string to report (e.g. "myterm 1.0"). Return an empty
  /// string to use the default "libghostty" identifier. Fires synchronously
  /// during [write].
  set onXtversion(ValueGetter<String>? value) {
    bindings.terminalSetOnXtversion(_handle, value);
  }

  /// Current 256-color palette with any active OSC 4 overrides applied.
  ///
  /// Always returns a 256-element list (the built-in default palette is used
  /// as a baseline).
  ///
  /// Throws [LibGhosttyException] if the terminal is in an invalid state.
  List<RgbColor> get palette {
    return check(bindings.terminalGetColorPalette(_handle));
  }

  /// Sets the default 256-color palette, or resets to built-in defaults if
  /// null.
  ///
  /// Only updates indices that have not been overridden by OSC 4. Per-index
  /// OSC overrides are preserved.
  ///
  /// Throws [LibGhosttyException] if the palette cannot be set.
  set palette(List<RgbColor>? colors) {
    checkCode(bindings.terminalSetColorPalette(_handle, colors));
  }

  /// Default 256-color palette, ignoring any OSC 4 overrides.
  ///
  /// Throws [LibGhosttyException] if the terminal is in an invalid state.
  List<RgbColor> get paletteDefault {
    return check(bindings.terminalGetColorPaletteDefault(_handle));
  }

  /// Current working directory as reported by OSC 7.
  ///
  /// The returned value is borrowed from the terminal. Read it immediately
  /// after [write] or [reset]; it may change on the next call to either.
  String get pwd => check(bindings.terminalGetPwd(_handle));

  /// Sets the working directory, or clears it if null.
  set pwd(String? value) => checkCode(bindings.terminalSetPwd(_handle, value));

  /// Maximum bytes retained for scrollback, or null when unlimited.
  ///
  /// This limit and [scrollbackMaxLines] apply together. Ghostty prunes when
  /// either limit is reached, at page granularity.
  int? get scrollbackMaxBytes {
    return _optionalValue(bindings.terminalGetScrollbackMaxBytes(_handle));
  }

  /// Sets the maximum bytes retained for scrollback.
  ///
  /// Set to null for no byte limit or zero to clear retained history and
  /// disable scrollback by bytes.
  set scrollbackMaxBytes(int? value) {
    checkCode(bindings.terminalSetScrollbackMaxBytes(_handle, value));
  }

  /// Maximum physical lines retained for scrollback, or null when unlimited.
  ///
  /// This limit and [scrollbackMaxBytes] apply together. Ghostty prunes when
  /// either limit is reached, at page granularity.
  int? get scrollbackMaxLines {
    return _optionalValue(bindings.terminalGetScrollbackMaxLines(_handle));
  }

  /// Sets the maximum physical lines retained for scrollback.
  ///
  /// Set to null for no line limit or zero to clear retained history and
  /// disable scrollback by lines.
  set scrollbackMaxLines(int? value) {
    checkCode(bindings.terminalSetScrollbackMaxLines(_handle, value));
  }

  /// Number of rows in the scrollback buffer (excluding the active grid).
  int get scrollbackRows => check(bindings.terminalGetScrollbackRows(_handle));

  /// Scrollbar position and dimensions for rendering a scrollbar widget.
  ///
  /// The total is maintained incrementally and the viewport offset is cached.
  /// The first read after moving the viewport to an arbitrary non-row position
  /// may traverse the scrollback page list to compute the offset, after which
  /// it is cached again.
  ///
  /// There is no scroll-state notification. Callers building scrollbars should
  /// poll this once per frame or per write batch and diff the result.
  Scrollbar get scrollbar => check(bindings.terminalGetScrollbar(_handle));

  /// Active selection on the terminal screen, or null when none is active.
  ///
  /// Getting returns an untracked snapshot. Setting installs a copy as
  /// terminal-owned tracked state. Set null to clear the active selection.
  Selection? get selection {
    final (code, raw) = bindings.terminalGetSelection(_handle);
    if (code == .noValue) return null;
    checkCode(code);
    return Selection._fromRaw(this, raw!);
  }

  /// Sets the active selection on the terminal screen.
  ///
  /// Assigning a selection installs a terminal-owned copy of its endpoints.
  /// Assign null to clear the active selection. Non-null selections must belong
  /// to this terminal.
  set selection(Selection? value) {
    checkCode(bindings.terminalSetSelection(_handle, _checkedSelection(value)));
    notifyListeners();
  }

  /// Terminal title as set by OSC 0 or OSC 2 sequences.
  ///
  /// The returned value is borrowed from the terminal. Read it immediately
  /// after [write] or [reset]; it may change on the next call to either.
  String get title => check(bindings.terminalGetTitle(_handle));

  /// Sets the terminal title, or clears it if null.
  set title(String? value) {
    checkCode(bindings.terminalSetTitle(_handle, value));
  }

  /// Total number of rows: active grid rows plus scrollback rows.
  int get totalRows => check(bindings.terminalGetTotalRows(_handle));

  /// Total terminal width in pixels (cols * cell width).
  int get widthPx => check(bindings.terminalGetWidthPx(_handle));

  int get _handleOrNull => _disposed ? 0 : _handle;

  /// Compresses eligible scrollback storage without changing terminal data.
  ///
  /// Incremental mode performs bounded work. Call it again while the result is
  /// [TerminalCompressionResult.pending] and [compressionActivity] has not
  /// changed. Full mode scans all currently eligible pages synchronously and
  /// can stall on large histories. Unsupported targets return
  /// [TerminalCompressionResult.unsupported].
  ///
  /// ```dart
  /// void compressOnce() {
  ///   final activity = terminal.compressionActivity;
  ///   final result = terminal.compress();
  ///   if (result == .pending && terminal.compressionActivity == activity) {
  ///     scheduleIdle(compressOnce);
  ///   }
  /// }
  /// ```
  TerminalCompressionResult compress({
    TerminalCompressionMode mode = .incremental,
  }) {
    return check(bindings.terminalCompress(_handle, mode));
  }

  /// Releases the native terminal handle and clears registered callbacks.
  ///
  /// Must be called to free resources; the terminal must not be used
  /// afterward.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    clearListeners();
    _finalizer.detach(this);
    bindings.terminalDisposeCallbacks(_handle);
    bindings.terminalFree(_handle);
  }

  /// Formats an explicit or active selection.
  ///
  /// When [selection] is null, the terminal's active selection is used. Returns
  /// null if no active selection exists.
  String? formatSelection({
    FormatterFormat format = .plain,
    bool unwrap = false,
    bool trim = false,
    Selection? selection,
  }) {
    final (code, text) = bindings.terminalSelectionFormat(
      _handle,
      format,
      unwrap: unwrap,
      trim: trim,
      selection: _checkedSelection(selection),
    );
    if (code == .noValue) return null;
    checkCode(code);
    return text;
  }

  /// Queries whether the given terminal [mode] is currently enabled.
  bool modeGet(TerminalMode mode) {
    return check(bindings.terminalModeGet(_handle, mode.value));
  }

  /// Enables or disables the given terminal [mode].
  void modeSet(TerminalMode mode, {required bool value}) {
    checkCode(bindings.terminalModeSet(_handle, mode.value, value: value));
  }

  /// Performs a full reset (RIS): resets modes, scrollback, scrolling region,
  /// and screen contents to defaults while preserving terminal dimensions.
  void reset() => bindings.terminalReset(_handle);

  /// Resizes the terminal grid to the given cell dimensions.
  ///
  /// The primary screen reflows content when autowrap is enabled; the
  /// alternate screen does not reflow. A no-op if dimensions are unchanged.
  ///
  /// Side effects: disables synchronized output mode, and sends an in-band
  /// size report if mode 2048 is enabled.
  ///
  /// [cellWidthPx] and [cellHeightPx] set the pixel dimensions per cell,
  /// used to compute [widthPx] and [heightPx] and to respond to pixel-based
  /// size queries. Notifies listeners synchronously after the resize completes.
  ///
  /// Throws [InvalidValueException] if [cols] or [rows] is zero.
  /// Throws [OutOfMemoryException] if reflow allocation fails.
  /// If an effect callback throws, the resize completes and listeners are
  /// notified before the exception is rethrown.
  void resize({
    required int cols,
    required int rows,
    int cellWidthPx = 0,
    int cellHeightPx = 0,
  }) {
    late final Result result;
    try {
      result = bindings.terminalResize(
        _handle,
        cols,
        rows,
        cellWidthPx,
        cellHeightPx,
      );
    } on Object catch (error, stackTrace) {
      try {
        notifyListeners();
      } finally {
        Error.throwWithStackTrace(error, stackTrace);
      }
    }
    checkCode(result);
    notifyListeners();
  }

  /// Scrolls the viewport to the bottom (active area).
  void scrollToBottom() => bindings.terminalScrollViewport(_handle, .bottom, 0);

  /// Scrolls the viewport to an absolute row in the scrollable area.
  ///
  /// Row zero is the top of scrollback. The requested row becomes the first
  /// visible viewport row and is clamped so the viewport never scrolls beyond
  /// the active area. If the terminal has no scrollback, for example when the
  /// alternate screen is active, the viewport remains on the active area.
  ///
  /// This uses the same row space as [Scrollbar.offset], so a scrollbar value
  /// can be passed here to restore that viewport position.
  void scrollToRow(int row) {
    RangeError.checkNotNegative(row, 'row');
    bindings.terminalScrollViewport(_handle, .row, row);
  }

  /// Scrolls the viewport to the top of the scrollback history.
  void scrollToTop() => bindings.terminalScrollViewport(_handle, .top, 0);

  /// Scrolls the viewport by [delta] rows. Positive values scroll down
  /// (toward the active area), negative values scroll up (toward history).
  void scrollViewport(int delta) {
    if (delta == 0) return;
    bindings.terminalScrollViewport(_handle, .delta, delta);
  }

  /// Derives a selection snapshot covering all selectable terminal content.
  ///
  /// The returned selection is not installed as the terminal's active
  /// selection. Assign it to [selection] to make it active.
  Selection? selectAll() {
    final (code, raw) = bindings.terminalSelectAll(_handle);
    if (code == .noValue) return null;
    checkCode(code);
    return Selection._fromRaw(this, raw!);
  }

  /// Derives a line selection snapshot under [ref].
  ///
  /// The returned selection is not installed as the terminal's active
  /// selection. Assign it to [selection] to make it active.
  Selection? selectLine(
    GridRef ref, {
    List<int>? whitespace,
    bool semanticPromptBoundary = false,
  }) {
    final (code, raw) = bindings.terminalSelectLine(
      _handle,
      _checkedRef(ref),
      whitespace: whitespace,
      semanticPromptBoundary: semanticPromptBoundary,
    );
    if (code == .noValue) return null;
    checkCode(code);
    return Selection._fromRaw(this, raw!);
  }

  /// Derives a semantic command-output selection snapshot under [ref].
  ///
  /// The returned selection is not installed as the terminal's active
  /// selection. Assign it to [selection] to make it active.
  Selection? selectOutput(GridRef ref) {
    final (code, raw) = bindings.terminalSelectOutput(
      _handle,
      _checkedRef(ref),
    );
    if (code == .noValue) return null;
    checkCode(code);
    return Selection._fromRaw(this, raw!);
  }

  /// Derives a word selection snapshot under [ref].
  ///
  /// The returned selection is not installed as the terminal's active
  /// selection. Assign it to [selection] to make it active.
  Selection? selectWord(GridRef ref, {List<int>? boundaryCodepoints}) {
    final (code, raw) = bindings.terminalSelectWord(
      _handle,
      _checkedRef(ref),
      boundaryCodepoints: boundaryCodepoints,
    );
    if (code == .noValue) return null;
    checkCode(code);
    return Selection._fromRaw(this, raw!);
  }

  /// Derives the nearest word selection snapshot between two grid references.
  ///
  /// The returned selection is not installed as the terminal's active
  /// selection. Assign it to [selection] to make it active.
  Selection? selectWordBetween(
    GridRef start,
    GridRef end, {
    List<int>? boundaryCodepoints,
  }) {
    final (code, raw) = bindings.terminalSelectWordBetween(
      _handle,
      _checkedRef(start, 'start'),
      _checkedRef(end, 'end'),
      boundaryCodepoints: boundaryCodepoints,
    );
    if (code == .noValue) return null;
    checkCode(code);
    return Selection._fromRaw(this, raw!);
  }

  /// Sets the maximum bytes the APC handler will buffer for all protocols.
  ///
  /// This replaces protocol-specific overrides. Pass null to remove all
  /// overrides and use the built-in defaults.
  void setApcBufferLimit(int? bytes) {
    checkCode(bindings.terminalSetApcBufferLimit(_handle, bytes));
  }

  /// Enables or disables Glyph Protocol APC handling.
  void setGlyphProtocol({required bool enabled}) {
    checkCode(bindings.terminalSetGlyphProtocol(_handle, enabled: enabled));
  }

  /// Sets the maximum bytes the APC handler will buffer for Kitty graphics
  /// protocol data.
  ///
  /// This overrides the general APC buffer limit for Kitty graphics payloads.
  /// Pass null to remove the Kitty-specific override and use the built-in
  /// Kitty graphics default.
  void setKittyApcBufferLimit(int? bytes) {
    checkCode(bindings.terminalSetKittyApcBufferLimit(_handle, bytes));
  }

  /// Enables or disables the file medium for Kitty image loading.
  void setKittyFileMedium({required bool enabled}) {
    checkCode(
      bindings.terminalSetKittyImageMediumFile(_handle, enabled: enabled),
    );
  }

  /// Enables or disables the shared memory medium for Kitty image loading.
  void setKittySharedMemMedium({required bool enabled}) {
    checkCode(
      bindings.terminalSetKittyImageMediumSharedMem(_handle, enabled: enabled),
    );
  }

  /// Restricts Kitty temporary-file image loading to [directory].
  ///
  /// Passing null disables the medium. The directory is copied, so callers do
  /// not need to retain the string. Throws [InvalidValueException] when the
  /// directory is empty and [OutOfMemoryException] when it exceeds the native
  /// path capacity.
  ///
  /// ```dart
  /// terminal.setKittyTempFileDirectory('/tmp/terminal-images');
  /// ```
  void setKittyTempFileDirectory(String? directory) {
    if (directory == '') {
      throw const InvalidValueException(
        'Kitty temporary-file directory must not be empty.',
      );
    }
    checkCode(bindings.terminalSetKittyImageMediumTempFile(_handle, directory));
  }

  /// Feeds raw VT-encoded bytes into the terminal for processing.
  ///
  /// Malformed input is logged internally but does not corrupt state or throw.
  /// All registered callbacks fire synchronously during this call. Callers
  /// **must not** call [write] from within a callback (no reentrancy). If one
  /// or more callbacks throw, processing finishes and listeners are notified
  /// before the first exception is rethrown with its original stack trace.
  ///
  /// Sequences requiring output (device status reports, mode queries) are
  /// silently ignored unless [onWritePty] is registered. Notifies listeners
  /// synchronously after processing completes.
  ///
  /// ```dart
  /// terminal.write(Uint8List.fromList(utf8.encode('Hello\r\n')));
  /// ```
  void write(Uint8List data) {
    try {
      bindings.terminalVtWrite(_handle, data);
    } on Object catch (error, stackTrace) {
      try {
        notifyListeners();
      } finally {
        Error.throwWithStackTrace(error, stackTrace);
      }
    }
    notifyListeners();
  }

  RawGridRef _checkedRef(GridRef ref, [String name = 'ref']) {
    _checkRefTerminal(ref, name);
    return ref._value;
  }

  RawSelection? _checkedSelection(Selection? selection) {
    if (selection == null) return null;
    if (!identical(selection.start._terminal, this)) {
      throw ArgumentError.value(
        selection,
        'selection',
        'must belong to this terminal',
      );
    }
    return selection._raw;
  }

  void _checkRefTerminal(GridRef ref, String name) {
    if (!identical(ref._terminal, this)) {
      throw ArgumentError.value(ref, name, 'must belong to this terminal');
    }
  }

  static T? _optionalValue<T>(CResult<T> result) {
    return result.$1 == .noValue ? null : check(result);
  }
}
