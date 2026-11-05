import 'package:flterm/src/foundation.dart';
import 'package:flterm/src/rendering/font/measure_cell_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/font_loader.dart';

void main() {
  setUpAll(loadBundledFonts);

  group('measureCellMetrics', () {
    testWidgets('returns valid dimensions with baseline within cell height', (
      tester,
    ) async {
      final metrics = measureCellMetrics(
        fontFamily: 'monospace',
        fontSize: 14.0,
      );

      expect(metrics.cellWidth, greaterThan(0));
      expect(metrics.cellHeight, greaterThan(0));
      expect(metrics.baseline, greaterThan(0));
      expect(metrics.baseline, lessThanOrEqualTo(metrics.cellHeight));
    });

    testWidgets('larger font produces larger dimensions', (tester) async {
      final small = measureCellMetrics(fontFamily: 'monospace', fontSize: 10);
      final large = measureCellMetrics(fontFamily: 'monospace', fontSize: 24);

      expect(large.cellWidth, greaterThan(small.cellWidth));
      expect(large.cellHeight, greaterThan(small.cellHeight));
    });

    testWidgets('cell width snaps up to device pixels', (tester) async {
      final metrics = measureCellMetrics(
        fontFamily: 'JetBrains Mono',
        fontSize: 9.0,
        fontData: jetBrainsMonoBytes,
        devicePixelRatio: 3.0,
      );

      expect(metrics.cellWidth, closeTo(17 / 3, 0.0001));
    });

    testWidgets('applies Ghostty-style adjustments', (tester) async {
      CellMetrics measure(FontAdjustments adjustments) => measureCellMetrics(
        fontFamily: 'JetBrains Mono',
        fontSize: 14.0,
        fontData: jetBrainsMonoBytes,
        adjustments: adjustments,
      );
      final plain = measure(const FontAdjustments());
      final adjusted = measure(
        const FontAdjustments(
          cellWidth: 0.5,
          cellHeight: 0.5,
          underlinePosition: 0.1,
          underlineThickness: 2,
        ),
      );

      expect(adjusted.cellWidth, closeTo(plain.cellWidth * 1.5, 1));
      expect(adjusted.cellHeight, closeTo(plain.cellHeight * 1.5, 1));
      expect(adjusted.underlineThickness, plain.underlineThickness + 2);
      // The baseline moved down with the centered glyphs, the underline
      // with it and a further tenth of the cell.
      expect(
        adjusted.underlinePosition - adjusted.baseline,
        closeTo(
          plain.underlinePosition - plain.baseline + adjusted.cellHeight * 0.1,
          1,
        ),
      );
    });

    testWidgets('accepts fontFamilyFallback', (tester) async {
      final metrics = measureCellMetrics(
        fontFamily: 'monospace',
        fontSize: 14.0,
        fontFamilyFallback: const ['serif'],
      );

      expect(metrics.cellWidth, greaterThan(0));
      expect(metrics.cellHeight, greaterThan(0));
    });

    testWidgets('extracts JetBrains Mono decoration metrics with fontData', (
      tester,
    ) async {
      final metrics = measureCellMetrics(
        fontFamily: 'JetBrains Mono',
        fontSize: 14.0,
        fontData: jetBrainsMonoBytes,
      );

      expect(metrics.underlineThickness, 1.0);
      expect(metrics.strikethroughThickness, 1.0);
      expect(metrics.underlinePosition, greaterThan(metrics.baseline));
      expect(metrics.strikethroughPosition, lessThan(metrics.baseline));
      expect(metrics.overlinePosition, 0);
      expect(
        metrics.underlinePosition + metrics.underlineThickness,
        lessThanOrEqualTo(metrics.cellHeight),
      );
    });

    testWidgets('underline thickness scales with font size', (tester) async {
      final metrics = measureCellMetrics(
        fontFamily: 'JetBrains Mono',
        fontSize: 24.0,
        fontData: jetBrainsMonoBytes,
      );
      expect(metrics.underlineThickness, 2.0);
      expect(metrics.strikethroughThickness, 2.0);
    });

    testWidgets('thickness is at least 1px at small font sizes', (
      tester,
    ) async {
      final metrics = measureCellMetrics(
        fontFamily: 'JetBrains Mono',
        fontSize: 8.0,
        fontData: jetBrainsMonoBytes,
      );
      expect(metrics.underlineThickness, greaterThanOrEqualTo(1.0));
      expect(metrics.strikethroughThickness, greaterThanOrEqualTo(1.0));
    });

    testWidgets('without fontData uses heuristic fallback', (tester) async {
      final withoutFont = measureCellMetrics(
        fontFamily: 'JetBrains Mono',
        fontSize: 14.0,
      );
      final withFont = measureCellMetrics(
        fontFamily: 'JetBrains Mono',
        fontSize: 14.0,
        fontData: jetBrainsMonoBytes,
      );

      expect(withoutFont.underlineThickness, greaterThanOrEqualTo(1.0));
      expect(withoutFont.strikethroughThickness, greaterThanOrEqualTo(1.0));
      expect(withoutFont.underlinePosition, greaterThan(0));
      expect(withoutFont.strikethroughPosition, greaterThan(0));
      expect(
        withFont.underlineThickness,
        lessThanOrEqualTo(withoutFont.underlineThickness),
      );
      expect(withFont.cellWidth, withoutFont.cellWidth);
      expect(withFont.cellHeight, withoutFont.cellHeight);
      expect(withFont.baseline, withoutFont.baseline);
    });
  });
}
