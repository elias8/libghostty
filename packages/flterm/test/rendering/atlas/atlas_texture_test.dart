import 'dart:ui';

import 'package:flterm/src/rendering/atlas/atlas_budget.dart';
import 'package:flterm/src/rendering/atlas/atlas_entry.dart';
import 'package:flterm/src/rendering/atlas/atlas_texture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AtlasTexture', () {
    test('retains published ink across growth, clear, and reuse', () async {
      final texture = AtlasTexture(initialSize: 4, maxSize: 16);
      addTearDown(texture.dispose);
      texture.allocate(width: 2, height: 2, bearingY: 0, lane: .text);
      texture.replaceImage((canvas) {
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 2, 2),
          Paint()..color = const Color(0xFFFF0000),
        );
      });
      final recorder = PictureRecorder();
      Canvas(recorder).drawImage(texture.image!, Offset.zero, Paint());
      final held = recorder.endRecording();
      addTearDown(held.dispose);

      final next = texture.allocate(
        width: 5,
        height: 2,
        bearingY: 0,
        lane: .text,
      )!;
      texture.replaceImage((canvas) {
        canvas.drawRect(
          Rect.fromLTRB(
            next.srcLeft,
            next.srcTop,
            next.srcRight,
            next.srcBottom,
          ),
          Paint()..color = const Color(0x8000FF00),
        );
      });
      expect(await _pixel(texture.image!, 0, 0), [255, 0, 0, 255]);
      expect(await _pixel(texture.image!, 0, 3), [0, 128, 0, 128]);
      expect(await _pixel(texture.image!, 7, 7), [0, 0, 0, 0]);

      texture.clear();
      final old = await held.toImage(4, 4);
      addTearDown(old.dispose);
      expect(await _pixel(old, 0, 0), [255, 0, 0, 255]);
      expect(await _pixel(old, 3, 3), [0, 0, 0, 0]);

      texture.allocate(width: 2, height: 2, bearingY: 0, lane: .text);
      texture.replaceImage((canvas) {
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 2, 2),
          Paint()..color = const Color(0xFF0000FF),
        );
      });
      expect(await _pixel(texture.image!, 0, 0), [0, 0, 255, 255]);
      expect(await _pixel(texture.image!, 0, 3), [0, 0, 0, 0]);
      expect(await _pixel(old, 0, 0), [255, 0, 0, 255]);
    });

    test(
      'failed publication preserves ink and does not duplicate a retry',
      () async {
        final texture = AtlasTexture(initialSize: 8, maxSize: 16);
        addTearDown(texture.dispose);
        texture.allocate(width: 2, height: 2, bearingY: 0, lane: .text);
        const rect = Rect.fromLTWH(0, 0, 2, 2);
        texture.replaceImage((canvas) {
          canvas.drawRect(rect, Paint()..color = const Color(0xFFFF0000));
        });
        expect(
          () => texture.replaceImage((canvas) {
            canvas.drawRect(rect, Paint()..color = const Color(0x8000FF00));
            throw StateError('Cannot finish this batch.');
          }),
          throwsStateError,
        );
        expect(await _pixel(texture.image!, 0, 0), [255, 0, 0, 255]);
        texture.replaceImage((canvas) {
          canvas.drawRect(rect, Paint()..color = const Color(0x800000FF));
        });
        expect(await _pixel(texture.image!, 0, 0), [127, 0, 128, 255]);
      },
    );

    test('admits the next shelf without charging unused width', () {
      final budget = AtlasBudget(maxImageBytes: 512 * 1024);
      final texture = AtlasTexture(budget: budget);
      addTearDown(texture.dispose);
      final entries = <AtlasEntry>[];
      for (var index = 0; index < 79; index++) {
        final entry = texture.allocate(
          width: 18,
          height: 36,
          bearingY: 0,
          lane: .text,
        );
        expect(entry, isNotNull, reason: 'Glyph $index fits the image budget.');
        entries.add(entry!);
      }
      expect(entries.first.srcLeft, 0);
      expect(entries.first.srcTop, 0);
      expect(entries.last.srcLeft, 0);
      expect(entries.last.srcTop, 222);
      expect(budget.imageBytes, 512 * 1024);
    });

    test('preserves the allocating owner lane', () {
      final texture = AtlasTexture();
      addTearDown(texture.dispose);

      for (final lane in AtlasEntryLane.values) {
        final entry = texture.allocate(
          width: 8,
          height: 16,
          bearingY: 0,
          lane: lane,
        )!;

        expect(entry.lane, lane);
      }
    });

    test('uses new slabs after max height without moving earlier slots', () {
      final budget = AtlasBudget();
      final texture = AtlasTexture(initialSize: 4, maxSize: 16, budget: budget);
      addTearDown(texture.dispose);
      final entries = <AtlasEntry>[];
      for (var index = 0; index < 20; index++) {
        if (index == 6) {
          final bytes = budget.imageBytes;
          expect(
            texture.allocate(width: 15, height: 2, bearingY: 0, lane: .text),
            isNull,
          );
          expect(budget.imageBytes, bytes);
        }
        entries.add(
          texture.allocate(width: 2, height: 2, bearingY: 0, lane: .text)!,
        );
      }
      expect(entries.first.srcLeft, 0);
      expect(entries.first.srcTop, 0);
      expect(entries[5].srcLeft, 5);
      expect(entries[5].srcTop, 0);
      expect(entries[6].srcLeft, 5);
      expect(entries[6].srcTop, 3);
      expect(entries.last.srcLeft, 12);
      expect(entries.last.srcTop, 12);
      expect(
        texture.allocate(width: 2, height: 2, bearingY: 0, lane: .text),
        isNull,
      );
      expect(budget.imageBytes, 16 * 16 * 4);
      texture.clear();
      final first = texture.allocate(
        width: 2,
        height: 2,
        bearingY: 0,
        lane: .text,
      )!;
      expect(first.srcLeft, 0);
      expect(first.srcTop, 0);
    });

    test('allocates non-overlapping slots and grows within bounds', () {
      final texture = AtlasTexture(initialSize: 16, maxSize: 64);
      addTearDown(texture.dispose);

      final first = texture.allocate(
        width: 12,
        height: 8,
        bearingY: 0,
        lane: .text,
      )!;
      final second = texture.allocate(
        width: 12,
        height: 8,
        bearingY: 0,
        lane: .text,
      )!;
      final large = texture.allocate(
        width: 40,
        height: 8,
        bearingY: 0,
        lane: .text,
      )!;

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
      )!;

      expect(afterClear.srcLeft, 0);
      expect(afterClear.srcTop, 0);
    });

    test('rejection changes neither packing nor projected image bytes', () {
      final budget = AtlasBudget(maxImageBytes: 2048);
      final texture = AtlasTexture(
        initialSize: 16,
        maxSize: 64,
        budget: budget,
      );
      addTearDown(texture.dispose);
      final first = texture.allocate(
        width: 12,
        height: 8,
        bearingY: 0,
        lane: .text,
      )!;
      expect(budget.imageBytes, 1024);
      expect(
        texture.allocate(width: 40, height: 40, bearingY: 0, lane: .text),
        isNull,
      );
      expect(budget.imageBytes, 1024);
      final next = texture.allocate(
        width: 1,
        height: 1,
        bearingY: 0,
        lane: .text,
      )!;
      expect(next.srcLeft, first.srcRight + AtlasTexture.padding);
      expect(next.srcTop, first.srcTop);
    });

    test('all lane textures share projected image admission', () {
      final budget = AtlasBudget(maxImageBytes: 1024);
      final first = AtlasTexture(initialSize: 16, maxSize: 16, budget: budget);
      final second = AtlasTexture(initialSize: 16, maxSize: 16, budget: budget);
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      expect(
        first.allocate(width: 1, height: 1, bearingY: 0, lane: .text),
        isNotNull,
      );
      expect(
        second.allocate(width: 1, height: 1, bearingY: 0, lane: .emoji),
        isNull,
      );
      expect(budget.imageBytes, 1024);
      first.dispose();
      expect(
        second.allocate(width: 1, height: 1, bearingY: 0, lane: .emoji),
        isNotNull,
      );
      expect(budget.imageBytes, 1024);
    });

    test('rejects a slot that exceeds the maximum texture size', () {
      final texture = AtlasTexture(initialSize: 16, maxSize: 32);
      addTearDown(texture.dispose);

      expect(
        texture.allocate(width: 32, height: 8, bearingY: 0, lane: .text),
        isNull,
      );
    });
  });
}

Future<List<int>> _pixel(Image image, int x, int y) async {
  final bytes = (await image.toByteData())!.buffer.asUint8List();
  final offset = (y * image.width + x) * 4;
  return bytes.sublist(offset, offset + 4);
}
