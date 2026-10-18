import 'package:flterm/src/rendering/atlas/atlas_entry.dart';
import 'package:flterm/src/rendering/atlas/atlas_texture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AtlasTexture', () {
    test('preserves the allocating owner lane', () {
      final texture = AtlasTexture();
      addTearDown(texture.dispose);

      for (final lane in AtlasEntryLane.values) {
        final entry = texture.allocate(
          width: 8,
          height: 16,
          bearingY: 0,
          lane: lane,
        );

        expect(entry.lane, lane);
      }
    });

    test('allocates non-overlapping slots and grows within bounds', () {
      final texture = AtlasTexture(initialSize: 16, maxSize: 64);
      addTearDown(texture.dispose);

      final first = texture.allocate(
        width: 12,
        height: 8,
        bearingY: 0,
        lane: .text,
      );
      final second = texture.allocate(
        width: 12,
        height: 8,
        bearingY: 0,
        lane: .text,
      );
      final large = texture.allocate(
        width: 40,
        height: 8,
        bearingY: 0,
        lane: .text,
      );

      expect(first.srcRight, lessThanOrEqualTo(16));
      expect(second.srcTop, greaterThan(first.srcTop));
      expect(large.srcRight, lessThanOrEqualTo(64));
      expect(large.srcBottom, lessThanOrEqualTo(64));
    });

    test('clear resets allocation to the initial origin', () {
      final texture = AtlasTexture(initialSize: 16, maxSize: 64);
      addTearDown(texture.dispose);

      texture.allocate(width: 12, height: 8, bearingY: 0, lane: .text);
      texture.allocate(width: 12, height: 8, bearingY: 0, lane: .text);

      texture.clear();
      final afterClear = texture.allocate(
        width: 12,
        height: 8,
        bearingY: 0,
        lane: .text,
      );

      expect(afterClear.srcLeft, 0);
      expect(afterClear.srcTop, 0);
    });

    test('throws when one slot exceeds the maximum texture size', () {
      final texture = AtlasTexture(initialSize: 16, maxSize: 32);
      addTearDown(texture.dispose);

      expect(
        () => texture.allocate(width: 32, height: 8, bearingY: 0, lane: .text),
        throwsA(isA<AtlasFullException>()),
      );
    });
  });
}
