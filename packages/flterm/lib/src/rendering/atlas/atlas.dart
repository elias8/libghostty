import 'dart:ui' show Image;

import 'package:libghostty/libghostty.dart';

import 'atlas_budget.dart';
import 'atlas_cache.dart';
import 'atlas_config.dart';
import 'atlas_entry.dart';
import 'lanes/decoration_lane.dart';
import 'lanes/emoji_lane.dart';
import 'lanes/sprite_lane.dart';
import 'lanes/text_lane.dart';

export 'atlas_cache.dart' show TextAtlasKey;
export 'atlas_config.dart';
export 'atlas_entry.dart';

/// Returns borrowed atlas entries or caller-owned [DirectGlyph] ink.
///
/// Call [ensureImage] before painting admitted entries and [dispose] when the
/// atlas owner releases its resources.
class Atlas {
  final AtlasConfig _config;
  final _budget = AtlasBudget();
  late final _textLane = TextLane(budget: _budget);
  late final _emojiLane = EmojiLane(budget: _budget);
  late final _spriteLane = SpriteLane(budget: _budget);
  late final _decorationLane = DecorationLane(budget: _budget);
  late final _cache = AtlasCache(
    budget: _budget,
    textLane: _textLane,
    emojiLane: _emojiLane,
    spriteLane: _spriteLane,
    decorationLane: _decorationLane,
  );

  Atlas(this._config) {
    _configureLanes();
  }

  int get cacheSize => _cache.size;

  Image? get decorationImage => _decorationLane.image;

  double get devicePixelRatio => _config.devicePixelRatio;

  Image? get emojiImage => _emojiLane.image;

  Image? get spriteImage => _spriteLane.image;

  Image? get textImage => _textLane.image;

  Image? imageFor(AtlasEntry entry) => switch (entry.lane) {
    .text => textImage,
    .emoji => emojiImage,
    .sprite => spriteImage,
    .decoration => decorationImage,
  };

  /// Returns or creates a glyph for [key].
  ///
  /// Convenience for call sites that classify text vs. emoji at runtime
  /// (e.g. wide-cell dispatch) and want to defer the branch to the atlas.
  Glyph add(TextAtlasKey key, {int span = 1, bool emoji = false}) =>
      _cache.add(key, span: span, emoji: emoji);

  /// Returns or creates a glyph for a single [codepoint].
  ///
  /// Built-in sprite codepoints bypass font rasterization entirely and
  /// render from geometry. Non-sprite codepoints route through the text
  /// lane so single-codepoint and text-keyed callers share entries.
  Glyph addCodepoint(
    int codepoint, {
    required bool bold,
    required bool italic,
    int span = 1,
    bool centerInFirstCell = false,
  }) => _cache.addCodepoint(
    codepoint,
    bold: bold,
    italic: italic,
    span: span,
    centerInFirstCell: centerInFirstCell,
  );

  /// Returns or creates a decoration sprite for the given underline [style].
  Glyph addDecoration(UnderlineStyle style) => _cache.addDecoration(style);

  void dispose() {
    _cache.clear();
    _textLane.dispose();
    _emojiLane.dispose();
    _spriteLane.dispose();
    _decorationLane.dispose();
  }

  /// Composites pending glyphs into the atlas texture.
  void ensureImage() {
    _textLane.ensureImage();
    _emojiLane.ensureImage();
    _spriteLane.ensureImage();
    _decorationLane.ensureImage();
  }

  /// Whether [codepoint] has a built-in sprite glyph.
  ///
  /// Sprite codepoints render from geometry regardless of how libghostty
  /// classifies the cell (wide, emoji, etc.). Callers route through
  /// [addCodepoint] to retrieve the entry; this predicate lets callers
  /// pick the right output channel before calling.
  bool hasSprite(int codepoint) => _cache.hasSprite(codepoint);

  void _configureLanes() {
    _textLane.configure(_config);
    _emojiLane.configure(_config);
    _spriteLane.configure(_config);
    _decorationLane.configure(_config);
  }
}
