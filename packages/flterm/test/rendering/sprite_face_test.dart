import 'dart:typed_data';
import 'dart:ui';

import 'package:flterm/src/rendering/sprite/sprite_face.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final face = SpriteFace();

  group('SpriteFace', () {
    // 8-bit octant patterns for U+1CD00..U+1CDDD, in codepoint order.
    // Each byte's bits 0..7 mark which of the eight 2x4 cells are filled.
    // dart format off
    const expectedOctantData = [
      0x04, 0x06, 0x07, 0x08, 0x09, 0x0b, 0x0c, 0x0d, // U+1CD00..1CD07
      0x0e, 0x10, 0x11, 0x12, 0x13, 0x15, 0x16, 0x17, // U+1CD08..1CD0F
      0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, // U+1CD10..1CD17
      0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, // U+1CD18..1CD1F
      0x29, 0x2a, 0x2b, 0x2c, 0x2d, 0x2e, 0x2f, 0x30, // U+1CD20..1CD27
      0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, // U+1CD28..1CD2F
      0x39, 0x3a, 0x3b, 0x3c, 0x3d, 0x3e, 0x41, 0x42, // U+1CD30..1CD37
      0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4a, // U+1CD38..1CD3F
      0x4b, 0x4c, 0x4d, 0x4e, 0x4f, 0x51, 0x52, 0x53, // U+1CD40..1CD47
      0x54, 0x56, 0x57, 0x58, 0x59, 0x5b, 0x5c, 0x5d, // U+1CD48..1CD4F
      0x5e, 0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, // U+1CD50..1CD57
      0x67, 0x68, 0x69, 0x6a, 0x6b, 0x6c, 0x6d, 0x6e, // U+1CD58..1CD5F
      0x6f, 0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, // U+1CD60..1CD67
      0x77, 0x78, 0x79, 0x7a, 0x7b, 0x7c, 0x7d, 0x7e, // U+1CD68..1CD6F
      0x7f, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, // U+1CD70..1CD77
      0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x8d, 0x8e, 0x8f, // U+1CD78..1CD7F
      0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, // U+1CD80..1CD87
      0x98, 0x99, 0x9a, 0x9b, 0x9c, 0x9d, 0x9e, 0x9f, // U+1CD88..1CD8F
      0xa1, 0xa2, 0xa3, 0xa4, 0xa6, 0xa7, 0xa8, 0xa9, // U+1CD90..1CD97
      0xab, 0xac, 0xad, 0xae, 0xb0, 0xb1, 0xb2, 0xb3, // U+1CD98..1CD9F
      0xb4, 0xb5, 0xb6, 0xb7, 0xb8, 0xb9, 0xba, 0xbb, // U+1CDA0..1CDA7
      0xbc, 0xbd, 0xbe, 0xbf, 0xc1, 0xc2, 0xc3, 0xc4, // U+1CDA8..1CDAF
      0xc5, 0xc6, 0xc7, 0xc8, 0xc9, 0xca, 0xcb, 0xcc, // U+1CDB0..1CDB7
      0xcd, 0xce, 0xcf, 0xd0, 0xd1, 0xd2, 0xd3, 0xd4, // U+1CDB8..1CDBF
      0xd5, 0xd6, 0xd7, 0xd8, 0xd9, 0xda, 0xdb, 0xdc, // U+1CDC0..1CDC7
      0xdd, 0xde, 0xdf, 0xe0, 0xe1, 0xe2, 0xe3, 0xe4, // U+1CDC8..1CDCF
      0xe5, 0xe6, 0xe7, 0xe8, 0xe9, 0xea, 0xeb, 0xec, // U+1CDD0..1CDD7
      0xed, 0xee, 0xef, 0xf1, 0xf2, 0xf3, 0xf4, 0xf6, // U+1CDD8..1CDDF
      0xf7, 0xf8, 0xf9, 0xfb, 0xfd, 0xfe, // U+1CDE0..1CDE5
    ];
    // dart format on

    int litPixelsInRect(
      Uint8List rgba,
      int width,
      int left,
      int top,
      int right,
      int bottom,
    ) {
      var count = 0;
      for (var y = top; y < bottom; y++) {
        for (var x = left; x < right; x++) {
          if (rgba[(y * width + x) * 4 + 3] != 0) count++;
        }
      }
      return count;
    }

    int alphaSumInRect(
      Uint8List rgba,
      int width,
      int left,
      int top,
      int right,
      int bottom,
    ) {
      var sum = 0;
      for (var y = top; y < bottom; y++) {
        for (var x = left; x < right; x++) {
          sum += rgba[(y * width + x) * 4 + 3];
        }
      }
      return sum;
    }

    void paintCodepoint(
      SpriteFace face,
      SpriteContext context,
      Canvas canvas,
      int codepoint,
      Rect cell,
    ) {
      final glyph = face.glyphFor(codepoint);
      expect(
        glyph,
        isNotNull,
        reason: 'missing codepoint ${codepoint.toRadixString(16)}',
      );
      context.reset();
      glyph!.paint(canvas, cell, context);
    }

    Future<Uint8List> rasterize(
      SpriteFace face,
      SpriteContext context,
      int codepoint,
    ) async {
      const width = 16.0;
      const height = 32.0;
      final recorder = PictureRecorder();
      paintCodepoint(
        face,
        context,
        Canvas(recorder),
        codepoint,
        const Rect.fromLTWH(0, 0, width, height),
      );
      final picture = recorder.endRecording();
      addTearDown(picture.dispose);
      final image = picture.toImageSync(width.toInt(), height.toInt());
      addTearDown(image.dispose);
      final bytes = await image.toByteData();
      return Uint8List.sublistView(bytes!);
    }

    void expectArcGlyph(Uint8List rgba, int width, int height, int corner) {
      final top = litPixelsInRect(
        rgba,
        width,
        width ~/ 3,
        0,
        width * 2 ~/ 3,
        2,
      );
      final bottom = litPixelsInRect(
        rgba,
        width,
        width ~/ 3,
        height - 2,
        width * 2 ~/ 3,
        height,
      );
      final left = litPixelsInRect(
        rgba,
        width,
        0,
        height ~/ 3,
        2,
        height * 2 ~/ 3,
      );
      final right = litPixelsInRect(
        rgba,
        width,
        width - 2,
        height ~/ 3,
        width,
        height * 2 ~/ 3,
      );

      switch (corner) {
        case 0:
          expect(top, greaterThan(0));
          expect(left, greaterThan(0));
          expect(bottom, 0);
          expect(right, 0);
        case 1:
          expect(top, greaterThan(0));
          expect(right, greaterThan(0));
          expect(bottom, 0);
          expect(left, 0);
        case 2:
          expect(bottom, greaterThan(0));
          expect(left, greaterThan(0));
          expect(top, 0);
          expect(right, 0);
        case 3:
          expect(bottom, greaterThan(0));
          expect(right, greaterThan(0));
          expect(top, 0);
          expect(left, 0);
      }
    }

    void expectGridCells(
      Uint8List rgba,
      int width,
      int height, {
      required int cols,
      required int rows,
      required Set<int> expectedBits,
    }) {
      final cellWidth = width ~/ cols;
      final cellHeight = height ~/ rows;
      for (var row = 0; row < rows; row++) {
        for (var col = 0; col < cols; col++) {
          final bit = row * cols + col;
          final lit = litPixelsInRect(
            rgba,
            width,
            col * cellWidth,
            row * cellHeight,
            (col + 1) * cellWidth,
            (row + 1) * cellHeight,
          );
          if (expectedBits.contains(bit)) {
            expect(lit, greaterThan(0), reason: 'expected bit $bit to be lit');
          } else {
            expect(lit, 0, reason: 'expected bit $bit to be empty');
          }
        }
      }
    }

    group('coverage', () {
      test('dense ranges are fully populated', () {
        const ranges = {
          'box drawing': (0x2500, 0x257F),
          'block elements': (0x2580, 0x259F),
          'braille': (0x2800, 0x28FF),
          'powerline': (0xE0B0, 0xE0BF),
          'legacy computing sextants': (0x1FB00, 0x1FB3B),
        };
        for (final entry in ranges.entries) {
          final (start, end) = entry.value;
          for (var cp = start; cp <= end; cp++) {
            expect(
              face.hasCodepoint(cp),
              isTrue,
              reason: '${entry.key}: ${cp.toRadixString(16)}',
            );
          }
        }
      });

      test('discrete codepoints from sparse ranges', () {
        // dart format off
        const codepoints = [
          0x25E2, 0x25E5, 0x25F8, 0x25FF, // geometric shapes
          0xE0D2, 0xE0D4, // powerline flames
          0xF5D0, 0xF60D, // branch drawing
          0x1CC21, 0x1CC30, 0x1CD00, 0x1CE0B, 0x1CE51, // legacy supplement
          0x1FB00, 0x1FB93, 0x1FB95, // legacy computing
          0x1FBBD, 0x1FBBF, 0x1FBEF, // legacy computing
        ];
        // dart format on

        for (final cp in codepoints) {
          expect(face.hasCodepoint(cp), isTrue, reason: cp.toRadixString(16));
        }
      });

      test('unregistered codepoints return false', () {
        // dart format off
        const groups = {
          'emoji presentation': [
            0x23BF, 0x23FA, 0x26AA, 0x26AB,
            0x2B1B, 0x2B1C, 0x2B24, 0x2B55,
          ],
          'sparse geometric shapes': [
            0x25A0, 0x25A1, 0x25AA, 0x25AB, 0x25B2,
            0x25B6, 0x25BC, 0x25C0, 0x25C6, 0x25CB,
            0x25CF, 0x25D0, 0x25D1, 0x25D6, 0x25E0,
          ],
          'unregistered miscellany': [
            0x41, 0x7E, 0x25F7, 0x2900, 0xE0AF,
            0xE0C0, 0xE0D3, 0x1CDE6, 0x1CDF3,
          ],
        };
        // dart format on

        for (final entry in groups.entries) {
          for (final cp in entry.value) {
            expect(
              face.hasCodepoint(cp),
              isFalse,
              reason: '${entry.key}: ${cp.toRadixString(16)}',
            );
          }
        }
      });
    });

    group('painting', () {
      late PictureRecorder recorder;
      late Canvas canvas;
      late SpriteContext context;
      const cell = Rect.fromLTWH(0, 0, 8, 16);

      setUp(() {
        recorder = PictureRecorder();
        canvas = Canvas(recorder);
        context = SpriteContext();
      });

      tearDown(() {
        recorder.endRecording().dispose();
      });

      test('every registered codepoint paints without throwing', () {
        for (final cp in face.supportedCodepoints) {
          paintCodepoint(face, context, canvas, cp, cell);
        }
      });

      test('various cell sizes', () {
        const sizes = [
          Size(6, 12),
          Size(8, 16),
          Size(10, 20),
          Size(16, 32),
          Size(24, 48),
        ];
        const samples = [0x2500, 0x2588, 0x28FF, 0xE0B0, 0x256C];

        for (final size in sizes) {
          final rect = Rect.fromLTWH(0, 0, size.width, size.height);
          for (final cp in samples) {
            paintCodepoint(face, context, canvas, cp, rect);
          }
        }
      });

      test('distinct codepoints produce distinct pixels', () async {
        final horizontalLine = await rasterize(face, context, 0x2500);
        final fullBlock = await rasterize(face, context, 0x2588);
        final cornerTriangle = await rasterize(face, context, 0x25F8);
        expect(horizontalLine, isNot(equals(fullBlock)));
        expect(horizontalLine, isNot(equals(cornerTriangle)));
        expect(fullBlock, isNot(equals(cornerTriangle)));
      });

      test(
        'box stubs draw a vertical pole with a half-bar in the right quadrant',
        () async {
          final topRight = await rasterize(face, context, 0x1CE16);
          final bottomRight = await rasterize(face, context, 0x1CE17);
          final topLeft = await rasterize(face, context, 0x1CE18);
          final bottomLeft = await rasterize(face, context, 0x1CE19);

          for (final bytes in [topRight, bottomRight, topLeft, bottomLeft]) {
            expect(litPixelsInRect(bytes, 16, 7, 0, 9, 32), greaterThan(0));
          }

          expect(litPixelsInRect(topRight, 16, 8, 0, 16, 2), greaterThan(0));
          expect(litPixelsInRect(topRight, 16, 0, 0, 7, 2), 0);
          expect(litPixelsInRect(topRight, 16, 10, 30, 16, 32), 0);

          expect(
            litPixelsInRect(bottomRight, 16, 8, 30, 16, 32),
            greaterThan(0),
          );
          expect(litPixelsInRect(bottomRight, 16, 0, 30, 7, 32), 0);
          expect(litPixelsInRect(bottomRight, 16, 10, 0, 16, 2), 0);

          expect(litPixelsInRect(topLeft, 16, 0, 0, 8, 2), greaterThan(0));
          expect(litPixelsInRect(topLeft, 16, 9, 0, 16, 2), 0);
          expect(litPixelsInRect(topLeft, 16, 0, 30, 7, 32), 0);

          expect(litPixelsInRect(bottomLeft, 16, 0, 30, 8, 32), greaterThan(0));
          expect(litPixelsInRect(bottomLeft, 16, 9, 30, 16, 32), 0);
          expect(litPixelsInRect(bottomLeft, 16, 0, 0, 7, 2), 0);
        },
      );

      test(
        'sixteenth mosaics light up the cells encoded by their codepoint',
        () async {
          for (var row = 0; row < 4; row++) {
            for (var col = 0; col < 4; col++) {
              final cp = 0x1CE90 + row * 4 + col;
              final bytes = await rasterize(face, context, cp);
              expectGridCells(
                bytes,
                16,
                32,
                cols: 4,
                rows: 4,
                expectedBits: {row * 4 + col},
              );
            }
          }

          expectGridCells(
            await rasterize(face, context, 0x1CEA0),
            16,
            32,
            cols: 4,
            rows: 4,
            expectedBits: {14, 15},
          );
          expectGridCells(
            await rasterize(face, context, 0x1CEA5),
            16,
            32,
            cols: 4,
            rows: 4,
            expectedBits: {4, 8, 12},
          );
          expectGridCells(
            await rasterize(face, context, 0x1CEAA),
            16,
            32,
            cols: 4,
            rows: 4,
            expectedBits: {1, 2, 3},
          );
          expectGridCells(
            await rasterize(face, context, 0x1CEAD),
            16,
            32,
            cols: 4,
            rows: 4,
            expectedBits: {3, 7, 11},
          );
        },
      );

      test(
        'separated 2x3 mosaics light up the cells encoded by codepoint bits',
        () async {
          for (var cp = 0x1CE51; cp <= 0x1CE8F; cp++) {
            final bytes = await rasterize(face, context, cp);
            final pattern = cp - 0x1CE50;
            final expectedBits = <int>{};
            for (var bit = 0; bit < 6; bit++) {
              if ((pattern & (1 << bit)) != 0) expectedBits.add(bit);
            }
            expectGridCells(
              bytes,
              16,
              32,
              cols: 2,
              rows: 3,
              expectedBits: expectedBits,
            );
          }
        },
      );

      test(
        '2x4 octants light up the cells encoded by their codepoint bits',
        () async {
          for (var i = 0; i < expectedOctantData.length; i++) {
            final bytes = await rasterize(face, context, 0x1CD00 + i);
            final expectedBits = <int>{};
            final pattern = expectedOctantData[i];
            for (var bit = 0; bit < 8; bit++) {
              if ((pattern & (1 << bit)) != 0) expectedBits.add(bit);
            }
            expectGridCells(
              bytes,
              16,
              32,
              cols: 2,
              rows: 4,
              expectedBits: expectedBits,
            );
          }
        },
      );

      test(
        'box dash combos draw a horizontal bar with a half-vertical spur',
        () async {
          final upperRight = await rasterize(face, context, 0x1CC1B);
          final lowerRight = await rasterize(face, context, 0x1CC1C);
          final topLeft = await rasterize(face, context, 0x1CC1D);
          final bottomLeft = await rasterize(face, context, 0x1CC1E);

          expect(
            litPixelsInRect(upperRight, 16, 0, 15, 16, 17),
            greaterThan(0),
          );
          expect(
            litPixelsInRect(upperRight, 16, 14, 0, 16, 15),
            greaterThan(0),
          );
          expect(litPixelsInRect(upperRight, 16, 14, 18, 16, 32), 0);

          expect(
            litPixelsInRect(lowerRight, 16, 0, 15, 16, 17),
            greaterThan(0),
          );
          expect(
            litPixelsInRect(lowerRight, 16, 14, 16, 16, 32),
            greaterThan(0),
          );
          expect(litPixelsInRect(lowerRight, 16, 14, 0, 16, 14), 0);

          expect(litPixelsInRect(topLeft, 16, 0, 0, 16, 2), greaterThan(0));
          expect(litPixelsInRect(topLeft, 16, 0, 2, 2, 16), greaterThan(0));
          expect(litPixelsInRect(topLeft, 16, 14, 2, 16, 16), 0);
          expect(litPixelsInRect(topLeft, 16, 0, 18, 2, 32), 0);

          expect(
            litPixelsInRect(bottomLeft, 16, 0, 30, 16, 32),
            greaterThan(0),
          );
          expect(litPixelsInRect(bottomLeft, 16, 0, 16, 2, 30), greaterThan(0));
          expect(litPixelsInRect(bottomLeft, 16, 14, 16, 16, 30), 0);
          expect(litPixelsInRect(bottomLeft, 16, 0, 0, 2, 14), 0);
        },
      );

      test('branch drawing arc corners connect the expected sides', () async {
        expectArcGlyph(await rasterize(face, context, 0xF5D6), 16, 32, 3);
        expectArcGlyph(await rasterize(face, context, 0xF5D7), 16, 32, 2);
        expectArcGlyph(await rasterize(face, context, 0xF5D8), 16, 32, 1);
        expectArcGlyph(await rasterize(face, context, 0xF5D9), 16, 32, 0);
      });

      test(
        'branch drawing fading lines fade toward the expected side',
        () async {
          final fadeRight = await rasterize(face, context, 0xF5D2);
          final fadeLeft = await rasterize(face, context, 0xF5D3);
          final fadeBottom = await rasterize(face, context, 0xF5D4);
          final fadeTop = await rasterize(face, context, 0xF5D5);

          expect(
            alphaSumInRect(fadeRight, 16, 0, 15, 4, 17),
            greaterThan(alphaSumInRect(fadeRight, 16, 12, 15, 16, 17)),
          );
          expect(
            alphaSumInRect(fadeLeft, 16, 12, 15, 16, 17),
            greaterThan(alphaSumInRect(fadeLeft, 16, 0, 15, 4, 17)),
          );
          expect(
            alphaSumInRect(fadeBottom, 16, 7, 0, 9, 8),
            greaterThan(alphaSumInRect(fadeBottom, 16, 7, 24, 9, 32)),
          );
          expect(
            alphaSumInRect(fadeTop, 16, 7, 24, 9, 32),
            greaterThan(alphaSumInRect(fadeTop, 16, 7, 0, 9, 8)),
          );
        },
      );

      test('powerline outline semicircles are arcs, not D-outlines', () async {
        final rightOutline = await rasterize(face, context, 0xE0B5);
        final leftOutline = await rasterize(face, context, 0xE0B7);

        expect(litPixelsInRect(rightOutline, 16, 0, 12, 2, 20), 0);
        expect(
          litPixelsInRect(rightOutline, 16, 14, 12, 16, 20),
          greaterThan(0),
        );

        expect(litPixelsInRect(leftOutline, 16, 14, 12, 16, 20), 0);
        expect(litPixelsInRect(leftOutline, 16, 0, 12, 2, 20), greaterThan(0));
      });

      test('powerline flames use a dynamic center gap', () async {
        final rightFlame = await rasterize(face, context, 0xE0D2);
        final leftFlame = await rasterize(face, context, 0xE0D4);

        expect(litPixelsInRect(rightFlame, 16, 0, 16, 16, 17), 0);
        expect(litPixelsInRect(leftFlame, 16, 0, 16, 16, 17), 0);

        expect(litPixelsInRect(rightFlame, 16, 0, 0, 16, 8), greaterThan(0));
        expect(litPixelsInRect(rightFlame, 16, 0, 24, 16, 32), greaterThan(0));
        expect(litPixelsInRect(leftFlame, 16, 0, 0, 16, 8), greaterThan(0));
        expect(litPixelsInRect(leftFlame, 16, 0, 24, 16, 32), greaterThan(0));
      });
    });

    group('paint state', () {
      late PictureRecorder recorder;
      late Canvas canvas;
      const cell = Rect.fromLTWH(0, 0, 8, 16);

      setUp(() {
        recorder = PictureRecorder();
        canvas = Canvas(recorder);
      });

      tearDown(() {
        recorder.endRecording().dispose();
      });

      test('FractionalBlock with alpha restores fill color after paint', () {
        final paintContext = SpriteContext()..reset();
        const originalColor = Color(0xFF123456);
        paintContext.fill.color = originalColor;

        const FractionalBlock(
          0,
          0,
          1,
          1,
          alpha: 0.5,
        ).paint(canvas, cell, paintContext);

        expect(paintContext.fill.color.toARGB32(), originalColor.toARGB32());
      });

      test('SpriteContext.resetForGlyph restores full drawing state', () {
        final paintContext = SpriteContext()..reset();
        const fillColor = Color(0xFFABCDEF);
        const strokeColor = Color(0xFFFEDCBA);
        paintContext.path
          ..addRect(cell)
          ..fillType = PathFillType.evenOdd;
        paintContext.fill
          ..color = const Color(0xFF010203)
          ..blendMode = BlendMode.multiply
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        paintContext.stroke
          ..color = const Color(0xFF040506)
          ..blendMode = BlendMode.multiply
          ..strokeWidth = 6.0
          ..strokeCap = StrokeCap.square
          ..strokeJoin = StrokeJoin.bevel;

        paintContext.resetForGlyph(
          fillColor: fillColor,
          strokeColor: strokeColor,
          fillBlendMode: BlendMode.plus,
          strokeBlendMode: BlendMode.screen,
        );

        expect(paintContext.path.getBounds(), Rect.zero);
        expect(paintContext.path.fillType, PathFillType.nonZero);
        expect(paintContext.fill.color.toARGB32(), fillColor.toARGB32());
        expect(paintContext.fill.blendMode, BlendMode.plus);
        expect(paintContext.fill.style, PaintingStyle.fill);
        expect(paintContext.fill.strokeWidth, 0.0);
        expect(paintContext.fill.strokeCap, StrokeCap.butt);
        expect(paintContext.fill.strokeJoin, StrokeJoin.miter);
        expect(paintContext.stroke.color.toARGB32(), strokeColor.toARGB32());
        expect(paintContext.stroke.blendMode, BlendMode.screen);
        expect(paintContext.stroke.style, PaintingStyle.stroke);
        expect(paintContext.stroke.strokeWidth, 0.0);
        expect(paintContext.stroke.strokeCap, StrokeCap.butt);
        expect(paintContext.stroke.strokeJoin, StrokeJoin.miter);
      });

      test('KnockoutComposite restores caller blend modes after paint', () {
        final paintContext = SpriteContext()..reset();
        const fillColor = Color(0xFFABCDEF);
        const strokeColor = Color(0xFFFEDCBA);
        paintContext.fill
          ..color = fillColor
          ..blendMode = BlendMode.plus;
        paintContext.stroke
          ..color = strokeColor
          ..blendMode = BlendMode.screen;

        const KnockoutComposite([
          FractionalBlock(0, 0, 1, 1),
          Circle(0.5, 0.5, 0.25, filled: false),
        ]).paint(canvas, cell, paintContext);

        expect(paintContext.fill.color.toARGB32(), fillColor.toARGB32());
        expect(paintContext.fill.blendMode, BlendMode.plus);
        expect(paintContext.stroke.color.toARGB32(), strokeColor.toARGB32());
        expect(paintContext.stroke.blendMode, BlendMode.screen);
      });
    });

    group('registry', () {
      test('contains at least 1000 entries', () {
        expect(buildBuiltinSpriteRegistry().length, greaterThan(1000));
      });
    });
  });
}
