import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty_flutter/foundation.dart';

void main() {
  group('TerminalSize', () {
    test('stores cols and rows', () {
      const size = TerminalSize(cols: 80, rows: 24);
      expect(size.cols, 80);
      expect(size.rows, 24);
    });

    test('equality with same values', () {
      expect(
        const TerminalSize(cols: 80, rows: 24),
        equals(const TerminalSize(cols: 80, rows: 24)),
      );
    });

    test('inequality with different cols', () {
      expect(
        const TerminalSize(cols: 80, rows: 24),
        isNot(equals(const TerminalSize(cols: 81, rows: 24))),
      );
    });

    test('inequality with different rows', () {
      expect(
        const TerminalSize(cols: 80, rows: 24),
        isNot(equals(const TerminalSize(cols: 80, rows: 25))),
      );
    });

    test('hashCode is consistent with equality', () {
      const a = TerminalSize(cols: 80, rows: 24);
      const b = TerminalSize(cols: 80, rows: 24);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString includes cols and rows', () {
      const size = TerminalSize(cols: 80, rows: 24);
      expect(size.toString(), contains('80'));
      expect(size.toString(), contains('24'));
    });
  });
}
