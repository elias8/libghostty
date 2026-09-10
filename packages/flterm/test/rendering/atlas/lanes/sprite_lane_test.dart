import 'dart:typed_data';
import 'dart:ui'
    show BlendMode, Canvas, Color, FontWeight, Paint, PictureRecorder, Rect;

import 'package:flterm/src/foundation/cell_metrics.dart';
import 'package:flterm/src/rendering/atlas/atlas_config.dart';
import 'package:flterm/src/rendering/atlas/atlas_entry.dart';
import 'package:flterm/src/rendering/atlas/lanes/sprite_lane.dart';
import 'package:flterm/src/rendering/sprite/sprite_face.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpriteLane', () {
    AtlasConfig config({
      CellMetrics metrics = const CellMetrics(
        cellWidth: 8,
        cellHeight: 16,
        baseline: 12,
      ),
      double devicePixelRatio = 1.0,
    }) {
      return AtlasConfig(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        fontFamily: 'monospace',
        fontFamilyFallback: const [],
        metrics: metrics,
        devicePixelRatio: devicePixelRatio,
      );
    }

    late SpriteLane lane;

    setUp(() {
      lane = SpriteLane(initialSize: 32, maxSize: 128)..configure(config());
    });

    tearDown(() {
      lane.dispose();
    });

    void configureLargeCells() {
      lane.configure(
        config(
          metrics: const CellMetrics(
            cellWidth: 16,
            cellHeight: 32,
            baseline: 24,
          ),
        ),
      );
    }

    Future<(AtlasEntry, Uint8List, int)> rasterizeGlyph(int codepoint) async {
      final glyph = SpriteFace().glyphFor(codepoint)!;
      final entry = lane.rasterizeSprite(glyph);

      lane.ensureImage();
      final bytes = await lane.image!.toByteData();

      return (entry, bytes!.buffer.asUint8List(), lane.image!.width);
    }

    Future<(Uint8List, int)> renderSpriteChain(
      int codepoint,
      List<(double x, double y)> positions, {
      int cols = 3,
      int rows = 3,
      CellMetrics metrics = const CellMetrics(
        cellWidth: 16,
        cellHeight: 32,
        baseline: 24,
      ),
      double devicePixelRatio = 2.0,
      Color? background,
      int color = 0xFFFFFFFF,
    }) async {
      lane.configure(
        config(metrics: metrics, devicePixelRatio: devicePixelRatio),
      );
      final glyph = SpriteFace().glyphFor(codepoint)!;
      final entry = lane.rasterizeSprite(glyph);
      lane.ensureImage();

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.scale(devicePixelRatio);
      if (background != null) {
        canvas.drawRect(
          Rect.fromLTWH(
            0,
            0,
            cols * metrics.cellWidth,
            rows * metrics.cellHeight,
          ),
          Paint()..color = background,
        );
      }
      final scale = 1 / devicePixelRatio;
      final transforms = Float32List.fromList([
        for (final (x, y) in positions) ...[
          scale,
          0,
          x + entry.bearingX * scale,
          y + entry.bearingY * scale,
        ],
      ]);
      final rects = Float32List.fromList([
        for (final _ in positions) ...[
          entry.srcLeft,
          entry.srcTop,
          entry.srcRight,
          entry.srcBottom,
        ],
      ]);
      final colors = Int32List.fromList([
        for (final _ in positions) color.toSigned(32),
      ]);
      canvas.drawRawAtlas(
        lane.image!,
        transforms,
        rects,
        colors,
        BlendMode.modulate,
        null,
        Paint(),
      );

      final picture = recorder.endRecording();
      addTearDown(picture.dispose);
      final image = await picture.toImage(
        (cols * metrics.cellWidth * devicePixelRatio).toInt(),
        (rows * metrics.cellHeight * devicePixelRatio).toInt(),
      );
      addTearDown(image.dispose);
      final bytes = await image.toByteData();
      final width = image.width;
      return (Uint8List.sublistView(bytes!), width);
    }

    test('rasterizeSprite includes sprite overflow padding', () {
      final glyph = SpriteFace().glyphFor(0x2500)!;

      final entry = lane.rasterizeSprite(glyph);

      expect(entry.srcRight, greaterThan(entry.srcLeft));
      expect(entry.srcLeft, 1);
      expect(entry.srcTop, 1);
      expect(entry.srcRight - entry.srcLeft, 12);
      expect(entry.srcBottom - entry.srcTop, 20);
      expect(entry.bearingX, -2);
      expect(entry.bearingY, -2);
      expect(entry.lane, AtlasEntryLane.sprite);
      expect(lane.hasPending, isTrue);
      expect(lane.image, isNull);
    });

    test('ensureImage creates the atlas image and clears pending sprites', () {
      final glyph = SpriteFace().glyphFor(0x2500)!;
      lane.rasterizeSprite(glyph);

      lane.ensureImage();

      expect(lane.image, isNotNull);
      expect(lane.hasPending, isFalse);
    });

    test('clear removes pending sprites without creating an image', () {
      final glyph = SpriteFace().glyphFor(0x2500)!;
      lane.rasterizeSprite(glyph);

      lane.clear();

      expect(lane.hasPending, isFalse);
      expect(lane.image, isNull);
    });

    test('solid block sprites keep overflow padding transparent', () async {
      configureLargeCells();

      final (entry, rgba, width) = await rasterizeGlyph(0x2588);
      final cellLeft = _cellLeft(entry);
      final midY = _cellTop(entry) + 16;

      expect(_alphaAt(rgba, width, entry.srcLeft.toInt(), midY), 0);
      expect(_alphaAt(rgba, width, cellLeft, midY), 255);
    });

    test('composite block sprites keep overflow padding transparent', () async {
      configureLargeCells();

      final (entry, rgba, width) = await rasterizeGlyph(0x1FB7C);
      final cellLeft = _cellLeft(entry);
      final midY = _cellTop(entry) + 16;

      expect(_alphaAt(rgba, width, entry.srcLeft.toInt(), midY), 0);
      expect(_alphaAt(rgba, width, cellLeft, midY), 255);
    });

    test('fractional block sprites keep visible source geometry', () async {
      configureLargeCells();

      final (entry, rgba, width) = await rasterizeGlyph(0x2581);
      final x = _cellLeft(entry) + 8;
      final top = _cellTop(entry);
      final beforeBlockAlpha = _alphaAt(rgba, width, x, top + 27);
      final firstBlockAlpha = _alphaAt(rgba, width, x, top + 28);

      expect(beforeBlockAlpha, 0);
      expect(firstBlockAlpha, 255);
    });

    test('closed stroked polygons stay inside the cell', () async {
      configureLargeCells();

      final (entry, rgba, width) = await rasterizeGlyph(0x25F8);
      final cellLeft = _cellLeft(entry);
      final cellTop = _cellTop(entry);

      expect(_alphaAt(rgba, width, cellLeft - 1, cellTop + 4), 0);
      expect(_alphaAt(rgba, width, cellLeft + 4, cellTop - 1), 0);
    });

    test('diagonal sprites join with tapered boundary pixels', () async {
      final (rgba, width) = await renderSpriteChain(0x2572, const [
        (0, 0),
        (16, 32),
        (32, 64),
      ]);

      final joinAlpha = _minimumAlphaAtPoints(
        rgba,
        width: width,
        points: const [(31, 63), (32, 64), (63, 127), (64, 128)],
      );
      final shoulderAlpha = _minimumAlphaAtPoints(
        rgba,
        width: width,
        points: const [(31, 67), (63, 131)],
      );

      expect(joinAlpha, 255);
      expect(shoulderAlpha, greaterThan(0));
    });

    test(
      'vertical line sprites keep full color at adjacent cell boundaries',
      () async {
        final (rgba, width) = await renderSpriteChain(
          0x2502,
          const [(0, 0), (0, 16), (0, 32)],
          cols: 1,
          metrics: const CellMetrics(
            cellWidth: 8,
            cellHeight: 16,
            baseline: 12,
          ),
          devicePixelRatio: 1.0,
          background: const Color(0xFF101010),
          color: 0xFFAAFFCC,
        );

        final (seamRed, seamGreen) = _minimumRgbAtPoints(
          rgba,
          width: width,
          points: const [(4, 15), (4, 16)],
        );

        expect(seamRed, 0xAA);
        expect(seamGreen, 0xFF);
      },
    );
  });
}

int _alphaAt(Uint8List rgba, int width, int x, int y) {
  return rgba[(y * width + x) * 4 + 3];
}

int _cellLeft(AtlasEntry entry) => (entry.srcLeft - entry.bearingX).toInt();

int _cellTop(AtlasEntry entry) => (entry.srcTop - entry.bearingY).toInt();

int _minimumAlphaAtPoints(
  Uint8List rgba, {
  required int width,
  required List<(int, int)> points,
}) {
  var minimum = 255;
  for (final (x, y) in points) {
    final alpha = _alphaAt(rgba, width, x, y);
    if (alpha < minimum) minimum = alpha;
  }
  return minimum;
}

(int, int) _minimumRgbAtPoints(
  Uint8List rgba, {
  required int width,
  required List<(int, int)> points,
}) {
  var minimumRed = 255;
  var minimumGreen = 255;
  for (final (x, y) in points) {
    final index = (y * width + x) * 4;
    final red = rgba[index];
    final green = rgba[index + 1];
    if (red < minimumRed) minimumRed = red;
    if (green < minimumGreen) minimumGreen = green;
  }
  return (minimumRed, minimumGreen);
}
