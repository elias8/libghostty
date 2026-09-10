@Tags(['ffi'])
library;

import 'package:flterm/src/foundation/cell_metrics.dart' show CellMetrics;
import 'package:flterm/src/input/selection_handle_geometry.dart'
    show SelectionHandleGeometry, SelectionHandleLayout;
import 'package:flterm/src/input/selection_session.dart' show SelectionEndpoint;
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart'
    show GridRef, Position, Selection, Terminal;

void main() {
  group('SelectionHandleGeometry', () {
    const metrics = CellMetrics(cellWidth: 8, cellHeight: 16, baseline: 12);
    late Terminal terminal;

    setUp(() {
      terminal = Terminal(cols: 8, rows: 3);
      addTearDown(terminal.dispose);
    });

    void select({
      Position start = const Position(row: 1, col: 1),
      Position end = const Position(row: 1, col: 6),
      bool rectangle = false,
    }) {
      terminal.selection = Selection.fromRefs(
        start: GridRef.at(terminal, start),
        end: GridRef.at(terminal, end),
        rectangle: rectangle,
      );
    }

    SelectionHandleLayout layoutFor(SelectionEndpoint endpoint) {
      final layout = SelectionHandleGeometry.layout(
        terminal.selection!,
        metrics,
      );
      return switch (endpoint) {
        .start => layout.start!,
        .end => layout.end!,
      };
    }

    group('layout', () {
      test('anchors inclusive selection boundaries', () {
        select();

        final anchors = (
          start: layoutFor(.start).anchor,
          end: layoutFor(.end).anchor,
        );

        expect(anchors, (
          start: const Offset(8, 32),
          end: const Offset(56, 32),
        ));
      });

      test('anchors reversed endpoints by logical ownership', () {
        select(
          start: const Position(row: 1, col: 6),
          end: const Position(row: 1, col: 1),
        );

        final anchors = (
          start: layoutFor(.start).anchor,
          end: layoutFor(.end).anchor,
        );

        expect(anchors, (
          start: const Offset(56, 32),
          end: const Offset(8, 32),
        ));
      });

      test('anchors top-right to bottom-left rectangle endpoints', () {
        select(
          start: const Position(row: 0, col: 6),
          end: const Position(row: 2, col: 1),
          rectangle: true,
        );

        final anchors = (
          start: layoutFor(.start).anchor,
          end: layoutFor(.end).anchor,
        );

        expect(anchors, (
          start: const Offset(56, 16),
          end: const Offset(8, 48),
        ));
      });

      test('anchors bottom-left to top-right rectangle endpoints', () {
        select(
          start: const Position(row: 2, col: 1),
          end: const Position(row: 0, col: 6),
          rectangle: true,
        );

        final anchors = (
          start: layoutFor(.start).anchor,
          end: layoutFor(.end).anchor,
        );

        expect(anchors, (
          start: const Offset(8, 48),
          end: const Offset(56, 16),
        ));
      });
    });

    group('positionForDrag', () {
      test('returns the origin for a grid without columns', () {
        final position = SelectionHandleGeometry.positionForDrag(
          anchor: const Offset(56, 17),
          leading: false,
          metrics: metrics,
          columns: 0,
          rows: 3,
        );

        expect(position, const Position(row: 0, col: 0));
      });

      test('returns the origin for a grid without rows', () {
        final position = SelectionHandleGeometry.positionForDrag(
          anchor: const Offset(56, 17),
          leading: false,
          metrics: metrics,
          columns: 8,
          rows: 0,
        );

        expect(position, const Position(row: 0, col: 0));
      });

      test('returns the first cell for zero-sized cells', () {
        final position = SelectionHandleGeometry.positionForDrag(
          anchor: const Offset(56, 17),
          leading: false,
          metrics: const CellMetrics(cellWidth: 0, cellHeight: 0, baseline: 0),
          columns: 8,
          rows: 3,
        );

        expect(position, const Position(row: 0, col: 0));
      });

      test('clamps positions before the grid', () {
        final position = SelectionHandleGeometry.positionForDrag(
          anchor: const Offset(-8, -16),
          leading: true,
          metrics: metrics,
          columns: 8,
          rows: 3,
        );

        expect(position, const Position(row: 0, col: 0));
      });

      test('clamps positions after the grid', () {
        final position = SelectionHandleGeometry.positionForDrag(
          anchor: const Offset(80, 64),
          leading: false,
          metrics: metrics,
          columns: 8,
          rows: 3,
        );

        expect(position, const Position(row: 2, col: 7));
      });

      test('preserves mirrored trailing-edge snapping', () {
        final position = SelectionHandleGeometry.positionForDrag(
          anchor: const Offset(56, 17),
          leading: false,
          metrics: metrics,
          columns: 8,
          rows: 3,
        );

        expect(position, const Position(row: 1, col: 6));
      });
    });
  });
}
