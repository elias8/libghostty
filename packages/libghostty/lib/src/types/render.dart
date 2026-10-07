import 'package:meta/meta.dart';

import '../generated/libghostty_enums.g.dart';
import 'aliases.dart';
import 'color.dart';

/// Number of extra rows requested or captured above and below the viewport.
@immutable
final class RenderOverscan {
  /// Rows above the top of the viewport.
  final int above;

  /// Rows below the bottom of the viewport.
  final int below;

  const RenderOverscan({required this.above, required this.below});

  @override
  int get hashCode => Object.hash(above, below);

  @override
  bool operator ==(Object other) =>
      other is RenderOverscan && other.above == above && other.below == below;

  @override
  String toString() => 'RenderOverscan(above: $above, below: $below)';
}

/// Opaque identity for a row across render-state updates.
///
/// Compare values for equality or use them as map keys. The words have no
/// meaning outside equality and preserve the complete upstream 128-bit id.
@immutable
final class RenderRowId {
  /// First opaque word of the row id.
  final BigInt word0;

  /// Second opaque word of the row id.
  final BigInt word1;

  /// Creates an opaque row id from its two unsigned 64-bit words.
  const RenderRowId({required this.word0, required this.word1});

  @override
  int get hashCode => Object.hash(word0, word1);

  @override
  bool operator ==(Object other) =>
      other is RenderRowId && other.word0 == word0 && other.word1 == word1;

  @override
  String toString() => 'RenderRowId($word0, $word1)';
}

/// Immutable cursor state from a render-state snapshot.
///
/// When [viewportHasValue] is false, [viewportX], [viewportY], and [wideTail]
/// contain placeholder values and must not be used.
@immutable
final class RenderStateCursor {
  /// Whether the cursor has a position in the visible viewport.
  final bool viewportHasValue;

  /// Column within the viewport.
  final int viewportX;

  /// Row within the viewport.
  final int viewportY;

  /// Whether the cursor is on the tail of a wide character.
  final bool wideTail;

  /// Whether terminal modes make the cursor visible.
  final bool visible;

  /// Whether terminal modes make the cursor blink.
  final bool blinking;

  /// Whether the cursor is at a password input field.
  final bool passwordInput;

  /// Visual style of the cursor.
  final CursorShape visualStyle;

  /// Creates an immutable cursor state.
  ///
  /// [viewportX], [viewportY], and [wideTail] are meaningful only when
  /// [viewportHasValue] is true.
  const RenderStateCursor({
    this.viewportHasValue = false,
    this.viewportX = 0,
    this.viewportY = 0,
    this.wideTail = false,
    this.visible = true,
    this.blinking = false,
    this.passwordInput = false,
    this.visualStyle = .block,
  });

  @override
  int get hashCode => Object.hash(
    viewportHasValue,
    viewportX,
    viewportY,
    wideTail,
    visible,
    blinking,
    passwordInput,
    visualStyle,
  );

  @override
  bool operator ==(Object other) =>
      other is RenderStateCursor &&
      other.viewportHasValue == viewportHasValue &&
      other.viewportX == viewportX &&
      other.viewportY == viewportY &&
      other.wideTail == wideTail &&
      other.visible == visible &&
      other.blinking == blinking &&
      other.passwordInput == passwordInput &&
      other.visualStyle == visualStyle;

  /// Returns a copy with the given fields replaced.
  RenderStateCursor copyWith({
    bool? viewportHasValue,
    int? viewportX,
    int? viewportY,
    bool? wideTail,
    bool? visible,
    bool? blinking,
    bool? passwordInput,
    CursorShape? visualStyle,
  }) {
    return RenderStateCursor(
      viewportHasValue: viewportHasValue ?? this.viewportHasValue,
      viewportX: viewportX ?? this.viewportX,
      viewportY: viewportY ?? this.viewportY,
      wideTail: wideTail ?? this.wideTail,
      visible: visible ?? this.visible,
      blinking: blinking ?? this.blinking,
      passwordInput: passwordInput ?? this.passwordInput,
      visualStyle: visualStyle ?? this.visualStyle,
    );
  }

  @override
  String toString() =>
      'RenderStateCursor(viewportHasValue: $viewportHasValue, '
      'viewportX: $viewportX, viewportY: $viewportY, visible: $visible, '
      'visualStyle: $visualStyle)';
}

/// A parsed SGR (Select Graphic Rendition) attribute.
///
/// Switch on [tag] to determine the attribute type, then access the
/// relevant field ([color], [paletteIndex], [underlineStyle]).
/// Attributes without data (e.g. bold, italic) are identified by [tag]
/// alone.
///
/// ```dart
/// for (final attr in parser.parse([1, 38, 2, 255, 0, 0])) {
///   switch (attr.tag) {
///     case .directColorFg:
///       print('fg: ${attr.color}');
///     case .bold:
///       print('bold');
///     default:
///       break;
///   }
/// }
/// ```
@immutable
final class SgrAttribute {
  /// The attribute type.
  final SgrAttributeTag tag;

  /// RGB color for direct color attributes ([SgrAttributeTag.directColorFg],
  /// [SgrAttributeTag.directColorBg], [SgrAttributeTag.underlineColor]).
  /// Null for non-color attributes.
  final RgbColor? color;

  /// Palette index for indexed color attributes ([SgrAttributeTag.fg8],
  /// [SgrAttributeTag.bg8], [SgrAttributeTag.fg256],
  /// [SgrAttributeTag.bg256], etc.). Zero for non-indexed attributes.
  final int paletteIndex;

  /// Full SGR parameter list when [tag] is [SgrAttributeTag.unknown].
  /// Empty for recognized attributes.
  final List<int> unknownFull;

  /// Partial parameter list where parsing stopped when [tag] is
  /// [SgrAttributeTag.unknown]. Empty for recognized attributes.
  final List<int> unknownPartial;

  /// Underline style when [tag] is [SgrAttributeTag.underline].
  /// [UnderlineStyle.none] for other attributes.
  final SgrUnderline underlineStyle;

  const SgrAttribute({
    required this.tag,
    this.color,
    this.paletteIndex = 0,
    this.unknownFull = const [],
    this.unknownPartial = const [],
    this.underlineStyle = SgrUnderline.none,
  });
}

/// SGR style applied to a terminal cell.
///
/// Combines text attributes (bold, italic, etc.), foreground/background
/// colors, and underline style/color. All attributes default to off,
/// colors default to [DefaultColor], and underline defaults to
/// [UnderlineStyle.none].
@immutable
final class Style {
  /// Whether bold (SGR 1) is active.
  final bool bold;

  /// Whether italic (SGR 3) is active.
  final bool italic;

  /// Whether faint/dim (SGR 2) is active.
  final bool faint;

  /// Whether blink (SGR 5/6) is active.
  final bool blink;

  /// Whether inverse/reverse video (SGR 7) is active.
  final bool inverse;

  /// Whether invisible (SGR 8) is active.
  final bool invisible;

  /// Whether overline (SGR 53) is active.
  final bool overline;

  /// Whether strikethrough (SGR 9) is active.
  final bool strikethrough;

  /// Foreground color. [DefaultColor] when no color is explicitly set.
  final CellColor foreground;

  /// Background color. [DefaultColor] when no color is explicitly set.
  final CellColor background;

  /// Underline style: none, single, double, curly, dotted, or dashed.
  final SgrUnderline underline;

  /// Underline color, or null when using the foreground color.
  final CellColor? underlineColor;

  const Style({
    this.bold = false,
    this.italic = false,
    this.faint = false,
    this.blink = false,
    this.inverse = false,
    this.invisible = false,
    this.overline = false,
    this.strikethrough = false,
    this.foreground = const DefaultColor(),
    this.background = const DefaultColor(),
    this.underline = SgrUnderline.none,
    this.underlineColor,
  });

  @override
  int get hashCode => Object.hash(
    bold,
    italic,
    faint,
    blink,
    inverse,
    invisible,
    overline,
    strikethrough,
    foreground,
    background,
    underline,
    underlineColor,
  );

  @override
  bool operator ==(Object other) =>
      other is Style &&
      other.bold == bold &&
      other.italic == italic &&
      other.faint == faint &&
      other.blink == blink &&
      other.inverse == inverse &&
      other.invisible == invisible &&
      other.overline == overline &&
      other.strikethrough == strikethrough &&
      other.foreground == foreground &&
      other.background == background &&
      other.underline == underline &&
      other.underlineColor == underlineColor;
}

/// Resolved terminal colors from the render state.
///
/// Contains the effective foreground, background, cursor color, and the
/// full 256-color palette after applying any OSC overrides.
@immutable
final class TerminalColors {
  /// Cursor color, or null if no explicit cursor color is set. When null, the
  /// renderer should choose its own cursor color.
  final RgbColor? cursor;

  /// Effective foreground color.
  final RgbColor foreground;

  /// Effective background color.
  final RgbColor background;

  /// The active 256-color palette with OSC 4 overrides applied.
  final List<RgbColor> palette;

  const TerminalColors({
    this.cursor,
    required this.foreground,
    required this.background,
    required this.palette,
  });
}
