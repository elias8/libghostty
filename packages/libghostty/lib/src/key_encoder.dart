import 'bindings/bindings.dart';
import 'enums/kitty_key_flags.dart';
import 'enums/option_as_alt.dart';
import 'exceptions.dart';
import 'key_event.dart';

/// Encodes key events into terminal escape sequences.
///
/// ```dart
/// final encoder = KeyEncoder();
/// encoder.setKittyFlags(KittyKeyFlags.all);
///
/// final event = KeyEvent()
///   ..action = KeyAction.press
///   ..key = Key.keyC
///   ..mods = Mods.ctrl;
///
/// final sequence = encoder.encode(event);
/// print(sequence); // the escape sequence bytes
///
/// event.dispose();
/// encoder.dispose();
/// ```
class KeyEncoder {
  static final _finalizer = Finalizer<int>(
    (handle) => bindings.keyEncoderFree(handle),
  );

  final int _handle;
  var _disposed = false;

  KeyEncoder() : _handle = bindings.keyEncoderNew() {
    _finalizer.attach(this, _handle, detach: this);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _finalizer.detach(this);
    bindings.keyEncoderFree(_handle);
  }

  /// Encodes [event] into a terminal escape sequence.
  ///
  /// Returns the escape sequence as a string, or an empty string if the
  /// event does not produce output (e.g., an unmodified modifier key press).
  String encode(KeyEvent event) {
    _ensureNotDisposed();
    return bindings.keyEncoderEncode(_handle, event.nativeHandle);
  }

  /// Alt sends escape prefix (DEC mode 1036).
  void setAltEscPrefix({required bool enabled}) {
    _setOptBool(KeyEncoderOpt.altEscPrefix, enabled);
  }

  /// Cursor key application mode (DEC mode 1).
  void setCursorKeyApplication({required bool enabled}) {
    _setOptBool(KeyEncoderOpt.cursorKeyApplication, enabled);
  }

  /// Ignore keypad with NumLock (DEC mode 1035).
  void setIgnoreKeypadWithNumLock({required bool enabled}) {
    _setOptBool(KeyEncoderOpt.ignoreKeypadWithNumlock, enabled);
  }

  /// Keypad key application mode (DEC mode 66).
  void setKeypadKeyApplication({required bool enabled}) {
    _setOptBool(KeyEncoderOpt.keypadKeyApplication, enabled);
  }

  /// Kitty keyboard protocol flags.
  void setKittyFlags(KittyKeyFlags flags) {
    _ensureNotDisposed();
    bindings.keyEncoderSetKittyFlags(_handle, flags.value);
  }

  /// xterm modifyOtherKeys mode 2.
  void setModifyOtherKeys({required bool enabled}) {
    _setOptBool(KeyEncoderOpt.modifyOtherKeysState2, enabled);
  }

  /// macOS option-as-alt setting.
  void setOptionAsAlt(OptionAsAlt option) {
    _ensureNotDisposed();
    bindings.keyEncoderSetOptionAsAlt(_handle, option.nativeValue);
  }

  void _ensureNotDisposed() {
    if (_disposed) throw const DisposedException('KeyEncoder');
  }

  void _setOptBool(int option, bool enabled) {
    _ensureNotDisposed();
    bindings.keyEncoderSetBoolOpt(_handle, option, enabled);
  }
}
