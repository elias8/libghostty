import 'dart:ui';

import 'package:flterm/src/foundation/cell_metrics.dart';
import 'package:flterm/src/rendering/atlas/atlas_config.dart';
import 'package:flterm/src/rendering/atlas/atlas_entry.dart';
import 'package:flterm/src/rendering/atlas/lanes/decoration_lane.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart';

void main() {
  group('DecorationLane', () {
    AtlasConfig config() {
      return AtlasConfig(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        fontFamily: 'monospace',
        fontFamilyFallback: const [],
        metrics: const CellMetrics(cellWidth: 8, cellHeight: 16, baseline: 12),
        devicePixelRatio: 1.0,
      );
    }

    late DecorationLane lane;

    setUp(() {
      lane = DecorationLane(initialSize: 32, maxSize: 128)..configure(config());
    });

    tearDown(() {
      lane.dispose();
    });

    test(
      'dashed ink stays inside its slot before an adjacent empty entry',
      () async {
        lane.configure(
          AtlasConfig(
            fontSize: 14,
            fontWeight: FontWeight.normal,
            fontFamily: 'monospace',
            fontFamilyFallback: const [],
            metrics: const CellMetrics(
              cellWidth: 10,
              cellHeight: 16,
              baseline: 12,
            ),
            devicePixelRatio: 1,
          ),
        );
        final dashed =
            lane.rasterizeDecoration(UnderlineStyle.dashed) as AtlasEntry;
        final empty =
            lane.rasterizeDecoration(UnderlineStyle.none) as AtlasEntry;
        expect(empty.srcLeft, dashed.srcRight + 1);
        lane.ensureImage();
        final image = lane.image!;
        final bytes = (await image.toByteData())!;
        var ink = 0;
        for (var y = dashed.srcTop.toInt(); y < dashed.srcBottom; y++) {
          for (var x = dashed.srcLeft.toInt(); x < dashed.srcRight; x++) {
            if (bytes.getUint8((y * image.width + x) * 4 + 3) > 0) ink++;
          }
        }
        expect(ink, greaterThan(0));
        for (var y = empty.srcTop.toInt(); y < empty.srcBottom; y++) {
          for (var x = empty.srcLeft.toInt(); x < empty.srcRight; x++) {
            expect(
              bytes.getUint8((y * image.width + x) * 4 + 3),
              0,
              reason: 'Dashed ink must not bleed into the adjacent slot.',
            );
          }
        }
      },
    );

    test('rasterizeDecoration allocates a pending decoration entry', () {
      final entry =
          lane.rasterizeDecoration(UnderlineStyle.single) as AtlasEntry;

      expect(entry.lane, AtlasEntryLane.decoration);
      expect(entry.srcRight, greaterThan(entry.srcLeft));
      expect(lane.hasPending, isTrue);
      expect(lane.image, isNull);
    });

    test(
      'ensureImage creates the atlas image and clears pending decorations',
      () {
        lane.rasterizeDecoration(UnderlineStyle.single);

        lane.ensureImage();

        expect(lane.image, isNotNull);
        expect(lane.hasPending, isFalse);
      },
    );
  });
}
