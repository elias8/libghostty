import 'package:flutter/painting.dart';
import 'package:libghostty/libghostty.dart';
import 'package:meta/meta.dart';

/// A resolved 256-color terminal palette as Flutter [Color] values.
///
/// Indices 0–15 hold the configurable ANSI base colors. Indices 16–231 and
/// 232–255 are generated via CIELAB-based interpolation to produce a
/// perceptually consistent extended palette.
///
/// ```dart
/// final palette = ColorPalette.fromAnsiColors(
///   ansiColors: myAnsiColors,
///   background: const Color(0xFF181818),
///   foreground: const Color(0xFFD8D8D8),
/// );
/// final red = palette[NamedColor.red]; // index 1
/// ```
@immutable
class ColorPalette {
  final List<Color> _colors;

  /// Generates a [ColorPalette] from 16 ANSI base colors.
  ///
  /// [ansiColors] must contain exactly 16 entries (indices 0–15).
  /// [background] and [foreground] anchor the CIELAB interpolation for
  /// the extended 240 colors (indices 16–255).
  factory ColorPalette.fromAnsiColors({
    required List<Color> ansiColors,
    required Color background,
    required Color foreground,
  }) {
    if (ansiColors.length != 16) {
      throw ArgumentError.value(
        ansiColors.length,
        'ansiColors',
        'must contain exactly 16 colors',
      );
    }

    final rgbBase = ansiColors.map(_colorToRgb).toList();
    final rgbResult = generate256Color(
      base: rgbBase,
      background: _colorToRgb(background),
      foreground: _colorToRgb(foreground),
    );

    return ColorPalette._(rgbResult.map(_rgbToColor).toList());
  }

  const ColorPalette._(List<Color> colors) : _colors = colors;

  @override
  int get hashCode => Object.hashAll(_colors);

  @override
  bool operator ==(Object other) {
    if (other is! ColorPalette) return false;
    for (var i = 0; i < 256; i++) {
      if (_colors[i] != other._colors[i]) return false;
    }
    return true;
  }

  /// Returns the [Color] at the given palette [index] (0–255).
  Color operator [](int index) => _colors[index];

  static RgbColor _colorToRgb(Color c) => RgbColor(
    (c.r * 255.0).round().clamp(0, 255),
    (c.g * 255.0).round().clamp(0, 255),
    (c.b * 255.0).round().clamp(0, 255),
  );

  static Color _rgbToColor(RgbColor rgb) => .fromARGB(255, rgb.r, rgb.g, rgb.b);
}
