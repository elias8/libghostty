import '../color.dart';
import '../enums/underline_style.dart';

/// A parsed SGR (Select Graphic Rendition) text attribute.
sealed class SgrAttribute {
  const SgrAttribute();
}

/// SGR 0: reset all attributes to default.
class SgrUnset extends SgrAttribute {
  const SgrUnset();
}

/// Unrecognized SGR parameter sequence.
class SgrUnknown extends SgrAttribute {
  final List<int> fullParams;
  final List<int> partialParams;

  const SgrUnknown(this.fullParams, this.partialParams);
}

/// SGR 1: bold or increased intensity.
class SgrBold extends SgrAttribute {
  const SgrBold();
}

/// SGR 22: normal intensity (neither bold nor faint).
class SgrResetBold extends SgrAttribute {
  const SgrResetBold();
}

/// SGR 3: italic.
class SgrItalic extends SgrAttribute {
  const SgrItalic();
}

/// SGR 23: not italic.
class SgrResetItalic extends SgrAttribute {
  const SgrResetItalic();
}

/// SGR 2: faint or decreased intensity.
class SgrFaint extends SgrAttribute {
  const SgrFaint();
}

/// SGR 4: underline with style variant.
class SgrUnderline extends SgrAttribute {
  final UnderlineStyle style;

  const SgrUnderline(this.style);
}

/// SGR 24: not underlined.
class SgrResetUnderline extends SgrAttribute {
  const SgrResetUnderline();
}

/// Underline color as direct RGB.
class SgrUnderlineRgb extends SgrAttribute {
  final RgbColor color;

  const SgrUnderlineRgb(this.color);
}

/// Underline color as 256-color palette index.
class SgrUnderline256 extends SgrAttribute {
  /// Palette index (0–255).
  final int index;

  const SgrUnderline256(this.index);
}

/// SGR 59: reset underline color to default.
class SgrResetUnderlineColor extends SgrAttribute {
  const SgrResetUnderlineColor();
}

/// SGR 53: overline.
class SgrOverline extends SgrAttribute {
  const SgrOverline();
}

/// SGR 55: not overlined.
class SgrResetOverline extends SgrAttribute {
  const SgrResetOverline();
}

/// SGR 5: slow blink.
class SgrBlink extends SgrAttribute {
  const SgrBlink();
}

/// SGR 25: not blinking.
class SgrResetBlink extends SgrAttribute {
  const SgrResetBlink();
}

/// SGR 7: inverse (swap foreground and background).
class SgrInverse extends SgrAttribute {
  const SgrInverse();
}

/// SGR 27: not inversed.
class SgrResetInverse extends SgrAttribute {
  const SgrResetInverse();
}

/// SGR 8: invisible (hidden text).
class SgrInvisible extends SgrAttribute {
  const SgrInvisible();
}

/// SGR 28: not invisible.
class SgrResetInvisible extends SgrAttribute {
  const SgrResetInvisible();
}

/// SGR 9: strikethrough.
class SgrStrikethrough extends SgrAttribute {
  const SgrStrikethrough();
}

/// SGR 29: not struck through.
class SgrResetStrikethrough extends SgrAttribute {
  const SgrResetStrikethrough();
}

/// SGR 38;2: direct RGB foreground color.
class SgrForegroundRgb extends SgrAttribute {
  final RgbColor color;

  const SgrForegroundRgb(this.color);
}

/// SGR 48;2: direct RGB background color.
class SgrBackgroundRgb extends SgrAttribute {
  final RgbColor color;

  const SgrBackgroundRgb(this.color);
}

/// SGR 30–37: standard 8-color foreground.
class SgrForeground8 extends SgrAttribute {
  /// Color palette index (see [NamedColor] constants).
  final int index;

  const SgrForeground8(this.index);
}

/// SGR 40–47: standard 8-color background.
class SgrBackground8 extends SgrAttribute {
  /// Color palette index (see [NamedColor] constants).
  final int index;

  const SgrBackground8(this.index);
}

/// SGR 39: default foreground color.
class SgrResetForeground extends SgrAttribute {
  const SgrResetForeground();
}

/// SGR 49: default background color.
class SgrResetBackground extends SgrAttribute {
  const SgrResetBackground();
}

/// SGR 90–97: bright 8-color foreground.
class SgrBrightForeground8 extends SgrAttribute {
  /// Color palette index (see [NamedColor] constants).
  final int index;

  const SgrBrightForeground8(this.index);
}

/// SGR 100–107: bright 8-color background.
class SgrBrightBackground8 extends SgrAttribute {
  /// Color palette index (see [NamedColor] constants).
  final int index;

  const SgrBrightBackground8(this.index);
}

/// SGR 38;5: 256-color foreground.
class SgrForeground256 extends SgrAttribute {
  /// Palette index (0–255).
  final int index;

  const SgrForeground256(this.index);
}

/// SGR 48;5: 256-color background.
class SgrBackground256 extends SgrAttribute {
  /// Palette index (0–255).
  final int index;

  const SgrBackground256(this.index);
}
