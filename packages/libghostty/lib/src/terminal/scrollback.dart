import '../bindings/bindings.dart';
import '../color.dart';
import 'line.dart';
import 'screen.dart' show rawCellToCell;

/// Scrollback history for the primary screen buffer.
abstract class Scrollback {
  int get length;

  Line lineAt(int index);

  /// Fetches [count] consecutive lines starting at [start].
  ///
  /// Subclasses may override to batch FFI calls.
  List<Line> linesInRange(int start, int count) {
    return [for (var i = 0; i < count; i++) lineAt(start + i)];
  }
}

/// [Scrollback] backed by the terminal's page list via FFI bindings.
///
/// Queries scrollback lines through the bindings abstraction layer.
/// Used on both native and WASM platforms.
class NativeScrollback implements Scrollback {
  final int _handle;
  final RgbColor _defaultFg;
  final RgbColor _defaultBg;

  NativeScrollback(
    this._handle, {
    required RgbColor defaultFg,
    required RgbColor defaultBg,
  }) : _defaultFg = defaultFg,
       _defaultBg = defaultBg;

  @override
  int get length => bindings.terminalGetScrollbackLength(_handle);

  @override
  Line lineAt(int index) {
    return _fetchLine(index, length, bindings.renderStateGetCols(_handle));
  }

  @override
  List<Line> linesInRange(int start, int count) {
    if (count <= 0) return const [];

    final len = length;
    final cols = bindings.renderStateGetCols(_handle);
    return [for (var i = 0; i < count; i++) _fetchLine(start + i, len, cols)];
  }

  Line _fetchLine(int index, int len, int cols) {
    if (index < 0 || index >= len) {
      throw RangeError.index(index, this, 'index', null, len);
    }

    final rawCells = bindings.terminalGetScrollbackLine(_handle, index, cols);
    if (rawCells == null) return const Line([]);

    return Line([
      for (final raw in rawCells)
        rawCellToCell(raw, defaultFg: _defaultFg, defaultBg: _defaultBg),
    ]);
  }
}
