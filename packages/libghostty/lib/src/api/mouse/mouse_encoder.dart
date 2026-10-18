part of '../terminal/terminal.dart';

/// Encodes mouse events into terminal escape sequences, supporting X10, UTF-8,
/// SGR, URxvt, and SGR-Pixels mouse protocols.
///
/// The encoder is stateful: configure it with the tracking mode, output
/// format, and renderer size before encoding. Options can be set individually
/// or synced from a [Terminal] via [sync].
///
/// When used with a [Terminal], call [sync] immediately before each [encode]
/// so the produced sequence matches the terminal's current tracking mode and
/// output format. Call [setSize] once up front and again whenever the grid or
/// cell dimensions change; [sync] does not touch it.
///
/// ```dart
/// final terminal = Terminal(cols: 80, rows: 24);
/// final encoder = MouseEncoder()
///   ..setSize(const MouseEncoderSize(
///     screenWidth: 640, screenHeight: 480,
///     cellWidth: 8, cellHeight: 16,
///   ));
///
/// final event = MouseEvent()
///   ..action = MouseAction.press
///   ..button = MouseButton.left
///   ..setPosition(x: 10.0, y: 20.0);
///
/// encoder.sync(terminal);
/// final seq = encoder.encode(event);
/// if (seq.isNotEmpty) pty.write(utf8.encode(seq));
///
/// event.dispose();
/// encoder.dispose();
/// terminal.dispose();
/// ```
final class MouseEncoder {
  static final _finalizer = Finalizer(bindings.mouse.mouseEncoderFree);

  final LibGhosttyHandle _handle;
  var _disposed = false;

  /// Creates a new mouse encoder with default options.
  ///
  /// All modes start disabled (no mouse tracking). Configure with [sync] or
  /// the typed setter methods, and call [setSize] before encoding.
  ///
  /// Throws [OutOfMemoryException] if the native allocation fails.
  MouseEncoder() : _handle = bindings.mouse.mouseEncoderNew() {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Releases the native encoder handle.
  ///
  /// Calling [dispose] more than once is safe. Every other member throws a
  /// [StateError] after disposal.
  void dispose() {
    if (_disposed) return;
    bindings.mouse.mouseEncoderFree(_handle);
    _finalizer.detach(this);
    _disposed = true;
  }

  /// Encodes a [MouseEvent] into the appropriate terminal escape sequence
  /// based on the encoder's current options.
  ///
  /// Not all mouse events produce output. For example, motion events outside
  /// the tracked area or with no tracking mode enabled produce no sequence.
  /// Returns an empty string when the event produces no output.
  ///
  /// Throws [OutOfMemoryException] if the internal buffer allocation fails.
  ///
  /// ```dart
  /// final seq = encoder.encode(event);
  /// if (seq.isNotEmpty) pty.write(utf8.encode(seq));
  /// ```
  String encode(MouseEvent event) {
    final handle = _requireHandle();
    final eventHandle = event._requireHandle();
    return bindings.mouse.mouseEncoderEncode(handle, eventHandle);
  }

  /// Clears internal motion deduplication state (last tracked cell).
  ///
  /// Call this when the terminal is reset or the viewport changes to avoid
  /// suppressing motion events that should be re-reported.
  void reset() {
    final handle = _requireHandle();
    bindings.mouse.mouseEncoderReset(handle);
  }

  /// Sets whether any mouse button is currently pressed.
  ///
  /// The encoder uses this to distinguish drag events from plain motion.
  void setAnyButtonPressed({required bool pressed}) {
    final handle = _requireHandle();
    bindings.mouse.mouseEncoderSetBoolOpt(
      handle,
      .anyButtonPressed,
      value: pressed,
    );
  }

  /// Sets the mouse output format (X10, UTF-8, SGR, URxvt, or SGR-Pixels).
  ///
  /// Controls how mouse coordinates and buttons are encoded in the escape
  /// sequence. Typically synced from the terminal via [sync], but can be set
  /// directly.
  void setFormat(MouseFormat format) {
    final handle = _requireHandle();
    bindings.mouse.mouseEncoderSetFormat(handle, format);
  }

  /// Sets the renderer size context for pixel-to-cell coordinate conversion.
  ///
  /// Describes the rendered terminal geometry used to convert surface-space
  /// pixel positions into encoded cell coordinates. Call once up front and
  /// again whenever the terminal grid dimensions or cell size change;
  /// [encode] needs this to produce a non-empty sequence.
  void setSize(MouseEncoderSize size) {
    final handle = _requireHandle();
    bindings.mouse.mouseEncoderSetSize(handle, size);
  }

  /// Sets the mouse tracking mode (none, X10, normal, button, or any).
  ///
  /// Controls which mouse events are reported. Typically synced from the
  /// terminal via [sync], but can be set directly.
  void setTrackingMode(MouseTracking mode) {
    final handle = _requireHandle();
    bindings.mouse.mouseEncoderSetTrackingMode(handle, mode);
  }

  /// Sets whether to enable motion deduplication by last cell.
  ///
  /// When enabled, consecutive motion events that resolve to the same cell are
  /// suppressed. Call [reset] to clear the deduplication state.
  void setTrackLastCell({required bool enabled}) {
    final handle = _requireHandle();
    bindings.mouse.mouseEncoderSetBoolOpt(
      handle,
      .trackLastCell,
      value: enabled,
    );
  }

  /// Syncs tracking mode and output format from [terminal]'s current state.
  ///
  /// Reads the terminal's mouse tracking mode and output format and applies
  /// them to the encoder. Call immediately before each [encode] so the
  /// produced sequence matches the terminal's current state. Does not modify
  /// size or any-button state.
  void sync(Terminal terminal) {
    final handle = _requireHandle();
    final terminalHandle = terminal._requireHandle();
    bindings.mouse.mouseEncoderSetOptFromTerminal(handle, terminalHandle);
  }

  LibGhosttyHandle _requireHandle() {
    if (_disposed) throw StateError('MouseEncoder has been disposed');
    return _handle;
  }
}
