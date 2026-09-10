import 'package:flterm/flterm.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CellRange', () {
    group('contains', () {
      test('includes cells between the start and end positions', () {
        const range = CellRange(
          start: Position(row: 1, col: 2),
          end: Position(row: 1, col: 4),
        );

        final result = range.contains(const Position(row: 1, col: 3));

        expect(result, isTrue);
      });

      test('excludes cells outside the end position', () {
        const range = CellRange(
          start: Position(row: 1, col: 2),
          end: Position(row: 1, col: 4),
        );

        final result = range.contains(const Position(row: 1, col: 5));

        expect(result, isFalse);
      });

      test('includes cells on interior rows', () {
        const range = CellRange(
          start: Position(row: 1, col: 2),
          end: Position(row: 3, col: 4),
        );

        final result = range.contains(const Position(row: 2, col: 100));

        expect(result, isTrue);
      });
    });

    group('overlaps', () {
      test('returns true for intersecting ranges', () {
        const first = CellRange(
          start: Position(row: 0, col: 2),
          end: Position(row: 0, col: 6),
        );
        const second = CellRange(
          start: Position(row: 0, col: 4),
          end: Position(row: 0, col: 8),
        );

        final result = first.overlaps(second);

        expect(result, isTrue);
      });

      test('returns false for separated ranges', () {
        const first = CellRange(
          start: Position(row: 0, col: 2),
          end: Position(row: 0, col: 4),
        );
        const second = CellRange(
          start: Position(row: 0, col: 5),
          end: Position(row: 0, col: 8),
        );

        final result = first.overlaps(second);

        expect(result, isFalse);
      });

      test('returns false when multiline boundary columns are separated', () {
        const first = CellRange(
          start: Position(row: 0, col: 5),
          end: Position(row: 1, col: 2),
        );
        const second = CellRange(
          start: Position(row: 1, col: 5),
          end: Position(row: 2, col: 9),
        );

        final firstOverlapsSecond = first.overlaps(second);
        final secondOverlapsFirst = second.overlaps(first);

        expect(firstOverlapsSecond, isFalse);
        expect(secondOverlapsFirst, isFalse);
      });

      test('returns true when multiline boundary columns intersect', () {
        const first = CellRange(
          start: Position(row: 0, col: 5),
          end: Position(row: 1, col: 2),
        );
        const second = CellRange(
          start: Position(row: 1, col: 1),
          end: Position(row: 2, col: 9),
        );

        final result = first.overlaps(second);

        expect(result, isTrue);
      });

      test('returns false when either range has reversed rows', () {
        const valid = CellRange(
          start: Position(row: 0, col: 0),
          end: Position(row: 4, col: 2),
        );
        const reversed = CellRange(
          start: Position(row: 3, col: 0),
          end: Position(row: 1, col: 2),
        );

        final validOverlapsReversed = valid.overlaps(reversed);
        final reversedOverlapsValid = reversed.overlaps(valid);

        expect(validOverlapsReversed, isFalse);
        expect(reversedOverlapsValid, isFalse);
      });

      test('returns false for ranges in different coordinate spaces', () {
        const viewport = CellRange(
          start: Position(row: 0, col: 0),
          end: Position(row: 0, col: 2),
        );
        const screen = CellRange(
          start: Position(row: 0, col: 0),
          end: Position(row: 0, col: 2),
          pointTag: .screen,
        );

        final result = viewport.overlaps(screen);

        expect(result, isFalse);
      });
    });
  });
}
