@Tags(['ffi'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart';
import 'package:libghostty_flutter/foundation.dart';
import 'package:libghostty_flutter/rendering.dart';
import 'package:libghostty_flutter/src/rendering/terminal_renderer.dart';

void main() {
  group('TerminalRenderBox layout', () {
    late Terminal terminal;

    setUp(() => terminal = Terminal(cols: _cols, rows: _rows));
    tearDown(() => terminal.dispose());

    testWidgets('snaps width to whole-cell multiples', (tester) async {
      await tester.pumpWidget(
        _wrap(
          terminal,
          maxWidth: 163.7,
          maxHeight: _rows * _metrics.cellHeight,
        ),
      );
      final box = tester.renderObject<TerminalRenderBox>(
        find.byType(TerminalRenderer),
      );
      expect(box.size.width, 160.0);
    });

    testWidgets('snaps height to whole-cell multiples', (tester) async {
      await tester.pumpWidget(
        _wrap(terminal, maxWidth: _cols * _metrics.cellWidth, maxHeight: 85.3),
      );
      final box = tester.renderObject<TerminalRenderBox>(
        find.byType(TerminalRenderer),
      );
      expect(box.size.height, 80.0);
    });

    testWidgets('metrics change triggers layout', (tester) async {
      await tester.pumpWidget(_wrap(terminal));
      final box = tester.renderObject<TerminalRenderBox>(
        find.byType(TerminalRenderer),
      );
      final sizeBefore = box.size;

      await tester.pumpWidget(_wrap(terminal, metrics: _altMetrics));
      expect(box.size, isNot(equals(sizeBefore)));
    });

    testWidgets('selection change does not trigger layout', (tester) async {
      await tester.pumpWidget(_wrap(terminal));
      final box = tester.renderObject<TerminalRenderBox>(
        find.byType(TerminalRenderer),
      );
      final sizeBefore = box.size;

      await tester.pumpWidget(
        _wrap(
          terminal,
          selection: const TerminalSelection(
            startRow: 0,
            startCol: 0,
            endRow: 0,
            endCol: 5,
          ),
        ),
      );
      expect(box.size, equals(sizeBefore));
    });
  });

  group('TerminalRenderer goldens', () {
    late Terminal terminal;

    setUp(() => terminal = Terminal(cols: _cols, rows: _rows));
    tearDown(() => terminal.dispose());

    void write(String s) => terminal.write(.fromList(utf8.encode(s)));

    Future<void> pump(
      WidgetTester tester, {
      TerminalTheme? theme,
      TerminalSelection? selection,
    }) async {
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        _wrap(terminal, theme: theme, selection: selection),
      );
    }

    testWidgets('basic text', (tester) async {
      write('Hello, World!');
      await pump(tester);
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/text_basic.png'),
      );
    });

    testWidgets('bold text', (tester) async {
      write('\x1b[1mBold text\x1b[0m');
      await pump(tester);
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/text_bold.png'),
      );
    });

    testWidgets('italic text', (tester) async {
      write('\x1b[3mItalic text\x1b[0m');
      await pump(tester);
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/text_italic.png'),
      );
    });

    testWidgets('faint text', (tester) async {
      write('\x1b[2mFaint text\x1b[0m');
      await pump(tester);
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/text_faint.png'),
      );
    });

    testWidgets('inverse text', (tester) async {
      write('\x1b[7mInverse text\x1b[0m');
      await pump(tester);
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/text_inverse.png'),
      );
    });

    testWidgets('single underline', (tester) async {
      write('\x1b[4mUnderline\x1b[0m');
      await pump(tester);
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/text_underline_single.png'),
      );
    });

    testWidgets('double underline', (tester) async {
      write('\x1b[4:2mDouble\x1b[0m');
      await pump(tester);
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/text_underline_double.png'),
      );
    });

    testWidgets('curly underline', (tester) async {
      write('\x1b[4:3mCurly\x1b[0m');
      await pump(tester);
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/text_underline_curly.png'),
      );
    });

    testWidgets('dotted underline', (tester) async {
      write('\x1b[4:4mDotted\x1b[0m');
      await pump(tester);
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/text_underline_dotted.png'),
      );
    });

    testWidgets('dashed underline', (tester) async {
      write('\x1b[4:5mDashed\x1b[0m');
      await pump(tester);
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/text_underline_dashed.png'),
      );
    });

    testWidgets('strikethrough', (tester) async {
      write('\x1b[9mStrikethrough\x1b[0m');
      await pump(tester);
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/text_strikethrough.png'),
      );
    });

    testWidgets('overline', (tester) async {
      write('\x1b[53mOverline\x1b[0m');
      await pump(tester);
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/text_overline.png'),
      );
    });

    testWidgets('combined underline and strikethrough', (tester) async {
      write('\x1b[4;9mUnder+Strike\x1b[0m');
      await pump(tester);
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/text_combined_decorations.png'),
      );
    });

    testWidgets('colored underline', (tester) async {
      write('\x1b[4m\x1b[58;2;255;80;80mColored underline\x1b[0m');
      await pump(tester);
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/text_underline_colored.png'),
      );
    });

    testWidgets('cell background color', (tester) async {
      write('\x1b[42;30m Colored BG \x1b[0m');
      await pump(tester);
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/text_cell_background.png'),
      );
    });

    testWidgets('wide CJK character', (tester) async {
      terminal.write(
        Uint8List.fromList([
          0x57, 0x69, 0x64, 0x65, 0x3A, 0x20, // 'Wide: '
          0xE6, 0x97, 0xA5, // 日 U+65E5
          0xE6, 0x9C, 0xAC, // 本 U+672C
          0xE8, 0xAA, 0x9E, // 語 U+8A9E
        ]),
      );
      await pump(tester);
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/text_wide_cjk.png'),
      );
    });

    testWidgets('selection single row', (tester) async {
      write('Hello, World!');
      await pump(
        tester,
        selection: const TerminalSelection(
          startRow: 0,
          startCol: 0,
          endRow: 0,
          endCol: 5,
        ),
      );
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/selection_single_row.png'),
      );
    });

    testWidgets('selection multi-row', (tester) async {
      write('Line one\r\nLine two\r\nLine three');
      await pump(
        tester,
        selection: const TerminalSelection(
          startRow: 0,
          startCol: 5,
          endRow: 1,
          endCol: 4,
        ),
      );
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/selection_multi_row.png'),
      );
    });

    testWidgets('selection reversed direction', (tester) async {
      write('Hello, World!');
      await pump(
        tester,
        selection: const TerminalSelection(
          startRow: 0,
          startCol: 5,
          endRow: 0,
          endCol: 0,
        ),
      );
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/selection_reversed.png'),
      );
    });

    testWidgets('selection spanning three rows', (tester) async {
      write('Line one\r\nLine two\r\nLine three');
      await pump(
        tester,
        selection: const TerminalSelection(
          startRow: 0,
          startCol: 5,
          endRow: 2,
          endCol: 4,
        ),
      );
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/selection_three_rows.png'),
      );
    });

    testWidgets('selection multi-row reversed', (tester) async {
      write('Line one\r\nLine two\r\nLine three');
      await pump(
        tester,
        selection: const TerminalSelection(
          startRow: 2,
          startCol: 4,
          endRow: 0,
          endCol: 5,
        ),
      );
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/selection_multi_row_reversed.png'),
      );
    });

    testWidgets('selection full row', (tester) async {
      write('Hello, World!');
      await pump(
        tester,
        selection: const TerminalSelection(
          startRow: 0,
          startCol: 0,
          endRow: 0,
          endCol: _cols,
        ),
      );
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/selection_full_row.png'),
      );
    });

    testWidgets('selection block single row', (tester) async {
      write('Hello, World!');
      await pump(
        tester,
        selection: const TerminalSelection(
          startRow: 0,
          startCol: 2,
          endRow: 0,
          endCol: 7,
          mode: SelectionMode.block,
        ),
      );
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/selection_block_single_row.png'),
      );
    });

    testWidgets('selection block multi-row', (tester) async {
      write('Line one\r\nLine two\r\nLine three');
      await pump(
        tester,
        selection: const TerminalSelection(
          startRow: 0,
          startCol: 2,
          endRow: 2,
          endCol: 7,
          mode: SelectionMode.block,
        ),
      );
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/selection_block_multi_row.png'),
      );
    });

    testWidgets('selection block reversed', (tester) async {
      write('Line one\r\nLine two\r\nLine three');
      await pump(
        tester,
        selection: const TerminalSelection(
          startRow: 2,
          startCol: 7,
          endRow: 0,
          endCol: 2,
          mode: SelectionMode.block,
        ),
      );
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/selection_block_reversed.png'),
      );
    });

    testWidgets('selection single cell', (tester) async {
      write('Hello, World!');
      await pump(
        tester,
        selection: const TerminalSelection(
          startRow: 0,
          startCol: 3,
          endRow: 0,
          endCol: 4,
        ),
      );
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/selection_single_cell.png'),
      );
    });

    testWidgets('selection multi-row topCol before botCol', (tester) async {
      write('Line one\r\nLine two\r\nLine three');
      await pump(
        tester,
        selection: const TerminalSelection(
          startRow: 0,
          startCol: 2,
          endRow: 2,
          endCol: 7,
        ),
      );
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/selection_topCol_before_botCol.png'),
      );
    });

    testWidgets('selection first row full-width', (tester) async {
      write('Line one\r\nLine two\r\nLine three');
      await pump(
        tester,
        selection: const TerminalSelection(
          startRow: 0,
          startCol: 0,
          endRow: 2,
          endCol: 4,
        ),
      );
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/selection_first_row_full_width.png'),
      );
    });

    testWidgets('selection last row full-width', (tester) async {
      write('Line one\r\nLine two\r\nLine three');
      await pump(
        tester,
        selection: const TerminalSelection(
          startRow: 0,
          startCol: 5,
          endRow: 2,
          endCol: _cols,
        ),
      );
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/selection_last_row_full_width.png'),
      );
    });

    testWidgets('selection block single cell', (tester) async {
      write('Hello, World!');
      await pump(
        tester,
        selection: const TerminalSelection(
          startRow: 0,
          startCol: 3,
          endRow: 0,
          endCol: 4,
          mode: SelectionMode.block,
        ),
      );
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/selection_block_single_cell.png'),
      );
    });

    testWidgets('selection block single-row reversed', (tester) async {
      write('Hello, World!');
      await pump(
        tester,
        selection: const TerminalSelection(
          startRow: 0,
          startCol: 7,
          endRow: 0,
          endCol: 2,
          mode: SelectionMode.block,
        ),
      );
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/selection_block_single_row_reversed.png'),
      );
    });

    testWidgets('selection beyond grid bounds', (tester) async {
      write('Hello, World!');
      await pump(
        tester,
        selection: const TerminalSelection(
          startRow: -1,
          startCol: -2,
          endRow: 1,
          endCol: 30,
        ),
      );
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/selection_beyond_bounds.png'),
      );
    });
  });
}

const _rows = 5;
const _cols = 25;
const _metrics = CellMetrics(cellWidth: 8, cellHeight: 16, baseline: 12);
const _altMetrics = CellMetrics(cellWidth: 10, cellHeight: 20, baseline: 15);

Widget _wrap(
  Terminal terminal, {
  TerminalTheme? theme,
  CellMetrics metrics = _metrics,
  TerminalSelection? selection,
  double? maxWidth,
  double? maxHeight,
}) {
  final mw = maxWidth ?? _cols * metrics.cellWidth;
  final mh = maxHeight ?? _rows * metrics.cellHeight;
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: mw, maxHeight: mh),
        child: TerminalRenderer(
          terminal: terminal,
          theme: theme ?? TerminalTheme.defaults,
          metrics: metrics,
          selection: selection,
        ),
      ),
    ),
  );
}
