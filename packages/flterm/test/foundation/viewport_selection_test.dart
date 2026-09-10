@Tags(['ffi'])
library;

import 'dart:typed_data';

import 'package:flterm/src/foundation/viewport_selection.dart'
    show ViewportSelection;
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart'
    show GridRef, Position, Selection, Terminal;

void main() {
  group('ViewportSelection', () {
    late Terminal terminal;

    setUp(() {
      terminal = Terminal(cols: 8, rows: 4);
    });

    tearDown(() {
      terminal.dispose();
    });

    Selection selection({bool reversed = false, bool rectangle = false}) {
      final start = GridRef.at(terminal, const Position(row: 0, col: 5));
      final end = GridRef.at(terminal, const Position(row: 2, col: 2));
      return Selection.fromRefs(
        start: reversed ? end : start,
        end: reversed ? start : end,
        rectangle: rectangle,
      );
    }

    group('resolve', () {
      for (final reversed in [false, true]) {
        test('projects contiguous rows with reversed=$reversed', () {
          final range = selection(reversed: reversed);

          final projected = ViewportSelection.resolve(
            range,
            rows: 4,
            cols: 8,
            viewportOffset: 0,
          )!;

          expect(
            [
              (projected.startColumn(0), projected.endColumn(0)),
              (projected.startColumn(1), projected.endColumn(1)),
              (projected.startColumn(2), projected.endColumn(2)),
            ],
            [(5, 8), (0, 8), (0, 3)],
          );
        });

        test('projects rectangular rows with reversed=$reversed', () {
          final range = selection(reversed: reversed, rectangle: true);

          final projected = ViewportSelection.resolve(
            range,
            rows: 4,
            cols: 8,
            viewportOffset: 0,
          )!;

          expect(
            [
              (projected.startColumn(0), projected.endColumn(0)),
              (projected.startColumn(1), projected.endColumn(1)),
              (projected.startColumn(2), projected.endColumn(2)),
            ],
            [(2, 6), (2, 6), (2, 6)],
          );
        });
      }

      test('clips rows to the measured viewport', () {
        final range = selection();

        final projected = ViewportSelection.resolve(
          range,
          rows: 2,
          cols: 8,
          viewportOffset: 0,
        )!;

        expect((projected.firstRow, projected.lastRow), (0, 1));
      });

      for (final bounds in const [
        (start: 1, end: 3, expected: (0, 1, 0, 3)),
        (start: 3, end: 6, expected: (1, 3, 5, 8)),
      ]) {
        test('clips history rows ${bounds.start} through ${bounds.end}', () {
          terminal.write(
            Uint8List.fromList(
              '0\r\n1\r\n2\r\n3\r\n4\r\n5\r\n6\r\n7'.codeUnits,
            ),
          );
          terminal.scrollToRow(2);
          final range = Selection.fromRefs(
            start: GridRef.at(
              terminal,
              Position(row: bounds.start, col: 5),
              pointTag: .screen,
            ),
            end: GridRef.at(
              terminal,
              Position(row: bounds.end, col: 2),
              pointTag: .screen,
            ),
          );

          final projected = ViewportSelection.resolve(
            range,
            rows: 4,
            cols: 8,
            viewportOffset: 2,
          )!;

          expect((
            projected.firstRow,
            projected.lastRow,
            projected.startColumn(projected.firstRow),
            projected.endColumn(projected.lastRow),
          ), bounds.expected);
        });
      }

      test('clips columns to the measured viewport', () {
        final range = selection();

        final projected = ViewportSelection.resolve(
          range,
          rows: 4,
          cols: 3,
          viewportOffset: 0,
        )!;

        expect((projected.startColumn(0), projected.endColumn(0)), (3, 3));
      });

      for (final size in [(0, 8), (4, 0)]) {
        test('returns null for an empty ${size.$1} by ${size.$2} grid', () {
          final range = selection();

          final projected = ViewportSelection.resolve(
            range,
            rows: size.$1,
            cols: size.$2,
            viewportOffset: 0,
          );

          expect(projected, isNull);
        });
      }
    });
  });
}
