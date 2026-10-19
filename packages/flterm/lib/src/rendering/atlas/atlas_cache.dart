import 'package:libghostty/libghostty.dart' show UnderlineStyle;

import '../sprite/sprite_face.dart';
import 'atlas_budget.dart';
import 'atlas_entry.dart';
import 'lanes/decoration_lane.dart';
import 'lanes/emoji_lane.dart';
import 'lanes/sprite_lane.dart';
import 'lanes/text_lane.dart';

/// Lookup key for a cached text glyph. Two glyphs with the same text, bold,
/// and italic state share the same atlas entry.
typedef TextAtlasKey = ({String text, bool bold, bool italic});
typedef _CodepointKey = ({
  int codepoint,
  bool bold,
  bool italic,
  int span,
  bool centerInFirstCell,
});
typedef _TextKey = ({
  String text,
  bool bold,
  bool italic,
  int span,
  bool centerInFirstCell,
});
typedef _SpriteKey = ({int codepoint, int span});

/// Caches atlas entries and delegates rasterization on cache miss.
class AtlasCache {
  // Printable ASCII excluding space; space does not rasterize.
  static const _printableAsciiStart = 0x21; // !
  static const _printableAsciiEnd = 0x7E; // ~
  static const _printableAsciiCount =
      _printableAsciiEnd - _printableAsciiStart + 1;

  // Built-in sprites start at U+2500; lower glyphs skip registry lookup.
  static const _builtinSpriteStart = 0x2500;
  static const _singleCellTextSourcePadding = 2.0;

  final AtlasBudget _budget;
  final SpriteFace _spriteFace;
  final TextLane _textLane;
  final EmojiLane _emojiLane;
  final SpriteLane _spriteLane;
  final DecorationLane _decorationLane;

  final Map<_TextKey, AtlasEntry> _text = {};
  final Map<({String text, bool bold, bool italic, int span}), AtlasEntry>
  _emoji = {};
  final Map<_SpriteKey, AtlasEntry> _sprites = {};
  final Map<_CodepointKey, AtlasEntry> _codepoints = {};
  final Map<UnderlineStyle, AtlasEntry> _decorations = {};
  final List<AtlasEntry?> _regularAscii = List.filled(
    _printableAsciiCount,
    null,
  );

  AtlasCache({
    required this._budget,
    required this._textLane,
    required this._emojiLane,
    required this._spriteLane,
    required this._decorationLane,
    SpriteFace? spriteFace,
  }) : _spriteFace = spriteFace ?? SpriteFace();

  int get size {
    return _text.length + _emoji.length + _sprites.length + _decorations.length;
  }

  /// Returns or creates a text or emoji glyph for [key].
  Glyph add(TextAtlasKey key, {int span = 1, bool emoji = false}) {
    return emoji ? _addEmoji(key, span: span) : _addText(key, span: span);
  }

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
  }) {
    if (span == 1 &&
        !bold &&
        !italic &&
        codepoint >= _printableAsciiStart &&
        codepoint <= _printableAsciiEnd) {
      final index = codepoint - _printableAsciiStart;
      final existing = _regularAscii[index];
      if (existing != null) return existing;
      final glyph = _addText((
        text: String.fromCharCode(codepoint),
        bold: false,
        italic: false,
      ));
      if (glyph is AtlasEntry && _budget.canIndex(1, 0)) {
        _regularAscii[index] = glyph;
        _budget.addIndex(1, 0);
      }
      return glyph;
    }

    if (codepoint >= _builtinSpriteStart) {
      final sprite = _addSpriteCodepoint(codepoint, span: span);
      if (sprite != null) return sprite;
    }

    final key = (
      codepoint: codepoint,
      bold: bold,
      italic: italic,
      span: span,
      centerInFirstCell: centerInFirstCell,
    );
    final existing = _codepoints[key];
    if (existing != null) return existing;

    final entry = _addText(
      (text: String.fromCharCode(codepoint), bold: bold, italic: italic),
      span: span,
      centerInFirstCell: centerInFirstCell,
    );
    if (entry is AtlasEntry && _budget.canIndex(1, 0)) {
      _codepoints[key] = entry;
      _budget.addIndex(1, 0);
    }
    return entry;
  }

  /// Returns or creates a decoration sprite for the given underline [style].
  Glyph addDecoration(UnderlineStyle style) {
    final existing = _decorations[style];
    if (existing != null) return existing;
    final glyph = _decorationLane.rasterizeDecoration(
      style,
      admit: _budget.canIndex(1, 0),
    );
    if (glyph is AtlasEntry) {
      _decorations[style] = glyph;
      _budget.addIndex(1, 0);
    }
    return glyph;
  }

  void clear() {
    _text.clear();
    _emoji.clear();
    _codepoints.clear();
    _sprites.clear();
    _decorations.clear();
    _regularAscii.fillRange(0, _regularAscii.length);
    _budget.clearIndexes();
  }

  bool hasSprite(int codepoint) => _spriteFace.hasCodepoint(codepoint);

  Glyph _addEmoji(TextAtlasKey key, {int span = 1}) {
    final cacheKey = (
      text: key.text,
      bold: key.bold,
      italic: key.italic,
      span: span,
    );
    final existing = _emoji[cacheKey];
    if (existing != null) return existing;
    final bytes = key.text.length * 2;
    final glyph = _emojiLane.rasterizeEmoji(
      key.text,
      bold: key.bold,
      italic: key.italic,
      span: span,
      admit: _budget.canIndex(1, bytes),
    );
    if (glyph is AtlasEntry) {
      _emoji[cacheKey] = glyph;
      _budget.addIndex(1, bytes);
    }
    return glyph;
  }

  Glyph? _addSpriteCodepoint(int codepoint, {int span = 1}) {
    final glyph = _spriteFace.glyphFor(codepoint);
    if (glyph == null) return null;

    final key = (codepoint: codepoint, span: span);
    final existing = _sprites[key];
    if (existing != null) return existing;
    final result = _spriteLane.rasterizeSprite(
      glyph,
      span: span,
      admit: _budget.canIndex(1, 0),
    );
    if (result is AtlasEntry) {
      _sprites[key] = result;
      _budget.addIndex(1, 0);
    }
    return result;
  }

  Glyph _addText(
    TextAtlasKey key, {
    int span = 1,
    bool centerInFirstCell = false,
  }) {
    final cacheKey = (
      text: key.text,
      bold: key.bold,
      italic: key.italic,
      span: span,
      centerInFirstCell: centerInFirstCell,
    );
    final existing = _text[cacheKey];
    if (existing != null) return existing;
    final bytes = key.text.length * 2;
    final glyph = _textLane.rasterizeText(
      key.text,
      bold: key.bold,
      italic: key.italic,
      span: span,
      centerInFirstCell: centerInFirstCell,
      sourcePadding: _textSourcePadding(key.text, span: span),
      admit: _budget.canIndex(1, bytes),
    );
    if (glyph is AtlasEntry) {
      _text[cacheKey] = glyph;
      _budget.addIndex(1, bytes);
    }
    return glyph;
  }

  double _textSourcePadding(String text, {required int span}) {
    if (span != 1) return 0.0;

    final runes = text.runes.iterator;
    if (!runes.moveNext()) return 0.0;
    final codepoint = runes.current;
    if (runes.moveNext()) return 0.0;

    return codepoint >= 0x80 ? _singleCellTextSourcePadding : 0.0;
  }
}
