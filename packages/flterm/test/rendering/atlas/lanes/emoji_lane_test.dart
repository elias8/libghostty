import 'dart:ui';

import 'package:flterm/src/foundation/cell_metrics.dart';
import 'package:flterm/src/rendering/atlas/atlas_config.dart';
import 'package:flterm/src/rendering/atlas/atlas_entry.dart';
import 'package:flterm/src/rendering/atlas/lanes/emoji_lane.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/font_loader.dart';

void main() {
  group('EmojiLane', () {
    Rect entryRect(AtlasEntry entry) {
      return Rect.fromLTRB(
        entry.srcLeft,
        entry.srcTop,
        entry.srcRight,
        entry.srcBottom,
      );
    }

    Future<Rect> paintedRect(Image image) async {
      final byteData = await image.toByteData();
      final bytes = byteData!.buffer.asUint8List();
      var left = image.width;
      var top = image.height;
      var right = 0;
      var bottom = 0;

      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          final alpha = bytes[(y * image.width + x) * 4 + 3];
          if (alpha == 0) continue;
          if (x < left) left = x;
          if (y < top) top = y;
          if (x + 1 > right) right = x + 1;
          if (y + 1 > bottom) bottom = y + 1;
        }
      }

      if (right <= left || bottom <= top) return Rect.zero;
      return Rect.fromLTRB(
        left.toDouble(),
        top.toDouble(),
        right.toDouble(),
        bottom.toDouble(),
      );
    }

    AtlasConfig config() {
      return AtlasConfig(
        fontSize: 24,
        fontWeight: .normal,
        fontFamily: 'JetBrains Mono',
        fontFamilyFallback: bundledFontFamilyFallback,
        metrics: const CellMetrics(cellWidth: 14, cellHeight: 28, baseline: 22),
        devicePixelRatio: 1.0,
      );
    }

    Future<void>? fontsLoaded;
    late EmojiLane lane;

    Future<(AtlasEntry, Rect)> rasterizedRect(
      String text, {
      int span = 1,
    }) async {
      final entry =
          lane.rasterizeEmoji(text, bold: false, italic: false, span: span)
              as AtlasEntry;
      lane.ensureImage();

      return (entry, await paintedRect(lane.image!));
    }

    setUp(() async {
      fontsLoaded ??= loadBundledFonts();
      await fontsLoaded;
      lane = EmojiLane(initialSize: 64, maxSize: 256)..configure(config());
    });

    tearDown(() {
      lane.dispose();
    });

    test('rasterizeEmoji allocates a pending emoji entry', () {
      final entry =
          lane.rasterizeEmoji('\u{1F600}', bold: false, italic: false)
              as AtlasEntry;

      expect(entry.lane, AtlasEntryLane.emoji);
      expect(entry.srcRight, greaterThan(entry.srcLeft));
      expect(lane.hasPending, isTrue);
      expect(lane.image, isNull);
    });

    test('ensureImage creates the atlas image and clears pending emoji', () {
      lane.rasterizeEmoji('\u{1F600}', bold: false, italic: false);

      lane.ensureImage();

      expect(lane.image, isNotNull);
      expect(lane.hasPending, isFalse);
    });

    test('VS16 heart fits centered in a wide cell span', () async {
      final (entry, rect) = await rasterizedRect('\u2764\uFE0F', span: 2);
      final bounds = entryRect(entry);

      expect(rect.height, greaterThanOrEqualTo(20));
      expect(rect.left, greaterThanOrEqualTo(bounds.left));
      expect(rect.right, lessThan(bounds.right));
      expect(rect.center.dx, closeTo(bounds.center.dx, 3.0));
    });

    test('wide emoji stays inside its atlas span', () async {
      final (entry, rect) = await rasterizedRect('\u{1F602}', span: 2);
      final bounds = entryRect(entry);

      expect(rect.left, greaterThan(bounds.left));
      expect(rect.top, greaterThanOrEqualTo(bounds.top));
      expect(rect.right, lessThan(bounds.right));
      expect(rect.bottom, lessThanOrEqualTo(bounds.bottom));
    });
  });
}
