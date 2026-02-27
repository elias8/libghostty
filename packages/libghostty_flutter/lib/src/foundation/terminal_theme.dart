import 'package:flutter/painting.dart';
import 'package:libghostty/libghostty.dart';
import 'package:meta/meta.dart';

import 'color_palette.dart';

const _defaultAnsiColors = [
  Color(0xFF282828), // 0: black
  Color(0xFFCC4242), // 1: red
  Color(0xFF66994C), // 2: green
  Color(0xFFE5B566), // 3: yellow
  Color(0xFF668ECC), // 4: blue
  Color(0xFFB266B2), // 5: magenta
  Color(0xFF4CB2B2), // 6: cyan
  Color(0xFFAAAAAA), // 7: white
  Color(0xFF505050), // 8: bright black
  Color(0xFFE66464), // 9: bright red
  Color(0xFF8CBE6E), // 10: bright green
  Color(0xFFF0C878), // 11: bright yellow
  Color(0xFF82A0DC), // 12: bright blue
  Color(0xFFC882C8), // 13: bright magenta
  Color(0xFF64C8C8), // 14: bright cyan
  Color(0xFFDCDCDC), // 15: bright white
];

/// The visual style of the terminal cursor.
///
/// ```dart
/// const cursor = CursorTheme(shape: CursorShape.bar);
/// ```
@immutable
class CursorTheme {
  /// Cursor shape: block, underline, bar, or block-hollow.
  final CursorShape shape;

  /// Explicit cursor color. When null, the renderer uses the foreground color.
  final Color? color;

  /// Time between blink state toggles.
  final Duration blinkInterval;

  const CursorTheme({
    this.shape = CursorShape.block,
    this.color,
    this.blinkInterval = const Duration(milliseconds: 600),
  });

  @override
  int get hashCode => Object.hash(CursorTheme, shape, color, blinkInterval);

  @override
  bool operator ==(Object other) =>
      other is CursorTheme &&
      other.shape == shape &&
      other.color == color &&
      other.blinkInterval == blinkInterval;

  @override
  String toString() =>
      'CursorTheme(shape: $shape, color: $color, '
      'blinkInterval: $blinkInterval)';
}

/// Terminal appearance configuration.
///
/// Holds all visual settings for a terminal: colors, cursor style, and font.
/// Resolves [CellColor] values from the core package to Flutter [Color] using
/// the configured palette and default colors.
///
/// ```dart
/// final theme = TerminalTheme.defaults;
/// final fg = theme.resolveColor(cell.foreground, isForeground: true);
/// ```
@immutable
class TerminalTheme {
  /// A sensible dark-background terminal theme.
  static final defaults = TerminalTheme(
    foreground: const Color(0xFFD8D8D8),
    background: const Color(0xFF181818),
    ansiColors: _defaultAnsiColors,
  );

  /// Default foreground color when a cell uses [DefaultColor].
  final Color foreground;

  /// Default background color when a cell uses [DefaultColor].
  final Color background;

  /// The resolved 256-color palette.
  final ColorPalette palette;

  /// Cursor appearance settings.
  final CursorTheme cursor;

  /// Font family name for rendering terminal text.
  final String fontFamily;

  /// Font size in logical pixels.
  final double fontSize;

  /// [ansiColors] must contain exactly 16 entries. The full 256-color palette
  /// is auto-generated via CIELAB-based interpolation.
  TerminalTheme({
    required this.foreground,
    required this.background,
    required List<Color> ansiColors,
    this.cursor = const CursorTheme(),
    this.fontFamily = 'monospace',
    this.fontSize = 14.0,
  }) : palette = ColorPalette.fromAnsiColors(
         ansiColors: ansiColors,
         background: background,
         foreground: foreground,
       );

  const TerminalTheme._withPalette({
    required this.foreground,
    required this.background,
    required this.palette,
    required this.cursor,
    required this.fontFamily,
    required this.fontSize,
  });

  @override
  int get hashCode => Object.hash(
    TerminalTheme,
    foreground,
    background,
    palette,
    cursor,
    fontFamily,
    fontSize,
  );

  @override
  bool operator ==(Object other) =>
      other is TerminalTheme &&
      other.foreground == foreground &&
      other.background == background &&
      other.palette == palette &&
      other.cursor == cursor &&
      other.fontFamily == fontFamily &&
      other.fontSize == fontSize;

  /// Returns a copy of this theme with the given fields replaced.
  TerminalTheme copyWith({
    Color? foreground,
    Color? background,
    List<Color>? ansiColors,
    CursorTheme? cursor,
    String? fontFamily,
    double? fontSize,
  }) {
    final newForeground = foreground ?? this.foreground;
    final newBackground = background ?? this.background;
    final regenerate =
        ansiColors != null ||
        newForeground != this.foreground ||
        newBackground != this.background;

    if (regenerate) {
      return TerminalTheme(
        foreground: newForeground,
        background: newBackground,
        ansiColors: ansiColors ?? List<Color>.generate(16, (i) => palette[i]),
        cursor: cursor ?? this.cursor,
        fontFamily: fontFamily ?? this.fontFamily,
        fontSize: fontSize ?? this.fontSize,
      );
    }

    return TerminalTheme._withPalette(
      palette: palette,
      foreground: newForeground,
      background: newBackground,
      cursor: cursor ?? this.cursor,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
    );
  }

  /// Resolves a [CellColor] from the core package to a Flutter [Color].
  ///
  /// When [isForeground] is true, [DefaultColor] resolves to [foreground];
  /// otherwise it resolves to [background].
  Color resolveColor(CellColor color, {required bool isForeground}) {
    return switch (color) {
      DefaultColor() => isForeground ? foreground : background,
      RgbColor(:final r, :final g, :final b) => Color.fromARGB(255, r, g, b),
      PaletteColor(:final index) => palette[index],
    };
  }

  @override
  String toString() =>
      'TerminalTheme(foreground: $foreground, '
      'background: $background, fontFamily: $fontFamily, fontSize: $fontSize)';
}
