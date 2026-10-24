import 'dart:ui';

import 'package:flterm/src/foundation/cell_metrics.dart';
import 'package:flterm/src/rendering/atlas/atlas_budget.dart';
import 'package:flterm/src/rendering/atlas/atlas_cache.dart';
import 'package:flterm/src/rendering/atlas/atlas_config.dart';
import 'package:flterm/src/rendering/atlas/atlas_entry.dart';
import 'package:flterm/src/rendering/atlas/lanes/decoration_lane.dart';
import 'package:flterm/src/rendering/atlas/lanes/emoji_lane.dart';
import 'package:flterm/src/rendering/atlas/lanes/sprite_lane.dart';
import 'package:flterm/src/rendering/atlas/lanes/text_lane.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart';

void main() {
  group('AtlasCache', () {
    AtlasConfig createConfig() {
      return AtlasConfig(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        fontFamily: 'monospace',
        fontFamilyFallback: const [],
        metrics: const CellMetrics(cellWidth: 8, cellHeight: 16, baseline: 12),
        devicePixelRatio: 1.0,
      );
    }

    late TextLane textLane;
    late EmojiLane emojiLane;
    late SpriteLane spriteLane;
    late DecorationLane decorationLane;
    late AtlasCache cache;
    late AtlasBudget budget;

    setUp(() {
      final config = createConfig();
      budget = AtlasBudget();
      textLane = TextLane()..configure(config);
      emojiLane = EmojiLane()..configure(config);
      spriteLane = SpriteLane()..configure(config);
      decorationLane = DecorationLane()..configure(config);
      cache = AtlasCache(
        budget: budget,
        textLane: textLane,
        emojiLane: emojiLane,
        spriteLane: spriteLane,
        decorationLane: decorationLane,
      );
    });

    tearDown(() {
      textLane.dispose();
      emojiLane.dispose();
      spriteLane.dispose();
      decorationLane.dispose();
    });

    test(
      'bounds primary keys, aliases and UTF16 payload without rejected keys',
      () {
        final limited = AtlasBudget(maxIndexEntries: 3, maxKeyBytes: 4);
        final bounded = AtlasCache(
          budget: limited,
          textLane: textLane,
          emojiLane: emojiLane,
          spriteLane: spriteLane,
          decorationLane: decorationLane,
        );
        final first = bounded.addCodepoint(0x41, bold: false, italic: false);
        expect(first, isA<AtlasEntry>());
        expect(limited.indexEntries, 2); // primary plus ASCII alias
        expect(limited.keyBytes, 2);
        for (var index = 0; index < 4; index++) {
          final rejected = bounded.add((
            text: 'long$index',
            bold: false,
            italic: false,
          ));
          expect(rejected, isA<DirectGlyph>());
          (rejected as DirectGlyph).dispose();
        }
        expect(limited.indexEntries, 2);
        expect(limited.keyBytes, 2);
        final smaller = bounded.addCodepoint(0x42, bold: false, italic: false);
        expect(smaller, isA<AtlasEntry>());
        expect(limited.indexEntries, 3);
        expect(limited.keyBytes, 4);
        expect(
          bounded.addCodepoint(0x41, bold: false, italic: false),
          same(first),
        );
        final rejected = bounded.addCodepoint(0x43, bold: false, italic: false);
        expect(rejected, isA<DirectGlyph>());
        (rejected as DirectGlyph).dispose();
        expect(bounded.size, 2);
        expect(limited.indexEntries, 3);
      },
    );

    test('shares text entries for matching keys', () {
      const key = (text: 'A', bold: false, italic: false);

      final first = cache.add(key) as AtlasEntry;
      final second = cache.add(key) as AtlasEntry;

      expect(second, same(first));
      expect(cache.size, 1);
    });

    test('shares codepoint entries with text entries', () {
      const key = (text: 'A', bold: false, italic: false);

      final text = cache.add(key) as AtlasEntry;
      final codepoint =
          cache.addCodepoint(0x41, bold: false, italic: false) as AtlasEntry;

      expect(codepoint, same(text));
      expect(cache.size, 1);
    });

    test('keeps text and emoji entries separate for matching keys', () {
      const key = (text: '\u{1F600}', bold: false, italic: false);

      final text = cache.add(key) as AtlasEntry;
      final emoji = cache.add(key, emoji: true) as AtlasEntry;

      expect(emoji, isNot(same(text)));
      expect(cache.size, 2);
    });

    test('keeps style and span in text cache keys', () {
      final plain =
          cache.addCodepoint(0x41, bold: false, italic: false) as AtlasEntry;
      final bold =
          cache.addCodepoint(0x41, bold: true, italic: false) as AtlasEntry;
      final wide =
          cache.addCodepoint(0x41, bold: false, italic: false, span: 2)
              as AtlasEntry;

      expect(bold, isNot(same(plain)));
      expect(wide, isNot(same(plain)));
      expect(cache.size, 3);
    });

    test('sprite codepoints are independent from text style', () {
      final plain =
          cache.addCodepoint(0x2500, bold: false, italic: false) as AtlasEntry;
      final styled =
          cache.addCodepoint(0x2500, bold: true, italic: true) as AtlasEntry;

      expect(styled, same(plain));
      expect(cache.size, 1);
    });

    test('sprite and text lanes keep separate entries', () {
      final text =
          cache.add((text: '\u2500', bold: false, italic: false)) as AtlasEntry;
      final sprite =
          cache.addCodepoint(0x2500, bold: false, italic: false) as AtlasEntry;

      expect(sprite, isNot(same(text)));
      expect(cache.size, 2);
    });

    test('single-cell non-ASCII text entries include source padding', () {
      final entry =
          cache.addCodepoint(0x25C6, bold: false, italic: false) as AtlasEntry;

      expect(entry.lane, AtlasEntryLane.text);
      expect(entry.srcRight - entry.srcLeft, 12);
      expect(entry.srcBottom - entry.srcTop, 20);
      expect(entry.bearingX, -2);
      expect(entry.bearingY, -2);
    });

    test('shares non-ASCII text entries with codepoint entries', () {
      const key = (text: '\u25C6', bold: false, italic: false);

      final text = cache.add(key) as AtlasEntry;
      final codepoint =
          cache.addCodepoint(0x25C6, bold: false, italic: false) as AtlasEntry;

      expect(codepoint, same(text));
      expect(cache.size, 1);
    });

    test('sprite span participates in the cache key', () {
      final single =
          cache.addCodepoint(0x2500, bold: false, italic: false) as AtlasEntry;
      final wide =
          cache.addCodepoint(0x2500, bold: false, italic: false, span: 2)
              as AtlasEntry;

      expect(wide, isNot(same(single)));
      expect(cache.size, 2);
    });

    test('reports supported sprite codepoints', () {
      expect(cache.hasSprite(0x2500), isTrue);
      expect(cache.hasSprite(0x41), isFalse);
    });

    test('shares decoration entries for matching styles', () {
      final first = cache.addDecoration(UnderlineStyle.single) as AtlasEntry;
      final second = cache.addDecoration(UnderlineStyle.single) as AtlasEntry;

      expect(second, same(first));
    });

    test('clear removes cached entries', () {
      cache.add((text: 'A', bold: false, italic: false));
      expect(cache.size, 1);

      cache.clear();

      expect(cache.size, 0);
    });

    test('clear removes all cache lanes', () {
      final textBefore =
          cache.addCodepoint(0x41, bold: false, italic: false) as AtlasEntry;
      final spriteBefore =
          cache.addCodepoint(0x2500, bold: false, italic: false) as AtlasEntry;
      final decorationBefore =
          cache.addDecoration(UnderlineStyle.single) as AtlasEntry;
      expect(cache.size, 3);

      cache.clear();

      expect(cache.size, 0);
      expect(
        cache.addCodepoint(0x41, bold: false, italic: false),
        isNot(same(textBefore)),
      );
      expect(
        cache.addCodepoint(0x2500, bold: false, italic: false),
        isNot(same(spriteBefore)),
      );
      expect(
        cache.addDecoration(UnderlineStyle.single),
        isNot(same(decorationBefore)),
      );
    });

    test('keeps common entries lazy until requested', () {
      expect(cache.size, 0);
      final ascii =
          cache.addCodepoint(0x41, bold: false, italic: false) as AtlasEntry;
      final boldAscii =
          cache.addCodepoint(0x41, bold: true, italic: false) as AtlasEntry;
      final sprite =
          cache.addCodepoint(0x2500, bold: false, italic: false) as AtlasEntry;
      final decoration =
          cache.addDecoration(UnderlineStyle.single) as AtlasEntry;

      expect(ascii, isNotNull);
      expect(boldAscii, isNotNull);
      expect(sprite, isNotNull);
      expect(decoration, isNotNull);
      expect(cache.size, 4);
    });
  });
}
