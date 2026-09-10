import 'dart:ui';

import 'package:flterm/src/foundation/cell_metrics.dart';
import 'package:flterm/src/rendering/atlas/atlas_config.dart';
import 'package:flterm/src/rendering/atlas/atlas_entry.dart';
import 'package:flterm/src/rendering/atlas/atlas_texture.dart';
import 'package:flterm/src/rendering/atlas/lanes/text_lane.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TextLane', () {
    AtlasConfig config({
      CellMetrics metrics = const CellMetrics(
        cellWidth: 8,
        cellHeight: 16,
        baseline: 12,
      ),
    }) {
      return AtlasConfig(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        fontFamily: 'monospace',
        fontFamilyFallback: const [],
        metrics: metrics,
        devicePixelRatio: 1.0,
      );
    }

    late TextLane lane;

    setUp(() {
      lane = TextLane(initialSize: 32, maxSize: 128)..configure(config());
    });

    tearDown(() {
      lane.dispose();
    });

    Future<({int height, int left, int right, int width})> paintedBounds(
      Image image,
      AtlasEntry entry,
    ) async {
      final bytes = await image.toByteData();
      final data = bytes!.buffer.asUint8List();
      final imageWidth = image.width;
      final left = entry.srcLeft.floor();
      final right = entry.srcRight.ceil();
      final top = entry.srcTop.floor();
      final bottom = entry.srcBottom.ceil();
      var paintedLeft = right;
      var paintedRight = left - 1;
      var paintedTop = bottom;
      var paintedBottom = top - 1;
      for (var y = top; y < bottom; y++) {
        for (var x = left; x < right; x++) {
          final alpha = data[(y * imageWidth + x) * 4 + 3];
          if (alpha > 0) {
            paintedLeft = x < paintedLeft ? x : paintedLeft;
            paintedRight = x > paintedRight ? x : paintedRight;
            paintedTop = y < paintedTop ? y : paintedTop;
            paintedBottom = y > paintedBottom ? y : paintedBottom;
          }
        }
      }

      return (
        height: paintedBottom >= paintedTop
            ? paintedBottom - paintedTop + 1
            : 0,
        left: paintedLeft,
        right: paintedRight,
        width: paintedRight >= paintedLeft ? paintedRight - paintedLeft + 1 : 0,
      );
    }

    test('rasterizeText allocates a pending text entry', () {
      final entry = lane.rasterizeText('A', bold: false, italic: false);

      expect(entry.lane, AtlasEntryLane.text);
      expect(entry.srcRight, greaterThan(entry.srcLeft));
      expect(lane.hasPending, isTrue);
      expect(lane.image, isNull);
    });

    test('ensureImage creates the atlas image and clears pending text', () {
      lane.rasterizeText('A', bold: false, italic: false);

      lane.ensureImage();

      expect(lane.image, isNotNull);
      expect(lane.hasPending, isFalse);
    });

    test('rasterizeText preserves narrow glyph width in wide spans', () async {
      final lane = TextLane(initialSize: 128, maxSize: 128)
        ..configure(
          config(
            metrics: const CellMetrics(
              cellWidth: 32,
              cellHeight: 32,
              baseline: 24,
            ),
          ),
        );
      addTearDown(lane.dispose);
      final single = lane.rasterizeText('A', bold: false, italic: false);
      final wide = lane.rasterizeText('A', bold: false, italic: false, span: 2);

      lane.ensureImage();
      final image = lane.image!;
      final singleBounds = await paintedBounds(image, single);
      final wideBounds = await paintedBounds(image, wide);

      expect(wideBounds.width, lessThanOrEqualTo(singleBounds.width + 2));
    });

    test('rasterizeText centers narrow glyphs in wide spans', () async {
      final lane = TextLane(initialSize: 128, maxSize: 128)
        ..configure(
          config(
            metrics: const CellMetrics(
              cellWidth: 32,
              cellHeight: 32,
              baseline: 24,
            ),
          ),
        );
      addTearDown(lane.dispose);
      final entry = lane.rasterizeText(
        'A',
        bold: false,
        italic: false,
        span: 2,
      );

      lane.ensureImage();
      final image = lane.image!;
      final bounds = await paintedBounds(image, entry);
      final leftInset = bounds.left - entry.srcLeft.floor();
      final rightInset = entry.srcRight.ceil() - bounds.right - 1;
      final insetDelta = (leftInset - rightInset).abs();

      expect(insetDelta, lessThanOrEqualTo(2));
    });

    test('rasterizeText centers borrowed symbols in the first cell', () async {
      final lane = TextLane()
        ..configure(
          config(
            metrics: const CellMetrics(
              cellWidth: 32,
              cellHeight: 32,
              baseline: 24,
            ),
          ),
        );
      addTearDown(lane.dispose);
      final centered = lane.rasterizeText(
        'A',
        bold: false,
        italic: false,
        span: 2,
      );
      final centerInFirstCell = lane.rasterizeText(
        'A',
        bold: false,
        italic: false,
        span: 2,
        centerInFirstCell: true,
      );

      lane.ensureImage();
      final image = lane.image!;
      final centeredBounds = await paintedBounds(image, centered);
      final firstCellBounds = await paintedBounds(image, centerInFirstCell);

      final centeredInset = centeredBounds.left - centered.srcLeft.floor();
      final firstCellInset =
          firstCellBounds.left - centerInFirstCell.srcLeft.floor();
      expect(firstCellInset, lessThan(centeredInset));
      expect(firstCellBounds.width, centeredBounds.width);
    });

    test('rasterizeText uniformly fits an oversized glyph', () async {
      final regularLane = TextLane(initialSize: 128, maxSize: 128)
        ..configure(
          config(
            metrics: const CellMetrics(
              cellWidth: 32,
              cellHeight: 32,
              baseline: 24,
            ),
          ),
        );
      final constrainedLane = TextLane(initialSize: 128, maxSize: 128)
        ..configure(
          config(
            metrics: const CellMetrics(
              cellWidth: 4,
              cellHeight: 32,
              baseline: 24,
            ),
          ),
        );
      addTearDown(regularLane.dispose);
      addTearDown(constrainedLane.dispose);
      final regular = regularLane.rasterizeText(
        '■',
        bold: false,
        italic: false,
      );
      final constrained = constrainedLane.rasterizeText(
        '■',
        bold: false,
        italic: false,
      );
      regularLane.ensureImage();
      constrainedLane.ensureImage();

      final regularBounds = await paintedBounds(regularLane.image!, regular);
      final constrainedBounds = await paintedBounds(
        constrainedLane.image!,
        constrained,
      );

      expect(constrainedBounds.width, lessThanOrEqualTo(4));
      expect(constrainedBounds.height, lessThan(regularBounds.height));
    });

    test('rasterizeText uniformly fits a glyph taller than its cell', () async {
      final regularLane = TextLane(initialSize: 128, maxSize: 128)
        ..configure(
          config(
            metrics: const CellMetrics(
              cellWidth: 32,
              cellHeight: 32,
              baseline: 24,
            ),
          ),
        );
      final constrainedLane = TextLane(initialSize: 128, maxSize: 128)
        ..configure(
          config(
            metrics: const CellMetrics(
              cellWidth: 32,
              cellHeight: 8,
              baseline: 6,
            ),
          ),
        );
      addTearDown(regularLane.dispose);
      addTearDown(constrainedLane.dispose);
      final regular = regularLane.rasterizeText(
        '■',
        bold: false,
        italic: false,
      );
      final constrained = constrainedLane.rasterizeText(
        '■',
        bold: false,
        italic: false,
        span: 2,
        centerInFirstCell: true,
      );
      regularLane.ensureImage();
      constrainedLane.ensureImage();

      final regularBounds = await paintedBounds(regularLane.image!, regular);
      final constrainedBounds = await paintedBounds(
        constrainedLane.image!,
        constrained,
      );

      expect(constrainedBounds.height, lessThanOrEqualTo(8));
      expect(constrainedBounds.width, lessThan(regularBounds.width));
    });

    test('clear drops pending text and releases the image', () {
      lane.rasterizeText('A', bold: false, italic: false);
      lane.ensureImage();
      lane.rasterizeText('B', bold: false, italic: false);

      lane.clear();

      expect(lane.hasPending, isFalse);
      expect(lane.image, isNull);
    });

    group('atlas capacity', () {
      const maxAtlasSize = 32;
      late TextLane capacityLane;

      setUp(() {
        capacityLane = TextLane(initialSize: 16, maxSize: maxAtlasSize)
          ..configure(
            config(
              metrics: const CellMetrics(
                cellWidth: 8,
                cellHeight: 8,
                baseline: 6,
              ),
            ),
          );
      });

      tearDown(() {
        capacityLane.dispose();
      });

      ({List<AtlasEntry> entries, AtlasFullException? error}) fillUntilFull() {
        final entries = <AtlasEntry>[];
        for (var index = 0; index < 64; index++) {
          try {
            entries.add(
              capacityLane.rasterizeText(
                String.fromCharCode(0x41 + index),
                bold: false,
                italic: false,
              ),
            );
          } on AtlasFullException catch (error) {
            return (entries: entries, error: error);
          }
        }
        return (entries: entries, error: null);
      }

      test('keeps allocated entries within the maximum atlas bounds', () {
        final result = fillUntilFull();

        expect(result.entries, isNotEmpty);
        expect(
          result.entries.map((entry) => entry.srcRight),
          everyElement(lessThanOrEqualTo(maxAtlasSize.toDouble())),
        );
        expect(
          result.entries.map((entry) => entry.srcBottom),
          everyElement(lessThanOrEqualTo(maxAtlasSize.toDouble())),
        );
      });

      test('throws when the next entry exceeds the maximum atlas size', () {
        final result = fillUntilFull();

        expect(result.error, isA<AtlasFullException>());
      });

      test('throws when a single entry exceeds the maximum atlas size', () {
        capacityLane.configure(
          config(
            metrics: const CellMetrics(
              cellWidth: 32,
              cellHeight: 8,
              baseline: 6,
            ),
          ),
        );

        expect(
          () => capacityLane.rasterizeText('A', bold: false, italic: false),
          throwsA(isA<AtlasFullException>()),
        );
      });
    });
  });
}
