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
  setUpAll(loadBundledFonts);

  group('Background opacity', () {
    const backdrop = Color(0xFFFF2030);
    const cols = 20;
    const explicitBgAnsi = '\x1b[48;2;40;200;80m';
    const metrics = CellMetrics(cellWidth: 8, cellHeight: 16, baseline: 12);
    const rows = 5;
    final sceneKey = GlobalKey();

    AtlasPool atlasPool() {
      final pool = AtlasPool();
      addTearDown(pool.dispose);
      return pool;
    }

    void writeUtf8(Terminal terminal, String text) {
      terminal.write(Uint8List.fromList(utf8.encode(text)));
    }

    Future<void> expectGolden(String name) {
      return expectLater(
        find.byKey(sceneKey),
        matchesGoldenFile('goldens/$name'),
      );
    }

    Future<void> pumpScene(
      WidgetTester tester,
      TerminalTheme theme, {
      required String content,
    }) async {
      final terminal = Terminal(cols: cols, rows: rows);
      addTearDown(terminal.dispose);
      applyTerminalTheme(terminal, theme);
      final frameChanges = ChangeNotifier();
      void onTerminalChanged() => frameChanges.notifyListeners();
      terminal.addListener(onTerminalChanged);
      addTearDown(() {
        terminal.removeListener(onTerminalChanged);
        frameChanges.dispose();
      });
      writeUtf8(terminal, content);

      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: cols * metrics.cellWidth,
                maxHeight: rows * metrics.cellHeight,
              ),

              child: RepaintBoundary(
                key: sceneKey,
                child: ColoredBox(
                  color: backdrop,
                  child: ColoredBox(
                    color: theme.background.withValues(
                      alpha: theme.backgroundOpacity,
                    ),
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
              ),
            ),
          ),
        ),
      );
    }

    final baseTheme = TerminalTheme.dark().copyWith(
      fontFamilyFallback: bundledFontFamilyFallback,
    );

    testWidgets('opacity 1.0 paints fully opaque over backdrop', (
      tester,
    ) async {
      await pumpScene(tester, baseTheme, content: 'Hello');
      await expectGolden('transparent_baseline.png');
    });

    testWidgets('opacity 0.5 leaves explicit-bg cells opaque by default', (
      tester,
    ) async {
      await pumpScene(
        tester,
        baseTheme.copyWith(backgroundOpacity: 0.5),
        content: 'default bg\r\n${explicitBgAnsi}explicit bg\x1b[0m',
      );
      await expectGolden('transparent_default_cells.png');
    });

    testWidgets('opacity 0.5 with cells=true tints explicit bgs too', (
      tester,
    ) async {
      await pumpScene(
        tester,
        baseTheme.copyWith(
          backgroundOpacity: 0.5,
          backgroundOpacityCells: true,
        ),
        content: 'default bg\r\n${explicitBgAnsi}explicit bg\x1b[0m',
      );
      await expectGolden('transparent_all_cells.png');
    });

    testWidgets('inverse cells stay opaque even with cells=true', (
      tester,
    ) async {
      await pumpScene(
        tester,
        baseTheme.copyWith(
          backgroundOpacity: 0.5,
          backgroundOpacityCells: true,
        ),
        content: 'normal\r\n\x1b[7minverse\x1b[0m',
      );
      await expectGolden('transparent_inverse.png');
    });

    testWidgets('explicit bg matching theme.background stays opaque', (
      tester,
    ) async {
      await pumpScene(
        tester,
        baseTheme.copyWith(backgroundOpacity: 0.5),
        content: 'default bg\r\n\x1b[48;2;29;31;33mexplicit default\x1b[0m',
      );
      await expectGolden('transparent_explicit_default.png');
    });
  });
}
