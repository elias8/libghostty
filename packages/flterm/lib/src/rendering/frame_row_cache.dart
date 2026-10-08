part of 'frame_builder.dart';

final class _DecodedCell {
  final int codepoint;
  final int graphemeLength;
  final String? content;
  final CellWidth wide;
  final int styleId;
  final Style style;
  final int? backgroundArgb;
  final bool hasText;
  final bool hasStyling;

  const _DecodedCell({
    required this.codepoint,
    required this.graphemeLength,
    required this.content,
    required this.wide,
    required this.styleId,
    required this.style,
    required this.backgroundArgb,
    required this.hasText,
    required this.hasStyling,
  });

  const _DecodedCell.empty()
    : codepoint = 0,
      graphemeLength = 0,
      content = null,
      wide = CellWidth.narrow,
      styleId = 0,
      style = const Style(),
      backgroundArgb = null,
      hasText = false,
      hasStyling = false;
}

final class _DecodedRow {
  final List<_DecodedCell> cells;

  const _DecodedRow(this.cells);
}
