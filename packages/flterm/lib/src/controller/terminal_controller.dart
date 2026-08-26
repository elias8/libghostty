import 'dart:convert';

import 'package:flutter/foundation.dart' hide Key;
import 'package:libghostty/libghostty.dart' hide Listenable;

import '../foundation.dart';
import '../input/input_encoder.dart';
import '../input/input_message.dart';
import '../interaction/selection_session.dart';
import 'kitty_png_decoder.dart';

part 'terminal_controller_impl.dart';

/// Reports the committed terminal grid dimensions to the backend.
typedef OnResize = void Function(int cols, int rows);

/// Manages terminal state and bridges it with [TerminalView].
///
/// Create a controller, wire up [onOutput] to your backend, pass the
/// controller to a [TerminalView], and feed backend data into [write].
/// The controller handles terminal state, input encoding, selection, and
/// terminal scrolling. Flutter focus, text input, and viewport state belong
/// to [TerminalView].
///
/// A controller can be attached to only one [TerminalView] at a time. Remove
/// the current view before attaching another one. Dispose formatters returned
/// by [createFormatter], then dispose the controller when the session ends.
/// Controller operations must not be used after disposal.
///
/// Callbacks caused by [write] run synchronously and block further terminal
/// input processing. They must remain brief and must not call [write] on this
/// controller reentrantly. If a callback throws, libghostty finishes processing
/// the current input before the exception is rethrown.
///
/// ```dart
/// final controller = TerminalController()
///   ..onOutput = (bytes) => pty.write(bytes)
///   ..onBell = () => playSound()
///   ..onTitleChanged = () => updateTitle(controller.title);
///
/// TerminalView(controller: controller);
///
/// pty.onData = (bytes) => controller.write(bytes);
/// controller.sendText('ls -la\n');
/// ```
abstract class TerminalController extends ChangeNotifier {
  /// Creates a controller with the given [config].
  ///
  /// The terminal is created immediately with the initial dimensions, modes,
  /// resource limits, and other behavior from [config].
  /// The terminal is created immediately with dimensions and scrollback
  /// from [config]. Disposed when the controller is disposed.
  ///
  /// [keyEventNormalizer] can enrich or replace the normalized keyboard event
  /// before terminal protocol encoding. flterm already supplies native layout
  /// metadata on desktop when its plugin is registered; custom runners can use
  /// this callback for metadata captured in their own event pipeline.
  factory TerminalController({
    TerminalConfig config,
    TerminalKeyEventNormalizer? keyEventNormalizer,
  }) = TerminalControllerImpl;

  @internal
  TerminalController.base();

  /// The active [TerminalScreen] buffer, either primary or alternate.
  ///
  /// Full-screen programs such as vim, less, and htop commonly enter the
  /// alternate screen with DEC private mode 1049. Scrollback is available
  /// only on the primary screen.
  TerminalScreen get activeScreen;

  /// The current controller configuration.
  ///
  /// The value contains the defaults applied by the controller. A program can
  /// change live terminal modes with [modeSet], so mode state may differ from
  /// [config].
  TerminalConfig get config;

  /// Replaces the configuration.
  ///
  /// Applies every entry in [TerminalConfig.modes] and updates the terminal's
  /// resource limits, cursor defaults, query responses, and input policies
  /// without recreating the terminal. Modes omitted from the new map retain
  /// their live values.
  ///
  /// [TerminalConfig.cols] and [TerminalConfig.rows] are creation-only; a
  /// connected [TerminalView] controls the live grid size. Lowering scrollback
  /// limits can immediately prune history, setting a byte limit of zero clears
  /// it, and disabling an image protocol can delete its stored resources.
  set config(TerminalConfig config);

  /// Whether the terminal currently has an active text selection.
  ///
  /// This corresponds to the underlying terminal selection state and is
  /// independent of whether the selection is currently visible in a view.
  bool get hasSelection;

  /// The current mouse tracking mode requested by the terminal program.
  ///
  /// Programs enable DEC private modes 9, 1000, 1002, or 1003 to receive
  /// mouse reports. When active, pointer events are encoded and sent to the
  /// program instead of performing selection. Hold Shift to bypass tracking.
  MouseTracking get mouseTracking;

  /// Sets the callback invoked when the terminal receives BEL (0x07).
  ///
  /// The callback runs synchronously while [write] processes the byte. Set it
  /// to null to ignore BEL events.
  set onBell(VoidCallback? value);

  /// Handles a clipboard write requested by terminal content.
  ///
  /// Requests are ignored when this is null. OSC 52 and iTerm2 Copy writes are
  /// normalized into the same binary-safe request. Every content entry is a
  /// representation of one logical value and must be committed atomically; no
  /// entries means clear the destination, while an entry containing no bytes
  /// means write an empty representation. Clipboard read requests are never
  /// forwarded.
  ///
  /// The callback fires synchronously during [write]. Its result describes the
  /// attempted write, although OSC 52 and iTerm2 Copy do not acknowledge it to
  /// the terminal program. Apply an explicit trust and platform policy because
  /// requests originate in untrusted terminal content.
  ///
  /// ```dart
  /// controller.onClipboardWrite = (write) {
  ///   if (write.location != .standard) return .denied;
  ///   return appClipboard.write(write);
  /// };
  /// ```
  set onClipboardWrite(ClipboardWriteCallback? callback);

  /// Sets the callback for desktop notifications requested through OSC 9 or
  /// OSC 777, or clears it if null.
  ///
  /// Requests are untrusted. The application decides whether and how to
  /// display them. Fires synchronously during [write].
  set onDesktopNotification(ValueChanged<DesktopNotification>? callback);

  /// Sets the callback that sends terminal output to the backend.
  ///
  /// Set this before calling [write]. The callback receives bytes produced by
  /// [write], [sendKey], [sendText], [paste], terminal queries, and in-band
  /// resize reports. It runs synchronously on the initiating operation. When
  /// invoked by [write], it is subject to the class-level non-reentrancy rule.
  set onOutput(ValueChanged<Uint8List>? value);

  /// Sets the callback for program progress reported through OSC 9;4, or
  /// clears it if null.
  ///
  /// The application decides how to present progress. Fires synchronously
  /// during [write].
  set onProgressReport(ValueChanged<TerminalProgress>? callback);

  /// Sets the callback invoked when the working directory changes.
  ///
  /// Programs commonly report the directory with OSC 7, OSC 9, or OSC 1337.
  /// Read [pwd] from the callback to obtain the updated value. The callback
  /// runs synchronously while [write] processes the report. The value is kept
  /// exactly as reported: OSC 7 commonly supplies a `file://` URI, whereas OSC
  /// 9 and OSC 1337 commonly supply a path.
  set onPwdChanged(VoidCallback? value);

  /// Sets the callback that reports measured terminal grid changes.
  ///
  /// Assigning this callback before a [TerminalView] has supplied measured
  /// geometry does not report the controller's configured default dimensions.
  /// Forward the values to your backend. If the view has already supplied
  /// measured geometry, assigning the callback immediately reports that
  /// committed grid.
  ///
  /// The callback runs after the measured geometry has been committed to the
  /// terminal and input subsystems, so it may synchronously start a backend or
  /// feed resulting output into this controller. Changes that affect only cell
  /// pixels, padding, or device scale are committed without invoking this
  /// callback.
  ///
  /// If DEC private mode 2048 (`TerminalMode.inBandResize`) is enabled, any
  /// committed grid or cell-pixel change can first cause [onOutput] to receive
  /// `CSI 48;rows;columns;pixel-height;pixel-width t`. When that update also
  /// changes `cols` or `rows`, this callback runs after the report; a
  /// cell-pixel-only update does not invoke it.
  set onResize(OnResize? value);

  /// Sets the callback invoked when the terminal title changes.
  ///
  /// Programs commonly set the title with OSC 0 or OSC 2. Read [title] from
  /// the callback to obtain the updated value. The callback runs synchronously
  /// while [write] processes the sequence.
  set onTitleChanged(VoidCallback? value);

  /// The working directory reported by the shell through OSC 7, OSC 9, or
  /// OSC 1337.
  ///
  /// Empty when no directory has been reported or the shell cleared it. The
  /// value is not parsed or normalized: it may be a `file://` URI or a path.
  String get pwd;

  /// The number of scrollback rows in the active screen.
  int get scrollbackRows;

  /// A snapshot of the active screen's total, visible, and offset rows.
  ///
  /// Scroll state does not itself notify controller listeners. Use the
  /// [TerminalScrollController] supplied to [TerminalView] when a Flutter UI
  /// must observe or control viewport movement.
  Scrollbar get scrollbar;

  /// The title set by the running program through OSC 0 or OSC 2.
  ///
  /// Empty when no title has been set.
  String get title;

  /// The active screen's grid rows plus scrollback rows.
  int get totalRows;

  /// Virtual modifier keys for on-screen keyboard UIs.
  ///
  /// Merged with physical modifiers when encoding input. Cleared
  /// automatically after [sendKey] or [sendText] produces output.
  ///
  /// ```dart
  /// controller.toggleMod(const Mods.ctrl());
  /// controller.sendKey(Key.c); // Sends Ctrl+C, clears the mod.
  /// ```
  Mods get virtualMods;

  /// Clears primary-screen scrollback and sends a form feed (FF, 0x0C) via
  /// [onOutput].
  ///
  /// This clears the selection but does not directly erase the active grid;
  /// the backend decides how to handle the form feed. The entire operation is
  /// a no-op on the alternate screen.
  void clear();

  /// Clears the current selection.
  void clearSelection();

  /// Clears all virtual modifiers.
  void clearVirtualMods();

  /// Creates a [Formatter] for extracting terminal content.
  ///
  /// The formatter reads the current active screen on every
  /// [Formatter.format] call. [format] selects plain text, HTML, or VT output;
  /// [unwrap] joins soft-wrapped lines; and [trim] removes trailing whitespace
  /// from non-blank lines. [extra] adds terminal and screen state only to VT
  /// output.
  ///
  /// The formatter borrows this controller's terminal. Dispose the formatter
  /// before the controller, and dispose it when no longer needed.
  ///
  /// ```dart
  /// final formatter = controller.createFormatter(
  ///   format: .plain,
  ///   unwrap: true,
  /// );
  /// final snapshot = formatter.format();
  /// formatter.dispose();
  /// ```
  Formatter createFormatter({
    required FormatterFormat format,
    bool unwrap = false,
    bool trim = false,
    FormatterExtra extra = const FormatterExtra(),
  });

  /// Returns the live value of an ANSI or DEC private terminal [mode].
  ///
  /// May differ from [config] if the running program changed it through a VT
  /// mode sequence. For example, query `const TerminalMode.bracketedPaste()`
  /// to see whether DEC private mode 2004 is active.
  bool modeGet(TerminalMode mode);

  /// Sets an ANSI or DEC private terminal [mode] at runtime.
  ///
  /// The change is not persisted in [config]. A program may overwrite it with
  /// a VT mode sequence. When the alternate screen returns to the primary
  /// screen, every mode present in [TerminalConfig.modes] is reapplied and can
  /// overwrite this value.
  void modeSet(TerminalMode mode, {required bool value});

  /// Sends paste data to the terminal via [onOutput].
  ///
  /// Unsafe control bytes such as NUL, ESC, and DEL are replaced with spaces.
  /// When bracketed paste mode (`const TerminalMode.bracketedPaste()`) is
  /// enabled, the sanitized text is wrapped in bracketed-paste delimiters;
  /// otherwise newlines are converted to carriage returns. The application
  /// remains responsible for confirming untrusted or multiline paste data
  /// before calling this method.
  ///
  /// Empty text is ignored. Non-empty text scrolls to the bottom according to
  /// [TerminalConfig.scrollToBottom].
  void paste(String text);

  /// Scrolls the viewport to the bottom (most recent content).
  void scrollToBottom();

  /// Scrolls the viewport to the top of the scrollback history.
  void scrollToTop();

  /// Selects all selectable content in the active screen.
  ///
  /// This includes scrollback while the primary screen is active.
  void selectAll();

  /// Returns the text within the current selection, or empty string when
  /// there is no selection.
  ///
  /// [format] controls the output encoding:
  /// - [FormatterFormat.plain]: unstyled text, suitable for the clipboard
  ///   (default).
  /// - [FormatterFormat.vt]: VT escape sequences preserving colors, styles,
  ///   and hyperlinks.
  /// - [FormatterFormat.html]: HTML with inline styles.
  ///
  /// In normal selection mode, soft-wrapped lines are joined into a single
  /// line without an inserted newline. In block mode, every row is kept
  /// separate regardless of wrapping. Trailing whitespace is preserved.
  String selectedText({FormatterFormat format = .plain});

  /// Selects the inclusive range between two terminal cells.
  ///
  /// Both zero-based coordinates are interpreted in [pointTag]:
  /// [PointTag.active] addresses the cursor-movable grid,
  /// [PointTag.viewport] the currently visible rows, [PointTag.screen] the
  /// entire active screen including scrollback, and [PointTag.history] only
  /// scrollback. Invalid or out-of-bounds coordinates throw.
  ///
  /// When [rectangle] is true, the endpoints describe opposite corners of a
  /// block selection. Otherwise their direction is preserved and the range is
  /// contiguous in terminal order.
  ///
  /// ```dart
  /// controller.selectRange(
  ///   start: const Position(row: 0, col: 0),
  ///   end: const Position(row: 0, col: 4),
  ///   pointTag: .viewport,
  /// );
  /// ```
  void selectRange({
    required Position start,
    required Position end,
    PointTag pointTag = .screen,
    bool rectangle = false,
  });

  /// Encodes a key press according to the terminal's keyboard modes and sends
  /// it via [onOutput].
  ///
  /// [mods] are merged with [virtualMods]. Virtual modifiers are cleared
  /// after output is produced. A key that has no representation under the
  /// current modes produces no output and leaves virtual modifiers unchanged.
  void sendKey(Key key, {Mods mods = const Mods.none()});

  /// Sends literal UTF-8 text via [onOutput].
  ///
  /// No key encoding, paste sanitization, or bracketed-paste wrapping is
  /// applied. Use [sendKey] for individual key presses that must respect
  /// terminal keyboard modes, and [paste] for clipboard content. Empty text is
  /// ignored; otherwise virtual modifiers are cleared after output is sent.
  void sendText(String text);

  /// Toggles a virtual modifier on or off.
  void toggleMod(Mods mod);

  /// Feeds raw VT bytes from the backend into the terminal.
  ///
  /// Call this with data received from your PTY, SSH channel, or socket.
  /// The terminal treats the stream as untrusted: malformed or unsupported
  /// input is ignored or logged without corrupting state. Registered effects
  /// fire synchronously, and [onOutput] can receive responses such as device
  /// attributes and status reports.
  ///
  /// Do not call [write] from a callback fired by this method. Callback
  /// exceptions are rethrown only after terminal processing completes.
  void write(Uint8List data);
}
