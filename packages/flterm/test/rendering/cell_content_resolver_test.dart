import 'dart:convert';
import 'dart:ui';

import 'package:flterm/src/foundation/cell_metrics.dart';
import 'package:flterm/src/rendering/atlas/atlas.dart';
import 'package:flterm/src/rendering/cell_content_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart';

void main() {
  group('CellContentResolver', () {
    const metrics = CellMetrics(cellWidth: 8, cellHeight: 16, baseline: 12);

    AtlasConfig config() {
      return AtlasConfig(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        fontFamily: 'monospace',
        fontFamilyFallback: const [],
        metrics: metrics,
        devicePixelRatio: 1.0,
      );
    }

    late Atlas atlas;
    late CellContentResolver resolver;

    setUp(() {
      atlas = Atlas(config());
      resolver = CellContentResolver(atlas);
    });

    tearDown(() => atlas.dispose());

    test('returns null for empty content', () {
      final entry = resolver.resolve(
        content: '',
        codepoint: 0,
        graphemeLength: 0,
        style: const Style(),
        span: 1,
      );

      expect(entry, isNull);
    });

    test('returns null for Kitty Unicode placeholders', () {
      final entry = resolver.resolve(
        content: '\u{10EEEE}\u0305\u0305',
        codepoint: 0x10EEEE,
        graphemeLength: 3,
        style: const Style(),
        span: 1,
      );

      expect(entry, isNull);
    });

    test('returns null for a terminal cell containing a Kitty placeholder', () {
      final terminal = Terminal(cols: 1, rows: 1);
      addTearDown(terminal.dispose);
      terminal.write(utf8.encode('\u{10EEEE}\u0305\u0305'));
      final renderState = RenderState();
      addTearDown(renderState.dispose);
      final rows = RowIterator();
      addTearDown(rows.dispose);
      final cells = CellIterator();
      addTearDown(cells.dispose);
      renderState.update(terminal);
      rows.reset(renderState);
      rows.next();
      cells.reset(rows);
      cells.next();

      final entry = resolver.resolveCell(cells, style: cells.style, span: 1);

      expect(entry, isNull);
    });

    test('routes narrow single codepoints through the text lane', () {
      final entry = resolver.resolve(
        content: 'A',
        codepoint: 0x41,
        graphemeLength: 1,
        style: const Style(),
        span: 1,
      )!;

      expect(entry.lane, AtlasEntryLane.text);
    });

    test('routes wide CJK through the text lane', () {
      final entry = resolver.resolve(
        content: '\u4E00',
        codepoint: 0x4E00,
        graphemeLength: 1,
        style: const Style(),
        span: 2,
      )!;

      expect(entry.lane, AtlasEntryLane.text);
    });

    test('routes wide emoji through the emoji lane', () {
      final entry = resolver.resolve(
        content: '\u{1F600}',
        codepoint: 0x1F600,
        graphemeLength: 1,
        style: const Style(),
        span: 2,
      )!;

      expect(entry.lane, AtlasEntryLane.emoji);
    });

    test('routes variation-selector emoji through the emoji lane', () {
      final entry = resolver.resolve(
        content: '\u2764\uFE0F',
        codepoint: 0x2764,
        graphemeLength: 2,
        style: const Style(),
        span: 1,
      )!;

      expect(entry.lane, AtlasEntryLane.emoji);
    });

    test('routes built-in sprite codepoints through the sprite lane', () {
      final entry = resolver.resolve(
        content: '\u2500',
        codepoint: 0x2500,
        graphemeLength: 1,
        style: const Style(),
        span: 2,
      )!;

      expect(entry.lane, AtlasEntryLane.sprite);
    });
  });
}
