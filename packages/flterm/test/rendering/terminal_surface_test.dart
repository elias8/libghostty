@Tags(['ffi'])
library;

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flterm/src/foundation/cell_metrics.dart';
import 'package:flterm/src/foundation/cell_range.dart';
import 'package:flterm/src/foundation/surface_geometry.dart';
import 'package:flterm/src/foundation/terminal_theme.dart';
import 'package:flterm/src/links/link_snapshot.dart';
import 'package:flterm/src/rendering/atlas/atlas.dart' show AtlasConfig;
import 'package:flterm/src/rendering/atlas_pool.dart';
import 'package:flterm/src/rendering/terminal_surface.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart';

void main() {
  group('TerminalSurface', () {
    const metrics = CellMetrics(cellWidth: 8, cellHeight: 16, baseline: 12);
    late AtlasPool pool;
    late Terminal terminal;
    late TerminalSurface pipeline;

    AtlasConfig config({TerminalTheme? theme}) {
      return .fromTheme(
        theme: theme ?? TerminalTheme.dark(),
        metrics: metrics,
        devicePixelRatio: 1,
      );
    }

    void paint(
      TerminalSurface subject,
      Terminal terminal, {
      LinkSnapshot links = .empty,
    }) {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      subject.draw(canvas, terminal, linkSnapshot: links);
      recorder.endRecording().dispose();
    }

    void writeUtf8(String text) {
      terminal.write(Uint8List.fromList(utf8.encode(text)));
    }

    setUp(() {
      pool = AtlasPool();
      terminal = Terminal(cols: 8, rows: 2);
      pipeline = TerminalSurface(
        atlasPool: pool,
        theme: TerminalTheme.dark(),
        metrics: metrics,
        devicePixelRatio: 1,
        onImageReady: () {},
      );
      pipeline.layout(
        terminal: terminal,
        constraints: const BoxConstraints(maxWidth: 64, maxHeight: 32),
        surfacePadding: EdgeInsets.zero,
        onGeometryChanged: SurfaceGeometry.tryFrom,
      );
    });

    tearDown(() {
      pipeline.dispose();
      pool.dispose();
      terminal.dispose();
    });

    group('undersized surfaces', () {
      for (final (name, size) in [
        ('zero width', const Size(0, 32)),
        ('zero height', const Size(64, 0)),
        ('sub-cell width', const Size(7, 32)),
        ('sub-cell height', const Size(64, 15)),
      ]) {
        test('suppresses painting only while the surface has $name', () {
          writeUtf8('visible content');
          paint(pipeline, terminal);
          final collapsed = TestRecordingCanvas();
          final expanded = TestRecordingCanvas();

          pipeline.layout(
            terminal: terminal,
            constraints: BoxConstraints.tight(size),
            surfacePadding: .zero,
            onGeometryChanged: SurfaceGeometry.tryFrom,
          );
          pipeline.draw(collapsed, terminal);
          pipeline.layout(
            terminal: terminal,
            constraints: const BoxConstraints.tightFor(width: 64, height: 32),
            surfacePadding: .zero,
            onGeometryChanged: SurfaceGeometry.tryFrom,
          );
          pipeline.draw(expanded, terminal);

          expect(
            [collapsed.invocations, expanded.invocations],
            [isEmpty, isNotEmpty],
          );
        });
      }
    });

    group('sync', () {
      test('retains native grid when geometry callback declines', () {
        final fallback = TerminalSurface(
          atlasPool: pool,
          theme: TerminalTheme.dark(),
          metrics: metrics,
          devicePixelRatio: 1,
          onImageReady: () {},
        );
        addTearDown(fallback.dispose);

        fallback.layout(
          terminal: terminal,
          constraints: const BoxConstraints(maxWidth: 64, maxHeight: 32),
          surfacePadding: EdgeInsets.zero,
          onGeometryChanged: (_) => null,
        );

        expect((cols: fallback.cols, rows: fallback.rows), (cols: 8, rows: 2));
      });

      test('prepares the terminal cursor caret', () {
        writeUtf8('A\x1b[1;2H');

        paint(pipeline, terminal);

        expect(pipeline.textInputCaretRect, const Rect.fromLTWH(8, 0, 8, 16));
      });

      test('paints a frame containing a selection', () {
        writeUtf8('hello');
        terminal.selection = Selection.fromRefs(
          start: GridRef.at(terminal, const Position(row: 0, col: 1)),
          end: GridRef.at(terminal, const Position(row: 0, col: 2)),
        );

        paint(pipeline, terminal);

        expect(() => paint(pipeline, terminal), returnsNormally);
      });

      test('paints a frame containing a prepared link snapshot', () {
        writeUtf8('https://a.test');
        final links = LinkSnapshot.highlighted(
          const CellRange(
            start: Position(row: 0, col: 0),
            end: Position(row: 0, col: 13),
          ),
        );

        paint(pipeline, terminal, links: links);

        expect(() => paint(pipeline, terminal, links: links), returnsNormally);
      });
    });

    group('atlas lease', () {
      test('keeps a shared atlas alive', () {
        final sharedLease = pool.acquireAtlas(config());
        final sharedAtlas = sharedLease.atlas;

        sharedLease.release();

        expect(sharedAtlas.textImage, isNotNull);
      });

      test('releases the atlas on disposal', () {
        final sharedLease = pool.acquireAtlas(config());
        final sharedAtlas = sharedLease.atlas;
        sharedLease.release();

        pipeline.dispose();

        expect(sharedAtlas.textImage, isNull);
      });

      test('rebinds after atlas configuration changes', () {
        final oldLease = pool.acquireAtlas(config());
        final oldAtlas = oldLease.atlas;
        oldLease.release();
        pipeline.updateTheme(TerminalTheme.dark().copyWith(fontSize: 16));

        pipeline.layout(
          terminal: terminal,
          constraints: const BoxConstraints(maxWidth: 64, maxHeight: 32),
          surfacePadding: EdgeInsets.zero,
          onGeometryChanged: SurfaceGeometry.tryFrom,
        );

        expect(oldAtlas.textImage, isNull);
      });
    });
  });
}
