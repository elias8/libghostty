@Tags(['ffi'])
library;

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flterm/src/foundation.dart';
import 'package:flterm/src/rendering/atlas/atlas.dart';
import 'package:flterm/src/rendering/atlas_pool.dart';
import 'package:flterm/src/rendering/terminal_surface.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart';

import 'helpers/font_loader.dart';

void main() {
  setUpAll(loadBundledFonts);

  testWidgets(
    'large cold metrics and live glyphs can exceed atlas dimensions',
    (tester) async {
      await tester.runAsync(() async {
        final terminal = Terminal(cols: 2, rows: 1);
        final pool = AtlasPool();
        TerminalSurface? surface;
        try {
          surface = _surface(
            pool,
            terminal,
            const CellMetrics(
              cellWidth: 5000,
              cellHeight: 5000,
              baseline: 4000,
            ),
          );
          terminal.write(
            Uint8List.fromList(
              utf8.encode('\x1b]11;#1d1f21\x07\x1b]10;#c5c8c6\x07\x1b[?25lA'),
            ),
          );
          _expectInk(await _pixels(surface, terminal));
        } finally {
          surface?.dispose();
          pool.dispose();
          terminal.dispose();
        }
      });
    },
  );

  testWidgets('historical diversity never prevents production surface paint', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final terminal = Terminal(cols: 2, rows: 1);
      final pool = AtlasPool();
      TerminalSurface? surface;
      try {
        const metrics = CellMetrics(
          cellWidth: 320,
          cellHeight: 320,
          baseline: 250,
        );
        surface = _surface(pool, terminal, metrics);
        for (var mark = 0x300; mark < 0x320; mark++) {
          final content = '\u03b1${String.fromCharCode(mark)}';
          terminal.write(
            Uint8List.fromList(
              utf8.encode(
                '\x1b]11;#1d1f21\x07\x1b]10;#c5c8c6\x07'
                '\x1b[?25l\x1b[2J\x1b[H$content',
              ),
            ),
          );
          surface.requestTerminalSync();
          final actual = await _pixels(surface, terminal, fullResolution: true);
          _expectInk(actual);
          final referenceTerminal = Terminal(cols: 2, rows: 1);
          final referencePool = AtlasPool();
          TerminalSurface? reference;
          try {
            reference = _surface(referencePool, referenceTerminal, metrics);
            _write(referenceTerminal, content);
            expect(
              actual,
              orderedEquals(
                await _pixels(
                  reference,
                  referenceTerminal,
                  fullResolution: true,
                ),
              ),
              reason: 'The current grapheme $content must survive atlas churn.',
            );
          } finally {
            reference?.dispose();
            referencePool.dispose();
            referenceTerminal.dispose();
          }
          final native = RenderState();
          final rows = RowIterator();
          final cells = CellIterator();
          try {
            // Observe after paint: native update consumes dirty flags.
            native.update(terminal);
            rows.reset(native);
            expect(rows.next(), isTrue);
            cells.reset(rows);
            expect(cells.next(), isTrue);
            expect(cells.content, content);
          } finally {
            cells.dispose();
            rows.dispose();
            native.dispose();
          }
        }
      } finally {
        surface?.dispose();
        pool.dispose();
        terminal.dispose();
      }
    });
  });
  testWidgets(
    'clean focus refresh publishes a newly admitted shaped cursor glyph',
    (tester) async {
      await tester.runAsync(() async {
        const metrics = CellMetrics(
          cellWidth: 32,
          cellHeight: 32,
          baseline: 25,
        );
        final pool = AtlasPool();
        final terminal = Terminal(cols: 2, rows: 1);
        final surface = _surface(pool, terminal, metrics);
        final lease = pool.acquireAtlas(
          AtlasConfig.fromTheme(
            theme: surface.theme,
            metrics: metrics,
            devicePixelRatio: 1,
          ),
        );
        try {
          terminal.write(Uint8List.fromList(utf8.encode('==\x1b[H')));
          await _pixels(surface, terminal);
          expect(lease.atlas.textImage, isNull);
          surface.updateFocused(focused: true);
          final focused = await _pixels(surface, terminal);
          expect(lease.atlas.textImage, isNotNull);
          surface.requestTerminalSync();
          expect(await _pixels(surface, terminal), orderedEquals(focused));
        } finally {
          surface.dispose();
          lease.release();
          pool.dispose();
          terminal.dispose();
        }
      });
    },
  );

  for (final cellSize in [320.0, 1100.0]) {
    testWidgets(
      'shared clean and held peers retain exact pixels at $cellSize cells',
      (tester) async {
        await tester.runAsync(() async {
          final metrics = CellMetrics(
            cellWidth: cellSize,
            cellHeight: cellSize,
            baseline: cellSize * .78,
          );
          final pool = AtlasPool();
          final changing = Terminal(cols: 2, rows: 1);
          final peer = Terminal(cols: 2, rows: 1);
          final first = _surface(pool, changing, metrics);
          final retained = _surface(pool, peer, metrics);
          try {
            _write(peer, 'B');
            final baseline = await _pixels(retained, peer);
            _expectInk(baseline);
            expect(retained.captureRenderHold(peer), isTrue);
            for (var mark = 0x300; mark < 0x310; mark++) {
              _write(changing, '\u03b1${String.fromCharCode(mark)}');
              first.requestTerminalSync();
              _expectInk(await _pixels(first, changing));
            }
            expect(await _pixels(retained, peer), orderedEquals(baseline));
            retained.releaseRenderHold();
            expect(await _pixels(retained, peer), orderedEquals(baseline));
            retained.updateBlinkVisible(visible: false);
            expect(await _pixels(retained, peer), orderedEquals(baseline));
            expect(retained.captureRenderHold(peer), isTrue);
            _write(peer, 'C');
            retained.requestTerminalSync();
            expect(await _pixels(retained, peer), orderedEquals(baseline));
            retained.releaseRenderHold();
            final fresh = await _pixels(retained, peer);
            _expectInk(fresh);
            final referenceTerminal = Terminal(cols: 2, rows: 1);
            final reference = _surface(pool, referenceTerminal, metrics);
            try {
              _write(referenceTerminal, 'C');
              expect(
                fresh,
                orderedEquals(await _pixels(reference, referenceTerminal)),
              );
            } finally {
              reference.dispose();
              referenceTerminal.dispose();
            }
          } finally {
            first.dispose();
            retained.dispose();
            pool.dispose();
            changing.dispose();
            peer.dispose();
          }
        });
      },
    );
  }
}

TerminalSurface _surface(
  AtlasPool pool,
  Terminal terminal,
  CellMetrics metrics,
) {
  final surface = TerminalSurface(
    atlasPool: pool,
    theme: TerminalTheme.dark().copyWith(fontSize: metrics.cellHeight * .75),
    metrics: metrics,
    devicePixelRatio: 1,
    focused: false,
    onImageReady: () {},
  );
  surface.layout(
    terminal: terminal,
    constraints: BoxConstraints.tightFor(
      width: metrics.cellWidth * 2,
      height: metrics.cellHeight,
    ),
    surfacePadding: EdgeInsets.zero,
    onGeometryChanged: SurfaceGeometry.tryFrom,
  );
  return surface;
}

Future<Uint8List> _pixels(
  TerminalSurface surface,
  Terminal terminal, {
  bool fullResolution = false,
}) async {
  final width = fullResolution
      ? (surface.metrics.cellWidth * surface.cols).ceil()
      : 128;
  final height = fullResolution
      ? (surface.metrics.cellHeight * surface.rows).ceil()
      : 128;
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder)
    ..clipRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));
  final scale = fullResolution
      ? 1.0
      : 128 / (surface.metrics.cellWidth * surface.cols);
  canvas.scale(scale);
  surface.draw(canvas, terminal);
  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(width, height);
    try {
      final data = (await image.toByteData())!;
      return Uint8List.fromList(data.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}

void _expectInk(Uint8List bytes) {
  var ink = 0;
  var background = 0;
  for (var offset = 0; offset < bytes.length; offset += 4) {
    if (bytes[offset + 3] == 0) continue;
    if (bytes[offset] == 29 &&
        bytes[offset + 1] == 31 &&
        bytes[offset + 2] == 33) {
      background++;
    } else {
      ink++;
    }
  }
  expect(
    ink,
    greaterThan(0),
    reason: 'The requested glyph must paint visible ink.',
  );
  expect(
    background,
    greaterThan(0),
    reason: 'The opaque terminal background must remain.',
  );
}

void _write(Terminal terminal, String content) {
  terminal.write(
    Uint8List.fromList(
      utf8.encode(
        '\x1b]11;#1d1f21\x07\x1b]10;#c5c8c6\x07\x1b[?25l\x1b[2J\x1b[H$content',
      ),
    ),
  );
}
