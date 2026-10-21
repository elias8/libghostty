import 'dart:math';
import 'dart:ui';

import '../atlas_config.dart';
import '../atlas_entry.dart';
import 'glyph_raster.dart';
import 'paragraph_lane.dart';

/// Rasterizes full-color emoji glyphs into the emoji atlas.
class EmojiLane extends ParagraphLane {
  static const _emojiLayoutWidthMultiplier = 8;
  static const _emojiFontFamilies = {
    'Apple Color Emoji',
    'Noto Color Emoji',
    'Segoe UI Emoji',
    'Noto Emoji',
  };

  String? _emojiFontFamily;
  List<String>? _emojiFontFamilyFallback;

  EmojiLane({super.initialSize, super.maxSize, super.budget})
    : super(entryLane: .emoji);

  @override
  void configure(AtlasConfig config) {
    super.configure(config);

    final emojiFontFamily = _emojiFontFamilyFor(config);
    _emojiFontFamily = emojiFontFamily;
    _emojiFontFamilyFallback = emojiFontFamily == null
        ? null
        : _emojiFallbackFor(config, emojiFontFamily);
  }

  /// Returns borrowed atlas pixels or caller-owned [DirectGlyph] ink.
  ///
  /// Emoji are rasterized in color and composited with uniform scaling to fit
  /// within the cell span; tinting is not applied at draw time.
  Glyph rasterizeEmoji(
    String text, {
    required bool bold,
    required bool italic,
    int span = 1,
    bool admit = true,
  }) {
    final pxSpanWidth = (pxCellWidth * span).ceilToDouble();
    final pxSpanHeight = pxCellHeight.ceilToDouble();
    final size = min(pxCellHeight, pxCellWidth * span) * 0.95;

    // Keep the paragraph wider than the atlas span so emoji sequences do not
    // wrap before this lane applies its own fitting.
    final layoutWidthMultiplier = max(_emojiLayoutWidthMultiplier, text.length);
    final layoutWidth = max(pxSpanWidth, size * layoutWidthMultiplier);

    final paragraph = buildParagraph(
      text,
      bold: bold,
      italic: italic,
      size: size,
      width: layoutWidth,
      fontFamily: _emojiFontFamily,
      fontFamilyFallback: _emojiFontFamilyFallback,
    );

    final emojiWidth = max(paragraph.maxIntrinsicWidth, 1.0);
    final emojiHeight = max(paragraph.height, 1.0);
    final scale = min(
      1.0,
      min(pxSpanWidth / emojiWidth, pxSpanHeight / emojiHeight),
    );
    return addRaster(
      ParagraphRaster(
        paragraph,
        Size(pxSpanWidth, pxSpanHeight),
        paragraphOffset: Offset(
          (pxSpanWidth - emojiWidth * scale) / 2,
          (pxSpanHeight - emojiHeight * scale) / 2,
        ),
        scaleX: scale,
        scaleY: scale,
      ),
      admit: admit,
    );
  }

  static List<String> _emojiFallbackFor(AtlasConfig config, String primary) {
    final seen = {primary};
    final fallback = <String>[];

    void add(String family) {
      if (seen.add(family)) fallback.add(family);
    }

    for (final family in config.fontFamilyFallback) {
      add(family);
    }
    add(config.fontFamily);
    return fallback;
  }

  static String? _emojiFontFamilyFor(AtlasConfig config) {
    if (_emojiFontFamilies.contains(config.fontFamily)) {
      return config.fontFamily;
    }

    for (final family in config.fontFamilyFallback) {
      if (_emojiFontFamilies.contains(family)) return family;
    }
    return null;
  }
}
