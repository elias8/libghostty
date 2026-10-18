import '../bindings/bindings.dart';
import '../bindings/types.dart';
import '../types/types.dart';

/// Parses SGR (Select Graphic Rendition) escape sequence parameters into
/// typed [SgrAttribute] values.
///
/// SGR sequences set styling attributes such as bold, italic, underline, and
/// colors for text in terminal emulators (e.g. `ESC[1;31m` where `1;31` is
/// the SGR parameter list). The parser supports both semicolon (`;`) and colon
/// (`:`) separators, possibly mixed, and handles 8-color, 16-color, 256-color,
/// and RGB color formats.
///
/// Throws [OutOfMemoryException] if the native allocation fails during
/// construction.
///
/// ```dart
/// final parser = SgrParser();
/// final attrs = parser.parse([1, 38, 2, 255, 0, 0]);
/// // attrs: [SgrAttribute(tag: .bold), SgrAttribute(tag: .directColorFg, ...)]
/// parser.dispose();
/// ```
final class SgrParser {
  static final _finalizer = Finalizer(bindings.parser.sgrFree);

  final LibGhosttyHandle _handle;
  var _disposed = false;

  /// Creates a new SGR parser.
  ///
  /// Throws [OutOfMemoryException] if the native allocation fails during
  /// construction.
  SgrParser() : _handle = bindings.parser.sgrNew() {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Releases the native parser handle.
  ///
  /// Calling [dispose] more than once is safe. Every other member throws a
  /// [StateError] after disposal. Any [SgrAttribute] values previously
  /// returned by [parse] remain valid because they are Dart-owned values.
  void dispose() {
    if (_disposed) return;
    bindings.parser.sgrFree(_handle);
    _finalizer.detach(this);
    _disposed = true;
  }

  /// Parses SGR [params] into a list of typed attributes.
  ///
  /// [params] are the numeric values from a CSI SGR sequence, for example,
  /// `[1, 31]` for `ESC[1;31m`. Each value must fit in an unsigned 16-bit
  /// integer, from 0 to 65535.
  ///
  /// [separators] optionally specifies the separator character for each
  /// parameter position: `";"` for semicolon or `":"` for colon. This is
  /// needed for color formats that use colon separators, such as `ESC[4:3m`
  /// for curly underline. It must have the same length as [params] when
  /// provided. If null, all parameters are assumed to be
  /// semicolon-separated.
  ///
  /// The parser makes an internal copy of the data, so [params] and
  /// [separators] can be modified after this call.
  ///
  /// Throws [OutOfMemoryException] if the internal copy allocation fails.
  /// Throws [RangeError] if a parameter is outside the supported range, or
  /// [ArgumentError] if separators have the wrong length or character.
  List<SgrAttribute> parse(List<int> params, {List<String>? separators}) {
    final handle = _requireHandle();
    if (separators != null) {
      if (separators.length != params.length) {
        throw ArgumentError.value(
          separators,
          'separators',
          'must have the same length as params',
        );
      }
    }
    bindings.parser.sgrSetParams(handle, params, separators);
    final results = <SgrAttribute>[];
    for (
      var attr = bindings.parser.sgrNext(handle);
      attr != null;
      attr = bindings.parser.sgrNext(handle)
    ) {
      results.add(attr);
    }
    return results;
  }

  /// Resets the parser's iteration state to the beginning of the parameter
  /// list without clearing the parameters.
  ///
  /// After calling this, the next [parse] or internal iteration starts from
  /// the beginning.
  void reset() {
    final handle = _requireHandle();
    bindings.parser.sgrReset(handle);
  }

  LibGhosttyHandle _requireHandle() =>
      _disposed ? throw StateError('SgrParser has been disposed') : _handle;
}
