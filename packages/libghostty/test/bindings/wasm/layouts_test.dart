import 'dart:convert';

import 'package:libghostty/src/bindings/types.dart' show RawCellData;
import 'package:libghostty/src/bindings/wasm/layouts.dart';
import 'package:libghostty/src/generated/libghostty_enums.g.dart';
import 'package:test/test.dart';

void main() {
  Map<String, dynamic> packedCellTypes() {
    Map<String, dynamic> bit(int lsb, int width, String type) => {
      'lsb': lsb,
      'width': width,
      'type': type,
    };

    Map<String, dynamic> arm(Map<String, dynamic> bits) => {
      'kind': 'packed',
      'width': 24,
      'bits': bits,
    };

    return {
      'GhosttyCell': {
        'kind': 'packed',
        'size': 8,
        'align': 8,
        'underlying': 'u64',
        'bits': {
          'content_tag': bit(0, 2, 'GhosttyCellContentTag'),
          'content': {
            'kind': 'union',
            'lsb': 2,
            'width': 24,
            'tag': 'content_tag',
            'arms': {
              'CODEPOINT': arm({'codepoint': bit(0, 21, 'u21')}),
              'CODEPOINT_GRAPHEME': arm({'codepoint': bit(0, 21, 'u21')}),
              'BG_COLOR_PALETTE': arm({
                'index': bit(0, 8, 'GhosttyColorPaletteIndex'),
              }),
              'BG_COLOR_RGB': arm({
                'r': bit(0, 8, 'u8'),
                'g': bit(8, 8, 'u8'),
                'b': bit(16, 8, 'u8'),
              }),
            },
          },
          'style_id': bit(26, 16, 'GhosttyStyleId'),
          'wide': bit(42, 2, 'GhosttyCellWide'),
          'protected': bit(44, 1, 'bool'),
          'hyperlink': bit(45, 1, 'bool'),
          'semantic_content': bit(46, 2, 'GhosttyCellSemanticContent'),
        },
      },
    };
  }

  int rawCell(
    Map<String, dynamic> types, {
    required int tag,
    required int codepoint,
    required int styleId,
    required int wide,
    bool isProtected = false,
    bool hasHyperlink = false,
    int semanticContent = 0,
  }) {
    final cell = types['GhosttyCell'] as Map<String, dynamic>;
    final bits = cell['bits'] as Map<String, dynamic>;
    int field(String name, int value) {
      final descriptor = bits[name] as Map<String, dynamic>;
      var scale = 1;
      final lsb = descriptor['lsb'] as int;
      for (var i = 0; i < lsb; i++) {
        scale *= 2;
      }
      return value * scale;
    }

    return field('content_tag', tag) +
        field('content', codepoint) +
        field('style_id', styleId) +
        field('wide', wide) +
        field('protected', isProtected ? 1 : 0) +
        field('hyperlink', hasHyperlink ? 1 : 0) +
        field('semantic_content', semanticContent);
  }

  group('PackedCellLayout', () {
    test('literal words overwrite every field across all content arms', () {
      final layout = PackedCellLayout.fromTypes(packedCellTypes());
      final data = RawCellData();
      const vectors = [
        (
          0x3448d15b,
          0x8000beaf,
          CellContentTag.bgColorRgb,
          0,
          false,
          true,
          0x56,
          0x34,
          0x12,
        ),
        (
          0x3407d908,
          0x8000beaf,
          CellContentTag.codepoint,
          128578,
          false,
          false,
          0x42,
          0xf6,
          1,
        ),
        (
          0x3407d909,
          0x8000beaf,
          CellContentTag.codepointGrapheme,
          128578,
          true,
          false,
          0x42,
          0xf6,
          1,
        ),
        (
          0x340003fe,
          0x8000beaf,
          CellContentTag.bgColorPalette,
          0,
          false,
          false,
          0xff,
          0,
          0,
        ),
        (
          0xffffffff,
          0xffffbfff,
          CellContentTag.bgColorRgb,
          0,
          false,
          true,
          0xff,
          0xff,
          0xff,
        ),
        (0, 0, CellContentTag.codepoint, 0, false, false, 0, 0, 0),
      ];
      for (final (lo, hi, tag, codepoint, grapheme, rgb, r, g, b) in vectors) {
        expect(layout.decodeWordsInto(lo, hi, data), same(data));
        expect(
          (
            data.contentTag,
            data.codepoint,
            data.hasGrapheme,
            data.hasBackgroundRgb,
            data.backgroundR,
            data.backgroundG,
            data.backgroundB,
          ),
          (tag, codepoint, grapheme, rgb, r, g, b),
        );
        if (hi == 0x8000beaf) {
          expect(
            (
              data.styleId,
              data.wide,
              data.isProtected,
              data.hasHyperlink,
              data.semanticContent,
            ),
            (
              0xabcd,
              CellWide.spacerHead,
              true,
              true,
              CellSemanticContent.prompt,
            ),
          );
        } else if (hi == 0) {
          expect(
            (
              data.styleId,
              data.wide,
              data.isProtected,
              data.hasHyperlink,
              data.semanticContent,
            ),
            (0, CellWide.narrow, false, false, CellSemanticContent.output),
          );
        }
      }
    });

    test('accepts tag at bit62 and widened enum storage at bit61', () {
      final types = packedCellTypes();
      final bits =
          (types['GhosttyCell'] as Map<String, dynamic>)['bits']
              as Map<String, dynamic>;
      final tag = bits['content_tag'] as Map<String, dynamic>;
      tag['lsb'] = 62;
      final data = RawCellData();
      PackedCellLayout.fromTypes(
        types,
      ).decodeWordsInto(0x0007d908, 0x40000000, data);
      expect(
        (data.contentTag, data.codepoint, data.hasGrapheme),
        (CellContentTag.codepointGrapheme, 128578, true),
      );
      tag['lsb'] = 61;
      tag['width'] = 3;
      PackedCellLayout.fromTypes(
        types,
      ).decodeWordsInto(0x0007d908, 0x20000000, data);
      expect(
        (data.contentTag, data.codepoint, data.hasGrapheme),
        (CellContentTag.codepointGrapheme, 128578, true),
      );
    });

    test('decodes a content arm crossing bit32 with tag at bit62', () {
      final types = packedCellTypes();
      final bits =
          (types['GhosttyCell'] as Map<String, dynamic>)['bits']
              as Map<String, dynamic>;
      for (final (name, lsb) in [
        ('content_tag', 62),
        ('content', 29),
        ('style_id', 0),
        ('wide', 16),
        ('protected', 18),
        ('hyperlink', 19),
        ('semantic_content', 20),
      ]) {
        (bits[name] as Map<String, dynamic>)['lsb'] = lsb;
      }
      final data = RawCellData();
      PackedCellLayout.fromTypes(
        types,
      ).decodeWordsInto(0xc02fabcd, 0xc002468a, data);
      expect(
        (
          data.contentTag,
          data.codepoint,
          data.hasGrapheme,
          data.styleId,
          data.wide,
          data.isProtected,
          data.hasHyperlink,
          data.semanticContent,
          data.hasBackgroundRgb,
          data.backgroundR,
          data.backgroundG,
          data.backgroundB,
        ),
        (
          CellContentTag.bgColorRgb,
          0,
          false,
          0xabcd,
          CellWide.spacerHead,
          true,
          true,
          CellSemanticContent.prompt,
          true,
          0x56,
          0x34,
          0x12,
        ),
      );
    });

    test('rejects unsupported scalar widths at the metadata boundary', () {
      for (final (name, width) in [
        ('style_id', 15),
        ('protected', 2),
        ('hyperlink', 2),
        ('content_tag', 1),
        ('wide', 1),
        ('semantic_content', 1),
      ]) {
        final types = packedCellTypes();
        final bits =
            (types['GhosttyCell'] as Map<String, dynamic>)['bits']
                as Map<String, dynamic>;
        (bits[name] as Map<String, dynamic>)['width'] = width;
        expect(() => PackedCellLayout.fromTypes(types), throwsFormatException);
      }
      for (final (arm, field, width) in [
        ('CODEPOINT', 'codepoint', 20),
        ('CODEPOINT_GRAPHEME', 'codepoint', 20),
        ('BG_COLOR_PALETTE', 'index', 7),
        ('BG_COLOR_RGB', 'r', 7),
        ('BG_COLOR_RGB', 'g', 7),
        ('BG_COLOR_RGB', 'b', 7),
      ]) {
        final types = packedCellTypes();
        final bits =
            (types['GhosttyCell'] as Map<String, dynamic>)['bits']
                as Map<String, dynamic>;
        final content = bits['content'] as Map<String, dynamic>;
        final arms = content['arms'] as Map<String, dynamic>;
        final descriptor = arms[arm] as Map<String, dynamic>;
        final fields = descriptor['bits'] as Map<String, dynamic>;
        (fields[field] as Map<String, dynamic>)['width'] = width;
        expect(() => PackedCellLayout.fromTypes(types), throwsFormatException);
      }
    });

    test('decodes codepoint, style, and width from manifest bits', () {
      final types = packedCellTypes();
      final layout = PackedCellLayout.fromTypes(types);
      final raw = rawCell(
        types,
        tag: 0,
        codepoint: 0x41,
        styleId: 0x1234,
        wide: 1,
      );

      final summary = RawCellData();

      layout.decodeInto(raw, summary);

      expect(summary.codepoint, 0x41);
      expect(summary.styleId, 0x1234);
      expect(summary.wide, CellWide.wide);
    });

    test('decodes grapheme codepoints through the tagged arm', () {
      final types = packedCellTypes();
      final layout = PackedCellLayout.fromTypes(types);
      final raw = rawCell(
        types,
        tag: 1,
        codepoint: 0x1F642,
        styleId: 0,
        wide: 0,
      );

      final summary = RawCellData();

      layout.decodeInto(raw, summary);

      expect(summary.codepoint, 0x1F642);
    });

    test('decodes packed cell metadata without a C query', () {
      final types = packedCellTypes();
      final layout = PackedCellLayout.fromTypes(types);
      final raw = rawCell(
        types,
        tag: 0,
        codepoint: 0x41,
        styleId: 7,
        wide: 2,
        isProtected: true,
        hasHyperlink: true,
        semanticContent: 2,
      );
      final data = RawCellData();

      layout.decodeInto(raw, data);

      expect(
        (
          contentTag: data.contentTag,
          codepoint: data.codepoint,
          hasGrapheme: data.hasGrapheme,
          styleId: data.styleId,
          wide: data.wide,
          isProtected: data.isProtected,
          hasHyperlink: data.hasHyperlink,
          semanticContent: data.semanticContent,
          hasBackgroundRgb: data.hasBackgroundRgb,
        ),
        (
          contentTag: CellContentTag.codepoint,
          codepoint: 0x41,
          hasGrapheme: false,
          styleId: 7,
          wide: CellWide.spacerTail,
          isProtected: true,
          hasHyperlink: true,
          semanticContent: CellSemanticContent.prompt,
          hasBackgroundRgb: false,
        ),
      );
    });

    test('decodes inline RGB background data from the tagged arm', () {
      final types = packedCellTypes();
      final layout = PackedCellLayout.fromTypes(types);
      final raw = rawCell(
        types,
        tag: 3,
        codepoint: 0x123456,
        styleId: 0,
        wide: 0,
      );
      final data = RawCellData();

      layout.decodeInto(raw, data);

      expect(
        (
          contentTag: data.contentTag,
          codepoint: data.codepoint,
          hasBackgroundRgb: data.hasBackgroundRgb,
          red: data.backgroundR,
          green: data.backgroundG,
          blue: data.backgroundB,
        ),
        (
          contentTag: CellContentTag.bgColorRgb,
          codepoint: 0,
          hasBackgroundRgb: true,
          red: 0x56,
          green: 0x34,
          blue: 0x12,
        ),
      );
    });

    test('overwrites RGB channels when reusing decoded cell storage', () {
      final types = packedCellTypes();
      final layout = PackedCellLayout.fromTypes(types);
      final data = RawCellData();
      const cases = [
        (
          3,
          0x123456,
          CellContentTag.bgColorRgb,
          0,
          false,
          true,
          0x56,
          0x34,
          0x12,
        ),
        (0, 0x1F642, CellContentTag.codepoint, 0x1F642, false, false, 0, 0, 0),
        (
          3,
          0xABCDEF,
          CellContentTag.bgColorRgb,
          0,
          false,
          true,
          0xEF,
          0xCD,
          0xAB,
        ),
        (
          1,
          0x1F642,
          CellContentTag.codepointGrapheme,
          0x1F642,
          true,
          false,
          0,
          0,
          0,
        ),
        (
          3,
          0x123456,
          CellContentTag.bgColorRgb,
          0,
          false,
          true,
          0x56,
          0x34,
          0x12,
        ),
        (2, 0xAB, CellContentTag.bgColorPalette, 0, false, false, 0, 0, 0),
        (3, 0, CellContentTag.bgColorRgb, 0, false, true, 0, 0, 0),
      ];

      for (final (tag, payload, contentTag, codepoint, grapheme, rgb, r, g, b)
          in cases) {
        final raw = rawCell(
          types,
          tag: tag,
          codepoint: payload,
          styleId: 0,
          wide: 0,
        );

        expect(layout.decodeInto(raw, data), same(data));
        expect(
          (
            data.contentTag,
            data.codepoint,
            data.hasGrapheme,
            data.hasBackgroundRgb,
            rgb ? data.backgroundR : 0,
            rgb ? data.backgroundG : 0,
            rgb ? data.backgroundB : 0,
          ),
          (contentTag, codepoint, grapheme, rgb, r, g, b),
        );
      }
    });

    test('rejects a missing packed field', () {
      final types = packedCellTypes();
      final cell = types['GhosttyCell'] as Map<String, dynamic>;
      final bits = cell['bits'] as Map<String, dynamic>;
      bits.remove('style_id');

      expect(
        () => PackedCellLayout.fromTypes(types),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a malformed tagged union', () {
      final types = packedCellTypes();
      final cell = types['GhosttyCell'] as Map<String, dynamic>;
      final bits = cell['bits'] as Map<String, dynamic>;
      final content = bits['content'] as Map<String, dynamic>;
      content['tag'] = 'wrong_tag';

      expect(
        () => PackedCellLayout.fromTypes(types),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Layouts.fromJson', () {
    String metadata({
      int schema = 1,
      String target = 'wasm32',
      int pointerSize = 4,
      int usizeSize = 4,
      String endian = 'little',
    }) => jsonEncode(<String, dynamic>{
      'schema': schema,
      'abi': {
        'target': target,
        'os': 'freestanding',
        'environment': 'unknown',
        'pointer_size': pointerSize,
        'usize_size': usizeSize,
        'max_alignment': 8,
        'endian': endian,
      },
      'library_version': 'test',
      'commit': null,
      'dirty': null,
      'types': <String, dynamic>{},
    });

    test('rejects an unsupported schema version', () {
      expect(
        () => Layouts.fromJson(metadata(schema: 2)),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Unsupported layout metadata schema: 2.',
          ),
        ),
      );
    });

    test('rejects a non-wasm target', () {
      expect(
        () => Layouts.fromJson(metadata(target: 'x86_64')),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Unsupported layout metadata target: x86_64.',
          ),
        ),
      );
    });

    test('rejects a non-32-bit pointer ABI', () {
      expect(
        () => Layouts.fromJson(metadata(pointerSize: 8)),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Wasm layout metadata must use 32-bit pointers and usize.',
          ),
        ),
      );
    });

    test('rejects a non-little-endian ABI', () {
      expect(
        () => Layouts.fromJson(metadata(endian: 'big')),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Unsupported Wasm layout metadata endianness: big.',
          ),
        ),
      );
    });

    test('rejects metadata with a missing manifest field', () {
      expect(
        () => Layouts.fromJson('{"schema":1}'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Layout metadata is missing manifest field: abi.',
          ),
        ),
      );
    });
  });
}
