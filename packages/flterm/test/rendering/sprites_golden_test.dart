@Tags(['ffi', 'golden'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flterm/src/foundation.dart';
import 'package:flterm/src/rendering.dart';
import 'package:flterm/src/rendering/atlas_pool.dart';
import 'package:flterm/src/rendering/sprite/sprite_face.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart';

import 'helpers/font_loader.dart';

void main() {
  setUpAll(loadBundledFonts);

  group('Sprite Goldens', () {
    const cols = 25;
    const rows = 5;

    List<int> inclusiveRange(int start, int end) => [
      for (var cp = start; cp <= end; cp++) cp,
    ];

    String codepointGridText(List<int> codepoints, int cols, int cellsPerSlot) {
      final buffer = StringBuffer();
      for (var i = 0; i < codepoints.length; i++) {
        final row = i ~/ cols;
        final col = i % cols;

        buffer.write('\x1B[${row + 1};${col * cellsPerSlot + 1}H');
        buffer.writeCharCode(codepoints[i]);
      }
      return buffer.toString();
    }

    List<int> geometricShapesCodepoints() {
      final face = SpriteFace();
      // dart format off
      return [
        ...inclusiveRange(0x25A0, 0x25FF),
        0x23BF, 0x23FA, 0x26AA, 0x26AB,
        0x2B1B, 0x2B1C, 0x2B24, 0x2B55,
      ].where(face.hasCodepoint).toList();
      // dart format on
    }

    List<int> legacyComputingCodepoints() => [
      ...inclusiveRange(0x1FB00, 0x1FBAF),
      ...inclusiveRange(0x1FBBD, 0x1FBBF),
      ...inclusiveRange(0x1FBCE, 0x1FBEF),
    ];

    List<int> legacySupplementCodepoints() => [
      ...inclusiveRange(0x1CC1B, 0x1CC1E),
      ...inclusiveRange(0x1CC21, 0x1CC2F),
      ...inclusiveRange(0x1CC30, 0x1CC3F),
      ...inclusiveRange(0x1CD00, 0x1CDE5),
      ...inclusiveRange(0x1CE00, 0x1CE01),
      ...inclusiveRange(0x1CE0B, 0x1CE0C),
      ...inclusiveRange(0x1CE16, 0x1CE19),
      ...inclusiveRange(0x1CE51, 0x1CE8F),
      ...inclusiveRange(0x1CE90, 0x1CEAF),
    ];

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
      required TerminalTheme theme,
      required CellMetrics metrics,
      double? maxWidth,
      double? maxHeight,
    }) {
      final frameChanges = ChangeNotifier();
      void onTerminalChanged() => frameChanges.notifyListeners();
      terminal.addListener(onTerminalChanged);
      addTearDown(() {
        terminal.removeListener(onTerminalChanged);
        frameChanges.dispose();
      });
      final width = maxWidth ?? cols * metrics.cellWidth;
      final height = maxHeight ?? rows * metrics.cellHeight;
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width, maxHeight: height),
            child: TerminalRenderer(
              terminal: terminal,
              frameChanges: frameChanges,
              theme: theme,
              metrics: metrics,
              offset: ViewportOffset.zero(),
              atlasPool: atlasPool(),
              focused: true,
              onGeometryChanged: SurfaceGeometry.tryFrom,
              onViewportRowChanged: (_) {},
            ),
          ),
        ),
      );
    }

    Future<void> pumpCodepointGrid(
      WidgetTester tester, {
      required TerminalTheme theme,
      required CellMetrics metrics,
      required List<int> codepoints,
      required int cols,
      int cellsPerSlot = 1,
    }) async {
      final rows = (codepoints.length + cols - 1) ~/ cols;
      final terminalCols = cols * cellsPerSlot;
      final terminal = Terminal(cols: terminalCols, rows: rows);
      addTearDown(terminal.dispose);
      applyTerminalTheme(terminal, theme);
      writeUtf8(terminal, codepointGridText(codepoints, cols, cellsPerSlot));
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        wrap(
          terminal,
          theme: theme,
          metrics: metrics,
          maxWidth: terminalCols * metrics.cellWidth,
          maxHeight: rows * metrics.cellHeight,
        ),
      );
    }

    final theme = TerminalTheme.dark().copyWith(
      fontSize: 24.0,
      fontFamilyFallback: bundledFontFamilyFallback,
    );
    late CellMetrics goldenMetrics;

    setUp(() {
      goldenMetrics = measureCellMetrics(
        fontFamily: theme.fontFamily,
        fontSize: theme.fontSize,
        fontData: jetBrainsMonoBytes,
      );
    });

    group('sprite grids', () {
      testWidgets('box drawing sheet', (tester) async {
        await pumpCodepointGrid(
          tester,
          theme: theme,
          metrics: goldenMetrics,
          codepoints: inclusiveRange(0x2500, 0x257F),
          cols: 16,
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/sprites_box_drawing.png'),
        );
      });

      testWidgets('block elements sheet', (tester) async {
        await pumpCodepointGrid(
          tester,
          theme: theme,
          metrics: goldenMetrics,
          codepoints: inclusiveRange(0x2580, 0x259F),
          cols: 16,
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/sprites_block_elements.png'),
        );
      });

      testWidgets('braille sheet', (tester) async {
        await pumpCodepointGrid(
          tester,
          theme: theme,
          metrics: goldenMetrics,
          codepoints: inclusiveRange(0x2800, 0x28FF),
          cols: 16,
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/sprites_braille.png'),
        );
      });

      testWidgets('geometric shapes sheet', (tester) async {
        await pumpCodepointGrid(
          tester,
          theme: theme,
          metrics: goldenMetrics,
          codepoints: geometricShapesCodepoints(),
          cols: 16,

          cellsPerSlot: 2,
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/sprites_geometric_shapes.png'),
        );
      });

      testWidgets('powerline sheet', (tester) async {
        await pumpCodepointGrid(
          tester,
          theme: theme,
          metrics: goldenMetrics,
          codepoints: [...inclusiveRange(0xE0B0, 0xE0BF), 0xE0D2, 0xE0D4],
          cols: 10,
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/sprites_powerline.png'),
        );
      });

      testWidgets('branch drawing sheet', (tester) async {
        await pumpCodepointGrid(
          tester,
          theme: theme,
          metrics: goldenMetrics,
          codepoints: inclusiveRange(0xF5D0, 0xF60D),
          cols: 16,
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/sprites_branch_drawing.png'),
        );
      });

      testWidgets('legacy computing sheet', (tester) async {
        await pumpCodepointGrid(
          tester,
          theme: theme,
          metrics: goldenMetrics,
          codepoints: legacyComputingCodepoints(),
          cols: 16,
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/sprites_legacy_computing.png'),
        );
      });

      testWidgets('legacy computing supplement sheet', (tester) async {
        await pumpCodepointGrid(
          tester,
          theme: theme,
          metrics: goldenMetrics,
          codepoints: legacySupplementCodepoints(),
          cols: 16,
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/sprites_legacy_computing_supplement.png'),
        );
      });
    });

    group('integration', () {
      testWidgets('mixed sprite showcase', (tester) async {
        const cols = 40;
        const rows = 9;
        final terminal = Terminal(cols: cols, rows: rows);
        addTearDown(terminal.dispose);
        applyTerminalTheme(terminal, theme);
        writeUtf8(
          terminal,
          'Box: ┌────────┐ ╞═╪═╡\r\n'
          '     │ sprite │ └────┘\r\n'
          'Blk: █▓▒░ ▖▗▘▙▚▛▜▝▞▟\r\n'
          'Brl: ⠁⠃⠇⡇⣇⣷⣿\r\n'
          'Geo: ■□▲▶◆○●⚪⚫⬛⭕\r\n'
          'Brn: ${String.fromCharCode(0xF5D0)}${String.fromCharCode(0xF5D6)}'
          '${String.fromCharCode(0xF5DA)}${String.fromCharCode(0xF5EE)}'
          '${String.fromCharCode(0xF60D)}\r\n'
          'Leg: ${String.fromCharCode(0x1FB00)}${String.fromCharCode(0x1FB3C)}'
          '${String.fromCharCode(0x1FB68)}${String.fromCharCode(0x1FB95)}'
          '${String.fromCharCode(0x1FBD0)}${String.fromCharCode(0x1FBEF)}\r\n'
          'Sup: ${String.fromCharCode(0x1CC21)}${String.fromCharCode(0x1CD00)}'
          '${String.fromCharCode(0x1CE00)}${String.fromCharCode(0x1CE51)}'
          '${String.fromCharCode(0x1CE90)}\r\n'
          'Pwr: \x1b[44;37m main \x1b[0m${String.fromCharCode(0xE0B0)}'
          '\x1b[30;42m src \x1b[0m${String.fromCharCode(0xE0B0)}'
          '\x1b[30;47m test \x1b[0m',
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
          matchesGoldenFile('goldens/sprites_showcase.png'),
        );
      });

      testWidgets('block cursor on sprite glyph', (tester) async {
        final terminal = Terminal(cols: cols, rows: rows);
        addTearDown(terminal.dispose);
        applyTerminalTheme(terminal, theme);
        writeUtf8(terminal, 'AB─CD\x1b[1;3H');
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(
          wrap(
            terminal,
            theme: theme.copyWith(
              cursor: const CursorTheme(blinkInterval: Duration(hours: 1)),
            ),
            metrics: goldenMetrics,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/sprites_cursor.png'),
        );
      });
    });
  });
}
