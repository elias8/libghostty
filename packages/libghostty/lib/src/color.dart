// The color types and 256-color palette generation in this file are a direct
// Dart translation of Ghostty's terminal color implementation:
// https://github.com/ghostty-org/ghostty/blob/main/src/terminal/color.zig

import 'dart:math' as math;

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

/// Generate the 256-color palette from the user's base16 theme colors,
/// terminal background, and terminal foreground.
///
/// Motivation: The default 256-color palette uses fixed, fully-saturated
/// colors that clash with custom base16 themes, have poor readability in
/// dark shades (the first non-black shade jumps to 37% intensity instead
/// of the expected 20%), and exhibit inconsistent perceived brightness
/// across hues of the same shade (e.g., blue appears darker than green).
/// By generating the extended palette from the user's chosen colors,
/// programs can use the richer 256-color range without requiring their
/// own theme configuration, and light/dark switching works automatically.
///
/// The 216-color cube (indices 16–231) is built via trilinear
/// interpolation in CIELAB space over the 8 base colors. The base16
/// palette maps to the 8 corners of a 6×6×6 RGB cube as follows:
///
/// ```text
///   R=0 edge: bg      → base[1] (red)
///   R=5 edge: base[6] → fg
///   G=0 edge: bg/base[6] (via R) → base[2]/base[4] (green/blue via R)
///   G=5 edge: base[1]/fg (via R) → base[3]/base[5] (yellow/magenta via R)
/// ```
///
/// For each R slice, four corner colors (c0–c3) are interpolated along
/// the R axis, then for each G row two edge colors (c4–c5) are
/// interpolated along G, and finally each B cell is interpolated along B
/// to produce the final color. CIELAB interpolation ensures perceptually
/// uniform brightness transitions across different hues.
///
/// The 24-step grayscale ramp (indices 232–255) is a simple linear
/// interpolation in CIELAB from the background to the foreground,
/// excluding pure black and white (available in the cube at (0,0,0)
/// and (5,5,5)). The interpolation parameter runs from 1/25 to 24/25.
///
/// [base] must contain exactly 16 entries.
/// [skip] contains indices whose values are preserved from [base] as-is.
/// [harmonious] keeps the cube orientation matching a light theme's color
/// direction; when false (default), cube always runs dark→light.
///
/// Reference: https://gist.github.com/jake-stewart/0a8ea46159a7da2c808e5be2177e1783
List<RgbColor> generate256Color({
  required List<RgbColor> base,
  required RgbColor background,
  required RgbColor foreground,
  bool harmonious = false,
  Set<int>? skip,
}) {
  if (base.length != 16) {
    throw ArgumentError.value(
      base.length,
      'base',
      'must contain exactly 16 colors',
    );
  }

  // Convert the background, foreground, and 8 base theme colors into
  // CIELAB space so that all interpolation is perceptually uniform.
  final base8 = <_Lab>[
    .fromRgb(background),
    .fromRgb(base[NamedColor.red]),
    .fromRgb(base[NamedColor.green]),
    .fromRgb(base[NamedColor.yellow]),
    .fromRgb(base[NamedColor.blue]),
    .fromRgb(base[NamedColor.magenta]),
    .fromRgb(base[NamedColor.cyan]),
    .fromRgb(foreground),
  ];

  // For light themes (where the foreground is darker than the
  // background), the cube's dark-to-light orientation is inverted
  // relative to the base color mapping. When harmonious is false,
  // swap bg and fg so the cube still runs from black (16) to
  // white (231).
  final isLightTheme = base8[7].l < base8[0].l;
  if (isLightTheme && !harmonious) {
    final tmp = base8[0];
    base8[0] = base8[7];
    base8[7] = tmp;
  }

  // Start from the base palette so indices 0–15 are preserved as-is.
  final result = List<RgbColor>.filled(256, const RgbColor(0, 0, 0));
  for (var i = 0; i < 16; i++) {
    result[i] = base[i];
  }

  // Build the 216-color cube (indices 16–231) via trilinear interpolation
  // in CIELAB. The three nested loops correspond to the R, G, and B axes
  // of a 6×6×6 cube. For each R slice, four corner colors (c0–c3) are
  // interpolated along R from the 8 base colors, mapping the cube corners
  // to theme-aware anchors (see doc comment for the mapping). Then for
  // each G row, two edge colors (c4–c5) blend along G, and finally each
  // B cell interpolates along B to produce the final color.
  var idx = 16;
  for (var ri = 0; ri < 6; ri++) {
    // R-axis corners: blend base colors along the red dimension.
    final tr = ri / 5.0;
    final c0 = _Lab.lerp(tr, base8[0], base8[1]);
    final c1 = _Lab.lerp(tr, base8[2], base8[3]);
    final c2 = _Lab.lerp(tr, base8[4], base8[5]);
    final c3 = _Lab.lerp(tr, base8[6], base8[7]);
    for (var gi = 0; gi < 6; gi++) {
      // G-axis edges: blend the R-interpolated corners along green.
      final tg = gi / 5.0;
      final c4 = _Lab.lerp(tg, c0, c1);
      final c5 = _Lab.lerp(tg, c2, c3);
      for (var bi = 0; bi < 6; bi++) {
        // B-axis: final interpolation along blue, then convert back to RGB.
        if (skip == null || !skip.contains(idx)) {
          final c6 = _Lab.lerp(bi / 5.0, c4, c5);
          result[idx] = c6.toRgb();
        }
        idx++;
      }
    }
  }

  // Build the 24-step grayscale ramp (indices 232–255) by linearly
  // interpolating in CIELAB from background to foreground. The parameter
  // runs from 1/25 to 24/25, excluding the endpoints which are already
  // available in the cube at (0,0,0) and (5,5,5).
  for (var i = 0; i < 24; i++) {
    if (skip == null || !skip.contains(idx)) {
      final t = (i + 1) / 25.0;
      result[idx] = _Lab.lerp(t, base8[0], base8[7]).toRgb();
    }
    idx++;
  }

  return result;
}

// LAB color space. Not part of the public API — used internally by
// generate256Color.
class _Lab {
  final double l;
  final double a;
  final double b;

  const _Lab(this.l, this.a, this.b);

  // RGB to LAB
  factory _Lab.fromRgb(RgbColor rgb) {
    // Step 1: Normalize sRGB channels from [0, 255] to [0.0, 1.0].
    var r = rgb.r / 255.0;
    var g = rgb.g / 255.0;
    var b = rgb.b / 255.0;

    // Step 2: Apply the inverse sRGB companding (gamma correction) to
    // convert from sRGB to linear RGB. The sRGB transfer function has
    // two segments: a linear portion for small values and a power curve
    // for the rest.
    r = r > 0.04045 ? math.pow((r + 0.055) / 1.055, 2.4).toDouble() : r / 12.92;
    g = g > 0.04045 ? math.pow((g + 0.055) / 1.055, 2.4).toDouble() : g / 12.92;
    b = b > 0.04045 ? math.pow((b + 0.055) / 1.055, 2.4).toDouble() : b / 12.92;

    // Step 3: Convert linear RGB to CIE XYZ using the sRGB to XYZ
    // transformation matrix (D65 illuminant). The X and Z values are
    // normalized by the D65 white point reference values (Xn=0.95047,
    // Zn=1.08883; Yn=1.0 is implicit).
    var x = (r * 0.4124564 + g * 0.3575761 + b * 0.1804375) / 0.95047;
    var y = r * 0.2126729 + g * 0.7151522 + b * 0.0721750;
    var z = (r * 0.0193339 + g * 0.1191920 + b * 0.9503041) / 1.08883;

    // Step 4: Apply the CIE f(t) nonlinear transform to each XYZ
    // component. Above the threshold (epsilon ≈ 0.008856) the cube
    // root is used; below it, a linear approximation avoids numerical
    // instability near zero.
    x = x > 0.008856
        ? math.pow(x, 1.0 / 3.0).toDouble()
        : 7.787 * x + 16.0 / 116.0;
    y = y > 0.008856
        ? math.pow(y, 1.0 / 3.0).toDouble()
        : 7.787 * y + 16.0 / 116.0;
    z = z > 0.008856
        ? math.pow(z, 1.0 / 3.0).toDouble()
        : 7.787 * z + 16.0 / 116.0;

    // Step 5: Compute the final CIELAB values from the transformed XYZ.
    // L* is lightness (0–100), a* is green–red, b* is blue–yellow.
    return _Lab(116.0 * y - 16.0, 500.0 * (x - y), 200.0 * (y - z));
  }

  // Linearly interpolate between two LAB colors component-wise.
  // t is the interpolation factor in [0, 1]: t=0 returns a,
  // t=1 returns b, and values in between blend proportionally.
  factory _Lab.lerp(double t, _Lab a, _Lab b) {
    return _Lab(
      a.l + t * (b.l - a.l),
      a.a + t * (b.a - a.a),
      a.b + t * (b.b - a.b),
    );
  }

  // LAB to RGB
  RgbColor toRgb() {
    // Step 1: Recover the intermediate f(Y), f(X), f(Z) values from
    // L*a*b* by inverting the CIELAB formulas.
    final fy = (l + 16.0) / 116.0;
    final fx = a / 500.0 + fy;
    final fz = fy - b / 200.0;

    // Step 2: Apply the inverse CIE f(t) transform to get back to
    // XYZ. Above epsilon (≈0.008856) the cube is used; below it the
    // linear segment is inverted. Results are then scaled by the D65
    // white point reference values (Xn=0.95047, Zn=1.08883; Yn=1.0).
    final x3 = fx * fx * fx;
    final y3 = fy * fy * fy;
    final z3 = fz * fz * fz;
    final xf = (x3 > 0.008856 ? x3 : (fx - 16.0 / 116.0) / 7.787) * 0.95047;
    final yf = y3 > 0.008856 ? y3 : (fy - 16.0 / 116.0) / 7.787;
    final zf = (z3 > 0.008856 ? z3 : (fz - 16.0 / 116.0) / 7.787) * 1.08883;

    // Step 3: Convert CIE XYZ back to linear RGB using the XYZ to sRGB
    // matrix (inverse of the sRGB to XYZ matrix, D65 illuminant).
    var r = xf * 3.2404542 - yf * 1.5371385 - zf * 0.4985314;
    var g = -xf * 0.9692660 + yf * 1.8760108 + zf * 0.0415560;
    var bl = xf * 0.0556434 - yf * 0.2040259 + zf * 1.0572252;

    // Step 4: Apply sRGB companding (gamma correction) to convert from
    // linear RGB back to sRGB. This is the forward sRGB transfer
    // function with the same two-segment split as the inverse.
    r = r > 0.0031308
        ? 1.055 * math.pow(r, 1.0 / 2.4).toDouble() - 0.055
        : 12.92 * r;
    g = g > 0.0031308
        ? 1.055 * math.pow(g, 1.0 / 2.4).toDouble() - 0.055
        : 12.92 * g;
    bl = bl > 0.0031308
        ? 1.055 * math.pow(bl, 1.0 / 2.4).toDouble() - 0.055
        : 12.92 * bl;

    // Step 5: Clamp to [0.0, 1.0], scale to [0, 255], and round to
    // the nearest integer to produce the final 8-bit sRGB values.
    return RgbColor(
      (r.clamp(0.0, 1.0) * 255.0).round(),
      (g.clamp(0.0, 1.0) * 255.0).round(),
      (bl.clamp(0.0, 1.0) * 255.0).round(),
    );
  }
}
