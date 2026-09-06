@Tags(['ffi', 'golden'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flterm/src/foundation.dart';
import 'package:flterm/src/links/link_snapshot.dart';
import 'package:flterm/src/rendering.dart';
import 'package:flterm/src/rendering/atlas_pool.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart';

import 'helpers/font_loader.dart';
import 'helpers/test_selection.dart';

void main() {
  setUpAll(loadBundledFonts);

  group('TerminalRenderer goldens', () {
    const defaultCols = 25;
    const customAnsiColors = [
      Color(0xFF282828),
      Color(0xFF00FFFF),
      Color(0xFF66994C),
      Color(0xFFE5B566),
      Color(0xFF668ECC),
      Color(0xFFB266B2),
      Color(0xFF4CB2B2),
      Color(0xFFAAAAAA),
      Color(0xFF505050),
      Color(0xFFE66464),
      Color(0xFF8CBE6E),
      Color(0xFFF0C878),
      Color(0xFF82A0DC),
      Color(0xFFC882C8),
      Color(0xFF64C8C8),
      Color(0xFFDCDCDC),
    ];
    const defaultMetrics = CellMetrics(
      cellWidth: 8,
      cellHeight: 16,
      baseline: 12,
    );
    const defaultRows = 5;

    final cjkTheme = TerminalTheme.dark().copyWith(
      fontFamilyFallback: const ['Noto Sans JP', 'JetBrains Mono'],
    );

    final emojiTheme = TerminalTheme.dark().copyWith(
      fontFamilyFallback: const ['Noto Emoji', 'JetBrains Mono'],
    );

    bool needsWhiteFg(ColorPalette palette, int colorIndex) {
      final c = palette[colorIndex];
      return (0.299 * c.r * 255 + 0.587 * c.g * 255 + 0.114 * c.b * 255) < 128;
    }

    AtlasPool atlasPool() {
      final pool = AtlasPool();
      addTearDown(pool.dispose);
      return pool;
    }

    void writeUtf8(Terminal terminal, String text) {
      terminal.write(Uint8List.fromList(utf8.encode(text)));
    }

    Widget wrap(
      Terminal terminal, {
      TerminalTheme? theme,
      CellMetrics metrics = defaultMetrics,
      TestSelection? selection,
      double? maxWidth,
      double? maxHeight,
      bool focused = true,
      bool blinkVisible = true,
      String preeditText = '',
      LinkSnapshot linkSnapshot = LinkSnapshot.empty,
      List<Selection> searchMatches = const [],
      Selection? selectedSearchMatch,
      ValueChanged<SurfaceMeasurement>? onGeometryChanged,
    }) {
      final resolvedTheme =
          theme ??
          TerminalTheme.dark().copyWith(
            fontFamilyFallback: bundledFontFamilyFallback,
          );
      applyTerminalTheme(terminal, resolvedTheme);
      selection?.applyTo(terminal);
      final frameSource = FrameSource(terminal);
      addTearDown(frameSource.dispose);
      final width = maxWidth ?? defaultCols * metrics.cellWidth;
      final height = maxHeight ?? defaultRows * metrics.cellHeight;
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width, maxHeight: height),
            child: RepaintBoundary(
              child: TerminalRenderer(
                frameSource: frameSource,
                theme: resolvedTheme,
                metrics: metrics,
                offset: ViewportOffset.zero(),
                atlasPool: atlasPool(),
                focused: focused,
                blinkVisible: blinkVisible,
                preeditText: preeditText,
                linkSnapshot: linkSnapshot,
                searchMatches: searchMatches,
                selectedSearchMatch: selectedSearchMatch,
                onGeometryChanged: (geometry) {
                  terminal.resize(
                    cols: geometry.cols,
                    rows: geometry.rows,
                    cellWidthPx:
                        (geometry.cellWidth * geometry.devicePixelRatio)
                            .round(),
                    cellHeightPx:
                        (geometry.cellHeight * geometry.devicePixelRatio)
                            .round(),
                  );
                  onGeometryChanged?.call(geometry);
                },
                onViewportRowChanged: (_) {},
              ),
            ),
          ),
        ),
      );
    }

    final theme = TerminalTheme.dark().copyWith(
      fontSize: 24.0,
      fontFamilyFallback: bundledFontFamilyFallback,
    );
    late Terminal terminal;
    late CellMetrics goldenMetrics;

    setUp(() {
      terminal = Terminal(cols: defaultCols, rows: defaultRows);
      goldenMetrics = measureCellMetrics(
        fontFamily: theme.fontFamily,
        fontSize: theme.fontSize,
        fontData: jetBrainsMonoBytes,
      );
    });

    tearDown(() => terminal.dispose());

    Future<void> pump(
      WidgetTester tester, {
      TerminalTheme? overrideTheme,
      TestSelection? selection,
      LinkSnapshot linkSnapshot = LinkSnapshot.empty,
      List<Selection> searchMatches = const [],
      Selection? selectedSearchMatch,
    }) async {
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        wrap(
          terminal,
          theme: overrideTheme ?? theme,
          selection: selection,
          metrics: goldenMetrics,
          linkSnapshot: linkSnapshot,
          searchMatches: searchMatches,
          selectedSearchMatch: selectedSearchMatch,
        ),
      );
    }

    group('text rendering', () {
      testWidgets('text styles', (tester) async {
        const cols = 25;
        const rows = 7;
        final terminal = Terminal(cols: cols, rows: rows);
        writeUtf8(
          terminal,
          'Normal text\r\n'
          '\x1b[1mBold text\x1b[0m\r\n'
          '\x1b[3mItalic text\x1b[0m\r\n'
          '\x1b[2mFaint text\x1b[0m\r\n'
          '\x1b[7mInverse text\x1b[0m\r\n'
          '\x1b[42;30m BG color \x1b[0m\r\n'
          '== === !== != -> =>',
        );
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(
          wrap(
            terminal,
            theme: theme,
            metrics: goldenMetrics,
            maxWidth: cols * goldenMetrics.cellWidth,
            maxHeight: rows * goldenMetrics.cellHeight,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/text_styles.png'),
        );
        terminal.dispose();
      });

      testWidgets('Nerd Font symbol spacing', (tester) async {
        const cols = 7;
        const rows = 1;
        final terminal = Terminal(cols: cols, rows: rows);
        writeUtf8(terminal, '\x1b[34m\uE5FF\x1b[0m fvm');
        final nerdTheme = theme.copyWith(
          fontFamilyFallback: bundledNerdFontFamilyFallback,
        );
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(
          wrap(
            terminal,
            theme: nerdTheme,
            metrics: goldenMetrics,
            maxWidth: cols * goldenMetrics.cellWidth,
            maxHeight: rows * goldenMetrics.cellHeight,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/text_nerd_font_symbol_spacing.png'),
        );
        terminal.dispose();
      });
    });

    group('text decorations', () {
      testWidgets('decoration styles', (tester) async {
        const cols = 25;
        const rows = 12;
        final terminal = Terminal(cols: cols, rows: rows);
        writeUtf8(
          terminal,
          '\x1b[4mSingle underline\x1b[0m\r\n'
          '\x1b[4:2mDouble underline\x1b[0m\r\n'
          '\x1b[4:3mCurly underline\x1b[0m\r\n'
          '\x1b[4:4mDotted underline\x1b[0m\r\n'
          '\x1b[4:5mDashed underline\x1b[0m\r\n'
          '\x1b[4m\x1b[58;2;255;80;80mColored underline\x1b[0m\r\n'
          '\x1b[9mStrikethrough\x1b[0m\r\n'
          '\x1b[53mOverline\x1b[0m\r\n'
          '\x1b[4;9mUnder+Strike\x1b[0m\r\n'
          '\x1b[3;4mItalic underline\x1b[0m\r\n'
          '\x1b[3;4:3mItalic curly\x1b[0m\r\n'
          '\x1b[3;4:2mItalic double\x1b[0m',
        );
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(
          wrap(
            terminal,
            theme: theme,
            metrics: goldenMetrics,
            maxWidth: cols * goldenMetrics.cellWidth,
            maxHeight: rows * goldenMetrics.cellHeight,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/text_decorations.png'),
        );
        terminal.dispose();
      });
    });

    group('link styling', () {
      testWidgets('OSC 8 link is plain when idle', (tester) async {
        writeUtf8(
          terminal,
          '\x1b]8;;https://example.test\x07OSC 8\x1b]8;;\x07 tail',
        );

        await pump(tester);

        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/link_osc8_idle_plain.png'),
        );
      });

      testWidgets('text link is plain when idle', (tester) async {
        writeUtf8(terminal, 'https://a.test tail');

        await pump(tester);

        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/link_text_idle_plain.png'),
        );
      });

      testWidgets('hovered text link underlines exact link cells', (
        tester,
      ) async {
        writeUtf8(terminal, 'https://a.test tail');

        await pump(
          tester,
          linkSnapshot: LinkSnapshot.highlighted(
            const CellRange(
              start: Position(row: 0, col: 0),
              end: Position(row: 0, col: 13),
            ),
          ),
        );

        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/link_text_hover_exact_range.png'),
        );
      });
    });

    group('wide characters', () {
      testWidgets('preedit replaces suggestion cells', (tester) async {
        final cjk24 = cjkTheme.copyWith(fontSize: 24.0);
        final cjkMetrics = measureCellMetrics(
          fontFamily: cjk24.fontFamily,
          fontSize: cjk24.fontSize,
          fontData: jetBrainsMonoBytes,
        );
        const cols = 25;
        const rows = 2;
        final terminal = Terminal(cols: cols, rows: rows);
        writeUtf8(terminal, 'Input: suggestion\x1b[10D');
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(
          wrap(
            terminal,
            theme: cjk24,
            metrics: cjkMetrics,
            maxWidth: cols * cjkMetrics.cellWidth,
            maxHeight: rows * cjkMetrics.cellHeight,
            preeditText: '日本',
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/preedit_replaces_suggestion_cells.png'),
        );
        terminal.dispose();
      });

      testWidgets('long preedit clips after prompt', (tester) async {
        final cjk24 = cjkTheme.copyWith(fontSize: 24.0);
        final cjkMetrics = measureCellMetrics(
          fontFamily: cjk24.fontFamily,
          fontSize: cjk24.fontSize,
          fontData: jetBrainsMonoBytes,
        );
        const cols = 22;
        const rows = 2;
        final terminal = Terminal(cols: cols, rows: rows);
        writeUtf8(terminal, '~/project \$ suggestion\x1b[10D');
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(
          wrap(
            terminal,
            theme: cjk24,
            metrics: cjkMetrics,
            maxWidth: cols * cjkMetrics.cellWidth,
            maxHeight: rows * cjkMetrics.cellHeight,
            preeditText: '一二三四五六七八',
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/preedit_long_clips_after_prompt.png'),
        );
        terminal.dispose();
      });

      testWidgets('very long preedit keeps visible tail', (tester) async {
        final cjk24 = cjkTheme.copyWith(fontSize: 24.0);
        final cjkMetrics = measureCellMetrics(
          fontFamily: cjk24.fontFamily,
          fontSize: cjk24.fontSize,
          fontData: jetBrainsMonoBytes,
        );
        const cols = 22;
        const rows = 2;
        final terminal = Terminal(cols: cols, rows: rows);
        writeUtf8(terminal, '~/project \$ suggestion\x1b[10D');
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(
          wrap(
            terminal,
            theme: cjk24,
            metrics: cjkMetrics,
            maxWidth: cols * cjkMetrics.cellWidth,
            maxHeight: rows * cjkMetrics.cellHeight,
            preeditText: '一二三四五六七八九十一二三四五六七八九十',
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/preedit_very_long_visible_tail.png'),
        );
        terminal.dispose();
      });

      testWidgets('CJK mixed with ASCII', (tester) async {
        final cjk24 = cjkTheme.copyWith(fontSize: 24.0);
        final cjkMetrics = measureCellMetrics(
          fontFamily: cjk24.fontFamily,
          fontSize: cjk24.fontSize,
          fontData: jetBrainsMonoBytes,
        );
        const cols = 25;
        const rows = 2;
        final terminal = Terminal(cols: cols, rows: rows);
        // dart format off
        terminal.write(
          Uint8List.fromList([
            0x57, 0x69, 0x64, 0x65, 0x3A, 0x20,
            0xE6, 0x97, 0xA5,
            0xE6, 0x9C, 0xAC,
            0xE8, 0xAA, 0x9E,
            0x0D, 0x0A,
            ...utf8.encode('A'),
            0xE6, 0x97, 0xA5,
            ...utf8.encode('B'),
            0xE6, 0x9C, 0xAC,
            ...utf8.encode('C'),
          ]),
        );
        // dart format on
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(
          wrap(
            terminal,
            theme: cjk24,
            metrics: cjkMetrics,
            maxWidth: cols * cjkMetrics.cellWidth,
            maxHeight: rows * cjkMetrics.cellHeight,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/text_wide_cjk.png'),
        );
        terminal.dispose();
      });

      testWidgets('emoji mixed with ASCII', (tester) async {
        final emoji24 = emojiTheme.copyWith(fontSize: 24.0);
        final emojiMetrics = measureCellMetrics(
          fontFamily: emoji24.fontFamily,
          fontSize: emoji24.fontSize,
          fontData: jetBrainsMonoBytes,
        );
        const cols = 25;
        const rows = 2;
        final terminal = Terminal(cols: cols, rows: rows);
        // dart format off
        terminal.write(
          Uint8List.fromList([
            ...utf8.encode('OK'),
            0xE2, 0x9C, 0x85,
            ...utf8.encode('NO'),
            0xE2, 0x9D, 0x8C,
            0x0D, 0x0A,
            ...utf8.encode('A'),
            0xE2, 0x9C, 0x85,
            ...utf8.encode('B'),
            0xE2, 0x9D, 0x8C,
            ...utf8.encode('C'),
            0xE2, 0x9C, 0x85,
            ...utf8.encode('D'),
          ]),
        );
        // dart format on
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(
          wrap(
            terminal,
            theme: emoji24,
            metrics: emojiMetrics,
            maxWidth: cols * emojiMetrics.cellWidth,
            maxHeight: rows * emojiMetrics.cellHeight,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/text_emoji.png'),
        );
        terminal.dispose();
      });
    });

    group('selection', () {
      testWidgets('single row', (tester) async {
        writeUtf8(terminal, 'Hello, World!');
        await pump(
          tester,
          selection: const TestSelection(
            start: Position(row: 0, col: 0),
            end: Position(row: 0, col: 4),
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/selection_single_row.png'),
        );
      });

      testWidgets('multi-row', (tester) async {
        writeUtf8(terminal, 'Line one\r\nLine two\r\nLine three');
        await pump(
          tester,
          selection: const TestSelection(
            start: Position(row: 0, col: 5),
            end: Position(row: 1, col: 3),
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/selection_multi_row.png'),
        );
      });

      testWidgets('reversed direction', (tester) async {
        writeUtf8(terminal, 'Hello, World!');
        await pump(
          tester,
          selection: const TestSelection(
            start: Position(row: 0, col: 4),
            end: Position(row: 0, col: 0),
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/selection_reversed.png'),
        );
      });

      testWidgets('spanning three rows', (tester) async {
        writeUtf8(terminal, 'Line one\r\nLine two\r\nLine three');
        await pump(
          tester,
          selection: const TestSelection(
            start: Position(row: 0, col: 5),
            end: Position(row: 2, col: 3),
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/selection_three_rows.png'),
        );
      });

      testWidgets('multi-row reversed', (tester) async {
        writeUtf8(terminal, 'Line one\r\nLine two\r\nLine three');
        await pump(
          tester,
          selection: const TestSelection(
            start: Position(row: 2, col: 3),
            end: Position(row: 0, col: 5),
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/selection_multi_row_reversed.png'),
        );
      });

      testWidgets('full row', (tester) async {
        writeUtf8(terminal, 'Hello, World!');
        await pump(
          tester,
          selection: const TestSelection(
            start: Position(row: 0, col: 0),
            end: Position(row: 0, col: defaultCols - 1),
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/selection_full_row.png'),
        );
      });

      testWidgets('single cell', (tester) async {
        writeUtf8(terminal, 'Hello, World!');
        await pump(
          tester,
          selection: const TestSelection(
            start: Position(row: 0, col: 3),
            end: Position(row: 0, col: 3),
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/selection_single_cell.png'),
        );
      });

      testWidgets('first row full-width in multi-row', (tester) async {
        writeUtf8(terminal, 'Line one\r\nLine two\r\nLine three');
        await pump(
          tester,
          selection: const TestSelection(
            start: Position(row: 0, col: 0),
            end: Position(row: 2, col: 3),
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/selection_first_row_full_width.png'),
        );
      });

      testWidgets('last row full-width in multi-row', (tester) async {
        writeUtf8(terminal, 'Line one\r\nLine two\r\nLine three');
        await pump(
          tester,
          selection: const TestSelection(
            start: Position(row: 0, col: 5),
            end: Position(row: 2, col: defaultCols - 1),
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/selection_last_row_full_width.png'),
        );
      });

      testWidgets('beyond grid bounds', (tester) async {
        writeUtf8(terminal, 'Hello, World!');
        await pump(
          tester,
          selection: const TestSelection(
            start: Position(row: -1, col: -2),
            end: Position(row: 1, col: 29),
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/selection_beyond_bounds.png'),
        );
      });
    });

    group('search', () {
      testWidgets('renders distinct search match states', (tester) async {
        final search = Search(terminal);
        addTearDown(search.dispose);
        writeUtf8(
          terminal,
          'alpha beta gamma\r\n'
          'beta delta beta\r\n'
          'omega beta sigma',
        );
        search.setNeedle('beta');
        search.run();
        search.selectNext();

        await pump(
          tester,
          overrideTheme: theme.copyWith(
            search: const SearchTheme(
              match: SelectionTheme(
                background: DynamicColor.fixed(Color(0xFFF0C674)),
                foreground: DynamicColor.fixed(Color(0xFF1D1F21)),
              ),
              selectedMatch: SelectionTheme(
                background: DynamicColor.fixed(Color(0xFFE64A3B)),
                foreground: DynamicColor.fixed(Color(0xFFFFFFFF)),
              ),
            ),
          ),
          searchMatches: search.viewportMatches,
          selectedSearchMatch: search.selectedMatch,
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/search_match_states.png'),
        );
      });

      testWidgets('renders the visible part of a multiline match', (
        tester,
      ) async {
        const cols = 12;
        const rows = 3;
        final terminal = Terminal(cols: cols, rows: rows);
        addTearDown(terminal.dispose);
        final search = Search(terminal);
        addTearDown(search.dispose);
        writeUtf8(
          terminal,
          'multiline-match\r\n'
          'second line\r\n'
          'third line\r\n'
          'fourth line',
        );
        search.setNeedle('multiline-match');
        search.run();
        terminal.scrollToRow(1);
        search.run();

        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(
          wrap(
            terminal,
            theme: theme,
            metrics: goldenMetrics,
            maxWidth: cols * goldenMetrics.cellWidth,
            maxHeight: rows * goldenMetrics.cellHeight,
            searchMatches: search.viewportMatches,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/search_multiline_clipped.png'),
        );
      });
    });

    group('block selection', () {
      testWidgets('single row', (tester) async {
        writeUtf8(terminal, 'Hello, World!');
        await pump(
          tester,
          selection: const TestSelection(
            start: Position(row: 0, col: 2),
            end: Position(row: 0, col: 6),
            rectangle: true,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/selection_block_single_row.png'),
        );
      });

      testWidgets('multi-row', (tester) async {
        writeUtf8(terminal, 'Line one\r\nLine two\r\nLine three');
        await pump(
          tester,
          selection: const TestSelection(
            start: Position(row: 0, col: 2),
            end: Position(row: 2, col: 6),
            rectangle: true,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/selection_block_multi_row.png'),
        );
      });

      testWidgets('reversed', (tester) async {
        writeUtf8(terminal, 'Line one\r\nLine two\r\nLine three');
        await pump(
          tester,
          selection: const TestSelection(
            start: Position(row: 2, col: 6),
            end: Position(row: 0, col: 2),
            rectangle: true,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/selection_block_reversed.png'),
        );
      });

      testWidgets('single cell', (tester) async {
        writeUtf8(terminal, 'Hello, World!');
        await pump(
          tester,
          selection: const TestSelection(
            start: Position(row: 0, col: 3),
            end: Position(row: 0, col: 3),
            rectangle: true,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/selection_block_single_cell.png'),
        );
      });

      testWidgets('single-row reversed', (tester) async {
        writeUtf8(terminal, 'Hello, World!');
        await pump(
          tester,
          selection: const TestSelection(
            start: Position(row: 0, col: 6),
            end: Position(row: 0, col: 2),
            rectangle: true,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/selection_block_single_row_reversed.png'),
        );
      });

      testWidgets('beyond grid bounds keeps columns', (tester) async {
        writeUtf8(terminal, 'Line one\r\nLine two\r\nLine three');
        await pump(
          tester,
          selection: const TestSelection(
            start: Position(row: -1, col: 2),
            end: Position(row: 5, col: 6),
            rectangle: true,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/selection_block_beyond_bounds.png'),
        );
      });
    });

    group('theme rendering', () {
      testWidgets('color modes', (tester) async {
        const cols = 30;
        const rows = 6;
        final terminal = Terminal(cols: cols, rows: rows);
        writeUtf8(
          terminal,
          '\x1b[31mRed\x1b[0m \x1b[32mGreen\x1b[0m \x1b[34mBlue\x1b[0m\r\n'
          '\x1b[1;31mBold Red (bright)\x1b[0m\r\n'
          '\x1b[38;5;100mColor 100\x1b[0m \x1b[38;5;200mColor 200\x1b[0m\r\n'
          '\x1b[38;5;232m232\x1b[0m '
          '\x1b[38;5;240m240\x1b[0m '
          '\x1b[38;5;248m248\x1b[0m '
          '\x1b[38;5;255m255\x1b[0m\r\n'
          '\x1b[38;2;255;128;0mOrange\x1b[0m '
          '\x1b[38;2;0;200;100mTeal\x1b[0m\r\n'
          '\x1b[48;5;1;37m Red BG \x1b[0m \x1b[48;5;4;37m Blue BG \x1b[0m',
        );
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(
          wrap(
            terminal,
            theme: theme,
            metrics: goldenMetrics,
            maxWidth: cols * goldenMetrics.cellWidth,
            maxHeight: rows * goldenMetrics.cellHeight,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/theme_colors.png'),
        );
        terminal.dispose();
      });

      testWidgets('selection background color', (tester) async {
        writeUtf8(terminal, 'Selected text here');
        await pump(
          tester,
          overrideTheme: theme.copyWith(
            selection: const SelectionTheme(
              background: DynamicColor.fixed(Color(0x80FF0000)),
            ),
          ),
          selection: const TestSelection(
            start: Position(row: 0, col: 0),
            end: Position(row: 0, col: 12),
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/theme_selection_bg.png'),
        );
      });

      testWidgets('faint text uses theme opacity', (tester) async {
        writeUtf8(terminal, '\x1b[2mFaint text\x1b[0m Normal');
        await pump(tester, overrideTheme: theme.copyWith(faintOpacity: 0.2));
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/theme_faint_opacity.png'),
        );
      });

      testWidgets('cursor opacity', (tester) async {
        writeUtf8(terminal, 'X');
        await pump(
          tester,
          overrideTheme: theme.copyWith(
            cursor: const CursorTheme(opacity: 0.3),
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/theme_cursor_opacity.png'),
        );
      });

      testWidgets('cursor color', (tester) async {
        writeUtf8(terminal, 'X');
        await pump(
          tester,
          overrideTheme: theme.copyWith(
            cursor: const CursorTheme(
              color: DynamicColor.fixed(Color(0xFFFF0000)),
            ),
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/theme_cursor_color.png'),
        );
      });

      testWidgets('cursor text color', (tester) async {
        writeUtf8(terminal, 'AB');
        await pump(
          tester,
          overrideTheme: theme.copyWith(
            cursor: const CursorTheme(
              color: DynamicColor.fixed(Color(0xFFFFFFFF)),
              text: DynamicColor.fixed(Color(0xFFFF00FF)),
            ),
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/theme_cursor_text.png'),
        );
      });

      testWidgets('cursor color tracks cell foreground', (tester) async {
        writeUtf8(terminal, '\x1b[31mR\x1b[0m\x1b[34mB\x1b[0m');
        await pump(
          tester,
          overrideTheme: theme.copyWith(
            cursor: const CursorTheme(color: DynamicColor.cellForeground()),
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/theme_cursor_cell_fg.png'),
        );
      });

      testWidgets('selection foreground tints selected text', (tester) async {
        writeUtf8(terminal, '\x1b[31mRed\x1b[0m \x1b[32mGreen\x1b[0m');
        await pump(
          tester,
          overrideTheme: theme.copyWith(
            selection: const SelectionTheme(
              background: DynamicColor.fixed(Color(0x80888888)),
              foreground: DynamicColor.fixed(Color(0xFFFFFF00)),
            ),
          ),
          selection: const TestSelection(
            start: Position(row: 0, col: 0),
            end: Position(row: 0, col: 8),
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/theme_selection_fg.png'),
        );
      });

      testWidgets('selection foreground tracks cell background', (
        tester,
      ) async {
        writeUtf8(terminal, '\x1b[41mA\x1b[0m\x1b[44mB\x1b[0m');
        await pump(
          tester,
          overrideTheme: theme.copyWith(
            selection: const SelectionTheme(
              background: DynamicColor.fixed(Color(0x80888888)),
              foreground: DynamicColor.cellBackground(),
            ),
          ),
          selection: const TestSelection(
            start: Position(row: 0, col: 0),
            end: Position(row: 0, col: 1),
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/theme_selection_fg_cell_bg.png'),
        );
      });

      testWidgets('boldColor overrides bold foreground', (tester) async {
        writeUtf8(terminal, '\x1b[31mRed\x1b[0m \x1b[1;31mBold Red\x1b[0m');
        await pump(
          tester,
          overrideTheme: theme.copyWith(boldColor: const Color(0xFF00FFFF)),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/theme_bold_color.png'),
        );
      });

      testWidgets('custom ANSI colors', (tester) async {
        writeUtf8(terminal, '\x1b[31mThis should be cyan\x1b[0m');
        await pump(
          tester,
          overrideTheme: TerminalTheme(
            palette: ColorPalette(
              ansiColors: customAnsiColors,
              background: theme.background,
              foreground: theme.foreground,
            ),
            fontSize: 24.0,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/theme_custom_ansi.png'),
        );
      });

      testWidgets('custom foreground and background', (tester) async {
        writeUtf8(terminal, 'Hello world');
        await pump(
          tester,
          overrideTheme: TerminalTheme(
            palette: ColorPalette(
              ansiColors: customAnsiColors,
              background: const Color(0xFF000080),
              foreground: const Color(0xFF00FF00),
            ),
            fontSize: 24.0,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/theme_custom_fg_bg.png'),
        );
      });

      testWidgets('bold text with boldIsBright false', (tester) async {
        writeUtf8(terminal, '\x1b[1;31mBold Red\x1b[0m');
        await pump(tester, overrideTheme: theme.copyWith(boldIsBright: false));
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/theme_bold_not_bright.png'),
        );
      });

      testWidgets('256-color palette', (tester) async {
        const cols = 72;
        const rows = 19;
        final terminal = Terminal(cols: cols, rows: rows);
        final buf = StringBuffer();

        for (var i = 0; i < 8; i++) {
          final fg = needsWhiteFg(theme.palette, i) ? '38;5;15' : '38;5;0';
          buf.write('\x1b[$fg;48;5;${i}m${i.toString().padLeft(3)} \x1b[0m');
        }
        buf.write('\r\n');

        for (var i = 8; i < 16; i++) {
          final fg = needsWhiteFg(theme.palette, i) ? '38;5;15' : '38;5;0';
          buf.write('\x1b[$fg;48;5;${i}m${i.toString().padLeft(3)} \x1b[0m');
        }
        buf.write('\r\n');

        buf.write('\r\n');

        for (var i = 16; i < 232; i++) {
          final fg = needsWhiteFg(theme.palette, i) ? '38;5;15' : '38;5;0';
          buf.write('\x1b[$fg;48;5;${i}m${i.toString().padLeft(3)} \x1b[0m');
          if ((i - 16 + 1) % 18 == 0) buf.write('\r\n');
        }

        buf.write('\r\n');

        for (var i = 232; i < 256; i++) {
          final fg = needsWhiteFg(theme.palette, i) ? '38;5;15' : '38;5;0';
          buf.write('\x1b[$fg;48;5;${i}m${i.toString().padLeft(3)} \x1b[0m');
          if ((i - 232 + 1) % 12 == 0 && i < 255) buf.write('\r\n');
        }

        writeUtf8(terminal, buf.toString());
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(
          wrap(
            terminal,
            theme: theme,
            metrics: goldenMetrics,
            maxWidth: cols * goldenMetrics.cellWidth,
            maxHeight: rows * goldenMetrics.cellHeight,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/theme_256_colors.png'),
        );
        terminal.dispose();
      });
    });
  });
}
