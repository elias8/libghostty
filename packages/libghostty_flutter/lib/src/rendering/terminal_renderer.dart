import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:libghostty/libghostty.dart';

import '../../foundation.dart';
import 'cell_style_key.dart';
import 'color_run.dart';
import 'selection.dart';

/// Per row data built during the update phase and consumed by paint.
///
/// All four lists share the same length and are always resized, invalidated,
/// and queried together.
class _RowCaches {
  List<bool> dirty;
  List<Line> lines;
  List<List<ColorRun>> bgRuns;
  List<ui.Paragraph?> paragraphs;

  _RowCaches()
    : dirty = const [],
      lines = const [],
      bgRuns = const [],
      paragraphs = const [];

  void detectDirtyFrom(Screen screen, int rows) {
    final limit = rows < screen.rows ? rows : screen.rows;
    for (var row = 0; row < limit; row++) {
      final newLine = screen.lineAt(row);
      if (newLine != lines[row]) {
        dirty[row] = true;
        lines[row] = newLine;
      }
    }
  }

  void dispose() {
    for (final paragraph in paragraphs) {
      paragraph?.dispose();
    }
  }

  void markAllDirty() => dirty.fillRange(0, dirty.length, true);

  void markBlinkingRowsDirty(int rows) {
    for (var row = 0; row < rows; row++) {
      for (final cell in lines[row].cells) {
        if (cell.style.blink) {
          dirty[row] = true;
          break;
        }
      }
    }
  }

  void resize(int rows) {
    dispose();
    paragraphs = List<ui.Paragraph?>.filled(rows, null);
    bgRuns = List<List<ColorRun>>.generate(rows, (_) => []);
    dirty = List<bool>.filled(rows, true);
    lines = List<Line>.generate(rows, (_) => const Line([]));
  }
}

/// Renders a terminal screen with full visual fidelity.
///
/// Paints cell backgrounds, styled text, cursors, and selection overlays
/// using a two-phase update/paint pipeline.
///
/// ```dart
/// TerminalRenderer(
///   terminal: myTerminal,
///   theme: TerminalTheme.defaults,
///   metrics: CellMetrics.measure(fontFamily: 'monospace', fontSize: 14),
/// )
/// ```
class TerminalRenderer extends LeafRenderObjectWidget {
  /// The terminal whose screen is rendered.
  final Terminal terminal;

  /// Visual style: colors, cursor, font.
  final TerminalTheme theme;

  /// Cell pixel dimensions.
  final CellMetrics metrics;

  /// Optional selected cell range painted as a semi-transparent overlay.
  final TerminalSelection? selection;

  const TerminalRenderer({
    super.key,
    required this.terminal,
    required this.theme,
    required this.metrics,
    this.selection,
  });

  @override
  TerminalRenderBox createRenderObject(BuildContext context) {
    return TerminalRenderBox(
      terminal: terminal,
      theme: theme,
      metrics: metrics,
      selection: selection,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<Terminal>('terminal', terminal))
      ..add(DiagnosticsProperty<TerminalTheme>('theme', theme))
      ..add(DiagnosticsProperty<CellMetrics>('metrics', metrics))
      ..add(DiagnosticsProperty<TerminalSelection?>('selection', selection));
  }

  @override
  void updateRenderObject(
    BuildContext context,
    TerminalRenderBox renderObject,
  ) {
    renderObject
      ..terminal = terminal
      ..theme = theme
      ..metrics = metrics
      ..selection = selection;
  }
}

class TerminalRenderBox extends RenderBox {
  TerminalRenderBox({
    required Terminal terminal,
    required TerminalTheme theme,
    required CellMetrics metrics,
    TerminalSelection? selection,
  }) : _terminal = terminal,
       _theme = theme,
       _metrics = metrics,
       _selection = selection {
    _backgroundPaint.color = theme.background;
    _selectionPaint
      ..color = const Color(0x3D7AA2F7)
      ..style = PaintingStyle.fill;
  }

  Terminal get terminal => _terminal;

  set terminal(Terminal value) {
    if (_terminal == value) return;
    _screenSub?.cancel().ignore();
    _cursorSub?.cancel().ignore();
    _terminal = value;
    _setupSubscriptions();
    _cache.markAllDirty();
    markNeedsLayout();
  }

  TerminalTheme get theme => _theme;

  set theme(TerminalTheme value) {
    if (_theme == value) return;
    final oldBlinkInterval = _theme.cursor.blinkInterval;
    _theme = value;
    _styleCache.clear();
    _backgroundPaint.color = value.background;
    _cache.markAllDirty();
    if (value.cursor.blinkInterval != oldBlinkInterval) {
      _setupBlinkTimer();
    }
    markNeedsLayout();
  }

  CellMetrics get metrics => _metrics;

  set metrics(CellMetrics value) {
    if (_metrics == value) return;
    _metrics = value;
    _cache.markAllDirty();
    markNeedsLayout();
  }

  TerminalSelection? get selection => _selection;

  set selection(TerminalSelection? value) {
    if (_selection == value) return;
    _selection = value;
    markNeedsPaint();
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  bool get sizedByParent => false;

  @override
  bool hitTestSelf(Offset position) => true;

  Terminal _terminal;
  TerminalTheme _theme;
  CellMetrics _metrics;
  TerminalSelection? _selection;

  var _cols = 0;
  var _rows = 0;

  final _cache = _RowCaches();
  final Map<CellStyleKey, TextStyle> _styleCache = {};

  Timer? _blinkTimer;
  var _blinkVisible = true;

  final _backgroundPaint = Paint()..style = PaintingStyle.fill;
  final _bgRunPaint = Paint()..style = PaintingStyle.fill;
  final _cursorPaint = Paint();
  final _selectionPaint = Paint();

  StreamSubscription<void>? _screenSub;
  StreamSubscription<Cursor>? _cursorSub;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _setupSubscriptions();
    _setupBlinkTimer();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IntProperty('cols', _cols))
      ..add(IntProperty('rows', _rows))
      ..add(DiagnosticsProperty<TerminalTheme>('theme', _theme))
      ..add(DiagnosticsProperty<CellMetrics>('metrics', _metrics))
      ..add(DiagnosticsProperty<TerminalSelection?>('selection', _selection))
      ..add(
        FlagProperty(
          'blinkVisible',
          value: _blinkVisible,
          ifTrue: 'cursor visible',
        ),
      );
  }

  @override
  void detach() {
    _screenSub?.cancel().ignore();
    _cursorSub?.cancel().ignore();
    _blinkTimer?.cancel();
    _cache.dispose();
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;

    canvas.drawRect(offset & size, _backgroundPaint);
    _paintCellBackgrounds(canvas, offset);

    final cursor = _terminal.cursor;

    // Block cursor paints before text so glyphs render on top.
    if (_shouldDrawCursor(cursor) && cursor.shape == CursorShape.block) {
      _paintBlockCursor(canvas, offset, cursor);
    }

    for (var row = 0; row < _rows; row++) {
      final paragraph = _cache.paragraphs[row];
      if (paragraph != null) {
        canvas.drawParagraph(
          paragraph,
          Offset(offset.dx, offset.dy + row * _metrics.cellHeight),
        );
      }
    }

    // Non-block cursors paint after text so they overlay.
    if (_shouldDrawCursor(cursor) && cursor.shape != CursorShape.block) {
      _paintNonBlockCursor(canvas, offset, cursor);
    }

    if (_selection != null) _paintSelection(canvas, offset);
  }

  @override
  void performLayout() {
    final maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
    final maxH = constraints.maxHeight.isFinite ? constraints.maxHeight : 0.0;
    final newCols = _metrics.cellWidth > 0
        ? (maxW / _metrics.cellWidth).floor()
        : 0;
    final newRows = _metrics.cellHeight > 0
        ? (maxH / _metrics.cellHeight).floor()
        : 0;

    size = constraints.constrain(
      Size(newCols * _metrics.cellWidth, newRows * _metrics.cellHeight),
    );

    if (newCols != _cols || newRows != _rows) {
      _cols = newCols;
      _rows = newRows;
      _cache.resize(_rows);
    }

    if (_rows > 0) _rebuildDirtyRows();
  }

  void _onTerminalChanged() {
    if (_rows == 0) return;
    _cache.detectDirtyFrom(_terminal.screen, _rows);
    _rebuildDirtyRows();
    markNeedsPaint();
  }

  void _rebuildDirtyRows() {
    final screen = _terminal.screen;
    for (var row = 0; row < _rows; row++) {
      if (!_cache.dirty[row]) continue;
      _rebuildRow(row, screen);
      _cache.dirty[row] = false;
    }
  }

  void _rebuildRow(int row, Screen screen) {
    _cache.paragraphs[row]?.dispose();
    final bgRunList = _cache.bgRuns[row]..clear();
    final rowWidth = _cols * _metrics.cellWidth;

    final paragraphStyle = ui.ParagraphStyle(
      fontFamily: _theme.fontFamily,
      fontSize: _theme.fontSize,
    );
    final builder = ui.ParagraphBuilder(paragraphStyle);

    final termBg = _theme.background;
    var bgRunStart = 0;
    var bgRunColor = termBg;
    var bgRunStarted = false;

    final screenRows = screen.rows;
    final screenCols = screen.cols;

    for (var col = 0; col < _cols; col++) {
      final cell = row < screenRows && col < screenCols
          ? screen.cellAt(row, col)
          : Cell.empty;
      final (foreground, background) = _resolveColors(cell);

      if (!bgRunStarted) {
        bgRunColor = background;
        bgRunStart = col;
        bgRunStarted = true;
      } else if (background != bgRunColor) {
        if (bgRunColor != termBg) {
          bgRunList.add(ColorRun(bgRunStart, col, bgRunColor));
        }
        bgRunColor = background;
        bgRunStart = col;
      }

      final content = cell.content;
      final isEmpty = content.isEmpty;

      if (!isEmpty) {
        final text = _cellText(cell);
        final style = _resolveTextStyle(cell, foreground, background);
        builder.pushStyle(style.getTextStyle());
        builder.addText(text);
        builder.pop();
        if (cell.isWide) {
          col++;
          if (bgRunColor != termBg) {
            bgRunList.add(ColorRun(bgRunStart, col + 1, bgRunColor));
          }
          bgRunStart = col + 1;
          bgRunColor = termBg;
          bgRunStarted = col + 1 < _cols;
        }
      } else {
        final style = _resolveTextStyle(cell, foreground, background);
        builder.pushStyle(style.getTextStyle());
        builder.addText(' ');
        builder.pop();
      }
    }

    if (bgRunStarted && bgRunColor != termBg) {
      bgRunList.add(ColorRun(bgRunStart, _cols, bgRunColor));
    }

    _cache.paragraphs[row] = builder.build()
      ..layout(ui.ParagraphConstraints(width: rowWidth));
  }

  (Color, Color) _resolveColors(Cell cell) {
    var fg = _theme.resolveColor(cell.foreground, isForeground: true);
    var bg = _theme.resolveColor(cell.background, isForeground: false);
    if (cell.style.inverse) {
      final tmp = fg;
      fg = bg;
      bg = tmp;
    }
    if (cell.style.faint) {
      fg = fg.withValues(alpha: fg.a * 0.5);
    }
    return (fg, bg);
  }

  TextStyle _resolveTextStyle(Cell cell, Color fg, Color bg) {
    final underlineColor = cell.underlineColor != null
        ? _theme.resolveColor(cell.underlineColor!, isForeground: true)
        : null;

    final key = CellStyleKey(
      bold: cell.style.bold,
      italic: cell.style.italic,
      faint: cell.style.faint,
      strikethrough: cell.style.strikethrough,
      overline: cell.style.overline,
      foreground: fg,
      underline: cell.style.underline,
      underlineColor: underlineColor,
    );

    return _styleCache.putIfAbsent(
      key,
      () => key.buildTextStyle(_theme.fontFamily, _theme.fontSize),
    );
  }

  String _cellText(Cell cell) {
    if (cell.content.isEmpty) return ' ';
    if (cell.style.invisible) return ' ';
    if (cell.style.blink && !_blinkVisible) return ' ';
    return cell.content;
  }

  void _paintCellBackgrounds(Canvas canvas, Offset offset) {
    for (var row = 0; row < _rows; row++) {
      for (final run in _cache.bgRuns[row]) {
        _bgRunPaint.color = run.color;
        canvas.drawRect(
          Rect.fromLTWH(
            offset.dx + run.startCol * _metrics.cellWidth,
            offset.dy + row * _metrics.cellHeight,
            (run.endCol - run.startCol) * _metrics.cellWidth,
            _metrics.cellHeight,
          ),
          _bgRunPaint,
        );
      }
    }
  }

  bool _shouldDrawCursor(Cursor cursor) {
    return cursor.visible &&
        cursor.row >= 0 &&
        cursor.row < _rows &&
        cursor.col >= 0 &&
        cursor.col < _cols &&
        _blinkVisible;
  }

  Rect _cursorCellRect(Offset offset, Cursor cursor) {
    return Rect.fromLTWH(
      offset.dx + cursor.col * _metrics.cellWidth,
      offset.dy + cursor.row * _metrics.cellHeight,
      _metrics.cellWidth,
      _metrics.cellHeight,
    );
  }

  Color _cursorColor(Cursor cursor) {
    if (_theme.cursor.color != null) return _theme.cursor.color!;
    final cell = _terminal.screen.cellAt(cursor.row, cursor.col);
    return _theme.resolveColor(cell.foreground, isForeground: true);
  }

  void _paintBlockCursor(Canvas canvas, Offset offset, Cursor cursor) {
    _cursorPaint
      ..style = PaintingStyle.fill
      ..color = _cursorColor(cursor);
    canvas.drawRect(_cursorCellRect(offset, cursor), _cursorPaint);
  }

  void _paintNonBlockCursor(Canvas canvas, Offset offset, Cursor cursor) {
    final rect = _cursorCellRect(offset, cursor);
    _cursorPaint.color = _cursorColor(cursor);

    switch (cursor.shape) {
      case CursorShape.blockHollow:
        _cursorPaint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawRect(rect, _cursorPaint);

      case CursorShape.underline:
        _cursorPaint.style = PaintingStyle.fill;
        final thickness = (_metrics.cellHeight / 8).clamp(1.0, 3.0);
        canvas.drawRect(
          Rect.fromLTWH(
            rect.left,
            rect.bottom - thickness,
            rect.width,
            thickness,
          ),
          _cursorPaint,
        );

      case CursorShape.bar:
        _cursorPaint.style = PaintingStyle.fill;
        final thickness = (_metrics.cellWidth / 6).clamp(1.0, 3.0);
        canvas.drawRect(
          Rect.fromLTWH(rect.left, rect.top, thickness, rect.height),
          _cursorPaint,
        );

      case CursorShape.block:
        // Painted before text via _paintBlockCursor.
        break;
    }
  }

  void _paintSelection(Canvas canvas, Offset offset) {
    final selection = _selection!;
    final topRow = selection.topRow.clamp(0, _rows - 1);
    final botRow = selection.botRow.clamp(0, _rows - 1);
    final topCol = selection.topCol.clamp(0, _cols);
    final botCol = selection.botCol.clamp(0, _cols);
    final cellWidth = _metrics.cellWidth;
    final cellHeight = _metrics.cellHeight;

    if (selection.mode == SelectionMode.block) {
      if (topCol >= botCol) return;
      canvas.drawRect(
        Rect.fromLTWH(
          offset.dx + topCol * cellWidth,
          offset.dy + topRow * cellHeight,
          (botCol - topCol) * cellWidth,
          (botRow - topRow + 1) * cellHeight,
        ),
        _selectionPaint,
      );
      return;
    }

    if (topRow == botRow) {
      if (topCol >= botCol) return;
      canvas.drawRect(
        Rect.fromLTWH(
          offset.dx + topCol * cellWidth,
          offset.dy + topRow * cellHeight,
          (botCol - topCol) * cellWidth,
          cellHeight,
        ),
        _selectionPaint,
      );
      return;
    }

    if (topCol < _cols) {
      canvas.drawRect(
        Rect.fromLTWH(
          offset.dx + topCol * cellWidth,
          offset.dy + topRow * cellHeight,
          (_cols - topCol) * cellWidth,
          cellHeight,
        ),
        _selectionPaint,
      );
    }

    if (botRow - topRow > 1) {
      canvas.drawRect(
        Rect.fromLTWH(
          offset.dx,
          offset.dy + (topRow + 1) * cellHeight,
          _cols * cellWidth,
          (botRow - topRow - 1) * cellHeight,
        ),
        _selectionPaint,
      );
    }

    if (botCol > 0) {
      canvas.drawRect(
        Rect.fromLTWH(
          offset.dx,
          offset.dy + botRow * cellHeight,
          botCol * cellWidth,
          cellHeight,
        ),
        _selectionPaint,
      );
    }
  }

  void _setupSubscriptions() {
    _screenSub = _terminal.onScreenChanged.listen((_) => _onTerminalChanged());
    _cursorSub = _terminal.onCursorChanged.listen((_) => markNeedsPaint());
  }

  void _setupBlinkTimer() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer.periodic(_theme.cursor.blinkInterval, (_) {
      _blinkVisible = !_blinkVisible;
      _cache.markBlinkingRowsDirty(_rows);
      if (_rows > 0) _rebuildDirtyRows();
      markNeedsPaint();
    });
  }
}
