import 'dart:ui';

import 'package:flterm/src/foundation/cell_metrics.dart';
import 'package:flterm/src/rendering/atlas/atlas.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart';

void main() {
  group('Atlas', () {
    const defaultMetrics = CellMetrics(
      cellWidth: 8,
      cellHeight: 16,
      baseline: 12,
    );

    AtlasConfig config({double dpr = 1, CellMetrics metrics = defaultMetrics}) {
      return AtlasConfig(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        fontFamily: 'monospace',
        fontFamilyFallback: const [],
        metrics: metrics,
        devicePixelRatio: dpr,
      );
    }

    // dart format off
    const spriteSamples = [
      0x2500, 0x25E2, 0xF5D6, 0x1CC21,
      0x1CC30, 0x1CE0B, 0x1FB95, 0x1FBBD,
    ];
    // dart format on

    late Atlas atlas;

    setUp(() {
      atlas = Atlas(config());
    });

    tearDown(() => atlas.dispose());

    group('construction', () {
      test('applies config without allocating unused glyphs', () {
        atlas.dispose();
        atlas = Atlas(config(dpr: 2.0));

        expect(atlas.devicePixelRatio, 2.0);
        expect(atlas.cacheSize, 0);
        expect(atlas.textImage, isNull);
        expect(atlas.spriteImage, isNull);
      });

      test('lane image accessors expose separate atlas textures', () {
        expect(atlas.textImage, isNull);
        expect(atlas.spriteImage, isNull);
        expect(atlas.decorationImage, isNull);

        atlas.add((text: 'A', bold: false, italic: false));
        atlas.addDecoration(UnderlineStyle.single);
        atlas.add((text: '\u{1F600}', bold: false, italic: false), emoji: true);
        atlas.addCodepoint(0x2500, bold: false, italic: false);
        atlas.ensureImage();

        expect(atlas.emojiImage, isNotNull);
        expect(atlas.spriteImage, isNotNull);
        expect(atlas.emojiImage, isNot(same(atlas.textImage)));
        expect(atlas.spriteImage, isNot(same(atlas.textImage)));
        expect(atlas.decorationImage, isNot(same(atlas.spriteImage)));
      });

      test('does not allocate when cell dimensions are unavailable', () {
        atlas.dispose();
        atlas = Atlas(
          config(
            metrics: const CellMetrics(
              cellWidth: 0,
              cellHeight: 0,
              baseline: 0,
            ),
          ),
        );

        expect(atlas.cacheSize, 0);
        expect(atlas.textImage, isNull);
      });
    });

    group('addCodepoint', () {
      test('creates entry and returns cached on second call', () {
        final entry1 =
            atlas.addCodepoint(0x100, bold: false, italic: false) as AtlasEntry;
        final entry2 =
            atlas.addCodepoint(0x100, bold: false, italic: false) as AtlasEntry;

        expect(entry1.srcRight, greaterThan(entry1.srcLeft));
        expect(identical(entry1, entry2), isTrue);
      });

      test('different styles produce different entries', () {
        final plain =
            atlas.addCodepoint(0x41, bold: false, italic: false) as AtlasEntry;
        final bold =
            atlas.addCodepoint(0x41, bold: true, italic: false) as AtlasEntry;
        expect(identical(plain, bold), isFalse);
      });

      test('sprite codepoints reuse geometry across styles', () {
        for (final codepoint in spriteSamples) {
          final plain =
              atlas.addCodepoint(codepoint, bold: false, italic: false)
                  as AtlasEntry;
          final boldItalic =
              atlas.addCodepoint(codepoint, bold: true, italic: true)
                  as AtlasEntry;

          expect(identical(plain, boldItalic), isTrue, reason: '$codepoint');
        }
      });

      test('span participates in sprite cache key', () {
        final single =
            atlas.addCodepoint(0xE0B0, bold: false, italic: false)
                as AtlasEntry;
        final doubleWidth =
            atlas.addCodepoint(0xE0B0, bold: false, italic: false, span: 2)
                as AtlasEntry;

        expect(identical(single, doubleWidth), isFalse);
        expect(
          doubleWidth.srcRight - doubleWidth.srcLeft,
          greaterThan(single.srcRight - single.srcLeft),
        );
      });

      test('sprite codepoints are rasterized lazily on first use', () {
        final sizeBefore = atlas.cacheSize;
        expect(atlas.spriteImage, isNull);

        final entry =
            atlas.addCodepoint(0x2500, bold: false, italic: false)
                as AtlasEntry;
        expect(entry.srcRight, greaterThan(entry.srcLeft));
        expect(atlas.cacheSize, sizeBefore + 1);
        expect(atlas.spriteImage, isNull);

        atlas.ensureImage();
        expect(atlas.spriteImage, isNotNull);
      });
    });

    group('add', () {
      test('creates entry and returns cached on second call', () {
        final sizeBefore = atlas.cacheSize;

        const key = (text: '\u{1234}', bold: false, italic: false);
        final entry1 = atlas.add(key) as AtlasEntry;
        final entry2 = atlas.add(key) as AtlasEntry;

        expect(atlas.cacheSize, sizeBefore + 1);
        expect(identical(entry1, entry2), isTrue);
      });

      test('wide text entry spans 2 cells', () {
        const key = (text: '\u{4e00}', bold: false, italic: false);
        final entry = atlas.add(key, span: 2) as AtlasEntry;

        final expectedWidth = (8.0 * 2 * 1.0).ceil().toDouble();
        expect(entry.srcRight - entry.srcLeft, expectedWidth);
        expect(entry.lane, AtlasEntryLane.text);
      });

      test('emoji entry exposes the emoji lane', () {
        const key = (text: '\u{1F600}', bold: false, italic: false);
        final entry = atlas.add(key, emoji: true) as AtlasEntry;
        expect(entry.lane, AtlasEntryLane.emoji);
      });

      test('sprite and decoration entries expose their owning lane', () {
        final sprite =
            atlas.addCodepoint(0x2500, bold: false, italic: false)
                as AtlasEntry;
        final decoration =
            atlas.addDecoration(UnderlineStyle.single) as AtlasEntry;

        expect(sprite.lane, AtlasEntryLane.sprite);
        expect(decoration.lane, AtlasEntryLane.decoration);
      });

      test('sequential adds produce non-overlapping positions', () {
        final entries = <AtlasEntry>[];
        for (var code = 0x300; code < 0x310; code++) {
          entries.add(
            atlas.add((
                  text: String.fromCharCode(code),
                  bold: false,
                  italic: false,
                ))
                as AtlasEntry,
          );
        }

        for (var i = 0; i < entries.length; i++) {
          for (var j = i + 1; j < entries.length; j++) {
            final a = entries[i];
            final b = entries[j];
            final overlap =
                a.srcLeft < b.srcRight &&
                a.srcRight > b.srcLeft &&
                a.srcTop < b.srcBottom &&
                a.srcBottom > b.srcTop;
            expect(overlap, isFalse, reason: 'entries $i and $j overlap');
          }
        }
      });

      test('early positions remain stable after many adds', () {
        final earlyEntries = <AtlasEntry>[];
        for (var code = 0x400; code < 0x410; code++) {
          earlyEntries.add(
            atlas.add((
                  text: String.fromCharCode(code),
                  bold: false,
                  italic: false,
                ))
                as AtlasEntry,
          );
        }

        final positions = earlyEntries
            .map((e) => (e.srcLeft, e.srcTop, e.srcRight, e.srcBottom))
            .toList();

        for (var code = 0x410; code < 0x600; code++) {
          atlas.add((
            text: String.fromCharCode(code),
            bold: false,
            italic: false,
          ));
        }

        for (var i = 0; i < earlyEntries.length; i++) {
          final e = earlyEntries[i];
          final p = positions[i];
          expect(e.srcLeft, p.$1);
          expect(e.srcTop, p.$2);
          expect(e.srcRight, p.$3);
          expect(e.srcBottom, p.$4);
        }
      });
    });

    group('ensureImage', () {
      test('composites pending glyphs into atlas image', () {
        atlas.add((text: '\u{1234}', bold: false, italic: false));
        atlas.ensureImage();
        expect(atlas.textImage, isNotNull);
      });

      test('composites pending sprite glyphs into sprite image', () {
        for (final codepoint in spriteSamples) {
          atlas.addCodepoint(codepoint, bold: false, italic: false);
        }
        atlas.ensureImage();
        expect(atlas.spriteImage, isNotNull);
      });

      test('keeps existing image without pending glyphs', () {
        final imageBefore = atlas.textImage;

        atlas.ensureImage();
        expect(atlas.textImage, same(imageBefore));
      });
    });

    group('dispose', () {
      test('releases image', () {
        atlas.addCodepoint(0x41, bold: false, italic: false);
        atlas.ensureImage();
        expect(atlas.textImage, isNotNull);

        atlas.dispose();
        expect(atlas.textImage, isNull);
        expect(atlas.emojiImage, isNull);
        expect(atlas.spriteImage, isNull);
        expect(atlas.decorationImage, isNull);
      });
    });
  });
}
