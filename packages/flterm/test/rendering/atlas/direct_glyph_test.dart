import 'dart:typed_data';
import 'dart:ui';

import 'package:flterm/src/rendering/atlas/atlas.dart';
import 'package:flterm/src/rendering/atlas/atlas_texture.dart';
import 'package:flterm/src/rendering/atlas/lanes/atlas_lane.dart';
import 'package:flterm/src/rendering/atlas/lanes/decoration_lane.dart';
import 'package:flterm/src/rendering/atlas/lanes/emoji_lane.dart';
import 'package:flterm/src/rendering/atlas/lanes/sprite_lane.dart';
import 'package:flterm/src/rendering/atlas/lanes/text_lane.dart';
import 'package:flterm/src/rendering/atlas/sprite_buffer.dart';
import 'package:flterm/src/rendering/font/measure_cell_metrics.dart';
import 'package:flterm/src/rendering/sprite/sprite_face.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart';

import '../helpers/font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadBundledFonts);

  test(
    'mixed rows preserve draw order after an earlier packed row shrinks',
    () async {
      final texture = AtlasTexture(initialSize: 16, maxSize: 16);
      final entry = texture.allocate(
        width: 8,
        height: 8,
        bearingY: 0,
        lane: .text,
      )!;
      texture.replaceImage(
        (canvas) => canvas.drawRect(
          const Rect.fromLTWH(0, 0, 8, 8),
          Paint()..color = const Color(0xFFFFFFFF),
        ),
      );
      DirectGlyph direct() {
        final recorder = PictureRecorder();
        Canvas(recorder).drawRect(
          const Rect.fromLTWH(0, 0, 8, 8),
          Paint()..color = const Color(0xFFFFFFFF),
        );
        return DirectGlyph(
          recorder.endRecording(),
          const Size(8, 8),
          .text,
          0,
          0,
        );
      }

      final sprites = AtlasSprites()..configure(3, 2);
      try {
        sprites.beginRow(0);
        sprites.add(16, 16, entry, 1, 0xFFFF0000);
        sprites.endRow();
        sprites.beginRow(1);
        sprites.addDirect(16, 16, direct(), 1, 0x800000FF);
        sprites.add(16, 16, entry, 1, 0x8000FF00);
        sprites.endRow();
        sprites.beginRow(2);
        sprites.addDirect(16, 16, direct(), 1, 0x80FFFF00);
        sprites.endRow();
        sprites.seal();
        for (final includeFirst in [true, false]) {
          if (!includeFirst) {
            sprites.beginRow(0);
            sprites.endRow();
            sprites.seal();
          }
          final actual = await _pixels(
            (canvas) => sprites.paint(canvas, texture.image, 1, Paint()),
          );
          final expected = await _pixels((canvas) {
            for (final color in [
              if (includeFirst) 0xFFFF0000,
              0x800000FF,
              0x8000FF00,
              0x80FFFF00,
            ]) {
              canvas.drawRect(
                const Rect.fromLTWH(16, 16, 8, 8),
                Paint()..color = Color(color),
              );
            }
          });
          expect(actual, orderedEquals(expected));
        }
      } finally {
        sprites.dispose();
        texture.dispose();
      }
    },
  );

  test(
    'row replacement and configure transfer direct glyph ownership once',
    () async {
      final sprites = AtlasSprites()..configure(2, 2);
      final pictures = <Picture>[];
      addTearDown(() {
        sprites.dispose();
        for (final picture in pictures) {
          expect(picture.debugDisposed, isTrue);
        }
      });
      DirectGlyph trackedCircle() {
        final recorder = PictureRecorder();
        Canvas(recorder).drawCircle(
          const Offset(4, 4),
          3.5,
          Paint()..color = const Color(0xFFFFFFFF),
        );
        final picture = recorder.endRecording();
        pictures.add(picture);
        return DirectGlyph(picture, const Size(8, 8), .text, 0, 0);
      }

      final original = trackedCircle();
      final replacement = trackedCircle();
      sprites.beginRow(1);
      sprites.addDirect(12, 12, original, 1, 0xFFFF0000);
      sprites.endRow();
      sprites.seal();
      expect(pictures[0].debugDisposed, isFalse);
      sprites.beginRow(1);
      expect(pictures[0].debugDisposed, isTrue);
      sprites.addDirect(12, 12, replacement, 1, 0xFF0000FF);
      sprites.endRow();
      sprites.seal();
      expect(pictures[1].debugDisposed, isFalse);
      final replaced = await _pixels(
        (canvas) => sprites.paint(canvas, null, 1, Paint()),
      );
      final expectedReplacement = await _pixels(
        (canvas) => replacement.paint(canvas, 12, 12, 1),
      );
      expect(replaced, orderedEquals(expectedReplacement));

      sprites.configure(1, 2);
      expect(pictures[1].debugDisposed, isTrue);
      final configured = trackedCircle();
      sprites.beginRow(0);
      sprites.addDirect(24, 12, configured, 1, 0xFF00FF00);
      sprites.endRow();
      sprites.seal();
      expect(pictures[2].debugDisposed, isFalse);
      final afterConfigure = await _pixels(
        (canvas) => sprites.paint(canvas, null, 1, Paint()),
      );
      final expectedConfigure = await _pixels(
        (canvas) => configured.paint(canvas, 24, 12, 1),
      );
      expect(afterConfigure, orderedEquals(expectedConfigure));
    },
  );

  for (final dpr in [1.0, 1.25, 2.0]) {
    for (final (label, color, positions) in <(String, int, List<Offset>)>[
      (
        'disjoint opaque masks',
        0xFF57A4D8,
        [const Offset(8.25, 7.5), const Offset(21.75, 7.5)],
      ),
      (
        'overlapping opaque masks',
        0xFF57A4D8,
        [const Offset(8.25, 7.5), const Offset(12.25, 7.5)],
      ),
      (
        'overlapping translucent masks',
        0x9957A4D8,
        [const Offset(8.25, 7.5), const Offset(12.25, 7.5)],
      ),
    ]) {
      test('$label match individual paints at $dpr DPR', () async {
        final sprites = AtlasSprites()..configure(1, 4);
        final glyphs = [for (var i = 0; i < positions.length; i++) _circle()];
        sprites.beginRow(0);
        for (var i = 0; i < glyphs.length; i++) {
          final position = positions[i];
          sprites.addDirect(
            position.dx,
            position.dy,
            glyphs[i],
            1 / dpr,
            color,
          );
        }
        sprites.endRow();
        sprites.seal();
        try {
          final actual = await _pixels((canvas) {
            canvas.scale(dpr);
            sprites.paint(canvas, null, 1 / dpr, Paint());
          });
          final expected = await _pixels((canvas) {
            canvas.scale(dpr);
            for (var i = 0; i < glyphs.length; i++) {
              final position = positions[i];
              glyphs[i].paint(canvas, position.dx, position.dy, 1 / dpr);
            }
          });
          expect(actual, orderedEquals(expected));
        } finally {
          sprites.dispose();
        }
      });
    }
  }

  for (final dpr in [1.0, 1.25, 2.0]) {
    test(
      'all lanes preserve placement and whole-glyph tint at $dpr DPR',
      () async {
        final metrics = measureCellMetrics(
          fontSize: 24,
          fontFamily: 'JetBrains Mono',
          fontFamilyFallback: bundledFontFamilyFallback,
          fontData: jetBrainsMonoBytes,
          devicePixelRatio: dpr,
        );
        final config = AtlasConfig(
          fontSize: 24,
          fontFamily: 'JetBrains Mono',
          fontFamilyFallback: bundledFontFamilyFallback,
          fontWeight: FontWeight.normal,
          metrics: metrics,
          devicePixelRatio: dpr,
        );
        final text = TextLane()..configure(config);
        final emoji = EmojiLane()..configure(config);
        final sprite = SpriteLane()..configure(config);
        final decoration = DecorationLane()..configure(config);
        final cases = <(AtlasLane, Glyph Function({required bool admit}))>[
          (
            text,
            ({required admit}) => text.rasterizeText(
              'A',
              bold: false,
              italic: false,
              admit: admit,
            ),
          ),
          (
            text,
            ({required admit}) => text.rasterizeText(
              'gj',
              bold: true,
              italic: true,
              admit: admit,
            ),
          ),
          (
            text,
            ({required admit}) => text.rasterizeText(
              '\u03b1\u0301',
              bold: false,
              italic: false,
              admit: admit,
            ),
          ),
          (
            text,
            ({required admit}) => text.rasterizeText(
              '\u4e2d',
              bold: false,
              italic: false,
              span: 2,
              admit: admit,
            ),
          ),
          (
            emoji,
            ({required admit}) => emoji.rasterizeEmoji(
              '\u{1F469}\u200d\u{1F4BB}',
              bold: false,
              italic: false,
              span: 2,
              admit: admit,
            ),
          ),
          (
            sprite,
            ({required admit}) => sprite.rasterizeSprite(
              SpriteFace().glyphFor(0x253c)!,
              admit: admit,
            ),
          ),
          (
            sprite,
            ({required admit}) => sprite.rasterizeSprite(
              SpriteFace().glyphFor(0x2588)!,
              admit: admit,
            ),
          ),
          (
            decoration,
            ({required admit}) => decoration.rasterizeDecoration(
              UnderlineStyle.curly,
              admit: admit,
            ),
          ),
        ];
        try {
          for (final (lane, resolve) in cases) {
            final packed = resolve(admit: true) as AtlasEntry;
            final direct = resolve(admit: false) as DirectGlyph;
            try {
              lane.ensureImage();
              // The atlas quantizes color before compositing. Compare emoji
              // on transparency; opaque composition has separate goldens.
              final background = packed.lane == .emoji
                  ? const Color(0x00000000)
                  : const Color(0xFF1D1F21);
              for (final color in [0xFFFFFFFF, 0x9957A4D8]) {
                direct.configureTint(packed.lane == .emoji ? null : color);
                final cached = await _pixels((canvas) {
                  final bearing = Offset(packed.bearingX, packed.bearingY);
                  final paint = Paint();
                  if (packed.lane != .emoji) {
                    paint.colorFilter = ColorFilter.mode(
                      Color(color),
                      BlendMode.modulate,
                    );
                  }
                  canvas.drawImageRect(
                    lane.image!,
                    Rect.fromLTRB(
                      packed.srcLeft,
                      packed.srcTop,
                      packed.srcRight,
                      packed.srcBottom,
                    ),
                    Rect.fromLTWH(
                      16 + bearing.dx,
                      16 + bearing.dy,
                      packed.srcRight - packed.srcLeft,
                      packed.srcBottom - packed.srcTop,
                    ),
                    paint,
                  );
                }, background: background);
                final fallback = await _pixels(
                  (canvas) => direct.paint(canvas, 16, 16, 1),
                  background: background,
                );
                expect(
                  fallback,
                  orderedEquals(cached),
                  reason: '${packed.lane}, DPR $dpr, color $color',
                );
              }
            } finally {
              direct.dispose();
            }
          }

          const opaque = 0xFF57A4D8;
          final glyphs = <DirectGlyph>[
            text.rasterizeText(
                  '\u4e2d',
                  bold: false,
                  italic: false,
                  span: 2,
                  admit: false,
                )
                as DirectGlyph,
            sprite.rasterizeSprite(SpriteFace().glyphFor(0x253C)!, admit: false)
                as DirectGlyph,
          ];
          final positions = [const Offset(8.25, 8.5), const Offset(64.25, 8.5)];
          expect(
            glyphs[0]
                .boundsAt(positions[0].dx, positions[0].dy, 1 / dpr)
                .overlaps(
                  glyphs[1].boundsAt(positions[1].dx, positions[1].dy, 1 / dpr),
                ),
            isFalse,
          );
          final grouped = AtlasSprites()..configure(1, glyphs.length);
          grouped.beginRow(0);
          for (var i = 0; i < glyphs.length; i++) {
            final position = positions[i];
            grouped.addDirect(
              position.dx,
              position.dy,
              glyphs[i],
              1 / dpr,
              opaque,
            );
          }
          grouped.endRow();
          grouped.seal();
          try {
            final actual = await _pixels((canvas) {
              canvas.scale(dpr);
              grouped.paint(canvas, null, 1 / dpr, Paint());
            });
            final expected = await _pixels((canvas) {
              canvas.scale(dpr);
              for (var i = 0; i < glyphs.length; i++) {
                final position = positions[i];
                glyphs[i].paint(canvas, position.dx, position.dy, 1 / dpr);
              }
            });
            expect(actual, orderedEquals(expected));
          } finally {
            grouped.dispose();
          }
        } finally {
          text.dispose();
          emoji.dispose();
          sprite.dispose();
          decoration.dispose();
        }
      },
    );
  }
}

DirectGlyph _circle() {
  final recorder = PictureRecorder();
  Canvas(recorder).drawCircle(
    const Offset(4, 4),
    3.5,
    Paint()..color = const Color(0xFFFFFFFF),
  );
  return DirectGlyph(recorder.endRecording(), const Size(8, 8), .text, 0, 0);
}

Future<Uint8List> _pixels(
  void Function(Canvas) draw, {
  Color background = const Color(0xFF1D1F21),
}) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(background, BlendMode.src);
  draw(canvas);
  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(192, 128);
    try {
      final data = (await image.toByteData())!;
      return Uint8List.fromList(data.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}
