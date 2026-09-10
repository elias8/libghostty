// ignore_for_file: lines_longer_than_80_chars

@Tags(['ffi', 'golden'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flterm/src/foundation.dart';
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

  group('Emoji rendering', () {
    const cjkFallback = ['Noto Sans JP', 'JetBrains Mono'];
    const defaultCols = 25;
    const emojiFallback = ['Noto Color Emoji', 'Noto Emoji', 'JetBrains Mono'];
    const defaultRows = 5;

    final baseTheme = TerminalTheme.dark().copyWith(
      fontSize: 24.0,
      fontFamilyFallback: bundledFontFamilyFallback,
    );

    TerminalTheme cursorTheme(CursorShape shape, {List<String>? fallback}) =>
        TerminalTheme.dark().copyWith(
          fontSize: 24.0,
          fontFamilyFallback: fallback ?? bundledFontFamilyFallback,
          cursor: CursorTheme(
            shape: shape,
            blinkInterval: const Duration(hours: 1),
          ),
        );

    final cjkCursorTheme = cursorTheme(.block, fallback: cjkFallback);
    final emojiCursorTheme = cursorTheme(.block, fallback: emojiFallback);

    final emojiTheme = TerminalTheme.dark().copyWith(
      fontSize: 24.0,
      fontFamilyFallback: emojiFallback,
    );

    final mixedTheme = TerminalTheme.dark().copyWith(
      fontSize: 24.0,
      fontFamilyFallback: [
        'Noto Color Emoji',
        'Noto Emoji',
        'Noto Sans JP',
        'JetBrains Mono',
      ],
    );

    AtlasPool atlasPool() {
      final pool = AtlasPool();
      addTearDown(pool.dispose);
      return pool;
    }

    void writeRawBytes(Terminal terminal, List<int> bytes) {
      terminal.write(Uint8List.fromList(bytes));
    }

    void writeUtf8(Terminal terminal, String text) {
      writeRawBytes(terminal, utf8.encode(text));
    }

    void writeCodepoint(Terminal terminal, int codepoint) {
      writeRawBytes(terminal, utf8.encode(String.fromCharCodes([codepoint])));
    }

    void writeEmojiGrid(Terminal terminal, List<List<int>> rows) {
      for (var row = 0; row < rows.length; row++) {
        if (row > 0) writeUtf8(terminal, '\r\n');
        for (final codepoint in rows[row]) {
          writeCodepoint(terminal, codepoint);
        }
      }
    }

    Future<void> pumpRenderer(
      WidgetTester tester,
      Terminal terminal,
      CellMetrics metrics, {
      int cols = defaultCols,
      int rows = defaultRows,
      TerminalTheme? theme,
      TestSelection? selection,
      bool focused = true,
    }) async {
      selection?.applyTo(terminal);
      final frameChanges = ChangeNotifier();
      void onTerminalChanged() => frameChanges.notifyListeners();
      terminal.addListener(onTerminalChanged);
      addTearDown(() {
        terminal.removeListener(onTerminalChanged);
        frameChanges.dispose();
      });
      final resolvedTheme = theme ?? emojiTheme;
      applyTerminalTheme(terminal, resolvedTheme);
      final width = cols * metrics.cellWidth;
      final height = rows * metrics.cellHeight;
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = Size(width, height);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width, maxHeight: height),
              child: TerminalRenderer(
                terminal: terminal,
                frameChanges: frameChanges,
                theme: resolvedTheme,
                metrics: metrics,
                offset: ViewportOffset.zero(),
                atlasPool: atlasPool(),
                focused: focused,
                onGeometryChanged: SurfaceGeometry.tryFrom,
                onViewportRowChanged: (_) {},
              ),
            ),
          ),
        ),
      );
    }

    late CellMetrics metrics;

    setUp(() {
      metrics = measureCellMetrics(
        fontFamily: baseTheme.fontFamily,
        fontSize: baseTheme.fontSize,
        fontData: jetBrainsMonoBytes,
      );
    });

    group('Emoji grid', () {
      testWidgets('10x10 diverse emoji grid', (tester) async {
        const gridCols = 22;
        const gridRows = 10;
        final terminal = Terminal(cols: gridCols, rows: gridRows);
        addTearDown(terminal.dispose);

        // dart format off
        writeEmojiGrid(terminal, [
          [0x1F600, 0x1F603, 0x1F604, 0x1F601, 0x1F606, 0x1F605, 0x1F602, 0x1F923, 0x1F60A, 0x1F607],
          [0x1F642, 0x1F643, 0x1F609, 0x1F60C, 0x1F60D, 0x1F970, 0x1F618, 0x1F617, 0x1F619, 0x1F61A],
          [0x1F60B, 0x1F61B, 0x1F61C, 0x1F92A, 0x1F61D, 0x1F911, 0x1F917, 0x1F92D, 0x1F92B, 0x1F914],
          [0x1F910, 0x1F928, 0x1F610, 0x1F611, 0x1F636, 0x1F60F, 0x1F612, 0x1F644, 0x1F62C, 0x1F925],
          [0x1F634, 0x1F637, 0x1F912, 0x1F915, 0x1F922, 0x1F92E, 0x1F927, 0x1F975, 0x1F976, 0x1F974],
          [0x1F635, 0x1F92F, 0x1F920, 0x1F973, 0x1F978, 0x1F60E, 0x1F913, 0x1F615, 0x1F61F, 0x1F62E],
          [0x1F62F, 0x1F632, 0x1F633, 0x1F97A, 0x1F626, 0x1F627, 0x1F628, 0x1F630, 0x1F625, 0x1F622],
          [0x1F62D, 0x1F631, 0x1F616, 0x1F623, 0x1F61E, 0x1F613, 0x1F629, 0x1F62B, 0x1F971, 0x1F624],
          [0x1F621, 0x1F620, 0x1F92C, 0x1F44D, 0x1F44E, 0x1F44C, 0x1F90C, 0x1F90F, 0x1F91E, 0x1F919],
          [0x1F44B, 0x1F91A, 0x1F596, 0x1F44F, 0x1F64F, 0x1F91D, 0x1F525, 0x1F680, 0x1F4AF, 0x2705],
        ]);
        // dart format on

        await pumpRenderer(
          tester,
          terminal,
          metrics,
          cols: gridCols,
          rows: gridRows,
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/emoji_grid_10x10.png'),
        );
      });

      testWidgets('mixed content: emoji, CJK, ASCII, VS16', (tester) async {
        final terminal = Terminal(cols: defaultCols, rows: defaultRows);
        addTearDown(terminal.dispose);
        terminal.modeSet(const TerminalMode.graphemeCluster(), value: true);

        writeUtf8(terminal, 'A');
        writeCodepoint(terminal, 0x2705);
        writeUtf8(terminal, 'B');
        writeCodepoint(terminal, 0x1F602);
        writeUtf8(terminal, 'C');
        writeCodepoint(terminal, 0x274C);
        writeUtf8(terminal, 'D');
        writeUtf8(terminal, '\r\n');
        // dart format off
        writeRawBytes(terminal, [
          0xE6, 0x97, 0xA5,
          0xE6, 0x9C, 0xAC,
          0xE8, 0xAA, 0x9E,
          0xE4, 0xB8, 0xAD,
          0xE6, 0x96, 0x87,
        ]);
        // dart format on
        writeUtf8(terminal, '\r\n');
        // dart format off
        writeRawBytes(terminal, [
          ...utf8.encode('I '),
          0xE2, 0x9D, 0xA4, 0xEF, 0xB8, 0x8F,
          ...utf8.encode(' Dart'),
        ]);
        // dart format on
        writeUtf8(terminal, '\r\n');
        writeRawBytes(terminal, [0xE6, 0x97, 0xA5]);
        writeCodepoint(terminal, 0x2705);
        writeRawBytes(terminal, [0xE6, 0x9C, 0xAC]);
        writeCodepoint(terminal, 0x1F602);
        writeRawBytes(terminal, [0xE8, 0xAA, 0x9E]);

        await pumpRenderer(tester, terminal, metrics, theme: mixedTheme);
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/emoji_grid_mixed.png'),
        );
      });
    });

    group('VS16 emoji', () {
      testWidgets('VS16 emoji grid with mode 2027', (tester) async {
        // dart format off
        const vs16Codepoints = [
          0x231A, 0x231B, 0x23E9, 0x23EA, 0x23F0, 0x23F3, 0x25AA, 0x25AB, 0x25B6, 0x25C0,
          0x25FB, 0x25FC, 0x25FD, 0x25FE, 0x2600, 0x2601, 0x2602, 0x2603, 0x2604, 0x260E,
          0x2614, 0x2615, 0x261D, 0x2620, 0x2622, 0x2623, 0x2626, 0x262A, 0x262E, 0x262F,
          0x2639, 0x263A, 0x2648, 0x2649, 0x264A, 0x264B, 0x264C, 0x264D, 0x2660, 0x2663,
          0x2665, 0x2666, 0x2668, 0x267B, 0x267F, 0x2692, 0x2693, 0x2694, 0x2695, 0x2696,
          0x2697, 0x2699, 0x269B, 0x269C, 0x26A0, 0x26A1, 0x26BD, 0x26BE, 0x26C4, 0x26C5,
          0x26D4, 0x26EA, 0x26F2, 0x26F3, 0x26F5, 0x26FA, 0x26FD, 0x2702, 0x2708, 0x2709,
          0x270C, 0x270D, 0x270F, 0x2712, 0x2714, 0x2716, 0x2728, 0x2744, 0x274C, 0x274E,
          0x2753, 0x2757, 0x2763, 0x2764, 0x2795, 0x2796, 0x27A1, 0x2934, 0x2935, 0x2B05,
          0x2B06, 0x2B07, 0x2B50, 0x2B55,
        ];
        // dart format on

        const gridCols = 40;
        const gridRows = 10;
        final terminal = Terminal(cols: gridCols, rows: gridRows);
        addTearDown(terminal.dispose);
        terminal.modeSet(const TerminalMode.graphemeCluster(), value: true);

        for (final codepoint in vs16Codepoints) {
          writeRawBytes(
            terminal,
            utf8.encode(String.fromCharCodes([codepoint, 0xFE0F])),
          );
        }

        await pumpRenderer(
          tester,
          terminal,
          metrics,
          cols: gridCols,
          rows: gridRows,
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/emoji_vs16_grid.png'),
        );
      });

      testWidgets('VS16 mixed content', (tester) async {
        const cols = 25;
        const rows = 2;
        final terminal = Terminal(cols: cols, rows: rows);
        addTearDown(terminal.dispose);
        terminal.modeSet(const TerminalMode.graphemeCluster(), value: true);

        // dart format off
        writeRawBytes(terminal, [
          ...utf8.encode('A'),
          0xE2, 0x9D, 0xA4, 0xEF, 0xB8, 0x8F,
          ...utf8.encode('B'),
        ]);
        // dart format on
        writeUtf8(terminal, '\r\n');

        writeCodepoint(terminal, 0x1F602);
        writeRawBytes(terminal, [0xE2, 0x9D, 0xA4, 0xEF, 0xB8, 0x8F]);
        writeCodepoint(terminal, 0x2705);
        // dart format off
        writeRawBytes(terminal, [
          0xE2, 0x9C, 0x8C, 0xEF, 0xB8, 0x8F,
          0xE2, 0x98, 0xBA, 0xEF, 0xB8, 0x8F,
        ]);
        // dart format on

        await pumpRenderer(tester, terminal, metrics, rows: rows);
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/emoji_vs16.png'),
        );
      });
    });

    group('RenderStateCursor on emoji', () {
      testWidgets('block cursor on standard wide emoji', (tester) async {
        final terminal = Terminal(cols: defaultCols, rows: defaultRows);
        addTearDown(terminal.dispose);
        writeRawBytes(terminal, [
          ...utf8.encode('AB'),
          ...utf8.encode(String.fromCharCode(0x2705)),
          ...utf8.encode('CD'),
          ...utf8.encode('\x1b[1;3H'),
        ]);

        await pumpRenderer(tester, terminal, metrics, theme: emojiCursorTheme);
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/emoji_cursor_block_on_emoji.png'),
        );
      });

      testWidgets('block cursor on VS16 emoji with mode 2027', (tester) async {
        final terminal = Terminal(cols: defaultCols, rows: defaultRows);
        addTearDown(terminal.dispose);
        terminal.modeSet(const TerminalMode.graphemeCluster(), value: true);
        // dart format off
        writeRawBytes(terminal, [
          ...utf8.encode('AB'),
          0xE2, 0x9D, 0xA4, 0xEF, 0xB8, 0x8F,
          ...utf8.encode('CD'),
          ...utf8.encode('\x1b[1;3H'),
        ]);
        // dart format on

        await pumpRenderer(tester, terminal, metrics, theme: emojiCursorTheme);
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/emoji_cursor_block_on_vs16.png'),
        );
      });

      testWidgets('block cursor on CJK character', (tester) async {
        final terminal = Terminal(cols: defaultCols, rows: defaultRows);
        addTearDown(terminal.dispose);
        // dart format off
        writeRawBytes(terminal, [
          ...utf8.encode('AB'),
          0xE6, 0x97, 0xA5,
          ...utf8.encode('CD'),
          ...utf8.encode('\x1b[1;3H'),
        ]);
        // dart format on

        await pumpRenderer(tester, terminal, metrics, theme: cjkCursorTheme);
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/emoji_cursor_block_on_cjk.png'),
        );
      });
    });

    group('Selection over emoji', () {
      testWidgets('selection over mixed content with VS16', (tester) async {
        final terminal = Terminal(cols: defaultCols, rows: defaultRows);
        addTearDown(terminal.dispose);
        terminal.modeSet(const TerminalMode.graphemeCluster(), value: true);

        writeRawBytes(terminal, [
          ...utf8.encode('Hi'),
          ...utf8.encode(String.fromCharCode(0x2705)),
          ...utf8.encode('OK'),
        ]);
        writeCodepoint(terminal, 0x1F602);
        writeUtf8(terminal, '!');
        writeUtf8(terminal, '\r\n');
        // dart format off
        writeRawBytes(terminal, [
          ...utf8.encode('X'),
          0xE2, 0x9D, 0xA4, 0xEF, 0xB8, 0x8F,
          ...utf8.encode('Y'),
        ]);
        // dart format on

        await pumpRenderer(
          tester,
          terminal,
          metrics,
          selection: const TestSelection(
            start: Position(row: 0, col: 0),
            end: Position(row: 1, col: 3),
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/emoji_selection_mixed.png'),
        );
      });
    });

    group('Styled emoji', () {
      testWidgets('emoji styles and edge cases', (tester) async {
        const cols = 25;
        const rows = 7;
        final terminal = Terminal(cols: cols, rows: rows);
        addTearDown(terminal.dispose);

        writeUtf8(terminal, '\x1b[1mB');
        writeCodepoint(terminal, 0x2705);
        writeUtf8(terminal, '\x1b[0m\r\n');
        writeUtf8(terminal, '\x1b[2mF');
        writeCodepoint(terminal, 0x2705);
        writeUtf8(terminal, '\x1b[0m\r\n');
        writeUtf8(terminal, '\x1b[7mI');
        writeCodepoint(terminal, 0x2705);
        writeUtf8(terminal, '\x1b[0m\r\n');
        writeUtf8(terminal, '\x1b[4mU');
        writeCodepoint(terminal, 0x2705);
        writeUtf8(terminal, '\x1b[0m\r\n');
        writeUtf8(terminal, '\x1b[42;30m');
        writeCodepoint(terminal, 0x2705);
        writeCodepoint(terminal, 0x1F602);
        writeUtf8(terminal, '\x1b[0m\r\n');

        writeUtf8(terminal, 'AAAAAAAAAAAAAAAAAAAAAAA');
        writeCodepoint(terminal, 0x2705);

        await pumpRenderer(tester, terminal, metrics, rows: rows);
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/emoji_misc.png'),
        );
      });
    });

    group('Edge cases', () {
      testWidgets('dense emoji row with trailing ASCII', (tester) async {
        const cols = 25;
        const rows = 1;
        final terminal = Terminal(cols: cols, rows: rows);
        addTearDown(terminal.dispose);
        writeCodepoint(terminal, 0x2705);
        writeCodepoint(terminal, 0x274C);
        writeCodepoint(terminal, 0x1F602);
        writeCodepoint(terminal, 0x1F601);
        writeCodepoint(terminal, 0x1F44D);
        writeCodepoint(terminal, 0x1F44E);
        writeUtf8(terminal, 'end');

        await pumpRenderer(tester, terminal, metrics, rows: rows);
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/emoji_dense_no_drift.png'),
        );
      });
    });
  });
}
