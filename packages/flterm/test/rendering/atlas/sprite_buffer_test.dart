import 'dart:typed_data';
import 'dart:ui';

import 'package:flterm/src/rendering/atlas/atlas.dart';
import 'package:flterm/src/rendering/atlas/shaped_paragraph_cache.dart';
import 'package:flterm/src/rendering/atlas/sprite_buffer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AtlasEntry entry({
    double srcLeft = 0,
    double srcTop = 0,
    double srcRight = 8,
    double srcBottom = 16,
  }) => AtlasEntry(
    srcLeft: srcLeft,
    srcTop: srcTop,
    srcRight: srcRight,
    srcBottom: srcBottom,
    bearingY: 0,
    lane: .text,
  );

  ShapedRun shapedRun(String text) {
    final paragraph =
        (ParagraphBuilder(
            ParagraphStyle(textDirection: TextDirection.ltr),
          )..addText(text)).build()
          ..layout(const ParagraphConstraints(width: double.infinity));
    return ShapedRun(
      paragraph: paragraph,
      offset: Offset.zero,
      clip: Rect.largest,
    );
  }

  group('ShapedParagraphCache', () {
    Paragraph build(String text, int foreground, {bool italic = false}) =>
        (ParagraphBuilder(ParagraphStyle(textDirection: TextDirection.ltr))
              ..pushStyle(
                TextStyle(
                  color: Color(foreground),
                  fontSize: 18,
                  fontStyle: italic ? FontStyle.italic : FontStyle.normal,
                  fontFeatures: const [FontFeature.enable('liga')],
                ),
              )
              ..addText(text)
              ..pop())
            .build()
          ..layout(const ParagraphConstraints(width: double.infinity));

    Future<Uint8List> pixels(Paragraph paragraph, double dpr) async {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder)..scale(dpr);
      canvas.clipRect(const Rect.fromLTWH(0, 0, 160, 28));
      canvas.drawParagraph(paragraph, const Offset(0, 2));
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        (160 * dpr).ceil(),
        (32 * dpr).ceil(),
      );
      final data = await image.toByteData();
      final result = Uint8List.fromList(data!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
      return result;
    }

    test('idle entry churn evicts old paragraphs', () {
      final cache = ShapedParagraphCache();
      addTearDown(cache.dispose);
      ShapedParagraphLease acquire(String text) => cache.acquire(
        text,
        foreground: 0xFFFFFFFF,
        bold: false,
        italic: false,
        create: () => build(text, 0xFFFFFFFF),
      );
      final first = acquire('first');
      final paragraph = first.paragraph;
      first.release();
      for (var index = 0; index < 140; index++) {
        acquire('entry $index').release();
      }
      final replacement = acquire('first');
      expect(replacement.paragraph, isNot(same(paragraph)));
      replacement.release();
    });

    test('long idle text is bounded independently of entry count', () {
      final cache = ShapedParagraphCache();
      addTearDown(cache.dispose);
      ShapedParagraphLease acquire(String text) => cache.acquire(
        text,
        foreground: 0xFFFFFFFF,
        bold: false,
        italic: false,
        create: () => build(text, 0xFFFFFFFF),
      );
      final text = List.filled(18000, '=').join();
      final first = acquire(text);
      final paragraph = first.paragraph;
      first.release();
      acquire('$text>').release();
      final replacement = acquire(text);
      expect(replacement.paragraph, isNot(same(paragraph)));
      replacement.release();
    });

    for (final dpr in [1.0, 1.25, 2.0]) {
      test(
        'leased paragraphs preserve pixels through churn at DPR $dpr',
        () async {
          var cache = ShapedParagraphCache();
          addTearDown(() => cache.dispose());
          for (final text in [
            '=> === != !== <= >= -> <->',
            r'$$$@@@%%%',
            '${List.filled(260, '=').join()}>',
          ]) {
            for (final foreground in [0xFFFFFFFF, 0x887733EE]) {
              final baseline = build(text, foreground, italic: true);
              addTearDown(baseline.dispose);
              ShapedParagraphLease acquire() => cache.acquire(
                text,
                foreground: foreground,
                bold: false,
                italic: true,
                create: () => build(text, foreground, italic: true),
              );
              final first = acquire();
              final second = acquire();
              expect(second.paragraph, same(first.paragraph));
              final expected = await pixels(baseline, dpr);
              first.release();
              for (var index = 0; index < 140; index++) {
                final otherText = '=>$index';
                cache
                    .acquire(
                      otherText,
                      foreground: foreground,
                      bold: false,
                      italic: false,
                      create: () => build(otherText, foreground),
                    )
                    .release();
              }
              expect(
                await pixels(second.paragraph, dpr),
                orderedEquals(expected),
              );
              cache.dispose();
              cache = ShapedParagraphCache();
              final replacement = acquire();
              expect(replacement.paragraph, isNot(same(second.paragraph)));
              expect(
                await pixels(second.paragraph, dpr),
                orderedEquals(expected),
              );
              expect(
                await pixels(replacement.paragraph, dpr),
                orderedEquals(expected),
              );
              second.release();
              replacement.release();
            }
          }
        },
      );
    }
  });

  group('AtlasSprites', () {
    test('count and hasSprites are zero before any emit', () {
      final sprites = AtlasSprites()..configure(4, 4);
      sprites.seal();
      expect(sprites.count, 0);
      expect(sprites.hasSprites, isFalse);
      expect(sprites.sealedTransforms.length, 0);
    });

    test('empty seals allow the first sprite in a lower row', () {
      final sprites = AtlasSprites()..configure(3, 2);
      sprites.seal();
      sprites.seal();

      sprites.beginRow(2);
      sprites.add(7, 8, entry(), 0.5, 0xFFAABBCC);
      sprites.endRow();
      sprites.seal();

      expect(sprites.count, 1);
      expect(sprites.sealedTransforms, [0.5, 0.0, 7.0, 8.0]);
      expect(sprites.sealedRects, [0.0, 0.0, 8.0, 16.0]);
      expect(sprites.sealedColors, [0xFFAABBCC.toSigned(32)]);
    });

    test('populated channel can empty and repopulate after sealing', () {
      final sprites = AtlasSprites()..configure(2, 3);
      sprites.beginRow(1);
      sprites.add(1, 2, entry(), 1.0, 0xFF111111);
      sprites.endRow();
      sprites.seal();

      sprites.beginRow(1);
      sprites.endRow();
      sprites.seal();
      expect(sprites.count, 0);
      expect(sprites.sealedTransforms, isEmpty);

      sprites.beginRow(0);
      sprites.add(9, 10, entry(), 0.25, 0xFFABCDEF);
      sprites.endRow();
      sprites.seal();

      expect(sprites.count, 1);
      expect(sprites.sealedTransforms, [0.25, 0.0, 9.0, 10.0]);
      expect(sprites.sealedColors, [0xFFABCDEF.toSigned(32)]);
    });

    test('seal packs active slots across rows', () {
      final sprites = AtlasSprites()..configure(4, 3);
      sprites.beginRow(1);
      sprites.add(
        100.0,
        200.0,
        entry(srcLeft: 10, srcTop: 20, srcRight: 18, srcBottom: 36),
        0.5,
        0xFFAABBCC,
      );
      sprites.endRow();
      sprites.seal();

      expect(sprites.count, 1);
      expect(sprites.sealedTransforms.length, 4);
      expect(sprites.sealedTransforms[0], 0.5);
      expect(sprites.sealedTransforms[2], 100.0);
      expect(sprites.sealedTransforms[3], 200.0);
      expect(sprites.sealedRects[0], 10.0);
      expect(sprites.sealedColors[0], 0xFFAABBCC.toSigned(32));
    });

    test('seal drops unused tail slots', () {
      final sprites = AtlasSprites()..configure(2, 4);
      sprites.beginRow(0);
      sprites.add(10, 20, entry(), 1.0);
      sprites.endRow();
      sprites.seal();

      expect(sprites.sealedTransforms.length, 4);
      expect(sprites.sealedTransforms[0], 1.0);
    });

    test('shrinking a row drops dropped sprites from the packed output', () {
      final sprites = AtlasSprites()..configure(2, 4);
      sprites.beginRow(0);
      sprites.add(10, 0, entry(), 1.0, 0x11111111);
      sprites.add(20, 0, entry(), 1.0, 0x22222222);
      sprites.add(30, 0, entry(), 1.0, 0x33333333);
      sprites.endRow();
      sprites.seal();
      expect(sprites.count, 3);

      sprites.beginRow(0);
      sprites.add(40, 0, entry(), 1.0, 0x44444444);
      sprites.endRow();
      sprites.seal();

      expect(sprites.count, 1);
      expect(sprites.sealedTransforms.length, 4);
      expect(sprites.sealedTransforms[2], 40.0);
    });

    test('configure resets active slot count when reusing the buffer', () {
      final sprites = AtlasSprites()..configure(4, 6);
      sprites.beginRow(3);
      sprites.add(1, 2, entry(), 1.0);
      sprites.endRow();
      sprites.seal();
      expect(sprites.count, 1);

      sprites.configure(2, 3);
      sprites.seal();
      expect(sprites.count, 0);
      expect(sprites.sealedTransforms.length, 0);
    });

    test('dispose releases buffers and resets counters', () {
      final sprites = AtlasSprites()..configure(4, 6);
      sprites.beginRow(0);
      sprites.add(1, 2, entry(), 1.0);
      sprites.endRow();
      sprites.seal();

      sprites.dispose();

      expect(sprites.count, 0);
      expect(sprites.hasSprites, isFalse);
      expect(sprites.sealedTransforms.length, 0);
    });

    test('repeat seal with no dirty rows keeps packed contents stable', () {
      final sprites = AtlasSprites()..configure(3, 4);
      sprites.beginRow(1);
      sprites.add(7, 8, entry(), 1.0, 0xFFAABBCC);
      sprites.endRow();
      sprites.seal();

      sprites.seal();
      sprites.seal();

      expect(sprites.count, 1);
      expect(sprites.sealedTransforms[2], 7.0);
      expect(sprites.sealedTransforms[3], 8.0);
      expect(sprites.sealedColors[0], 0xFFAABBCC.toSigned(32));
    });

    test('incremental seal preserves clean row prefix', () {
      final sprites = AtlasSprites()..configure(3, 4);
      sprites.beginRow(0);
      sprites.add(1, 2, entry(), 1.0, 0xFF111111);
      sprites.endRow();
      sprites.beginRow(2);
      sprites.add(3, 4, entry(), 1.0, 0xFF333333);
      sprites.endRow();
      sprites.seal();
      expect(sprites.count, 2);

      sprites.beginRow(2);
      sprites.add(9, 9, entry(), 1.0, 0xFF999999);
      sprites.endRow();
      sprites.seal();

      expect(sprites.count, 2);
      expect(sprites.sealedColors[0], 0xFF111111.toSigned(32));
      expect(sprites.sealedTransforms[2], 1.0);
      expect(sprites.sealedColors[1], 0xFF999999.toSigned(32));
      expect(sprites.sealedTransforms[4 + 2], 9.0);
    });
  });

  group('RectSprites', () {
    test('count and hasSprites are zero before any emit', () {
      final sprites = RectSprites()..configure(2, 3);
      expect(sprites.count, 0);
      expect(sprites.hasSprites, isFalse);
    });

    test('add and endRow update the active count', () {
      final sprites = RectSprites()..configure(2, 3);
      sprites.beginRow(0);
      sprites.add(0, 0, 1, 1, 0xFFAA0000);
      sprites.endRow();
      sprites.beginRow(1);
      sprites.add(2, 2, 3, 3, 0xFF00BB00);
      sprites.add(4, 4, 5, 5, 0xFF0000CC);
      sprites.endRow();
      expect(sprites.count, 3);
    });

    test('buildVertices returns no batches when no row is active', () {
      final sprites = RectSprites()..configure(2, 3);
      expect(sprites.buildVertices(Uint16List(0)), isEmpty);
    });

    test('buildVertices returns a batch once any row is active', () {
      final sprites = RectSprites()..configure(2, 3);
      sprites.beginRow(0);
      sprites.add(10, 20, 30, 40, 0xFFFF0000);
      sprites.endRow();
      final indices = Uint16List.fromList([0, 1, 2, 0, 2, 3]);
      expect(sprites.buildVertices(indices), isNotEmpty);
    });

    test('shrinking a row decreases the active count', () {
      final sprites = RectSprites()..configure(1, 4);
      sprites.beginRow(0);
      sprites.add(10, 10, 20, 20, 0xFFFF0000);
      sprites.add(30, 30, 40, 40, 0xFF00FF00);
      sprites.endRow();
      expect(sprites.count, 2);

      sprites.beginRow(0);
      sprites.add(50, 50, 60, 60, 0xFF0000FF);
      sprites.endRow();
      expect(sprites.count, 1);
    });

    test(
      'buildVertices resets starts when active slots drop to 0 then grow',
      () {
        final sprites = RectSprites()..configure(10, 5);
        final indices = Uint16List(600);
        for (var i = 0; i < 100; i++) {
          final base = i * 4;
          final offset = i * 6;
          indices[offset] = base;
          indices[offset + 1] = base + 1;
          indices[offset + 2] = base + 2;
          indices[offset + 3] = base;
          indices[offset + 4] = base + 2;
          indices[offset + 5] = base + 3;
        }

        sprites.beginRow(0);
        sprites.add(0, 0, 10, 10, 0xFF000000);
        sprites.add(0, 0, 10, 10, 0xFF000000);
        sprites.endRow();
        sprites.beginRow(5);
        sprites.add(0, 0, 10, 10, 0xFF000000);
        sprites.add(0, 0, 10, 10, 0xFF000000);
        sprites.endRow();
        sprites.buildVertices(indices);

        sprites.beginRow(0);
        sprites.endRow();
        sprites.beginRow(5);
        sprites.endRow();
        expect(sprites.buildVertices(indices), isEmpty);

        sprites.beginRow(7);
        sprites.add(0, 0, 10, 10, 0xFF000000);
        sprites.add(0, 0, 10, 10, 0xFF000000);
        sprites.endRow();
        expect(sprites.buildVertices(indices), isNotEmpty);
        expect(sprites.count, 2);
      },
    );

    test('buildVertices returns cached Vertices when nothing dirtied', () {
      final sprites = RectSprites()..configure(2, 3);
      sprites.beginRow(0);
      sprites.add(10, 20, 30, 40, 0xFFFF0000);
      sprites.endRow();
      final indices = Uint16List.fromList([0, 1, 2, 0, 2, 3]);
      final first = sprites.buildVertices(indices);

      final second = sprites.buildVertices(indices);

      expect(identical(first, second), isTrue);
    });

    test('dispose releases buffers', () {
      final sprites = RectSprites()..configure(2, 3);
      sprites.beginRow(0);
      sprites.add(1, 2, 3, 4, 0xFFAA0000);
      sprites.endRow();

      sprites.dispose();

      expect(sprites.count, 0);
      expect(sprites.hasSprites, isFalse);
    });
  });

  group('SpriteBuffer', () {
    void addBackgrounds(SpriteBuffer buffer, int count) {
      buffer.beginRow(0);
      for (var index = 0; index < count; index++) {
        final left = index.toDouble();
        buffer.background.add(left, 0, left + 1, 1, 0xFFAABBCC);
      }
      buffer.endRow();
    }

    test('configure resets active count across every channel', () {
      final buffer = SpriteBuffer()..configure(4, 10);
      buffer.seal();
      expect(buffer.regular.count, 0);
      expect(buffer.wide.count, 0);
      expect(buffer.emoji.count, 0);
      expect(buffer.background.count, 0);
      expect(buffer.underline.count, 0);
      expect(buffer.decoration.count, 0);
      expect(buffer.shaped.count, 0);
    });

    test('resize rebuilds atlas and rectangle outputs for the new grid', () {
      final buffer = SpriteBuffer()..configure(30, 30);
      addTearDown(buffer.dispose);
      buffer.beginRow(29);
      buffer.regular.add(1, 2, entry(), 1.0, 0xFF111111);
      buffer.background.add(1, 2, 3, 4, 0xFF222222);
      buffer.decoration.add(5, 6, 7, 8, 0xFF333333);
      buffer.endRow();
      buffer.seal();

      buffer.configure(2, 2);
      buffer.beginRow(1);
      buffer.regular.add(9, 10, entry(), 0.5, 0xFFABCDEF);
      buffer.background.add(11, 12, 13, 14, 0xFF123456);
      buffer.decoration.add(15, 16, 17, 18, 0xFF654321);
      buffer.endRow();
      buffer.seal();

      expect(buffer.regular.count, 1);
      expect(buffer.regular.sealedTransforms, [0.5, 0.0, 9.0, 10.0]);
      expect(buffer.regular.sealedColors, [0xFFABCDEF.toSigned(32)]);
      expect(buffer.backgroundVertices, hasLength(1));
      expect(buffer.decorationVertices, hasLength(1));
    });

    test('seal builds backgroundVertices when any row has bg rects', () {
      final buffer = SpriteBuffer()..configure(2, 4);
      buffer.beginRow(0);
      buffer.regular.add(0, 0, entry(), 1.0, 0xFF111111);
      buffer.background.add(0, 0, 100, 50, 0xFFAABBCC);
      buffer.endRow();
      buffer.seal();

      expect(buffer.backgroundVertices, isNotEmpty);
      expect(buffer.decorationVertices, isEmpty);
    });

    test('seal splits rectangle vertices before indices overflow', () {
      const rectangleCount = 16385;
      final buffer = SpriteBuffer()..configure(1, rectangleCount - 1);
      addTearDown(buffer.dispose);
      addBackgrounds(buffer, rectangleCount);

      buffer.seal();

      expect(buffer.backgroundVertices, hasLength(2));
    });

    test('clean rows keep sprites across a partial rebuild', () {
      final buffer = SpriteBuffer()..configure(3, 4);
      buffer.beginRow(0);
      buffer.regular.add(1, 2, entry(), 0.5, 0xFF112233);
      buffer.endRow();
      buffer.beginRow(2);
      buffer.regular.add(3, 4, entry(), 0.5, 0xFF445566);
      buffer.endRow();
      buffer.seal();

      buffer.beginRow(2);
      buffer.regular.add(9, 9, entry(), 0.5, 0xFF778899);
      buffer.endRow();
      buffer.seal();

      expect(buffer.regular.count, 2);
    });

    test('clean rows keep shaped runs across a partial rebuild', () {
      final buffer = SpriteBuffer()..configure(3, 4);
      addTearDown(buffer.dispose);
      final row0 = shapedRun('=>');
      final row2 = shapedRun('!=');
      buffer.beginRow(0);
      buffer.shaped.add(row0);
      buffer.endRow();
      buffer.beginRow(2);
      buffer.shaped.add(row2);
      buffer.endRow();
      buffer.seal();

      final replacement = shapedRun('==');
      buffer.beginRow(2);
      buffer.shaped.add(replacement);
      buffer.endRow();
      buffer.seal();

      expect(buffer.shaped.count, 2);
      expect(buffer.shaped.rows[0].single, same(row0));
      expect(buffer.shaped.rows[2].single, same(replacement));
    });

    test('dirty rows replace shaped runs', () {
      final buffer = SpriteBuffer()..configure(1, 4);
      addTearDown(buffer.dispose);
      final first = shapedRun('=>');
      buffer.beginRow(0);
      buffer.shaped.add(first);
      buffer.endRow();
      buffer.seal();

      final second = shapedRun('!=');
      buffer.beginRow(0);
      buffer.shaped.add(second);
      buffer.endRow();
      buffer.seal();

      expect(buffer.shaped.count, 1);
      expect(buffer.shaped.rows[0].single, same(second));
    });

    test('configure and dispose clear shaped runs', () {
      final buffer = SpriteBuffer()..configure(2, 4);
      final first = shapedRun('=>');
      buffer.beginRow(1);
      buffer.shaped.add(first);
      buffer.endRow();
      expect(buffer.shaped.count, 1);

      buffer.configure(1, 4);
      expect(buffer.shaped.count, 0);
      expect(buffer.shaped.rows.length, 1);

      buffer.beginRow(0);
      buffer.shaped.add(shapedRun('!='));
      buffer.endRow();
      expect(buffer.shaped.count, 1);

      buffer.dispose();
      expect(buffer.shaped.count, 0);
      expect(buffer.shaped.rows, isEmpty);
    });

    test('dispose releases every channel', () {
      final buffer = SpriteBuffer()..configure(2, 4);
      buffer.beginRow(0);
      buffer.regular.add(0, 0, entry(), 1.0, 0xFF111111);
      buffer.background.add(0, 0, 100, 50, 0xFFAABBCC);
      buffer.endRow();
      buffer.seal();

      buffer.dispose();

      expect(buffer.regular.count, 0);
      expect(buffer.background.count, 0);
      expect(buffer.shaped.count, 0);
      expect(buffer.backgroundVertices, isEmpty);
    });
  });
}
