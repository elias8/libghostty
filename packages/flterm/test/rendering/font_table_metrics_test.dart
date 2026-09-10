import 'dart:typed_data';

import 'package:flterm/src/rendering/font/font_table_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/font_loader.dart';

void main() {
  group('parseFontTableMetrics', () {
    Uint8List buildMinimalFont({
      required List<String> includeTables,
      int unitsPerEm = 1000,
      int underlinePosition = -150,
      int underlineThickness = 50,
      int strikethroughPosition = 300,
      int strikethroughSize = 50,
      int os2Version = 4,
      int capHeight = 730,
      int exHeight = 550,
    }) {
      final numTables = includeTables.length;
      final headerSize = 12 + numTables * 16;

      final tableSizes = <String, int>{};
      if (includeTables.contains('head')) tableSizes['head'] = 54;
      if (includeTables.contains('hhea')) tableSizes['hhea'] = 36;
      if (includeTables.contains('post')) tableSizes['post'] = 32;
      if (includeTables.contains('OS/2')) tableSizes['OS/2'] = 96;

      var totalSize = headerSize;
      final tableOffsets = <String, int>{};
      for (final table in includeTables) {
        tableOffsets[table] = totalSize;
        totalSize += tableSizes[table] ?? 0;
      }

      final data = Uint8List(totalSize);
      final bd = ByteData.sublistView(data);

      bd.setUint32(0, 0x00010000);
      bd.setUint16(4, numTables);

      for (var i = 0; i < includeTables.length; i++) {
        final tag = includeTables[i];
        final entryOffset = 12 + i * 16;
        for (var j = 0; j < 4 && j < tag.length; j++) {
          data[entryOffset + j] = tag.codeUnitAt(j);
        }
        bd.setUint32(entryOffset + 8, tableOffsets[tag]!);
        bd.setUint32(entryOffset + 12, tableSizes[tag]!);
      }

      if (tableOffsets.containsKey('head')) {
        final off = tableOffsets['head']!;
        bd.setUint16(off + 18, unitsPerEm);
      }

      if (tableOffsets.containsKey('hhea')) {
        final off = tableOffsets['hhea']!;
        bd.setInt16(off + 4, 800);
        bd.setInt16(off + 6, -200);
        bd.setInt16(off + 8, 0);
      }

      if (tableOffsets.containsKey('post')) {
        final off = tableOffsets['post']!;
        bd.setInt16(off + 8, underlinePosition);
        bd.setInt16(off + 10, underlineThickness);
      }

      if (tableOffsets.containsKey('OS/2')) {
        final off = tableOffsets['OS/2']!;
        bd.setUint16(off, os2Version);
        bd.setInt16(off + 26, strikethroughSize);
        bd.setInt16(off + 28, strikethroughPosition);
        if (os2Version >= 2) {
          bd.setInt16(off + 86, exHeight);
          bd.setInt16(off + 88, capHeight);
        }
      }

      return data;
    }

    setUpAll(loadBundledFonts);

    test('parses JetBrains Mono tables correctly', () {
      final metrics = parseFontTableMetrics(jetBrainsMonoBytes!);
      expect(metrics, isNotNull);
      expect(metrics!.unitsPerEm, 1000);
      expect(metrics.ascent, 1020);
      expect(metrics.descent, -300);
      expect(metrics.lineGap, 0);
      expect(metrics.underlinePosition, -155);
      expect(metrics.underlineThickness, 50);
      expect(metrics.strikethroughPosition, 320);
      expect(metrics.strikethroughThickness, 50);
      expect(metrics.capHeight, 730);
      expect(metrics.exHeight, 550);
    });

    test('returns null for empty data', () {
      expect(parseFontTableMetrics(Uint8List(0)), isNull);
    });

    test('returns null for truncated data', () {
      expect(parseFontTableMetrics(Uint8List(10)), isNull);
    });

    test('returns null when table directory is truncated', () {
      final data = Uint8List(16);
      ByteData.sublistView(data).setUint16(4, 100);
      expect(parseFontTableMetrics(data), isNull);
    });

    test('returns null when a table offset is outside the data', () {
      final data = buildMinimalFont(includeTables: ['head', 'hhea']);
      ByteData.sublistView(data).setUint32(20, data.length + 1);

      expect(parseFontTableMetrics(data), isNull);
    });

    test('returns null when a table extends past the data', () {
      final data = buildMinimalFont(includeTables: ['head', 'hhea']);
      ByteData.sublistView(data).setUint32(24, data.length);

      expect(parseFontTableMetrics(data), isNull);
    });

    test('returns null when head table is missing', () {
      final data = buildMinimalFont(includeTables: ['hhea']);
      expect(parseFontTableMetrics(data), isNull);
    });

    test('returns null when hhea table is missing', () {
      final data = buildMinimalFont(includeTables: ['head']);
      expect(parseFontTableMetrics(data), isNull);
    });

    test('returns null when unitsPerEm is zero', () {
      final data = buildMinimalFont(
        includeTables: ['head', 'hhea'],
        unitsPerEm: 0,
      );
      expect(parseFontTableMetrics(data), isNull);
    });

    test('returns null underline fields when post table is absent', () {
      final data = buildMinimalFont(includeTables: ['head', 'hhea']);
      final metrics = parseFontTableMetrics(data);
      expect(metrics, isNotNull);
      expect(metrics!.underlinePosition, isNull);
      expect(metrics.underlineThickness, isNull);
    });

    test('treats zero underline thickness as broken', () {
      final data = buildMinimalFont(
        includeTables: ['head', 'hhea', 'post'],
        underlinePosition: -100,
        underlineThickness: 0,
      );
      final metrics = parseFontTableMetrics(data);
      expect(metrics, isNotNull);
      expect(metrics!.underlinePosition, -100);
      expect(metrics.underlineThickness, isNull);
    });

    test('treats zero underline position and thickness as broken', () {
      final data = buildMinimalFont(
        includeTables: ['head', 'hhea', 'post'],
        underlinePosition: 0,
        underlineThickness: 0,
      );
      final metrics = parseFontTableMetrics(data);
      expect(metrics, isNotNull);
      expect(metrics!.underlinePosition, isNull);
      expect(metrics.underlineThickness, isNull);
    });

    test('returns null strikethrough fields when OS/2 table is absent', () {
      final data = buildMinimalFont(includeTables: ['head', 'hhea']);
      final metrics = parseFontTableMetrics(data);
      expect(metrics, isNotNull);
      expect(metrics!.strikethroughPosition, isNull);
      expect(metrics.strikethroughThickness, isNull);
    });

    test('treats zero strikethrough size as broken', () {
      final data = buildMinimalFont(
        includeTables: ['head', 'hhea', 'OS/2'],
        strikethroughSize: 0,
      );
      final metrics = parseFontTableMetrics(data);
      expect(metrics, isNotNull);
      expect(metrics!.strikethroughPosition, 300);
      expect(metrics.strikethroughThickness, isNull);
    });

    test('returns null cap/x-height when OS/2 version < 2', () {
      final data = buildMinimalFont(
        includeTables: ['head', 'hhea', 'OS/2'],
        os2Version: 1,
      );
      final metrics = parseFontTableMetrics(data);
      expect(metrics, isNotNull);
      expect(metrics!.capHeight, isNull);
      expect(metrics.exHeight, isNull);
    });

    test('reads cap/x-height from OS/2 version 2+', () {
      final data = buildMinimalFont(
        includeTables: ['head', 'hhea', 'OS/2'],
        os2Version: 2,
      );
      final metrics = parseFontTableMetrics(data);
      expect(metrics, isNotNull);
      expect(metrics!.capHeight, 730);
      expect(metrics.exHeight, 550);
    });

    test('returns null cap/x-height when values are zero', () {
      final data = buildMinimalFont(
        includeTables: ['head', 'hhea', 'OS/2'],
        os2Version: 2,
        capHeight: 0,
        exHeight: 0,
      );
      final metrics = parseFontTableMetrics(data);
      expect(metrics, isNotNull);
      expect(metrics!.capHeight, isNull);
      expect(metrics.exHeight, isNull);
    });
  });
}
