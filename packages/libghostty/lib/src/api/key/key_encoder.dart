part of '../terminal/terminal.dart';

/// Encodes key events into terminal escape sequences, supporting both legacy
/// encoding and the Kitty keyboard protocol.
///
/// The encoder is stateful: configure it with terminal modes and protocol flags
/// before encoding. Options can be set individually ([setCursorKeyApplication],
/// [setKittyFlags], etc.) or synced in bulk from a [Terminal] via [sync].
///
/// When used with a [Terminal], call [sync] immediately before each [encode]
/// so the produced sequence matches the terminal's current mode state.
///
/// ```dart
/// final terminal = Terminal(cols: 80, rows: 24);
/// final encoder = KeyEncoder();
/// final event = KeyEvent()
///   ..action = KeyAction.press
///   ..key = Key.c
///   ..mods = Mods.ctrl();
///
/// encoder.sync(terminal);
/// final seq = encoder.encode(event);
/// if (seq.isNotEmpty) pty.write(utf8.encode(seq));
///
/// event.dispose();
/// encoder.dispose();
/// terminal.dispose();
/// ```
final class KeyEncoder {
  static final _finalizer = Finalizer(bindings.key.keyEncoderFree);

  final LibGhosttyHandle _handle;
  var _disposed = false;

  /// Creates a new key encoder with default options.
  ///
  /// All modes start disabled (legacy encoding). Configure with the setter
  /// methods or [sync] before calling [encode].
  ///
  /// Throws [OutOfMemoryException] if the native allocation fails.
  KeyEncoder() : _handle = bindings.key.keyEncoderNew() {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Releases the native encoder handle.
  ///
  /// Calling [dispose] more than once is safe. Every other member throws a
  /// [StateError] after disposal.
  void dispose() {
    if (_disposed) return;
    bindings.key.keyEncoderFree(_handle);
    _finalizer.detach(this);
    _disposed = true;
  }

  /// Encodes a [KeyEvent] into the appropriate terminal escape sequence based
  /// on the encoder's current options.
  ///
  /// Not all key events produce output. For example, unmodified modifier keys
  /// typically do not generate escape sequences. Check whether the returned
  /// string is empty to determine if any data was produced.
  ///
  /// The encoding format depends on the encoder's current options: legacy
  /// encoding by default, or Kitty keyboard protocol sequences when Kitty
  /// flags are set via [setKittyFlags].
  ///
  /// Throws [OutOfMemoryException] if the internal buffer allocation fails.
  ///
  /// ```dart
  /// final seq = encoder.encode(event);
  /// if (seq.isNotEmpty) pty.write(utf8.encode(seq));
  /// ```
  String encode(KeyEvent event) {
    final handle = _requireHandle();
    final eventHandle = event._requireHandle();
    return bindings.key.keyEncoderEncode(handle, eventHandle);
  }

  /// Sets DEC mode 1036: whether Alt sends an ESC prefix before the key
  /// sequence.
  void setAltEscPrefix({required bool enabled}) {
    _setOptBool(.altEscPrefix, enabled);
  }

  /// Sets DEC mode 67: back-arrow key mode.
  ///
  /// When enabled, Backspace emits BS (`0x08`) in legacy key encoding.
  /// When disabled, Backspace emits DEL (`0x7f`).
  void setBackArrowKeyMode({required bool enabled}) {
    _setOptBool(.backarrowKeyMode, enabled);
  }

  /// Sets DEC mode 1: cursor key application mode.
  ///
  /// When enabled, cursor keys send SS3-prefixed sequences (e.g. `\eOA`)
  /// instead of CSI-prefixed sequences (e.g. `\e[A`).
  void setCursorKeyApplication({required bool enabled}) {
    _setOptBool(.cursorKeyApplication, enabled);
  }

  /// Sets DEC mode 1035: ignore keypad keys when Num Lock is active.
  void setIgnoreKeypadWithNumLock({required bool enabled}) {
    _setOptBool(.ignoreKeypadWithNumlock, enabled);
  }

  /// Sets DEC mode 66: keypad application mode.
  ///
  /// When enabled, keypad keys send application-mode sequences instead of
  /// their normal values.
  void setKeypadKeyApplication({required bool enabled}) {
    _setOptBool(.keypadKeyApplication, enabled);
  }

  /// Sets the Kitty keyboard protocol flags controlling which key events and
  /// metadata are reported.
  ///
  /// Pass `KittyKeyFlags.disabled` to use legacy encoding. Flags can be
  /// combined with `|` to enable multiple modes simultaneously.
  void setKittyFlags(KittyKeyFlags flags) {
    final handle = _requireHandle();
    bindings.key.keyEncoderSetKittyFlags(handle, flags.value);
  }

  /// Sets xterm modifyOtherKeys mode 2.
  ///
  /// When enabled, keys that would normally produce a character are encoded
  /// with modifier information using CSI 27 sequences.
  void setModifyOtherKeys({required bool enabled}) {
    _setOptBool(.modifyOtherKeysState2, enabled);
  }

  /// Sets the macOS option-as-alt behavior.
  ///
  /// Controls whether the macOS Option key is treated as Alt for encoding
  /// purposes. This option cannot be determined from terminal state, so
  /// [sync] resets it to [OptionAsAlt.false$]. Call this method afterward if
  /// needed.
  void setOptionAsAlt(OptionAsAlt option) {
    final handle = _requireHandle();
    bindings.key.keyEncoderSetOptionAsAlt(handle, option);
  }

  /// Syncs all encoder options from [terminal]'s current mode state.
  ///
  /// Reads the terminal's current modes and applies them to the encoder:
  /// cursor key application mode (DEC 1), keypad mode (DEC 66), back-arrow key
  /// mode (DEC 67), alt escape prefix (DEC 1036), modifyOtherKeys state, and
  /// Kitty keyboard protocol flags.
  ///
  /// Call immediately before each [encode] so the produced sequence matches
  /// the terminal's current mode state.
  ///
  /// The macOS option-as-alt option cannot be determined from terminal state
  /// and is reset to [OptionAsAlt.false$] by this call. Use [setOptionAsAlt]
  /// afterward if needed.
  void sync(Terminal terminal) {
    final handle = _requireHandle();
    final terminalHandle = terminal._requireHandle();
    bindings.key.keyEncoderSetOptFromTerminal(handle, terminalHandle);
  }

  LibGhosttyHandle _requireHandle() {
    if (_disposed) throw StateError('KeyEncoder has been disposed');
    return _handle;
  }

  void _setOptBool(KeyEncoderOption option, bool enabled) {
    final handle = _requireHandle();
    bindings.key.keyEncoderSetBoolOpt(handle, option, value: enabled);
  }
}
