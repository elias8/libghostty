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

void main() {
  group('RenderStateCursor goldens', () {
    const cjkFallback = ['Noto Sans JP', 'JetBrains Mono'];
    const cols = 15;
    const emojiFallback = ['Noto Emoji', 'JetBrains Mono'];
    const rows = 3;

    AtlasPool atlasPool() {
      final pool = AtlasPool();
      addTearDown(pool.dispose);
      return pool;
    }

    TerminalTheme cursorTheme(
      CursorShape shape, {
      Color? color,
      List<String>? fallback,
    }) {
      return TerminalTheme.dark().copyWith(
        fontSize: 24.0,
        fontFamilyFallback: fallback ?? bundledFontFamilyFallback,
        cursor: CursorTheme(
          shape: shape,
          color: color == null ? null : DynamicColor.fixed(color),
          blinkInterval: const Duration(hours: 1),
        ),
      );
    }

    void writeRawBytes(Terminal terminal, List<int> bytes) {
      terminal.write(Uint8List.fromList(bytes));
    }

    void writeUtf8(Terminal terminal, String text) {
      writeRawBytes(terminal, utf8.encode(text));
    }

    Future<void> pumpRenderer(
      WidgetTester tester,
      Terminal terminal,
      CellMetrics metrics,
      TerminalTheme theme,
    ) async {
      applyTerminalTheme(terminal, theme);
      final width = cols * metrics.cellWidth;
      final height = rows * metrics.cellHeight;
      final frameChanges = ChangeNotifier();
      void onTerminalChanged() => frameChanges.notifyListeners();
      terminal.addListener(onTerminalChanged);
      addTearDown(() {
        terminal.removeListener(onTerminalChanged);
        frameChanges.dispose();
      });
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
                theme: theme,
                metrics: metrics,
                terminal: terminal,
                frameChanges: frameChanges,
                offset: ViewportOffset.zero(),
                atlasPool: atlasPool(),
                focused: true,
                onGeometryChanged: SurfaceGeometry.tryFrom,
                onViewportRowChanged: (_) {},
              ),
            ),
          ),
        ),
      );
    }

    setUpAll(loadBundledFonts);

    group('cursor shapes', () {
      late Terminal terminal;
      late CellMetrics metrics;

      setUp(() {
        terminal = Terminal(cols: cols, rows: rows);
        writeUtf8(terminal, 'Hello World!\r\n\x1b[1;4H');
        final theme = TerminalTheme.dark().copyWith(
          fontSize: 24.0,
          fontFamilyFallback: bundledFontFamilyFallback,
        );
        metrics = measureCellMetrics(
          fontFamily: theme.fontFamily,
          fontSize: theme.fontSize,
          fontData: jetBrainsMonoBytes,
        );
      });

      tearDown(() => terminal.dispose());

      testWidgets('block cursor', (tester) async {
        await pumpRenderer(
          tester,
          terminal,
          metrics,
          cursorTheme(CursorShape.block),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/cursor_block.png'),
        );
      });

      testWidgets('block hollow cursor', (tester) async {
        await pumpRenderer(
          tester,
          terminal,
          metrics,
          cursorTheme(CursorShape.blockHollow),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/cursor_block_hollow.png'),
        );
      });

      testWidgets('underline cursor', (tester) async {
        await pumpRenderer(
          tester,
          terminal,
          metrics,
          cursorTheme(CursorShape.underline),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/cursor_underline.png'),
        );
      });

      testWidgets('bar cursor', (tester) async {
        await pumpRenderer(
          tester,
          terminal,
          metrics,
          cursorTheme(CursorShape.bar),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/cursor_bar.png'),
        );
      });

      testWidgets('cursor with explicit color', (tester) async {
        await pumpRenderer(
          tester,
          terminal,
          metrics,
          cursorTheme(CursorShape.block, color: const Color(0xFF00FF88)),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/cursor_custom_color.png'),
        );
      });

      testWidgets('hidden cursor via DECTCEM', (tester) async {
        writeUtf8(terminal, '\x1b[?25l');
        await pumpRenderer(
          tester,
          terminal,
          metrics,
          cursorTheme(CursorShape.block),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/cursor_hidden.png'),
        );
      });
    });

    group('cursor on inverse text', () {
      late CellMetrics metrics;

      setUp(() {
        final theme = TerminalTheme.dark().copyWith(
          fontSize: 24.0,
          fontFamilyFallback: bundledFontFamilyFallback,
        );
        metrics = measureCellMetrics(
          fontFamily: theme.fontFamily,
          fontSize: theme.fontSize,
          fontData: jetBrainsMonoBytes,
        );
      });

      testWidgets('block cursor on inverse text', (tester) async {
        final terminal = Terminal(cols: cols, rows: rows);
        addTearDown(terminal.dispose);
        writeUtf8(terminal, '\x1b[7mHello\x1b[m World!\r\n\x1b[1;4H');

        await pumpRenderer(
          tester,
          terminal,
          metrics,
          cursorTheme(CursorShape.block),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/cursor_block_inverse.png'),
        );
      });

      testWidgets('block cursor on colored inverse text', (tester) async {
        final terminal = Terminal(cols: cols, rows: rows);
        addTearDown(terminal.dispose);
        writeUtf8(terminal, '\x1b[31;7mHello\x1b[m World!\r\n\x1b[1;2H');

        await pumpRenderer(
          tester,
          terminal,
          metrics,
          cursorTheme(CursorShape.block),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/cursor_block_colored_inverse.png'),
        );
      });
    });

    group('cursor on wide characters', () {
      late CellMetrics metrics;

      setUp(() {
        final theme = TerminalTheme.dark().copyWith(
          fontSize: 24.0,
          fontFamilyFallback: bundledFontFamilyFallback,
        );
        metrics = measureCellMetrics(
          fontFamily: theme.fontFamily,
          fontSize: theme.fontSize,
          fontData: jetBrainsMonoBytes,
        );
      });

      void writeEmojiCursorContent(Terminal terminal) {
        // dart format off
        writeRawBytes(terminal, [
          ...utf8.encode('AB'),
          0xE2, 0x9C, 0x85,
          ...utf8.encode('CD'),
          ...utf8.encode('\x1b[1;3H'),
        ]);
        // dart format on
      }

      testWidgets('block cursor on emoji', (tester) async {
        final terminal = Terminal(cols: cols, rows: rows);
        addTearDown(terminal.dispose);
        writeEmojiCursorContent(terminal);

        await pumpRenderer(
          tester,
          terminal,
          metrics,
          cursorTheme(CursorShape.block, fallback: emojiFallback),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/cursor_block_emoji.png'),
        );
      });

      testWidgets('hollow cursor on emoji', (tester) async {
        final terminal = Terminal(cols: cols, rows: rows);
        addTearDown(terminal.dispose);
        writeEmojiCursorContent(terminal);

        await pumpRenderer(
          tester,
          terminal,
          metrics,
          cursorTheme(CursorShape.blockHollow, fallback: emojiFallback),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/cursor_hollow_emoji.png'),
        );
      });

      testWidgets('block cursor on CJK character', (tester) async {
        final terminal = Terminal(cols: cols, rows: rows);
        addTearDown(terminal.dispose);
        // dart format off
        writeRawBytes(terminal, [
          ...utf8.encode('AB'),
          0xE6, 0x97, 0xA5,
          ...utf8.encode('CD'),
          ...utf8.encode('\x1b[1;3H'),
        ]);
        // dart format on

        await pumpRenderer(
          tester,
          terminal,
          metrics,
          cursorTheme(CursorShape.block, fallback: cjkFallback),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/cursor_block_wide.png'),
        );
      });

      testWidgets('underline cursor on wide char', (tester) async {
        final terminal = Terminal(cols: cols, rows: rows);
        addTearDown(terminal.dispose);
        writeEmojiCursorContent(terminal);

        await pumpRenderer(
          tester,
          terminal,
          metrics,
          cursorTheme(CursorShape.underline, fallback: emojiFallback),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/cursor_underline_emoji.png'),
        );
      });
    });
  });
}
