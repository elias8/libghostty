part of 'frame_builder.dart';

final class _DecodedRow {
  static const _text = 4;
  static const _styled = 8;
  static const _background = 16;

  final Uint32List codepoints;
  final Uint16List styleIds;
  final Uint32List backgrounds;
  final Uint8List flags;
  final Map<int, Style> styles = {};
  final Map<int, (int length, String text)> graphemes = {};

  _DecodedRow(int columns)
    : codepoints = Uint32List(columns),
      styleIds = Uint16List(columns),
      backgrounds = Uint32List(columns),
      flags = Uint8List(columns);

  void refresh(CellIterator cells) {
    codepoints.fillRange(0, codepoints.length, 0);
    styleIds.fillRange(0, styleIds.length, 0);
    flags.fillRange(0, flags.length, 0);
    styles.clear();
    graphemes.clear();
    while (cells.next() && cells.col < codepoints.length) {
      final col = cells.col;
      final length = cells.graphemeLength;
      final styleId = cells.styleId;
      final hasText = length > 0;
      final hasStyling = cells.hasStyling;
      final background = hasText ? null : cells.backgroundArgb;
      codepoints[col] = cells.codepoint;
      styleIds[col] = styleId;
      flags[col] =
          cells.wide.index |
          (hasText ? _text : 0) |
          (hasStyling ? _styled : 0) |
          (background != null ? _background : 0);
      if (background != null) backgrounds[col] = background;
      if (styleId != 0 && !styles.containsKey(styleId)) {
        styles[styleId] = cells.style;
      }
      if (length > 1) graphemes[col] = (length, cells.content);
    }
  }

  bool hasText(int col) => flags[col] & _text != 0;
  bool hasStyling(int col) => flags[col] & _styled != 0;
  CellWidth width(int col) => CellWidth.values[flags[col] & 3];
  int? background(int col) =>
      flags[col] & _background != 0 ? backgrounds[col] : null;
  Style style(int col) => styles[styleIds[col]] ?? const Style();
  int graphemeLength(int col) => graphemes[col]?.$1 ?? (hasText(col) ? 1 : 0);
}
