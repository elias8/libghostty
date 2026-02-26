import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty_flutter/foundation.dart';

void main() {
  group('CellMetrics', () {
    test('const constructor stores values', () {
      const metrics = CellMetrics(
        cellWidth: 8.0,
        cellHeight: 16.0,
        baseline: 13.0,
      );
      expect(metrics.cellWidth, 8.0);
      expect(metrics.cellHeight, 16.0);
      expect(metrics.baseline, 13.0);
    });

    test('equality with same values', () {
      expect(
        const CellMetrics(cellWidth: 8.0, cellHeight: 16.0, baseline: 13.0),
        equals(
          const CellMetrics(cellWidth: 8.0, cellHeight: 16.0, baseline: 13.0),
        ),
      );
    });

    test('inequality with different values', () {
      expect(
        const CellMetrics(cellWidth: 8.0, cellHeight: 16.0, baseline: 13.0),
        isNot(
          equals(
            const CellMetrics(cellWidth: 9.0, cellHeight: 16.0, baseline: 13.0),
          ),
        ),
      );
    });

    testWidgets('measure returns positive dimensions', (tester) async {
      final metrics = CellMetrics.measure(
        fontFamily: 'monospace',
        fontSize: 14.0,
      );
      expect(metrics.cellWidth, greaterThan(0));
      expect(metrics.cellHeight, greaterThan(0));
      expect(metrics.baseline, greaterThan(0));
    });

    testWidgets('measure: baseline is less than or equal to height', (
      tester,
    ) async {
      final metrics = CellMetrics.measure(
        fontFamily: 'monospace',
        fontSize: 14.0,
      );
      expect(metrics.baseline, lessThanOrEqualTo(metrics.cellHeight));
    });

    testWidgets('measure: larger font produces larger dimensions', (
      tester,
    ) async {
      final small = CellMetrics.measure(fontFamily: 'monospace', fontSize: 10);
      final large = CellMetrics.measure(fontFamily: 'monospace', fontSize: 24);
      expect(large.cellWidth, greaterThan(small.cellWidth));
      expect(large.cellHeight, greaterThan(small.cellHeight));
    });
  });
}
