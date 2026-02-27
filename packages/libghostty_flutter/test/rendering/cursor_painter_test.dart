@Tags(['ffi'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart';
import 'package:libghostty_flutter/foundation.dart';
import 'package:libghostty_flutter/rendering.dart';

void main() {
  group('Cursor shape goldens', () {
    late Terminal terminal;

    setUp(() {
      terminal = Terminal(cols: _cols, rows: _rows);
      terminal.write(.fromList(utf8.encode('Hello World!\r\n\x1b[1;4H')));
    });

    tearDown(() => terminal.dispose());

    testWidgets('block cursor', (tester) async {
      await _pump(tester, terminal, _cursorTheme(CursorShape.block));
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/cursor_block.png'),
      );
    });

    testWidgets('block hollow cursor', (tester) async {
      await _pump(tester, terminal, _cursorTheme(CursorShape.blockHollow));
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/cursor_block_hollow.png'),
      );
    });

    testWidgets('underline cursor', (tester) async {
      await _pump(tester, terminal, _cursorTheme(CursorShape.underline));
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/cursor_underline.png'),
      );
    });

    testWidgets('bar cursor', (tester) async {
      await _pump(tester, terminal, _cursorTheme(CursorShape.bar));
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/cursor_bar.png'),
      );
    });

    testWidgets('cursor with explicit color', (tester) async {
      await _pump(
        tester,
        terminal,
        _cursorTheme(CursorShape.block, color: const Color(0xFF00FF88)),
      );
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/cursor_custom_color.png'),
      );
    });

    testWidgets('hidden cursor', (tester) async {
      terminal.write(Uint8List.fromList(utf8.encode('\x1b[?25l')));
      await _pump(tester, terminal, _cursorTheme(CursorShape.block));
      await expectLater(
        find.byType(TerminalRenderer),
        matchesGoldenFile('goldens/cursor_hidden.png'),
      );
    });
  });
}

const _rows = 3;
const _cols = 15;
const _metrics = CellMetrics(cellWidth: 8, cellHeight: 16, baseline: 12);

TerminalTheme _cursorTheme(CursorShape shape, {Color? color}) {
  return TerminalTheme.defaults.copyWith(
    cursor: CursorTheme(
      shape: shape,
      color: color,
      blinkInterval: const Duration(hours: 1),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Terminal terminal,
  TerminalTheme theme,
) async {
  final w = _cols * _metrics.cellWidth;
  final h = _rows * _metrics.cellHeight;
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(w, h);
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
          constraints: BoxConstraints(maxWidth: w, maxHeight: h),
          child: TerminalRenderer(
            terminal: terminal,
            theme: theme,
            metrics: _metrics,
          ),
        ),
      ),
    ),
  );
}
