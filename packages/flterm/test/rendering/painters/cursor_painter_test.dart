@Tags(['ffi'])
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flterm/src/foundation.dart'
    show CellMetrics, CursorTheme, TerminalTheme;
import 'package:flterm/src/rendering/atlas/atlas.dart';
import 'package:flterm/src/rendering/paint_state.dart';
import 'package:flterm/src/rendering/painters/cursor_painter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart' show Cursor, CursorShape, Position;

void main() {
  group('CursorPainter', () {
    const metrics = CellMetrics(cellWidth: 8, cellHeight: 16, baseline: 12);
    const background = ui.Color(0xFFFF0000);

    AtlasConfig config() {
      return AtlasConfig(
        fontSize: 14,
        fontWeight: ui.FontWeight.normal,
        fontFamily: 'monospace',
        fontFamilyFallback: const [],
        metrics: metrics,
        devicePixelRatio: 1.0,
      );
    }

    Future<ByteData> render({
      bool preeditActive = false,
      Cursor cursor = const Cursor(),
      CursorTheme? cursorTheme,
    }) async {
      final atlas = Atlas(config());
      addTearDown(atlas.dispose);
      final theme = TerminalTheme.dark().copyWith(cursor: cursorTheme);
      final state = TerminalPaintState(theme, metrics)
        ..cols = 2
        ..rows = 1
        ..cursor = cursor
        ..cursorColorArgb = 0xFF0000FF
        ..preeditActive = preeditActive;

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, 16, 16),
        ui.Paint()..color = background,
      );
      CursorPainter(state, atlas).paint(canvas);
      final picture = recorder.endRecording();
      final image = await picture.toImage(16, 16);
      final bytes = await image.toByteData();
      picture.dispose();
      image.dispose();
      return bytes!;
    }

    int pixel(ByteData bytes, {required int x, required int y}) {
      final offset = (y * 16 + x) * 4;
      final r = bytes.getUint8(offset);
      final g = bytes.getUint8(offset + 1);
      final b = bytes.getUint8(offset + 2);
      final a = bytes.getUint8(offset + 3);
      return (a << 24) | (r << 16) | (g << 8) | b;
    }

    group('paint', () {
      test('paints cursor when preedit is inactive', () async {
        final bytes = await render();

        final cursorPixel = pixel(bytes, x: 1, y: 1);

        expect(cursorPixel, 0xFF0000FF);
      });

      test('skips cursor when preedit is active', () async {
        final bytes = await render(preeditActive: true);

        final cursorPixel = pixel(bytes, x: 1, y: 1);

        expect(cursorPixel, 0xFFFF0000);
      });

      test('keeps hollow cursor stroke inside its cell', () async {
        final bytes = await render(
          cursor: const Cursor(
            position: Position(row: 0, col: 1),
            shape: CursorShape.blockHollow,
          ),
        );

        expect(pixel(bytes, x: 12, y: 0), 0xFF0000FF);
        expect(pixel(bytes, x: 15, y: 8), 0xFF0000FF);
      });

      test('uses the configured bar cursor width ratio', () async {
        final bytes = await render(
          cursor: const Cursor(shape: CursorShape.bar),
          cursorTheme: const CursorTheme(barWidthRatio: 0.5),
        );

        expect(pixel(bytes, x: 3, y: 8), 0xFF0000FF);
        expect(pixel(bytes, x: 4, y: 8), 0xFFFF0000);
      });
    });
  });
}
