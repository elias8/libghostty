import 'dart:typed_data';

import 'package:listen/listen.dart' show ChangeNotifier;
import 'package:meta/meta.dart';

import '../../bindings/bindings.dart';
import '../../bindings/types.dart';
import '../../generated/libghostty_enums.g.dart';
import '../../types/types.dart';
import '../key/kitty_key_flags.dart';
import '../key/mods.dart';
import 'terminal_mode.dart';

part '../key/key_encoder.dart';
part '../key/key_event.dart';
part '../mouse/mouse_encoder.dart';
part '../mouse/mouse_event.dart';
part 'cell_iterator.dart';
part 'formatter.dart';
part 'grid_ref.dart';
part 'kitty_graphics.dart';
part 'render_state.dart';
part 'row_iterator.dart';
part 'search.dart';
part 'selection.dart';
part 'selection_gesture.dart';
part 'snapshot.dart';
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
/// - [Search] for incremental content searches
/// - [SnapshotDecoder] for restoring state encoded by [encodeSnapshot]
/// - [KeyEncoder] / [MouseEncoder] for encoding input events
///
/// ## Effects
///
/// Effects are callbacks invoked synchronously by terminal operations. Most
/// respond to VT sequences during [write] or [writeUntilGround], while
/// [onWritePty] can also fire during a callback-emitting [resize]. Register
/// them by assigning the callback setters ([onWritePty], [onBell],
/// [onTitleChanged], etc.). Set to null to disable.
///
/// Callbacks run synchronously. An effect invoked while [write] or
/// [writeUntilGround] is processing VT input must not call either method for
/// the same terminal. The [onWritePty] callback emitted by an in-band [resize]
/// report may call [write]. Callbacks should avoid blocking or expensive
/// operations since they block further I/O processing. Callback exceptions do
/// not interrupt terminal processing. After the initiating operation finishes,
/// the first exception is rethrown with its original stack trace.
///
/// Title query responses are disabled by default. Enable them with
/// [setTitleReports] in addition to registering [onWritePty].
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
/// Calling [dispose] more than once is safe. Every other member throws a
/// [StateError] after disposal.
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
final class Terminal with ChangeNotifier {
  static final _finalizer = Finalizer(bindings.terminal.terminalFree);

  final LibGhosttyHandle _handle;
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
    : _handle = bindings.terminal.terminalNew(cols, rows),
      _disposed = false {
    _finalizer.attach(this, _handle, detach: this);
  }

  Terminal._fromHandle(this._handle) : _disposed = false {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// The active screen buffer (primary or alternate).
  ///
  /// Programs switch screens via DEC private mode 1049 (e.g. when entering
  /// full-screen editors like vim).
  TerminalScreen get activeScreen {
    return bindings.terminal.terminalGetActiveScreen(_terminalHandle);
  }

  /// Effective background color (OSC override if active, otherwise default).
  ///
  /// Returns null if no color is configured (neither a default nor an OSC
  /// override).
  RgbColor? get background {
    return bindings.terminal.terminalGetColorBackground(_terminalHandle);
  }

  /// Sets the default background color, or clears it if null.
  ///
  /// This sets the embedder default. Programs running in the terminal can
  /// still override it via OSC 11.
  set background(RgbColor? color) {
    bindings.terminal.terminalSetColorBackground(_terminalHandle, color);
  }

  /// Default background color, ignoring any OSC override.
  ///
  /// Returns null if no default has been configured.
  RgbColor? get backgroundDefault {
    return bindings.terminal.terminalGetColorBackgroundDefault(_terminalHandle);
  }

  /// Maximum decoded bytes accepted in one Kitty clipboard write transaction.
  ///
  /// The default is 64 MiB. Setting this to null restores that default.
  int get clipboardWriteMaxBytes {
    return bindings.terminal.terminalGetClipboardWriteMaxBytes(_terminalHandle);
  }

  set clipboardWriteMaxBytes(int? value) {
    bindings.terminal.terminalSetClipboardWriteMaxBytes(_terminalHandle, value);
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
    return bindings.terminal.terminalCompressionActivity(_terminalHandle);
  }

  /// Replay-safe bytes for the terminal's unfinished VT or UTF-8 input.
  ///
  /// This returns the exact byte suffix needed to reconstruct parser state in
  /// an equivalent terminal. It does not contain screen, cursor, mode, or
  /// scrollback state. Returns an empty list when input is complete.
  ///
  /// Throws [InvalidValueException] when tracking is disabled or the current
  /// unfinished input cannot be reconstructed. Throws
  /// [OutOfMemoryException] if the bytes cannot be allocated. Access this
  /// property serially with [write] and other terminal operations.
  Uint8List get continuation {
    return bindings.terminal.terminalContinuationGet(_terminalHandle);
  }

  /// Maximum number of unfinished VT or UTF-8 bytes retained for
  /// [continuation].
  ///
  /// A value of zero disables continuation tracking. Tracking must be enabled
  /// before the input that produces unfinished parser state is written.
  int get continuationMaxBytes {
    return bindings.terminal.terminalGetContinuationMaxBytes(_terminalHandle);
  }

  /// Sets the maximum number of unfinished VT or UTF-8 bytes retained for
  /// [continuation].
  ///
  /// Set to zero to disable continuation tracking. Lowering the limit can
  /// make the current continuation unavailable. Enabling tracking after
  /// unfinished input has already been written does not recover it.
  set continuationMaxBytes(int value) {
    RangeError.checkNotNegative(value, 'value');
    bindings.terminal.terminalSetContinuationMaxBytes(_terminalHandle, value);
  }

  /// Effective cursor color (OSC override if active, otherwise default).
  ///
  /// Returns null if no color is configured.
  RgbColor? get cursorColor {
    return bindings.terminal.terminalGetColorCursor(_terminalHandle);
  }

  /// Sets the default cursor color, or clears it if null.
  ///
  /// Programs running in the terminal can override this via OSC 12.
  set cursorColor(RgbColor? color) {
    bindings.terminal.terminalSetColorCursor(_terminalHandle, color);
  }

  /// Default cursor color, ignoring any OSC override.
  ///
  /// Returns null if no default has been configured.
  RgbColor? get cursorColorDefault {
    return bindings.terminal.terminalGetColorCursorDefault(_terminalHandle);
  }

  /// The cursor's current SGR style (applied to newly printed characters).
  Style get cursorStyle =>
      bindings.terminal.terminalGetCursorStyle(_terminalHandle);

  /// Sets whether DECSCUSR reset (CSI 0 q) restores a blinking cursor.
  set defaultCursorBlink(bool? value) {
    bindings.terminal.terminalSetDefaultCursorBlink(
      _terminalHandle,
      blinking: value,
    );
  }

  /// Sets the cursor shape restored by DECSCUSR reset (CSI 0 q).
  set defaultCursorShape(TerminalCursorShape? value) {
    bindings.terminal.terminalSetDefaultCursorShape(_terminalHandle, value);
  }

  /// Effective foreground color (OSC override if active, otherwise default).
  ///
  /// Returns null if no color is configured (neither a default nor an OSC
  /// override).
  RgbColor? get foreground {
    return bindings.terminal.terminalGetColorForeground(_terminalHandle);
  }

  /// Sets the default foreground color, or clears it if null.
  ///
  /// Programs running in the terminal can override this via OSC 10.
  set foreground(RgbColor? color) {
    bindings.terminal.terminalSetColorForeground(_terminalHandle, color);
  }

  /// Default foreground color, ignoring any OSC override.
  ///
  /// Returns null if no default has been configured.
  RgbColor? get foregroundDefault {
    return bindings.terminal.terminalGetColorForegroundDefault(_terminalHandle);
  }

  /// Current terminal dimensions in cells and pixels.
  ///
  /// Pixel dimensions are zero when no cell pixel size has been configured.
  ///
  /// ```dart
  /// final geometry = terminal.geometry;
  /// final cellWidth = geometry.widthPx ~/ geometry.cols;
  /// ```
  TerminalGeometry get geometry =>
      bindings.terminal.terminalGetGeometry(_terminalHandle);

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
    return bindings.terminal.terminalGetVtProcessingError(_terminalHandle);
  }

  /// Total terminal height in pixels (rows * cell height).
  int get heightPx => bindings.terminal.terminalGetHeightPx(_terminalHandle);

  /// Whether the cursor is at the semantic prompt boundary.
  ///
  /// The value is false when prompt tracking is unavailable or when the
  /// cursor is on the alternate screen.
  bool get isCursorAtPrompt {
    return bindings.terminal.terminalGetCursorAtPrompt(_terminalHandle);
  }

  /// Whether the file medium is enabled for Kitty image loading.
  /// Returns null when Kitty graphics are not compiled in.
  bool? get isKittyFileMedium {
    return bindings.terminal.terminalGetKittyImageMediumFile(_terminalHandle);
  }

  /// Whether the shared memory medium is enabled for Kitty image loading.
  /// Returns null when Kitty graphics are not compiled in.
  bool? get isKittySharedMemMedium {
    return bindings.terminal.terminalGetKittyImageMediumSharedMem(
      _terminalHandle,
    );
  }

  /// Whether any mouse tracking mode is currently active.
  bool get isMouseTracking =>
      bindings.terminal.terminalGetMouseTracking(_terminalHandle);

  /// Whether the viewport is at the active terminal area instead of scrollback.
  bool get isViewportActive {
    return bindings.terminal.terminalGetViewportActive(_terminalHandle);
  }

  /// Whether the VT parser is in its ground state.
  ///
  /// This is true when no escape, control, or UTF-8 sequence is pending and
  /// the next byte can be processed from a stateless boundary.
  bool get isVtGround => bindings.terminal.terminalGetVtGround(_terminalHandle);

  /// Kitty image storage limit in bytes for the active screen.
  ///
  /// Zero means the Kitty graphics protocol is disabled. Returns null when
  /// Kitty graphics support is not compiled into the library.
  int? get kittyImageStorageLimit {
    return bindings.terminal.terminalGetKittyImageStorageLimit(_terminalHandle);
  }

  /// Sets the Kitty image storage limit in bytes. Zero or null disables
  /// the Kitty graphics protocol entirely.
  set kittyImageStorageLimit(int? value) {
    bindings.terminal.terminalSetKittyImageStorageLimit(_terminalHandle, value);
  }

  /// Current Kitty keyboard protocol flags.
  ///
  /// Reflects the flags set by the program running in the terminal via the
  /// Kitty keyboard protocol. Use [KeyEncoder] to encode key events according
  /// to these flags.
  KittyKeyFlags get kittyKeyboardFlags => KittyKeyFlags.fromValue(
    bindings.terminal.terminalGetKittyKeyboardFlags(_terminalHandle),
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
    return bindings.terminal.terminalGetKittyImageMediumTempFile(
      _terminalHandle,
    );
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

  /// Mouse pointer shape requested by the running program through OSC 22.
  MouseShape get mouseShape =>
      bindings.terminal.terminalGetMouseShape(_terminalHandle);

  /// Screen and Kitty graphics memory held by this terminal.
  ///
  /// This reads every screen page and may take time for long scrollback
  /// histories. Query it when checking memory budgets instead of after every
  /// write.
  TerminalMemoryUsage get memoryUsage =>
      bindings.terminal.terminalGetMemoryUsage(_terminalHandle);

  /// Registers a callback for BEL character (0x07).
  ///
  /// Fires synchronously during [write]. Set to null to ignore bell events.
  set onBell(VoidCallback? value) {
    bindings.terminal.terminalSetOnBell(_terminalHandle, value);
  }

  /// Registers a callback for clipboard reads requested by terminal content.
  ///
  /// The callback runs synchronously while [write]. Return a
  /// [ClipboardReadReply] containing the permitted representations. Set to
  /// null to refuse reads. Requests originate in untrusted terminal content,
  /// so applications should apply an explicit permission policy. A reply is
  /// required before the callback returns.
  set onClipboardRead(ClipboardReadCallback? value) {
    bindings.terminal.terminalSetOnClipboardRead(_terminalHandle, value);
  }

  /// Registers a callback for clipboard writes requested by terminal content.
  ///
  /// OSC 52, iTerm2 OSC 1337 Copy, and Kitty OSC 5522 requests are decoded
  /// into protocol-neutral, binary-safe [ClipboardWrite] values. The result
  /// answers protocols with write acknowledgements and is ignored by
  /// protocols without them. Fires synchronously during [write]. Set to null
  /// to deny and ignore clipboard writes.
  ///
  /// ```dart
  /// terminal.onClipboardWrite = (request) {
  ///   if (!trustedSession) return .denied;
  ///   clipboard.replace(request);
  ///   return .success;
  /// };
  /// ```
  set onClipboardWrite(ClipboardWriteCallback? value) {
    bindings.terminal.terminalSetOnClipboardWrite(_terminalHandle, value);
  }

  /// Registers a callback for color scheme queries (CSI ? 996 n).
  ///
  /// Return the current [ColorScheme], or null to silently ignore the query.
  /// Fires synchronously during [write].
  set onColorScheme(ValueGetter<ColorScheme?>? value) {
    bindings.terminal.terminalSetOnColorScheme(_terminalHandle, value);
  }

  /// Registers a callback for OSC 9 and OSC 777 desktop notifications.
  ///
  /// Requests are untrusted terminal content. The callback decides whether and
  /// how to display them. Fires synchronously during [write]. Set to null to
  /// ignore notifications.
  set onDesktopNotification(DesktopNotificationCallback? value) {
    bindings.terminal.terminalSetOnDesktopNotification(_terminalHandle, value);
  }

  /// Registers a callback for device attributes queries (CSI c / > c / = c).
  ///
  /// Return a [DeviceAttributesResponse], or null to silently ignore the query.
  /// Fires synchronously during [write].
  set onDeviceAttributes(ValueGetter<DeviceAttributesResponse?>? value) {
    bindings.terminal.terminalSetOnDeviceAttributes(_terminalHandle, value);
  }

  /// Registers a callback for ENQ character (0x05).
  ///
  /// Return the response bytes to write back to the PTY. Return an empty list
  /// to send no response. Fires synchronously during [write].
  set onEnquiry(ValueGetter<Uint8List>? value) {
    bindings.terminal.terminalSetOnEnquiry(_terminalHandle, value);
  }

  /// Registers a callback for OSC 9;4 progress reports.
  ///
  /// Fires synchronously during [write]. Set to null to ignore reports.
  set onProgressReport(TerminalProgressCallback? value) {
    bindings.terminal.terminalSetOnProgressReport(_terminalHandle, value);
  }

  /// Registers a callback for working-directory changes via OSC 7/9/1337.
  ///
  /// Read the new [pwd] inside the callback. OSC 7 values remain raw URIs;
  /// OSC 9 and OSC 1337 values are typically paths. Fires synchronously during
  /// [write].
  set onPwdChanged(VoidCallback? value) {
    bindings.terminal.terminalSetOnPwdChanged(_terminalHandle, value);
  }

  /// Registers a callback for XTWINOPS size queries (CSI 14/16/18 t).
  ///
  /// Return a [TerminalSizeInfo] with the current geometry, or null to
  /// silently ignore the query. Fires synchronously during [write].
  set onSize(ValueGetter<TerminalSizeInfo?>? value) {
    bindings.terminal.terminalSetOnSize(_terminalHandle, value);
  }

  /// Registers a callback for title changes via OSC 0 or OSC 2.
  ///
  /// Read the new [title] inside the callback. Fires synchronously during
  /// [write].
  set onTitleChanged(VoidCallback? value) {
    bindings.terminal.terminalSetOnTitleChanged(_terminalHandle, value);
  }

  /// Registers a callback for unsupported string sequences.
  ///
  /// Capture must be enabled with [unknownSequenceMaxBytes]. The callback
  /// receives copied, binary-safe content and runs synchronously during
  /// [write] or [writeUntilGround]. Only normally terminated sequences with
  /// unsupported identifiers are reported. Aborted sequences, malformed
  /// recognized commands, and disabled known protocols are ignored. The
  /// callback must not call [write] or [writeUntilGround] for this terminal.
  /// Set to null to ignore captured sequences.
  ///
  /// ```dart
  /// terminal.unknownSequenceMaxBytes = 4096;
  /// terminal.onUnknownSequence = (sequence) {
  ///   if (sequence.tag == TerminalUnknownSequenceTag.apc) {
  ///     inspectApc(sequence.content, truncated: sequence.truncated);
  ///   }
  /// };
  /// ```
  set onUnknownSequence(TerminalUnknownSequenceCallback? value) {
    bindings.terminal.terminalSetOnUnknownSequence(_terminalHandle, value);
  }

  /// Registers a callback for PTY write-back data.
  ///
  /// Invoked when the terminal needs to send data back to the PTY, for
  /// example in response to device status reports or mode queries. The data is
  /// owned by Dart and remains valid after the callback returns. Title query
  /// responses also use this callback when [setTitleReports] is enabled. Fires
  /// synchronously during [write].
  set onWritePty(ValueSetter<Uint8List>? value) {
    bindings.terminal.terminalSetOnWritePty(_terminalHandle, value);
  }

  /// Registers a callback for XTVERSION queries (CSI > q).
  ///
  /// Return the version string to report (e.g. "myterm 1.0"). Return an empty
  /// string to use the default "libghostty" identifier. Fires synchronously
  /// during [write].
  set onXtversion(ValueGetter<String>? value) {
    bindings.terminal.terminalSetOnXtversion(_terminalHandle, value);
  }

  /// Current 256-color palette with any active OSC 4 overrides applied.
  ///
  /// Always returns a 256-element list (the built-in default palette is used
  /// as a baseline).
  List<RgbColor> get palette {
    return bindings.terminal.terminalGetColorPalette(_terminalHandle);
  }

  /// Sets the default 256-color palette, or resets to built-in defaults if
  /// null.
  ///
  /// Only updates indices that have not been overridden by OSC 4. Per-index
  /// OSC overrides are preserved.
  ///
  /// Throws [ArgumentError] when [colors] is non-null and does not contain
  /// exactly 256 entries.
  set palette(List<RgbColor>? colors) {
    bindings.terminal.terminalSetColorPalette(_terminalHandle, colors);
  }

  /// Default 256-color palette, ignoring any OSC 4 overrides.
  List<RgbColor> get paletteDefault {
    return bindings.terminal.terminalGetColorPaletteDefault(_terminalHandle);
  }

  /// Current working directory as reported by OSC 7.
  ///
  /// The terminal stores the bytes reported by OSC 7, OSC 9, or OSC 1337
  /// without parsing them. OSC 7 values are therefore raw URIs, while the
  /// other forms are typically paths. The returned string is a Dart-owned
  /// snapshot and remains valid after subsequent terminal operations.
  String get pwd => bindings.terminal.terminalGetPwd(_terminalHandle);

  /// Sets the working directory, or clears it if null.
  set pwd(String? value) {
    bindings.terminal.terminalSetPwd(_terminalHandle, value);
  }

  /// Maximum bytes retained for scrollback, or null when unlimited.
  ///
  /// This limit and [scrollbackMaxLines] apply together. Ghostty prunes when
  /// either limit is reached, at page granularity.
  int? get scrollbackMaxBytes {
    return bindings.terminal.terminalGetScrollbackMaxBytes(_terminalHandle);
  }

  /// Sets the maximum bytes retained for scrollback.
  ///
  /// Set to null for no byte limit or zero to clear retained history and
  /// disable scrollback by bytes.
  set scrollbackMaxBytes(int? value) {
    bindings.terminal.terminalSetScrollbackMaxBytes(_terminalHandle, value);
  }

  /// Maximum physical lines retained for scrollback, or null when unlimited.
  ///
  /// This limit and [scrollbackMaxBytes] apply together. Ghostty prunes when
  /// either limit is reached, at page granularity.
  int? get scrollbackMaxLines {
    return bindings.terminal.terminalGetScrollbackMaxLines(_terminalHandle);
  }

  /// Sets the maximum physical lines retained for scrollback.
  ///
  /// Set to null for no line limit or zero to clear retained history and
  /// disable scrollback by lines.
  set scrollbackMaxLines(int? value) {
    bindings.terminal.terminalSetScrollbackMaxLines(_terminalHandle, value);
  }

  /// Controls whether a resize can pull rows from scrollback into the active
  /// grid.
  ///
  /// Set null to restore libghostty's default, which is true. Set false when
  /// the PTY keeps its own screen buffer without scrollback.
  set resizePullScrollback(bool? value) {
    bindings.terminal.terminalSetResizePullScrollback(
      _terminalHandle,
      value: value,
    );
  }

  /// Enables or disables DECRQCRA checksum replies.
  ///
  /// Checksum replies are disabled by default because a program could use
  /// them to read screen contents.
  set xtChecksumReport(bool enabled) {
    bindings.terminal.terminalSetXtChecksumReport(
      _terminalHandle,
      enabled: enabled,
    );
  }

  /// Sets DECRQCRA checksum calculation flags and the default used after a
  /// full terminal reset.
  ///
  /// The value must be between 0 and 31. Set null to restore the DEC default.
  set xtChecksumExtension(int? value) {
    if (value != null && (value < 0 || value > 31)) {
      throw RangeError.range(value, 0, 31, 'value');
    }
    bindings.terminal.terminalSetXtChecksumExtension(_terminalHandle, value);
  }

  /// Number of rows in the scrollback buffer (excluding the active grid).
  int get scrollbackRows =>
      bindings.terminal.terminalGetScrollbackRows(_terminalHandle);

  /// Scrollbar position and dimensions for rendering a scrollbar widget.
  ///
  /// The total is maintained incrementally and the viewport offset is cached.
  /// The first read after moving the viewport to an arbitrary non-row position
  /// may traverse the scrollback page list to compute the offset, after which
  /// it is cached again.
  ///
  /// There is no scroll-state notification. Callers building scrollbars should
  /// poll this once per frame or per write batch and diff the result.
  Scrollbar get scrollbar =>
      bindings.terminal.terminalGetScrollbar(_terminalHandle);

  /// Active selection on the terminal screen, or null when none is active.
  ///
  /// Getting returns an untracked snapshot. Setting installs a copy as
  /// terminal-owned tracked state. Set null to clear the active selection.
  Selection? get selection {
    final raw = bindings.selection.terminalGetSelection(_terminalHandle);
    return raw == null ? null : Selection._fromRaw(this, raw);
  }

  /// Sets the active selection on the terminal screen.
  ///
  /// Assigning a selection installs a terminal-owned copy of its endpoints.
  /// Assign null to clear the active selection. Non-null selections must belong
  /// to this terminal.
  set selection(Selection? value) {
    bindings.selection.terminalSetSelection(
      _terminalHandle,
      _checkedSelection(value),
    );
    notifyListeners();
  }

  /// Sets the terminfo name used to answer XTGETTCAP `TN` queries.
  ///
  /// The name is copied by libghostty. Set to null or an empty string to
  /// leave `TN` queries unanswered. Names longer than 128 UTF-8 bytes throw
  /// [InvalidValueException].
  set terminfoName(String? value) {
    bindings.terminal.terminalSetTerminfoName(_terminalHandle, value);
  }

  /// Terminal title as set by OSC 0 or OSC 2 sequences.
  ///
  /// The returned string is a Dart-owned snapshot and remains valid after
  /// subsequent terminal operations.
  String get title => bindings.terminal.terminalGetTitle(_terminalHandle);

  /// Sets the terminal title, or clears it if null.
  set title(String? value) {
    bindings.terminal.terminalSetTitle(_terminalHandle, value);
  }

  /// Total number of rows: active grid rows plus scrollback rows.
  int get totalRows => bindings.terminal.terminalGetTotalRows(_terminalHandle);

  /// Maximum bytes captured for unsupported string sequences.
  ///
  /// Set to null or zero to disable capture. The limit applies to sequence
  /// content. The callback reports truncation when the limit is exceeded or
  /// the complete content cannot be allocated.
  set unknownSequenceMaxBytes(int? value) {
    if (value != null) RangeError.checkNotNegative(value, 'value');
    bindings.terminal.terminalSetUnknownSequenceMaxBytes(
      _terminalHandle,
      value,
    );
  }

  /// Total terminal width in pixels (cols * cell width).
  int get widthPx => bindings.terminal.terminalGetWidthPx(_terminalHandle);

  LibGhosttyHandle? get _handleOrNull => _disposed ? null : _handle;

  LibGhosttyHandle get _terminalHandle {
    if (_disposed) throw StateError('Terminal has been disposed');
    return _handle;
  }

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
    final result = bindings.terminal.terminalCompress(_terminalHandle, mode);
    return result;
  }

  /// Releases the native terminal handle and clears registered callbacks.
  ///
  /// Calling [dispose] more than once is safe. Every other member throws a
  /// [StateError] after disposal. Do not call [dispose] from an active terminal
  /// callback.
  @override
  void dispose() {
    if (_disposed) return;
    bindings.terminal.terminalFree(_handle);
    _finalizer.detach(this);
    _disposed = true;
    super.dispose();
  }

  /// Encodes the complete terminal state into a portable snapshot.
  ///
  /// The snapshot includes screen contents, scrollback, terminal modes, and
  /// any tracked unfinished VT input. Encoding unfinished input requires
  /// [continuationMaxBytes] to have been enabled before that input was written.
  /// Do not mutate the terminal concurrently with this call.
  Uint8List encodeSnapshot() {
    return bindings.snapshot.snapshotEncode(_terminalHandle);
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
    return bindings.selection.terminalSelectionFormat(
      _terminalHandle,
      format,
      unwrap: unwrap,
      trim: trim,
      selection: _checkedSelection(selection),
    );
  }

  /// Queries whether the given terminal [mode] is currently enabled.
  bool modeGet(TerminalMode mode) {
    return bindings.terminal.terminalModeGet(_terminalHandle, mode.value);
  }

  /// Enables or disables the given terminal [mode].
  void modeSet(TerminalMode mode, {required bool value}) {
    bindings.terminal.terminalModeSet(
      _terminalHandle,
      mode.value,
      value: value,
    );
  }

  /// Sets the current and reset-default value of the given terminal [mode].
  ///
  /// Some transition or mirrored modes cannot be configured as reset defaults
  /// and throw [InvalidValueException].
  void modeSetDefault(TerminalMode mode, {required bool value}) {
    bindings.terminal.terminalModeSetDefault(
      _terminalHandle,
      mode.value,
      value: value,
    );
  }

  /// Pastes [text] according to the terminal's current modes.
  ///
  /// The text is supplied as a clipboard-like MIME representation and is
  /// written through [onWritePty]. By default unsafe command-injecting text is
  /// rejected before any output is written; set [allowUnsafe] only after the
  /// application has confirmed the paste with the user.
  void paste(String text, {bool allowUnsafe = false}) {
    final written = bindings.terminal.terminalPasteText(
      _terminalHandle,
      text,
      allowUnsafe: allowUnsafe,
    );
    if (written) notifyListeners();
  }

  /// Performs a full reset (RIS): resets modes, scrollback, scrolling region,
  /// and screen contents to defaults while preserving terminal dimensions.
  void reset() {
    bindings.terminal.terminalReset(_terminalHandle);
  }

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
    try {
      bindings.terminal.terminalResize(
        _terminalHandle,
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
    notifyListeners();
  }

  /// Scrolls the viewport to the bottom (active area).
  void scrollToBottom() {
    bindings.terminal.terminalScrollViewport(_terminalHandle, .bottom, 0);
  }

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
    bindings.terminal.terminalScrollViewport(_terminalHandle, .row, row);
  }

  /// Scrolls the viewport to the top of the scrollback history.
  void scrollToTop() {
    bindings.terminal.terminalScrollViewport(_terminalHandle, .top, 0);
  }

  /// Scrolls the viewport by [delta] rows. Positive values scroll down
  /// (toward the active area), negative values scroll up (toward history).
  void scrollViewport(int delta) {
    if (delta == 0) return;
    bindings.terminal.terminalScrollViewport(_terminalHandle, .delta, delta);
  }

  /// Derives a selection snapshot covering all selectable terminal content.
  ///
  /// The returned selection is not installed as the terminal's active
  /// selection. Assign it to [selection] to make it active.
  Selection? selectAll() {
    final raw = bindings.selection.terminalSelectAll(_terminalHandle);
    return raw == null ? null : Selection._fromRaw(this, raw);
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
    final raw = bindings.selection.terminalSelectLine(
      _terminalHandle,
      _checkedRef(ref),
      whitespace: whitespace,
      semanticPromptBoundary: semanticPromptBoundary,
    );
    return raw == null ? null : Selection._fromRaw(this, raw);
  }

  /// Derives a semantic command-output selection snapshot under [ref].
  ///
  /// The returned selection is not installed as the terminal's active
  /// selection. Assign it to [selection] to make it active.
  Selection? selectOutput(GridRef ref) {
    final raw = bindings.selection.terminalSelectOutput(
      _terminalHandle,
      _checkedRef(ref),
    );
    return raw == null ? null : Selection._fromRaw(this, raw);
  }

  /// Derives a word selection snapshot under [ref].
  ///
  /// The returned selection is not installed as the terminal's active
  /// selection. Assign it to [selection] to make it active.
  Selection? selectWord(GridRef ref, {List<int>? boundaryCodepoints}) {
    final raw = bindings.selection.terminalSelectWord(
      _terminalHandle,
      _checkedRef(ref),
      boundaryCodepoints: boundaryCodepoints,
    );
    return raw == null ? null : Selection._fromRaw(this, raw);
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
    final raw = bindings.selection.terminalSelectWordBetween(
      _terminalHandle,
      _checkedRef(start, 'start'),
      _checkedRef(end, 'end'),
      boundaryCodepoints: boundaryCodepoints,
    );
    return raw == null ? null : Selection._fromRaw(this, raw);
  }

  /// Sets the maximum bytes the APC handler will buffer for all protocols.
  ///
  /// This replaces protocol-specific overrides. Pass null to remove all
  /// overrides and use the built-in defaults.
  void setApcBufferLimit(int? bytes) {
    bindings.terminal.terminalSetApcBufferLimit(_terminalHandle, bytes);
  }

  /// Enables or disables Glyph Protocol APC handling.
  void setGlyphProtocol({required bool enabled}) {
    bindings.terminal.terminalSetGlyphProtocol(
      _terminalHandle,
      enabled: enabled,
    );
  }

  /// Sets the maximum bytes the APC handler will buffer for Kitty graphics
  /// protocol data.
  ///
  /// This overrides the general APC buffer limit for Kitty graphics payloads.
  /// Pass null to remove the Kitty-specific override and use the built-in
  /// Kitty graphics default.
  void setKittyApcBufferLimit(int? bytes) {
    bindings.terminal.terminalSetKittyApcBufferLimit(_terminalHandle, bytes);
  }

  /// Enables or disables the file medium for Kitty image loading.
  void setKittyFileMedium({required bool enabled}) {
    bindings.terminal.terminalSetKittyImageMediumFile(
      _terminalHandle,
      enabled: enabled,
    );
  }

  /// Enables or disables the shared memory medium for Kitty image loading.
  void setKittySharedMemMedium({required bool enabled}) {
    bindings.terminal.terminalSetKittyImageMediumSharedMem(
      _terminalHandle,
      enabled: enabled,
    );
  }

  /// Restricts Kitty temporary-file image loading to [directory].
  ///
  /// Passing null disables the medium. An empty directory remains a value and
  /// does not disable it. The directory is copied, so callers do not need to
  /// retain the string. Throws [OutOfMemoryException] when the directory
  /// exceeds the native path capacity.
  ///
  /// ```dart
  /// terminal.setKittyTempFileDirectory('/tmp/terminal-images');
  /// ```
  void setKittyTempFileDirectory(String? directory) {
    bindings.terminal.terminalSetKittyImageMediumTempFile(
      _terminalHandle,
      directory,
    );
  }

  /// Enables or disables title reports in response to `CSI 21 t` queries.
  ///
  /// When enabled, the response containing the current title is sent through
  /// [onWritePty]. This is disabled by default because a program can set a
  /// title, query it, and inject the response into the PTY input stream.
  /// Enable it only for trusted terminal workloads.
  ///
  /// This setting is independent of [onTitleChanged], which observes title
  /// changes made by OSC 0 or OSC 2.
  void setTitleReports({required bool enabled}) {
    bindings.terminal.terminalSetTitleReport(_terminalHandle, enabled: enabled);
  }

  /// Feeds raw VT-encoded bytes into the terminal for processing.
  ///
  /// Malformed input is logged internally but does not corrupt state or throw.
  /// Callbacks fire synchronously during this call and must not call [write] or
  /// [writeUntilGround] for this terminal. Writes to another terminal are
  /// allowed when that terminal's own concurrency rules permit them. If one or
  /// more callbacks
  /// throw, processing finishes and listeners are notified before the first
  /// exception is rethrown with its original stack trace.
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
      bindings.terminal.terminalVtWrite(_terminalHandle, data);
    } on Object catch (error, stackTrace) {
      try {
        notifyListeners();
      } finally {
        Error.throwWithStackTrace(error, stackTrace);
      }
    }
    notifyListeners();
  }

  /// Writes the replay-safe continuation to [writer].
  ///
  /// The continuation is the exact byte suffix needed to reconstruct
  /// unfinished VT or UTF-8 input. [writer] is called synchronously and may
  /// receive more than one non-empty chunk. Return `true` only after the
  /// complete chunk has been accepted; returning `false` aborts the operation
  /// with [IoException]. The callback must not call operations on this
  /// terminal, and this method must be serialized with [write] and other
  /// terminal operations.
  ///
  /// Throws [InvalidValueException] when tracking is disabled or the current
  /// unfinished input cannot be reconstructed, [IoException] when [writer]
  /// rejects a chunk, and [LimitExceededException] when output accounting
  /// overflows. If [writer] throws, that exception is rethrown after the C
  /// operation completes.
  void writeContinuation(ContinuationWriter writer) {
    bindings.terminal.terminalContinuationWrite(_terminalHandle, writer);
  }

  /// Writes bytes until the parser reaches the ground state.
  ///
  /// Returns the number of bytes consumed when ground is reached, including
  /// zero when the parser was already in ground. When the returned count is
  /// less than `data.length`, the remaining suffix was not processed. Returns
  /// null when all bytes were consumed without reaching ground. Callbacks and
  /// listener notifications follow the same rules as [write]. Callbacks must
  /// not call [write] or [writeUntilGround] on this terminal.
  ///
  /// ```dart
  /// final consumed = terminal.writeUntilGround(data);
  /// if (consumed != null) {
  ///   handleGroundBoundary();
  ///   terminal.write(Uint8List.sublistView(data, consumed));
  /// }
  /// ```
  int? writeUntilGround(Uint8List data) {
    late final int? consumed;
    try {
      consumed = bindings.terminal.terminalWriteUntilGround(
        _terminalHandle,
        data,
      );
    } on Object catch (error, stackTrace) {
      try {
        notifyListeners();
      } finally {
        Error.throwWithStackTrace(error, stackTrace);
      }
    }
    notifyListeners();
    return consumed;
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

  void _notifyListenersFromSearch() => notifyListeners();
}
