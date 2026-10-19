import 'dart:ui';

import 'package:flterm/src/foundation.dart';
import 'package:flterm/src/rendering/atlas/atlas_config.dart';
import 'package:flterm/src/rendering/atlas_pool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AtlasPool', () {
    AtlasConfig key({double fontSize = 14}) {
      return AtlasConfig(
        fontSize: fontSize,
        fontWeight: FontWeight.normal,
        fontFamily: 'monospace',
        fontFamilyFallback: const [],
        metrics: const CellMetrics(cellWidth: 8, cellHeight: 16, baseline: 12),
        devicePixelRatio: 1.0,
      );
    }

    test('shares atlas for matching keys', () {
      final pool = AtlasPool();
      addTearDown(pool.dispose);

      final first = pool.acquireAtlas(key());
      final second = pool.acquireAtlas(key());
      addTearDown(second.release);
      addTearDown(first.release);

      expect(second.atlas, same(first.atlas));
    });

    test('keeps atlas alive until the last lease is released', () {
      final pool = AtlasPool();
      addTearDown(pool.dispose);

      final first = pool.acquireAtlas(key());
      final second = pool.acquireAtlas(key());
      final atlas = first.atlas;
      atlas.addCodepoint(0x41, bold: false, italic: false);
      atlas.ensureImage();
      expect(atlas.textImage, isNotNull);

      first.release();
      expect(atlas.textImage, isNotNull);

      second.release();
      expect(atlas.textImage, isNull);
    });

    test('does not share atlas across font-affecting keys', () {
      final pool = AtlasPool();
      addTearDown(pool.dispose);

      final first = pool.acquireAtlas(key());
      final second = pool.acquireAtlas(key(fontSize: 16));
      addTearDown(second.release);
      addTearDown(first.release);

      expect(second.atlas, isNot(same(first.atlas)));
    });
  });
}
