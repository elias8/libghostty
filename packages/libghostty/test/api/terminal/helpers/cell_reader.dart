import 'package:libghostty/libghostty.dart';

class CellSnapshot {
  final String content;
  final bool hasText;
  final CellWide wide;
  final Style style;
  final CellColor foreground;
  final CellColor background;
  final SgrUnderline underlineStyle;
  final bool hasHyperlink;

  const CellSnapshot({
    this.content = '',
    this.hasText = false,
    this.wide = CellWide.narrow,
    this.style = const Style(),
    this.foreground = const DefaultColor(),
    this.background = const DefaultColor(),
    this.underlineStyle = SgrUnderline.none,
    this.hasHyperlink = false,
  });

  bool get isEmpty => !hasText;
}

CellSnapshot readCellAt(Terminal terminal, int row, int col) {
  final rs = RenderState();
  final rows = RowIterator();
  final cells = CellIterator();
  try {
    rs.update(terminal);
    rows.reset(rs);
    while (rows.next()) {
      if (rows.index != row) continue;
      cells.reset(rows);
      while (cells.next()) {
        if (cells.col != col) continue;
        return CellSnapshot(
          content: cells.content,
          hasText: cells.hasText,
          wide: cells.wide,
          style: cells.style,
          foreground: cells.style.foreground,
          background: cells.style.background,
          underlineStyle: cells.style.underline,
          hasHyperlink: cells.hasHyperlink,
        );
      }
    }
    return const CellSnapshot();
  } finally {
    cells.dispose();
    rows.dispose();
    rs.dispose();
  }
}

/// Queries the dirty flag for [row] from an already-updated [renderState].
///
/// Takes a [RenderState] (instead of allocating a fresh one) because the
/// first [RenderState.update] on a freshly allocated render state marks
/// every row dirty unconditionally; using the caller's render state keeps
/// the flag consistent with whatever per-row clearing the caller has done.
bool isRowDirty(RenderState renderState, int row) {
  final rows = RowIterator();
  try {
    rows.reset(renderState);
    while (rows.next()) {
      if (rows.index == row) return rows.dirty;
    }
    return false;
  } finally {
    rows.dispose();
  }
}

bool isRowWrapped(Terminal terminal, int row) {
  final rs = RenderState();
  final rows = RowIterator();
  try {
    rs.update(terminal);
    rows.reset(rs);
    while (rows.next()) {
      if (rows.index == row) return rows.wrap;
    }
    return false;
  } finally {
    rows.dispose();
    rs.dispose();
  }
}

String readRowText(Terminal terminal, int row) {
  final rs = RenderState();
  final rows = RowIterator();
  final cells = CellIterator();
  try {
    rs.update(terminal);
    rows.reset(rs);
    while (rows.next()) {
      if (rows.index != row) continue;
      final buffer = StringBuffer();
      cells.reset(rows);
      while (cells.next()) {
        buffer.write(cells.content);
      }
      return buffer.toString();
    }
    return '';
  } finally {
    cells.dispose();
    rows.dispose();
    rs.dispose();
  }
}
