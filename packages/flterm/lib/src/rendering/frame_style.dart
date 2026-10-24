part of 'frame_builder.dart';

int _resolveColorArgb(CellColor color, Uint32List palette, int defaultArgb) {
  return switch (color) {
    DefaultColor() => defaultArgb,
    RgbColor() => color.toArgb32,
    PaletteColor(:final index) => palette[index],
  };
}

(int foreground, int background) _resolveStyleColors(
  PaintState state,
  Style style,
) {
  var foreground = _resolveColorArgb(
    style.foreground,
    state.terminalPaletteArgb,
    state.terminalForegroundArgb,
  );
  var background = _resolveColorArgb(
    style.background,
    state.terminalPaletteArgb,
    state.terminalBackgroundArgb,
  );

  if (style.bold) {
    final boldColor = state.theme.boldColor;
    if (boldColor != null) {
      foreground = boldColor.toARGB32();
    } else if (state.theme.boldIsBright) {
      final raw = style.foreground;
      if (raw is PaletteColor && raw.index < 8) {
        foreground = state.terminalPaletteArgb[raw.index + 8];
      }
    }
  }

  if (style.inverse) (foreground, background) = (background, foreground);
  if (style.faint) {
    foreground = (state.faintAlpha << 24) | (foreground & 0x00FFFFFF);
  }

  return (foreground, background);
}

RgbColor? _rgbColor(Color? color) {
  if (color == null) return null;
  return RgbColor(
    (color.r * 255.0).round().clamp(0, 255),
    (color.g * 255.0).round().clamp(0, 255),
    (color.b * 255.0).round().clamp(0, 255),
  );
}

/// Resolves and caches style-derived colors for the current row.
final class _StyleCache {
  static const _maxEntries = 1024;

  final PaintState _state;
  final Int32List _gen;
  final Int32List _foreground;
  final Int32List _background;
  final Uint8List _explicitBg;
  var _generation = 0;

  _StyleCache(this._state)
    : _gen = Int32List(_maxEntries),
      _foreground = Int32List(_maxEntries),
      _background = Int32List(_maxEntries),
      _explicitBg = Uint8List(_maxEntries);

  void beginRow() => _generation++;

  (int foreground, int background, Style style, bool explicitBg) resolve(
    _DecodedRow row,
    int column, {
    required int? backgroundArgb,
  }) {
    final id = row.styleIds[column];
    if (!row.hasStyling(column) && backgroundArgb == null) {
      return (
        _state.terminalForegroundArgb,
        _state.terminalBackgroundArgb,
        const Style(),
        false,
      );
    }

    final style = row.style(column);
    final contentBackground = style.background is DefaultColor
        ? backgroundArgb
        : null;
    if (contentBackground != null) {
      final (foreground, background) = _resolveStyleColors(_state, style);
      return (
        foreground,
        style.inverse ? background : contentBackground,
        style,
        true,
      );
    }

    if (id < _maxEntries && _gen[id] == _generation) {
      return (_foreground[id], _background[id], style, _explicitBg[id] != 0);
    }

    final (foreground, background) = _resolveStyleColors(_state, style);
    var explicitBg = style.background is! DefaultColor;

    if (style.inverse) explicitBg = true;

    if (id < _maxEntries) {
      _gen[id] = _generation;
      _foreground[id] = foreground;
      _background[id] = background;
      _explicitBg[id] = explicitBg ? 1 : 0;
    }

    return (foreground, background, style, explicitBg);
  }
}
