@Tags(['ffi'])
library;

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

void main() {
  group('Line', () {
    test('empty line', () {
      const line = Line([]);
      expect(line.length, 0);
      expect(line.text, '');
      expect(line.cells, isEmpty);
    });

    test('line with cells', () {
      const line = Line([Cell(content: 'H'), Cell(content: 'i')]);
      expect(line.length, 2);
      expect(line.text, 'Hi');
    });

    test('text strips trailing empty cells', () {
      const line = Line([
        Cell(content: 'A'),
        Cell(content: 'B'),
        Cell.empty,
        Cell.empty,
      ]);
      expect(line.text, 'AB');
    });

    test('text preserves internal spaces', () {
      const line = Line([
        Cell(content: 'A'),
        Cell(content: ' '),
        Cell(content: 'B'),
      ]);
      expect(line.text, 'A B');
    });

    test('cells are iterable', () {
      final cells = [const Cell(content: 'X'), const Cell(content: 'Y')];
      final line = Line(cells);
      expect(line.cells.toList(), equals(cells));
    });

    test('equality', () {
      const a = Line([Cell(content: 'A')]);
      const b = Line([Cell(content: 'A')]);
      expect(a, equals(b));
    });

    test('inequality', () {
      const a = Line([Cell(content: 'A')]);
      const b = Line([Cell(content: 'B')]);
      expect(a, isNot(equals(b)));
    });

    group('cellAt', () {
      test('returns correct cell for valid index', () {
        const line = Line([
          Cell(content: 'A'),
          Cell(content: 'B'),
          Cell(content: 'C'),
        ]);
        expect(line.cellAt(0), const Cell(content: 'A'));
        expect(line.cellAt(1), const Cell(content: 'B'));
        expect(line.cellAt(2), const Cell(content: 'C'));
      });

      test('returns Cell.empty for negative index', () {
        const line = Line([Cell(content: 'A')]);
        expect(line.cellAt(-1), Cell.empty);
        expect(line.cellAt(-100), Cell.empty);
      });

      test('returns Cell.empty for index >= length', () {
        const line = Line([Cell(content: 'A'), Cell(content: 'B')]);
        expect(line.cellAt(2), Cell.empty);
        expect(line.cellAt(100), Cell.empty);
      });

      test('returns Cell.empty for empty line', () {
        const line = Line([]);
        expect(line.cellAt(0), Cell.empty);
      });
    });
  });
}
