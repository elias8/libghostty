import '../bindings/bindings.dart';
import '../color.dart';
import '../enums/underline_style.dart';
import '../exceptions.dart';
import 'sgr_attribute.dart';

SgrAttribute _convertAttribute(RawSgrAttribute attr) {
  return switch (attr.tag) {
    SgrTag.unset => const SgrUnset(),
    SgrTag.unknown => SgrUnknown(attr.unknownFull, attr.unknownPartial),
    SgrTag.bold => const SgrBold(),
    SgrTag.resetBold => const SgrResetBold(),
    SgrTag.italic => const SgrItalic(),
    SgrTag.resetItalic => const SgrResetItalic(),
    SgrTag.faint => const SgrFaint(),
    SgrTag.underline => _convertUnderline(attr),
    SgrTag.underlineColor => SgrUnderlineRgb(RgbColor(attr.r, attr.g, attr.b)),
    SgrTag.underlineColor256 => SgrUnderline256(attr.paletteIndex),
    SgrTag.resetUnderlineColor => const SgrResetUnderlineColor(),
    SgrTag.overline => const SgrOverline(),
    SgrTag.resetOverline => const SgrResetOverline(),
    SgrTag.blink => const SgrBlink(),
    SgrTag.resetBlink => const SgrResetBlink(),
    SgrTag.inverse => const SgrInverse(),
    SgrTag.resetInverse => const SgrResetInverse(),
    SgrTag.invisible => const SgrInvisible(),
    SgrTag.resetInvisible => const SgrResetInvisible(),
    SgrTag.strikethrough => const SgrStrikethrough(),
    SgrTag.resetStrikethrough => const SgrResetStrikethrough(),
    SgrTag.directColorFg => SgrForegroundRgb(RgbColor(attr.r, attr.g, attr.b)),
    SgrTag.directColorBg => SgrBackgroundRgb(RgbColor(attr.r, attr.g, attr.b)),
    SgrTag.fg8 => SgrForeground8(attr.paletteIndex),
    SgrTag.bg8 => SgrBackground8(attr.paletteIndex),
    SgrTag.resetFg => const SgrResetForeground(),
    SgrTag.resetBg => const SgrResetBackground(),
    SgrTag.brightFg8 => SgrBrightForeground8(attr.paletteIndex),
    SgrTag.brightBg8 => SgrBrightBackground8(attr.paletteIndex),
    SgrTag.fg256 => SgrForeground256(attr.paletteIndex),
    SgrTag.bg256 => SgrBackground256(attr.paletteIndex),
    _ => const SgrUnknown([], []),
  };
}

SgrAttribute _convertUnderline(RawSgrAttribute attr) {
  final style = UnderlineStyle.fromNative(attr.underlineStyle);
  return style == UnderlineStyle.none
      ? const SgrResetUnderline()
      : SgrUnderline(style);
}

/// Parser for SGR (Select Graphic Rendition) sequences.
///
/// ```dart
/// final parser = SgrParser();
///
/// // Parse "bold, red foreground": ESC[1;31m
/// final attrs = parser.parse([1, 31]);
/// for (final attr in attrs) {
///   switch (attr) {
///     case SgrBold():
///       print('Bold');
///     case SgrForeground8(index: final i):
///       print('Foreground color index: $i');
///     default:
///       break;
///   }
/// }
///
/// parser.dispose();
/// ```
class SgrParser {
  static final _finalizer = Finalizer<int>(
    (handle) => bindings.sgrFree(handle),
  );

  final int _handle;
  var _disposed = false;

  SgrParser() : _handle = bindings.sgrNew() {
    _finalizer.attach(this, _handle, detach: this);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _finalizer.detach(this);
    bindings.sgrFree(_handle);
  }

  /// Parses SGR parameters and returns a list of attributes.
  ///
  /// [params] are the numeric values from a CSI SGR sequence.
  /// [separators] optionally specifies `;` or `:` for each parameter position.
  List<SgrAttribute> parse(List<int> params, {List<String>? separators}) {
    _ensureNotDisposed();
    final raw = bindings.sgrParse(_handle, params, separators);
    return raw.map(_convertAttribute).toList();
  }

  void reset() {
    _ensureNotDisposed();
    bindings.sgrReset(_handle);
  }

  void _ensureNotDisposed() {
    if (_disposed) throw const DisposedException('SgrParser');
  }
}
