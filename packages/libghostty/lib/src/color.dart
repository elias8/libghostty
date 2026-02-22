import 'package:meta/meta.dart';

/// A terminal cell color.
///
/// Sealed to enable exhaustive pattern matching:
///
/// ```dart
/// final color = cell.style.fg;
/// switch (color) {
///   case DefaultColor():
///     print('default');
///   case PaletteColor(index: final i):
///     print('palette $i');
///   case RgbColor(r: final r, g: final g, b: final b):
///     print('rgb($r, $g, $b)');
/// }
/// ```
// Wraps the native color representation from the C API.
@immutable
sealed class CellColor {
  const CellColor();
}

/// An RGB color with 8-bit components (0-255).
///
/// ```dart
/// const red = RgbColor(255, 0, 0);
/// print(red.r); // 255
/// ```
// Wraps the native GhosttyColorRgb type.
class RgbColor extends CellColor {
  final int r;
  final int g;
  final int b;

  const RgbColor(this.r, this.g, this.b);

  @override
  int get hashCode => Object.hash(RgbColor, r, g, b);

  @override
  bool operator ==(Object other) =>
      other is RgbColor && other.r == r && other.g == g && other.b == b;

  @override
  String toString() => 'RgbColor($r, $g, $b)';
}

/// The terminal's default foreground or background color.
///
/// Indicates no explicit color was set by an SGR escape sequence,
/// so the terminal should use its configured default.
///
/// ```dart
/// const color = DefaultColor();
/// print(color == const DefaultColor()); // true
/// ```
class DefaultColor extends CellColor {
  const DefaultColor();

  @override
  int get hashCode => (DefaultColor).hashCode;

  @override
  bool operator ==(Object other) => other is DefaultColor;

  @override
  String toString() => 'DefaultColor()';
}

/// A color from the 256-color palette (indices 0-255).
///
/// Indices 0-7 are standard colors, 8-15 are bright colors, 16-231 are
/// a 6x6x6 color cube, and 232-255 are grayscale.
///
/// ```dart
/// const red = PaletteColor(NamedColor.red);
/// print(red.index); // 1
/// ```
// Wraps the native GhosttyColorPaletteIndex type.
class PaletteColor extends CellColor {
  final int index;

  const PaletteColor(this.index);

  @override
  int get hashCode => Object.hash(PaletteColor, index);

  @override
  bool operator ==(Object other) =>
      other is PaletteColor && other.index == index;

  @override
  String toString() => 'PaletteColor($index)';
}

/// Standard ANSI terminal color palette indices (0-15).
///
/// Provides named constants for the 8 standard and 8 bright colors
/// defined by the terminal color palette.
///
/// ```dart
/// const fg = PaletteColor(NamedColor.red);
/// const bg = PaletteColor(NamedColor.brightBlue);
/// ```
abstract final class NamedColor {
  static const black = 0;
  static const red = 1;
  static const green = 2;
  static const yellow = 3;
  static const blue = 4;
  static const magenta = 5;
  static const cyan = 6;
  static const white = 7;
  static const brightBlack = 8;
  static const brightRed = 9;
  static const brightGreen = 10;
  static const brightYellow = 11;
  static const brightBlue = 12;
  static const brightMagenta = 13;
  static const brightCyan = 14;
  static const brightWhite = 15;
}
