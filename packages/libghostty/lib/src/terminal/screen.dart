import '../bindings/bindings.dart';
import '../color.dart';
import '../enums/underline_style.dart' show UnderlineStyle;
import 'cell.dart';
import 'line.dart';

Cell rawCellToCell(
  RawCell raw, {
  required RgbColor defaultFg,
  required RgbColor defaultBg,
  String? contentOverride,
}) {
  if (raw.codepoint == 0) return Cell.empty;

  final fg = RgbColor(raw.fgR, raw.fgG, raw.fgB);
  final bg = RgbColor(raw.bgR, raw.bgG, raw.bgB);

  return Cell(
    content: contentOverride ?? String.fromCharCode(raw.codepoint),
    foreground: fg == defaultFg ? const DefaultColor() : fg,
    background: bg == defaultBg ? const DefaultColor() : bg,
    style: _styleFromFlags(raw.flags, raw.underlineStyle),
    isWide: raw.width > 1,
  );
}

CellStyle _styleFromFlags(int flags, int underlineStyle) {
  return CellStyle(
    bold: flags & CellFlags.bold != 0,
    italic: flags & CellFlags.italic != 0,
    faint: flags & CellFlags.faint != 0,
    strikethrough: flags & CellFlags.strikethrough != 0,
    blink: flags & CellFlags.blink != 0,
    inverse: flags & CellFlags.inverse != 0,
    invisible: flags & CellFlags.invisible != 0,
    overline: flags & CellFlags.overline != 0,
    underline: UnderlineStyle.fromNative(underlineStyle),
  );
}

/// [Screen] backed by the terminal's render state via FFI bindings.
///
/// Lazily fetches the viewport grid on first access and caches lines
/// until [invalidate] is called. Used on both native and WASM platforms
/// through the bindings abstraction layer.
class NativeScreen implements Screen {
  final int _handle;
  final RgbColor _defaultFg;
  final RgbColor _defaultBg;

  var _cachedCols = 0;
  var _cachedRows = 0;
  List<RawCell>? _viewport;
  List<Line?>? _cachedLines;

  NativeScreen(
    this._handle, {
    required RgbColor defaultFg,
    required RgbColor defaultBg,
  }) : _defaultFg = defaultFg,
       _defaultBg = defaultBg;

  @override
  int get cols => bindings.renderStateGetCols(_handle);

  @override
  int get rows => bindings.renderStateGetRows(_handle);

  @override
  Cell cellAt(int row, int col) {
    _ensureViewport();

    if (_cachedLines case final lines? when row >= 0 && row < _cachedRows) {
      final cached = lines[row];
      if (cached != null) return cached.cellAt(col);
    }

    final idx = row * _cachedCols + col;
    if (idx < 0 || idx >= _viewport!.length) return Cell.empty;

    return _resolveCell(_viewport![idx], row, col);
  }

  void invalidate() {
    _viewport = null;
    _cachedLines = null;
  }

  @override
  Line lineAt(int row) {
    _ensureViewport();

    if (row < 0 || row >= _cachedRows) return const Line([]);

    final lines = _cachedLines ??= List<Line?>.filled(_cachedRows, null);
    final cached = lines[row];
    if (cached != null) return cached;

    final start = row * _cachedCols;
    if (start >= _viewport!.length) return const Line([]);

    final end = start + _cachedCols;
    final line = Line([
      for (var i = start; i < end && i < _viewport!.length; i++)
        _resolveCell(_viewport![i], row, i - start),
    ]);

    lines[row] = line;
    return line;
  }

  void _ensureViewport() {
    if (_viewport != null) return;

    _cachedCols = cols;
    _cachedRows = rows;
    _viewport = bindings.renderStateGetViewport(
      _handle,
      _cachedCols,
      _cachedRows,
    );
  }

  Cell _resolveCell(RawCell raw, int row, int col) {
    String? contentOverride;

    if (raw.graphemeLen > 0) {
      final codepoints = bindings.renderStateGetGrapheme(_handle, row, col);
      if (codepoints.isNotEmpty) {
        contentOverride = String.fromCharCodes(codepoints);
      }
    }

    return rawCellToCell(
      raw,
      defaultFg: _defaultFg,
      defaultBg: _defaultBg,
      contentOverride: contentOverride,
    );
  }
}

/// Live view of a terminal screen buffer.
///
/// ```dart
/// for (var row = 0; row < screen.rows; row++) {
///   for (var col = 0; col < screen.cols; col++) {
///     final cell = screen.cellAt(row, col);
///   }
/// }
/// ```
abstract class Screen {
  int get cols;

  int get rows;

  Cell cellAt(int row, int col);

  Line lineAt(int row);
}
