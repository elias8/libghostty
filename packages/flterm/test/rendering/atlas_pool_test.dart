import 'dart:ui';

import 'package:flterm/src/foundation.dart';
import 'package:flterm/src/rendering/atlas/atlas_config.dart';
import 'package:flterm/src/rendering/atlas/shaped_paragraph_cache.dart';
import 'package:flterm/src/rendering/atlas/sprite_buffer.dart';
import 'package:flterm/src/rendering/atlas_pool.dart';
import 'package:flutter/painting.dart' show PaintingBinding;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

    ShapedParagraphLease paragraph(
      AtlasLease atlas, {
      int foreground = 0xFFFFFFFF,
    }) => atlas.atlas.paragraphs.acquire(
      '===',
      foreground: foreground,
      bold: false,
      italic: false,
      create: () =>
          (ParagraphBuilder(ParagraphStyle(textDirection: TextDirection.ltr))
                ..pushStyle(TextStyle(color: Color(foreground)))
                ..addText('===')
                ..pop())
              .build()
            ..layout(const ParagraphConstraints(width: double.infinity)),
    );

    void paint(Paragraph value) {
      final recorder = PictureRecorder();
      Canvas(recorder).drawParagraph(value, Offset.zero);
      recorder.endRecording().dispose();
    }

    test('shares paragraphs across buffers and survives either disposal', () {
      final pool = AtlasPool();
      addTearDown(pool.dispose);
      final first = pool.acquireAtlas(key());
      final second = pool.acquireAtlas(key());
      final firstRun = paragraph(first);
      final secondRun = paragraph(second);
      final value = secondRun.paragraph;
      expect(firstRun.paragraph, same(value));
      final firstBuffer = ShapedRunBuffer()..configure(1);
      final secondBuffer = ShapedRunBuffer()..configure(1);
      for (final item in [(firstBuffer, firstRun), (secondBuffer, secondRun)]) {
        item.$1.beginRow(0);
        item.$1.add(
          ShapedRun.leased(
            lease: item.$2,
            offset: Offset.zero,
            clip: Rect.largest,
          ),
        );
        item.$1.endRow();
      }
      firstBuffer.configure(2);
      firstBuffer.dispose();
      first.release();
      paint(value);
      final thirdRun = paragraph(second);
      expect(thirdRun.paragraph, same(value));
      thirdRun.release();
      second.release();
      paint(value);
      expect(() => paragraph(second), throwsStateError);
      secondBuffer.dispose();
    });

    test('foreground themes separate entries within a shared atlas', () {
      final pool = AtlasPool();
      addTearDown(pool.dispose);
      final first = pool.acquireAtlas(key());
      final second = pool.acquireAtlas(key());
      addTearDown(first.release);
      addTearDown(second.release);
      final white = paragraph(first);
      final red = paragraph(second, foreground: 0xFFFF0000);
      final whiteAgain = paragraph(second);
      expect(white.paragraph, isNot(same(red.paragraph)));
      expect(whiteAgain.paragraph, same(white.paragraph));
      white.release();
      red.release();
      whiteAgain.release();
    });

    test('font and DPR changes isolate paragraph caches', () async {
      final pool = AtlasPool();
      addTearDown(pool.dispose);
      final old = pool.acquireAtlas(key());
      final oldRun = paragraph(old);
      final oldParagraph = oldRun.paragraph;
      final scaled = pool.acquireAtlas(key().copyWith(devicePixelRatio: 2));
      final resized = pool.acquireAtlas(key(fontSize: 20));
      final scaledRun = paragraph(scaled);
      final resizedRun = paragraph(resized);
      expect(scaledRun.paragraph, isNot(same(oldParagraph)));
      expect(resizedRun.paragraph, isNot(same(oldParagraph)));
      await PaintingBinding.instance.handleSystemMessage({
        'type': 'fontsChange',
      });
      final next = pool.acquireAtlas(key());
      final nextRun = paragraph(next);
      expect(nextRun.paragraph, isNot(same(oldParagraph)));
      old.release();
      paint(oldParagraph);
      oldRun.release();
      scaledRun.release();
      resizedRun.release();
      nextRun.release();
      scaled.release();
      resized.release();
      next.release();
    });

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

    test('rotates shared atlases while preserving old leases', () async {
      final pool = AtlasPool();
      addTearDown(pool.dispose);
      final first = pool.acquireAtlas(key());
      final second = pool.acquireAtlas(key());
      final oldAtlas = first.atlas;
      oldAtlas.addCodepoint(0x41, bold: false, italic: false);
      oldAtlas.ensureImage();

      await PaintingBinding.instance.handleSystemMessage({
        'type': 'fontsChange',
      });

      final next = pool.acquireAtlas(key());
      final sharedNext = pool.acquireAtlas(key());
      addTearDown(sharedNext.release);
      addTearDown(next.release);
      expect(first.isCurrent, isFalse);
      expect(next.isCurrent, isTrue);
      expect(next.atlas, isNot(same(oldAtlas)));
      expect(sharedNext.atlas, same(next.atlas));
      expect(oldAtlas.textImage, isNotNull);
      next.atlas.addCodepoint(0x42, bold: false, italic: false);
      next.atlas.ensureImage();

      first.release();
      expect(oldAtlas.textImage, isNotNull);
      second.release();
      expect(oldAtlas.textImage, isNull);
      expect(next.atlas.textImage, isNotNull);
    });

    test('stops observing fonts after the last release and resumes', () async {
      final pool = AtlasPool();
      addTearDown(pool.dispose);
      final released = pool.acquireAtlas(key());
      released.release();

      await PaintingBinding.instance.handleSystemMessage({
        'type': 'fontsChange',
      });
      expect(released.isCurrent, isTrue);

      final resumed = pool.acquireAtlas(key());
      addTearDown(resumed.release);
      await PaintingBinding.instance.handleSystemMessage({
        'type': 'fontsChange',
      });
      expect(resumed.isCurrent, isFalse);
    });

    test('stops observing fonts on disposal and allows reuse', () async {
      final pool = AtlasPool();
      addTearDown(pool.dispose);
      final abandoned = pool.acquireAtlas(key());
      pool.dispose();
      final reused = pool.acquireAtlas(key());
      abandoned.release();
      expect(reused.isCurrent, isTrue);
      reused.release();

      await PaintingBinding.instance.handleSystemMessage({
        'type': 'fontsChange',
      });
      expect(reused.isCurrent, isTrue);
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
