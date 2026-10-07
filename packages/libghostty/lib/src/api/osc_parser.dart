import 'dart:typed_data';

import '../bindings/bindings.dart';
import '../bindings/types.dart';
import '../generated/libghostty_enums.g.dart';

/// The result of parsing an OSC sequence.
///
/// Query [type] to determine what command was parsed, then read the
/// corresponding data field (e.g. [windowTitle] for
/// [OscCommandType.changeWindowTitle]).
final class OscCommand {
  /// The parsed command type, or [OscCommandType.invalid] if the sequence
  /// was malformed.
  final OscCommandType type;

  /// The window title from a [OscCommandType.changeWindowTitle] command,
  /// or null for other command types.
  ///
  /// This is a Dart-owned snapshot of the title and remains valid after the
  /// parser is reused or disposed.
  final String? windowTitle;

  /// Captured bytes from an unimplemented OSC command, or null for other
  /// command types. The bytes are copied and remain valid after parser reuse.
  final Uint8List? unknownContent;

  /// Whether [unknownContent] was shortened, or null for other command types.
  final bool? unknownTruncated;

  /// How the unknown OSC sequence ended, or null for other command types.
  final OscTerminator? unknownTerminator;

  /// Creates a parsed OSC command value.
  const OscCommand({
    required this.type,
    this.windowTitle,
    this.unknownContent,
    this.unknownTruncated,
    this.unknownTerminator,
  });
}

/// Streaming parser for OSC (Operating System Command) sequences.
///
/// Processes input byte-by-byte to handle OSC sequences that may arrive in
/// fragments across multiple reads. This avoids over-allocating buffers and
/// integrates easily into most environments.
///
/// Throws [OutOfMemoryException] if the native allocation fails during
/// construction.
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
final class OscParser {
  static final _finalizer = Finalizer(bindings.parser.oscFree);

  final LibGhosttyHandle _handle;
  var _disposed = false;

  /// Creates a new OSC parser.
  ///
  /// By default, unimplemented command numbers produce
  /// [OscCommandType.invalid]. Set [unknownMaxBytes] to a positive value to
  /// retain up to that many bytes from each unimplemented command. It must be
  /// between 0 and 4294967295 so the limit has the same range on native and
  /// WebAssembly targets.
  ///
  /// Throws [OutOfMemoryException] if the native allocation fails.
  OscParser({int unknownMaxBytes = 0})
    : _handle = bindings.parser.oscNew(
        unknownMaxBytes: _checkUnknownMaxBytes(unknownMaxBytes),
      ) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Releases the native parser handle.
  ///
  /// Calling [dispose] more than once is safe. Every other member throws a
  /// [StateError] after disposal.
  void dispose() {
    if (_disposed) return;
    bindings.parser.oscFree(_handle);
    _finalizer.detach(this);
    _disposed = true;
  }

  /// Finalizes parsing and returns the parsed command.
  ///
  /// Call this after feeding all bytes of the OSC sequence body via
  /// [feedByte] or [feedBytes]. Do not include the opening ESC ] or the
  /// terminating character (BEL or ST) in the fed bytes.
  ///
  /// [terminator] is the byte that terminated the OSC sequence, typically
  /// 0x07 for BEL or 0x5C for ST after ESC. This is preserved in the parsed
  /// command so that responses can use the same terminator format for
  /// compatibility. For commands that do not require a response, this
  /// parameter is ignored.
  ///
  /// Always returns a result. Invalid or unrecognized sequences produce a
  /// command with type [OscCommandType.invalid].
  OscCommand end(int terminator) {
    final handle = _requireHandle();
    final command = bindings.parser.oscEnd(handle, terminator);
    final type = bindings.parser.oscCommandType(command);
    final windowTitle = switch (type) {
      .changeWindowTitle => bindings.parser.oscCommandWindowTitle(command),
      _ => null,
    };
    final unknownData = type == OscCommandType.unknown
        ? bindings.parser.oscCommandUnknownData(command)
        : null;
    return OscCommand(
      type: type,
      windowTitle: windowTitle,
      unknownContent: unknownData?.content,
      unknownTruncated: unknownData?.truncated,
      unknownTerminator: unknownData?.terminator,
    );
  }

  /// Feeds a single byte to the parser.
  ///
  /// Call for each byte in the OSC sequence body, after the opening ESC ]
  /// and before the terminator.
  void feedByte(int byte) {
    final handle = _requireHandle();
    bindings.parser.oscFeedByte(handle, byte);
  }

  /// Feeds multiple bytes to the parser.
  ///
  /// This is equivalent to calling [feedByte] for each byte in [bytes].
  void feedBytes(List<int> bytes) {
    final handle = _requireHandle();
    for (final byte in bytes) {
      bindings.parser.oscFeedByte(handle, byte);
    }
  }

  /// Resets the parser to its initial state.
  ///
  /// Clears any partially parsed sequence. Useful for reusing the parser
  /// or recovering from parse errors.
  void reset() {
    final handle = _requireHandle();
    bindings.parser.oscReset(handle);
  }

  LibGhosttyHandle _requireHandle() =>
      _disposed ? throw StateError('OscParser has been disposed') : _handle;

  static int _checkUnknownMaxBytes(int value) {
    if (value < 0 || value > 0xffffffff) {
      throw RangeError.range(value, 0, 0xffffffff, 'unknownMaxBytes');
    }
    return value;
  }
}
