@Tags(['ffi'])
library;

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

void main() {
  group('CursorShape', () {
    test('has expected values', () {
      expect(
        CursorShape.values,
        containsAll([
          CursorShape.block,
          CursorShape.underline,
          CursorShape.bar,
          CursorShape.blockHollow,
        ]),
      );
    });
  });

  group('Cursor', () {
    test('default cursor', () {
      const cursor = Cursor();
      expect(cursor.row, 0);
      expect(cursor.col, 0);
      expect(cursor.visible, isTrue);
      expect(cursor.shape, CursorShape.block);
    });

    test('equality', () {
      const a = Cursor(row: 5, col: 10, shape: CursorShape.bar);
      const b = Cursor(row: 5, col: 10, shape: CursorShape.bar);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality on position', () {
      const a = Cursor(row: 5, col: 10);
      const b = Cursor(row: 6, col: 10);
      expect(a, isNot(equals(b)));
    });

    test('inequality on visibility', () {
      const a = Cursor();
      const b = Cursor(visible: false);
      expect(a, isNot(equals(b)));
    });

    test('inequality on shape', () {
      const a = Cursor();
      const b = Cursor(shape: CursorShape.underline);
      expect(a, isNot(equals(b)));
    });

    test('copyWith', () {
      const cursor = Cursor(row: 5, col: 10, shape: CursorShape.bar);
      final moved = cursor.copyWith(row: 6, col: 11);
      expect(moved.row, 6);
      expect(moved.col, 11);
      expect(moved.shape, CursorShape.bar);
      expect(moved.visible, isTrue);
    });
  });
}
