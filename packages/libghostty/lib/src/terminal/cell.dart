import 'package:meta/meta.dart';

import '../color.dart';
import '../enums/underline_style.dart' show UnderlineStyle;

/// An immutable snapshot of a single terminal cell.
@immutable
class Cell {
  static const empty = Cell();

  /// Unicode text content, or empty string for blank cells.
  final String content;
  final CellColor foreground;
  final CellColor background;
  final CellColor? underlineColor;
  final CellStyle style;

  /// OSC 8 hyperlink URI, if any.
  final String? hyperlink;

  /// True for characters that occupy two columns (e.g. CJK).
  final bool isWide;

  const Cell({
    this.content = '',
    this.foreground = const DefaultColor(),
    this.background = const DefaultColor(),
    this.underlineColor,
    this.style = const CellStyle(),
    this.hyperlink,
    this.isWide = false,
  });

  @override
  int get hashCode => Object.hash(
    content,
    foreground,
    background,
    underlineColor,
    style,
    hyperlink,
    isWide,
  );

  bool get isEmpty => content.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is Cell &&
      other.content == content &&
      other.foreground == foreground &&
      other.background == background &&
      other.underlineColor == underlineColor &&
      other.style == style &&
      other.hyperlink == hyperlink &&
      other.isWide == isWide;

  @override
  String toString() => 'Cell($content)';
}

/// Text style attributes for a terminal cell.
@immutable
class CellStyle {
  final bool bold;
  final bool italic;
  final bool faint;
  final bool strikethrough;
  final bool blink;
  final bool inverse;
  final bool invisible;
  final bool overline;
  final UnderlineStyle underline;

  const CellStyle({
    this.bold = false,
    this.italic = false,
    this.faint = false,
    this.strikethrough = false,
    this.blink = false,
    this.inverse = false,
    this.invisible = false,
    this.overline = false,
    this.underline = UnderlineStyle.none,
  });

  @override
  int get hashCode => Object.hash(
    bold,
    italic,
    faint,
    strikethrough,
    blink,
    inverse,
    invisible,
    overline,
    underline,
  );

  @override
  bool operator ==(Object other) =>
      other is CellStyle &&
      other.bold == bold &&
      other.italic == italic &&
      other.faint == faint &&
      other.strikethrough == strikethrough &&
      other.blink == blink &&
      other.inverse == inverse &&
      other.invisible == invisible &&
      other.overline == overline &&
      other.underline == underline;

  CellStyle copyWith({
    bool? bold,
    bool? italic,
    bool? faint,
    bool? strikethrough,
    bool? blink,
    bool? inverse,
    bool? invisible,
    bool? overline,
    UnderlineStyle? underline,
  }) {
    return CellStyle(
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      faint: faint ?? this.faint,
      strikethrough: strikethrough ?? this.strikethrough,
      blink: blink ?? this.blink,
      inverse: inverse ?? this.inverse,
      invisible: invisible ?? this.invisible,
      overline: overline ?? this.overline,
      underline: underline ?? this.underline,
    );
  }

  @override
  String toString() {
    final flags = <String>[];
    if (bold) flags.add('bold');
    if (italic) flags.add('italic');
    if (faint) flags.add('faint');
    if (strikethrough) flags.add('strikethrough');
    if (blink) flags.add('blink');
    if (inverse) flags.add('inverse');
    if (invisible) flags.add('invisible');
    if (overline) flags.add('overline');
    if (underline != UnderlineStyle.none) flags.add('underline: $underline');
    return 'CellStyle(${flags.join(', ')})';
  }
}
