import 'package:libghostty/libghostty.dart';

import 'atlas/atlas.dart';
import 'codepoint_classification.dart';

/// Resolves terminal cell content to stable atlas pixels or owned direct ink.
///
/// This owns the text/emoji/built-in-sprite routing rules shared by normal
/// row rendering and block cursor glyph rendering. It does not decide where
/// or how the glyph is painted. Row and cursor builders own returned direct
/// glyphs; only admitted atlas entries are retained by this resolver.
final class CellContentResolver {
  final Atlas _atlas;
  var _lastCodepoint = -1;
  var _lastSpan = 0;
  var _lastCenterInFirstCell = false;
  var _lastBold = false;
  var _lastItalic = false;
  late AtlasEntry _lastEntry;

  CellContentResolver(this._atlas);

  Glyph? resolveCell({
    required String? content,
    required int codepoint,
    required int graphemeLength,
    required Style style,
    required int span,
    bool borrowedCell = false,
  }) {
    if (graphemeLength == 0) return null;

    if (borrowedCell && graphemeLength == 1) {
      return resolveCodepoint(
        codepoint,
        style: style,
        span: span,
        centerInFirstCell: true,
      );
    }
    if (graphemeLength == 1) {
      if (codepoint == 0x20) return null;
      if (_usesCodepointEntry(
        codepoint: codepoint,
        graphemeLength: graphemeLength,
        span: span,
      )) {
        return resolveCodepoint(codepoint, style: style, span: span);
      }
    }

    final cellContent = content ?? String.fromCharCode(codepoint);
    if (cellContent.isEmpty || cellContent == ' ') return null;

    return resolve(
      content: cellContent,
      codepoint: codepoint,
      graphemeLength: graphemeLength,
      style: style,
      span: span,
    );
  }

  Glyph? resolve({
    required String content,
    required int codepoint,
    required int graphemeLength,
    required Style style,
    required int span,
  }) {
    if (content.isEmpty || content == ' ') return null;

    if (_usesCodepointEntry(
      codepoint: codepoint,
      graphemeLength: graphemeLength,
      span: span,
    )) {
      return resolveCodepoint(codepoint, style: style, span: span);
    }

    return _atlas.add(
      (text: content, bold: style.bold, italic: style.italic),
      span: span,
      emoji: _paintsAsEmoji(content, codepoint, span: span),
    );
  }

  Glyph resolveCodepoint(
    int codepoint, {
    required Style style,
    int span = 1,
    bool centerInFirstCell = false,
  }) {
    if (codepoint == _lastCodepoint &&
        span == _lastSpan &&
        centerInFirstCell == _lastCenterInFirstCell &&
        style.bold == _lastBold &&
        style.italic == _lastItalic) {
      return _lastEntry;
    }

    final entry = _atlas.addCodepoint(
      codepoint,
      bold: style.bold,
      italic: style.italic,
      span: span,
      centerInFirstCell: centerInFirstCell,
    );
    if (entry is AtlasEntry) {
      _lastCodepoint = codepoint;
      _lastSpan = span;
      _lastCenterInFirstCell = centerInFirstCell;
      _lastBold = style.bold;
      _lastItalic = style.italic;
      _lastEntry = entry;
    }
    return entry;
  }

  bool _paintsAsEmoji(String content, int codepoint, {required int span}) {
    return content.contains('\uFE0F') ||
        (span == 2 && !isCjkCodepoint(codepoint));
  }

  bool _usesCodepointEntry({
    required int codepoint,
    required int graphemeLength,
    required int span,
  }) {
    if (graphemeLength != 1) return false;
    if (span == 1) return codepoint < 0x100000;
    return _atlas.hasSprite(codepoint) || isCjkCodepoint(codepoint);
  }
}
