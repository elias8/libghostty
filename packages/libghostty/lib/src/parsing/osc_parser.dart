import '../bindings/bindings.dart';
import '../enums/osc_command_type.dart';
import '../exceptions.dart';

/// The result of parsing an OSC sequence.
class OscCommand {
  final OscCommandType type;

  /// The window title from a [OscCommandType.changeWindowTitle] command.
  final String? windowTitle;

  OscCommand({required this.type, this.windowTitle});
}

/// Streaming parser for OSC (Operating System Command) sequences.
///
/// ```dart
/// final parser = OscParser();
///
/// // Feed bytes of "0;My Title" (OSC set window title)
/// for (final byte in utf8.encode('0;My Title')) {
///   parser.feedByte(byte);
/// }
///
/// final command = parser.end(0x07); // BEL terminator
/// print(command.type);              // OscCommandType.changeWindowTitle
/// print(command.windowTitle);       // "My Title"
///
/// parser.dispose();
/// ```
class OscParser {
  static final _finalizer = Finalizer<int>(
    (handle) => bindings.oscFree(handle),
  );

  final int _handle;
  var _disposed = false;

  OscParser() : _handle = bindings.oscNew() {
    _finalizer.attach(this, _handle, detach: this);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _finalizer.detach(this);
    bindings.oscFree(_handle);
  }

  /// Finalizes parsing and returns the parsed command.
  ///
  /// [terminator] is the byte that ended the sequence: `0x07` for BEL,
  /// `0x5C` for ST.
  OscCommand end(int terminator) {
    _ensureNotDisposed();
    final result = bindings.oscEnd(_handle, terminator);
    return OscCommand(
      type: OscCommandType.fromNative(result.commandType),
      windowTitle: result.windowTitle,
    );
  }

  void feedByte(int byte) {
    _ensureNotDisposed();
    bindings.oscFeedByte(_handle, byte);
  }

  void feedBytes(List<int> bytes) {
    _ensureNotDisposed();
    for (final byte in bytes) {
      bindings.oscFeedByte(_handle, byte);
    }
  }

  void reset() {
    _ensureNotDisposed();
    bindings.oscReset(_handle);
  }

  void _ensureNotDisposed() {
    if (_disposed) throw const DisposedException('OscParser');
  }
}
