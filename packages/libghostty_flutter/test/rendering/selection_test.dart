import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty_flutter/src/rendering/selection.dart';

void main() {
  group('TerminalSelection', () {
    test('stores all fields', () {
      const sel = TerminalSelection(
        startRow: 1,
        startCol: 3,
        endRow: 2,
        endCol: 7,
      );
      expect(sel.startRow, 1);
      expect(sel.startCol, 3);
      expect(sel.endRow, 2);
      expect(sel.endCol, 7);
      expect(sel.mode, SelectionMode.normal);
    });

    test('mode defaults to normal', () {
      const sel = TerminalSelection(
        startRow: 0,
        startCol: 0,
        endRow: 0,
        endCol: 5,
      );
      expect(sel.mode, SelectionMode.normal);
    });

    group('equality', () {
      test('same values are equal', () {
        const a = TerminalSelection(
          startRow: 1,
          startCol: 2,
          endRow: 3,
          endCol: 4,
        );
        const b = TerminalSelection(
          startRow: 1,
          startCol: 2,
          endRow: 3,
          endCol: 4,
        );
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different values are not equal', () {
        const a = TerminalSelection(
          startRow: 1,
          startCol: 2,
          endRow: 3,
          endCol: 4,
        );
        const b = TerminalSelection(
          startRow: 1,
          startCol: 2,
          endRow: 3,
          endCol: 5,
        );
        expect(a, isNot(equals(b)));
      });

      test('different mode is not equal', () {
        const a = TerminalSelection(
          startRow: 1,
          startCol: 2,
          endRow: 3,
          endCol: 4,
        );
        const b = TerminalSelection(
          startRow: 1,
          startCol: 2,
          endRow: 3,
          endCol: 4,
          mode: SelectionMode.block,
        );
        expect(a, isNot(equals(b)));
      });
    });

    group('contains: single-row selection', () {
      const sel = TerminalSelection(
        startRow: 2,
        startCol: 4,
        endRow: 2,
        endCol: 9,
      );

      test('cell at start is included', () {
        expect(sel.contains(2, 4), isTrue);
      });

      test('cell before end is included', () {
        expect(sel.contains(2, 8), isTrue);
      });

      test('cell at end col is excluded (exclusive end)', () {
        expect(sel.contains(2, 9), isFalse);
      });

      test('cell before startCol is excluded', () {
        expect(sel.contains(2, 3), isFalse);
      });

      test('different row is excluded', () {
        expect(sel.contains(1, 5), isFalse);
        expect(sel.contains(3, 5), isFalse);
      });
    });

    group('contains: multi-row selection', () {
      const sel = TerminalSelection(
        startRow: 1,
        startCol: 5,
        endRow: 3,
        endCol: 4,
      );

      test('first row: only cells from startCol onward', () {
        expect(sel.contains(1, 4), isFalse);
        expect(sel.contains(1, 5), isTrue);
        expect(sel.contains(1, 79), isTrue);
      });

      test('middle row: all cells included', () {
        expect(sel.contains(2, 0), isTrue);
        expect(sel.contains(2, 79), isTrue);
      });

      test('last row: only cells before endCol', () {
        expect(sel.contains(3, 0), isTrue);
        expect(sel.contains(3, 3), isTrue);
        expect(sel.contains(3, 4), isFalse);
      });

      test('rows outside range excluded', () {
        expect(sel.contains(0, 5), isFalse);
        expect(sel.contains(4, 0), isFalse);
      });
    });

    group('contains: reversed selection (endRow < startRow)', () {
      const sel = TerminalSelection(
        startRow: 3,
        startCol: 4,
        endRow: 1,
        endCol: 5,
      );

      test('normalizes to correct range', () {
        expect(sel.contains(1, 4), isFalse);
        expect(sel.contains(1, 5), isTrue);
        expect(sel.contains(2, 0), isTrue);
        expect(sel.contains(3, 3), isTrue);
        expect(sel.contains(3, 4), isFalse);
      });
    });

    group('contains: single-row reversed (startCol > endCol)', () {
      const sel = TerminalSelection(
        startRow: 2,
        startCol: 9,
        endRow: 2,
        endCol: 4,
      );

      test('normalizes column order', () {
        expect(sel.contains(2, 3), isFalse);
        expect(sel.contains(2, 4), isTrue);
        expect(sel.contains(2, 8), isTrue);
        expect(sel.contains(2, 9), isFalse);
      });
    });

    group('normalized getters: forward selection', () {
      const sel = TerminalSelection(
        startRow: 1,
        startCol: 5,
        endRow: 3,
        endCol: 4,
      );

      test('topRow/botRow follow row order', () {
        expect(sel.topRow, 1);
        expect(sel.botRow, 3);
      });

      test('topCol/botCol follow row order', () {
        expect(sel.topCol, 5);
        expect(sel.botCol, 4);
      });
    });

    group('normalized getters: reversed rows', () {
      const sel = TerminalSelection(
        startRow: 3,
        startCol: 4,
        endRow: 1,
        endCol: 5,
      );

      test('topRow/botRow are swapped', () {
        expect(sel.topRow, 1);
        expect(sel.botRow, 3);
      });

      test('topCol/botCol follow swapped row order', () {
        expect(sel.topCol, 5);
        expect(sel.botCol, 4);
      });
    });

    group('normalized getters: same-row reversed columns', () {
      const sel = TerminalSelection(
        startRow: 2,
        startCol: 9,
        endRow: 2,
        endCol: 4,
      );

      test('topRow/botRow are equal', () {
        expect(sel.topRow, 2);
        expect(sel.botRow, 2);
      });

      test('topCol is min, botCol is max', () {
        expect(sel.topCol, 4);
        expect(sel.botCol, 9);
      });
    });

    group('contains: block mode', () {
      const sel = TerminalSelection(
        startRow: 1,
        startCol: 3,
        endRow: 3,
        endCol: 7,
        mode: SelectionMode.block,
      );

      test('cell inside rectangle is included', () {
        expect(sel.contains(1, 3), isTrue);
        expect(sel.contains(2, 5), isTrue);
        expect(sel.contains(3, 6), isTrue);
      });

      test('cell at end col is excluded (exclusive end)', () {
        expect(sel.contains(2, 7), isFalse);
      });

      test('cell outside column range is excluded', () {
        expect(sel.contains(2, 2), isFalse);
        expect(sel.contains(2, 8), isFalse);
      });

      test('cell outside row range is excluded', () {
        expect(sel.contains(0, 5), isFalse);
        expect(sel.contains(4, 5), isFalse);
      });

      test('middle row uses same column range as first and last', () {
        expect(sel.contains(2, 2), isFalse);
        expect(sel.contains(2, 3), isTrue);
        expect(sel.contains(2, 6), isTrue);
        expect(sel.contains(2, 7), isFalse);
      });
    });

    group('contains: block mode reversed', () {
      const sel = TerminalSelection(
        startRow: 3,
        startCol: 7,
        endRow: 1,
        endCol: 3,
        mode: SelectionMode.block,
      );

      test('normalizes rows and columns', () {
        expect(sel.contains(1, 3), isTrue);
        expect(sel.contains(2, 5), isTrue);
        expect(sel.contains(3, 6), isTrue);
        expect(sel.contains(2, 2), isFalse);
        expect(sel.contains(2, 7), isFalse);
        expect(sel.contains(0, 5), isFalse);
        expect(sel.contains(4, 5), isFalse);
      });
    });
  });
}
