import 'dart:ui';

import 'package:flterm/src/foundation/cell_metrics.dart';
import 'package:flterm/src/rendering/atlas/atlas_config.dart';
import 'package:flterm/src/rendering/atlas/atlas_entry.dart';
import 'package:flterm/src/rendering/atlas/lanes/decoration_lane.dart';
import 'package:flterm/src/rendering/atlas/lanes/emoji_lane.dart';
import 'package:flterm/src/rendering/atlas/lanes/sprite_lane.dart';
import 'package:flterm/src/rendering/atlas/lanes/text_lane.dart';
import 'package:flterm/src/rendering/sprite/sprite_face.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart' show UnderlineStyle;

void main() {
  group('AtlasLane', () {
    AtlasConfig createConfig({required CellMetrics metrics}) {
      return AtlasConfig(
        fontSize: 8,
        fontWeight: FontWeight.normal,
        fontFamily: 'monospace',
        fontFamilyFallback: const [],
        metrics: metrics,
        devicePixelRatio: 1.0,
      );
    }

    test('ensureImage composites pending text through the text texture', () {
      final lane = TextLane(initialSize: 16, maxSize: 64)
        ..configure(
          createConfig(
            metrics: const CellMetrics(
              cellWidth: 40,
              cellHeight: 8,
              baseline: 6,
            ),
          ),
        );
      addTearDown(lane.dispose);

      final entry =
          lane.rasterizeText('A', bold: false, italic: false) as AtlasEntry;
      lane.ensureImage();

      expect(entry.srcRight, lessThanOrEqualTo(lane.image!.width));
      expect(entry.srcBottom, lessThanOrEqualTo(lane.image!.height));
      expect(lane.image, isNotNull);
    });

    test('keeps lane textures physically separate', () {
      final config = createConfig(
        metrics: const CellMetrics(cellWidth: 8, cellHeight: 8, baseline: 6),
      );
      final text = TextLane(initialSize: 16, maxSize: 64)..configure(config);
      final emoji = EmojiLane(initialSize: 16, maxSize: 64)..configure(config);
      final sprite = SpriteLane(initialSize: 16, maxSize: 64)
        ..configure(config);
      final decoration = DecorationLane(initialSize: 16, maxSize: 64)
        ..configure(config);
      addTearDown(text.dispose);
      addTearDown(emoji.dispose);
      addTearDown(sprite.dispose);
      addTearDown(decoration.dispose);

      text.rasterizeText('A', bold: false, italic: false);
      emoji.rasterizeEmoji('\u{1F600}', bold: false, italic: false);
      sprite.rasterizeSprite(SpriteFace().glyphFor(0x2500)!);
      decoration.rasterizeDecoration(UnderlineStyle.single);

      text.ensureImage();
      emoji.ensureImage();
      sprite.ensureImage();
      decoration.ensureImage();

      expect(text.image, isNotNull);
      expect(emoji.image, isNotNull);
      expect(sprite.image, isNotNull);
      expect(decoration.image, isNotNull);
      expect(emoji.image, isNot(same(text.image)));
      expect(sprite.image, isNot(same(text.image)));
      expect(decoration.image, isNot(same(sprite.image)));
    });
  });
}
